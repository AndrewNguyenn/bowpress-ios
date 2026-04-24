#!/usr/bin/env python3
"""Submit an already-uploaded build to App Review.

Called from the release.yml GitHub Actions workflow after altool finishes
the TestFlight upload. Handles the full ASC submission dance:

  1. Cancels any WAITING_FOR_REVIEW / IN_REVIEW / UNRESOLVED_ISSUES review
     submissions for this app (Apple only allows one at a time).
  2. Polls until the target build reaches processingState=VALID (altool's
     upload is async; ASC processes in 1-15 min).
  3. Finds or creates an appStoreVersion with the requested versionString.
  4. Links the build to the version.
  5. Copies localization + screenshots from the most-recent prior version
     (so reviewers aren't blocked on metadata).
  6. Ensures appStoreReviewDetail has the reviewer demo account.
  7. Creates a reviewSubmission, attaches the version, PATCHes submitted=true.

Usage:
  scripts/ci/submit-to-review.py --version-string 1.0.2 --build-version 8

Environment:
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH  (required — used by scripts/asc/asc.py)
  BUNDLE_ID                                (optional, default com.andrewnguyen.bowpress)
"""
import argparse
import hashlib
import os
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "asc"))
from asc import api, load_env, find_app_id_by_bundle  # noqa: E402
import requests  # noqa: E402


BUNDLE_ID_DEFAULT = "com.andrewnguyen.bowpress"
DEMO_EMAIL = "applereview@bowpresssupport.test"
DEMO_PASSWORD = "AppleRev2026-Bow"
CANCELLABLE_STATES = {"WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"}

# Apple's validator rejects anything it reads as markup (HTML tags, e.g.
# `<name@host>` in Co-Authored-By lines). Strip angle-bracket segments +
# bare angles + ASCII control chars so commit-message-derived whats-new
# doesn't 409 the localization PATCH.
_ANGLE_RE = re.compile(r"<[^>]*>")
_CTRL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")
_BLANK_RUN_RE = re.compile(r"\n{3,}")


def sanitize_for_asc(text: str) -> str:
    s = _ANGLE_RE.sub("", text)
    s = s.replace("<", "").replace(">", "")
    s = _CTRL_RE.sub("", s)
    s = _BLANK_RUN_RE.sub("\n\n", s)
    return s.strip()


def log(msg):
    print(f"[submit-to-review] {msg}", flush=True)


def find_build(app_id, build_version):
    """Find the build row for the uploaded CFBundleVersion. Poll up to 15 min."""
    for attempt in range(30):
        builds = api("GET", f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=20")["data"]
        for b in builds:
            if b["attributes"].get("version") == str(build_version):
                state = b["attributes"].get("processingState")
                if state == "VALID":
                    log(f"build {build_version} VALID (id={b['id']})")
                    return b
                log(f"build {build_version} state={state}, waiting...")
                break
        else:
            log(f"build {build_version} not yet visible in ASC, waiting...")
        time.sleep(30)
    sys.exit(f"build {build_version} never reached VALID after 15 min")


def cancel_in_flight_submissions(app_id):
    for state in CANCELLABLE_STATES:
        r = api("GET", f"/reviewSubmissions?filter[app]={app_id}&filter[state]={state}&limit=5")
        for d in r.get("data", []):
            sid = d["id"]
            try:
                api("PATCH", f"/reviewSubmissions/{sid}", json={
                    "data": {"type": "reviewSubmissions", "id": sid, "attributes": {"canceled": True}},
                })
                log(f"cancelled submission {sid[:8]} (was {state})")
            except requests.HTTPError as e:
                log(f"cancel {sid[:8]} failed: {e.response.text[:200]}")

    # Wait out the CANCELING transition.
    for _ in range(30):
        r = api("GET", f"/reviewSubmissions?filter[app]={app_id}&filter[state]=CANCELING&limit=5")
        if not r.get("data"):
            return
        time.sleep(5)
    log("cancellations still pending after 150s — continuing anyway")


def find_or_create_version(app_id, version_string):
    versions = api("GET", f"/apps/{app_id}/appStoreVersions?limit=10")["data"]
    for v in versions:
        if v["attributes"].get("versionString") == version_string:
            log(f"reusing existing version {version_string} (id={v['id']}, state={v['attributes'].get('appStoreState')})")
            return v
    body = {"data": {
        "type": "appStoreVersions",
        "attributes": {"platform": "IOS", "versionString": version_string, "releaseType": "AFTER_APPROVAL"},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
    }}
    v = api("POST", "/appStoreVersions", json=body)["data"]
    log(f"created version {version_string} (id={v['id']})")
    return v


def copy_localization(app_id, target_version_id, whats_new):
    """Fill en-US localization on the new version from the most recent prior version."""
    vers = api("GET", f"/apps/{app_id}/appStoreVersions?limit=10")["data"]
    # Pick a source: any version that isn't the target with en-US localization populated.
    source = None
    for v in vers:
        if v["id"] == target_version_id:
            continue
        locs = api("GET", f"/appStoreVersions/{v['id']}/appStoreVersionLocalizations?limit=5")["data"]
        for loc in locs:
            if loc["attributes"].get("locale") == "en-US" and loc["attributes"].get("description"):
                source = loc
                break
        if source:
            break

    # The new version auto-creates an empty en-US localization when it's POSTed.
    target_locs = api("GET", f"/appStoreVersions/{target_version_id}/appStoreVersionLocalizations?limit=5")["data"]
    target = next((l for l in target_locs if l["attributes"].get("locale") == "en-US"), None)
    if not target:
        # Create one.
        body = {"data": {
            "type": "appStoreVersionLocalizations",
            "attributes": {"locale": "en-US"},
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": target_version_id}}},
        }}
        target = api("POST", "/appStoreVersionLocalizations", json=body)["data"]

    if source:
        attrs = {
            k: source["attributes"].get(k)
            for k in ("description", "keywords", "promotionalText", "supportUrl", "marketingUrl")
            if source["attributes"].get(k)
        }
        # If a sibling whats_new.txt exists, prefer that over the raw commit
        # message — the commit message tends to contain `<noreply@...>`
        # Co-Authored-By lines that Apple rejects as markup.
        whats_new_txt = Path(__file__).parent.parent / "asc" / "metadata" / "whats_new.txt"
        if whats_new_txt.exists() and whats_new_txt.read_text().strip():
            attrs["whatsNew"] = sanitize_for_asc(whats_new_txt.read_text())
        else:
            attrs["whatsNew"] = sanitize_for_asc(whats_new)
        api("PATCH", f"/appStoreVersionLocalizations/{target['id']}", json={
            "data": {"type": "appStoreVersionLocalizations", "id": target["id"], "attributes": attrs},
        })
        log(f"copied localization from prior version into {target['id']}")
        # Now copy screenshots.
        copy_screenshots(source["id"], target["id"])
    else:
        log("no prior localization found to copy — new version will need manual metadata")


def copy_screenshots(source_loc_id, target_loc_id):
    """Download each screenshot from source localization, upload to target."""
    source_sets = api("GET", f"/appStoreVersionLocalizations/{source_loc_id}/appScreenshotSets?limit=10")["data"]
    for sset in source_sets:
        display_type = sset["attributes"].get("screenshotDisplayType")
        # Create (or reuse) the matching set on target.
        existing = api("GET", f"/appStoreVersionLocalizations/{target_loc_id}/appScreenshotSets?limit=10")["data"]
        target_set = next((s for s in existing if s["attributes"].get("screenshotDisplayType") == display_type), None)
        if not target_set:
            body = {"data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {"appStoreVersionLocalization": {"data": {
                    "type": "appStoreVersionLocalizations", "id": target_loc_id,
                }}},
            }}
            target_set = api("POST", "/appScreenshotSets", json=body)["data"]

        # Each screenshot needs to be downloaded from source's asset URL and reuploaded.
        # Apple doesn't offer a server-side copy. Skip if target already has any screenshots
        # (idempotent for partial failures).
        target_shots = api("GET", f"/appScreenshotSets/{target_set['id']}/appScreenshots?limit=20")["data"]
        if target_shots:
            log(f"screenshots already present for {display_type} — skipping copy")
            continue

        shots = api("GET", f"/appScreenshotSets/{sset['id']}/appScreenshots?limit=20")["data"]
        for shot in shots:
            asset = shot["attributes"].get("imageAsset", {})
            template = asset.get("templateUrl")
            if not template:
                continue
            # Download at source resolution.
            w, h = asset.get("width"), asset.get("height")
            url = template.replace("{w}", str(w)).replace("{h}", str(h)).replace("{f}", "png")
            data = requests.get(url, timeout=60).content

            file_name = shot["attributes"].get("fileName", f"screen-{shot['id']}.png")
            reserve = api("POST", "/appScreenshots", json={
                "data": {
                    "type": "appScreenshots",
                    "attributes": {"fileName": file_name, "fileSize": len(data)},
                    "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": target_set["id"]}}},
                },
            })["data"]
            for op in reserve["attributes"]["uploadOperations"]:
                headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
                chunk = data[op["offset"]:op["offset"] + op["length"]]
                r = requests.request(op["method"], op["url"], headers=headers, data=chunk, timeout=120)
                r.raise_for_status()
            api("PATCH", f"/appScreenshots/{reserve['id']}", json={
                "data": {"type": "appScreenshots", "id": reserve["id"], "attributes": {
                    "uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest(),
                }},
            })
        log(f"copied {len(shots)} screenshots for {display_type}")


def link_build(version_id, build_id):
    api("PATCH", f"/appStoreVersions/{version_id}", json={
        "data": {"type": "appStoreVersions", "id": version_id,
                 "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}},
    })
    log(f"linked build {build_id} to version {version_id}")


def ensure_review_detail(version_id, version_string):
    rd = api("GET", f"/appStoreVersions/{version_id}/appStoreReviewDetail")
    if rd.get("data"):
        rid = rd["data"]["id"]
    else:
        body = {"data": {"type": "appStoreReviewDetails",
                         "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}}
        rid = api("POST", "/appStoreReviewDetails", json=body)["data"]["id"]

    notes = f"""BowPress v{version_string} — Reviewer test account:
  Email: {DEMO_EMAIL}
  Password: {DEMO_PASSWORD}

Purchase flow:
1. Sign in with the account above (or your own Apple ID via Sign in with Apple).
2. Settings tab (bottom right) -> "Upgrade to Pro" in Subscription section.
3. Paywall presents two plans: Monthly ($4.99/mo, 1-month trial) and Annual ($49.99/yr, 1-month trial).
4. Tap a plan -> StoreKit sheet -> complete sandbox purchase.
5. Paywall closes; Settings reflects active subscription.

5.1.1(v) note: BowPress is a personal data-logging app. Every session and configuration is tied to a user account for personalized analytics and cross-device sync. Sign in with Apple is the primary sign-in option.

Paid Apps Agreement is active."""

    api("PATCH", f"/appStoreReviewDetails/{rid}", json={
        "data": {"type": "appStoreReviewDetails", "id": rid, "attributes": {
            "contactFirstName": "Andrew", "contactLastName": "Nguyen",
            "contactEmail": "bowpresssupport@gmail.com",
            "demoAccountRequired": True,
            "demoAccountName": DEMO_EMAIL,
            "demoAccountPassword": DEMO_PASSWORD,
            "notes": notes,
        }},
    })
    log("set App Review demo account + notes")


def submit(app_id, version_id):
    body = {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
                     "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}}
    # Retry if there's a lingering READY_FOR_REVIEW we can reuse.
    r = api("GET", f"/reviewSubmissions?filter[app]={app_id}&filter[state]=READY_FOR_REVIEW&limit=3")
    if r.get("data"):
        rsid = r["data"][0]["id"]
        log(f"reusing READY_FOR_REVIEW submission {rsid[:8]}")
    else:
        rsid = api("POST", "/reviewSubmissions", json=body)["data"]["id"]
        log(f"created submission {rsid[:8]}")

    for attempt in range(20):
        try:
            api("POST", "/reviewSubmissionItems", json={
                "data": {"type": "reviewSubmissionItems",
                         "relationships": {
                             "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": rsid}},
                             "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                         }},
            })
            break
        except requests.HTTPError as e:
            txt = e.response.text
            if "not ready" in txt or "try again later" in txt:
                log(f"version not yet submittable (attempt {attempt+1}/20), waiting 15s")
                time.sleep(15)
                continue
            raise

    r = api("PATCH", f"/reviewSubmissions/{rsid}", json={
        "data": {"type": "reviewSubmissions", "id": rsid, "attributes": {"submitted": True}},
    })
    log(f"submission state: {r['data']['attributes'].get('state')}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--version-string", required=True, help="e.g. 1.0.2")
    ap.add_argument("--build-version", required=True, help="CFBundleVersion as an int string, e.g. 8")
    ap.add_argument("--whats-new", default="Bug fixes and performance improvements.",
                    help="Text for the 'What's New in This Version' field")
    args = ap.parse_args()

    load_env()
    bundle_id = os.environ.get("BUNDLE_ID", BUNDLE_ID_DEFAULT)
    app_id = find_app_id_by_bundle(bundle_id)

    log(f"app_id={app_id} bundle={bundle_id} version={args.version_string} build={args.build_version}")

    build = find_build(app_id, args.build_version)
    cancel_in_flight_submissions(app_id)
    version = find_or_create_version(app_id, args.version_string)
    link_build(version["id"], build["id"])
    copy_localization(app_id, version["id"], args.whats_new)
    ensure_review_detail(version["id"], args.version_string)
    submit(app_id, version["id"])

    log("done — version submitted to App Review")


if __name__ == "__main__":
    main()
