#!/usr/bin/env python3
"""Finalize an App Store Connect listing for the current release.

Use when the CI's `submit-to-review.py` has already uploaded the build and
created the appStoreVersion but you need to replace the copy+screenshots
with fresh assets (e.g. the old version's copy contained angle-bracket
"markup" that Apple rejects, or you've redesigned the app and the copied-
forward screenshots are stale).

What it does:
  1. Finds the appStoreVersion with the given versionString.
  2. Locates the en-US localization (creates one if missing).
  3. Reads description.txt / promo.txt / keywords.txt / whats_new.txt
     from scripts/asc/metadata/ and strips anything that looks like
     HTML markup (Apple's validator rejects `<name@host>` etc.).
  4. PATCHes the localization with the sanitized text.
  5. Deletes existing screenshots in the iPhone 6.7"
     (APP_IPHONE_67) set and uploads the five PNGs from
     scripts/asc/screenshots/iphone_67/ in filename order.
  6. Leaves reviewDetail + submission alone — run submit-to-review.py
     (or click Submit in ASC) once everything looks right.

Usage:
  ./scripts/ci/finalize-listing.py --version-string 1.1.0
  ./scripts/ci/finalize-listing.py --version-string 1.1.0 --submit
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
META_DIR = Path(__file__).parent.parent / "asc" / "metadata"
SCREENSHOT_DIR = Path(__file__).parent.parent / "asc" / "screenshots" / "iphone_67"
SCREENSHOT_DISPLAY_TYPE = "APP_IPHONE_67"
DEMO_EMAIL = "applereview@bowpresssupport.test"
DEMO_PASSWORD = "AppleRev2026-Bow"
# ASC length ceilings (iOS).
MAX_DESCRIPTION = 4000
MAX_KEYWORDS = 100
MAX_PROMO = 170
MAX_WHATS_NEW = 4000


def log(msg):
    print(f"[finalize-listing] {msg}", flush=True)


# ---- text sanitizer -------------------------------------------------------
#
# Apple rejects anything it thinks is markup: HTML tags, entities, even
# things like `<name@host>` in Co-Authored-By lines. We strip:
#   - <...> segments
#   - bare angle brackets
#   - ASCII control chars except \n \r \t
# and collapse runs of blank lines.


_ANGLE_RE = re.compile(r"<[^>]*>")
_CTRL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")
_BLANK_RUN_RE = re.compile(r"\n{3,}")


def sanitize(text: str) -> str:
    s = _ANGLE_RE.sub("", text)
    s = s.replace("<", "").replace(">", "")
    s = _CTRL_RE.sub("", s)
    s = _BLANK_RUN_RE.sub("\n\n", s)
    return s.strip()


def read_metadata_file(name: str, max_len: int) -> str:
    path = META_DIR / name
    if not path.exists():
        log(f"metadata file missing: {path}")
        return ""
    raw = path.read_text()
    clean = sanitize(raw)
    if len(clean) > max_len:
        log(f"{name} is {len(clean)} chars, truncating to {max_len}")
        clean = clean[:max_len].rstrip()
    return clean


# ---- version + localization ----------------------------------------------


def find_version(app_id: str, version_string: str):
    versions = api(
        "GET",
        f"/apps/{app_id}/appStoreVersions?limit=20",
    )["data"]
    for v in versions:
        if v["attributes"].get("versionString") == version_string:
            return v
    sys.exit(f"version {version_string} not found on app {app_id}")


def find_or_create_en_us(version_id: str):
    locs = api(
        "GET",
        f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=10",
    )["data"]
    for loc in locs:
        if loc["attributes"].get("locale") == "en-US":
            return loc
    body = {"data": {
        "type": "appStoreVersionLocalizations",
        "attributes": {"locale": "en-US"},
        "relationships": {"appStoreVersion": {"data": {
            "type": "appStoreVersions", "id": version_id,
        }}},
    }}
    return api("POST", "/appStoreVersionLocalizations", json=body)["data"]


def patch_localization(loc_id: str):
    attrs = {
        "description": read_metadata_file("description.txt", MAX_DESCRIPTION),
        "keywords": read_metadata_file("keywords.txt", MAX_KEYWORDS),
        "promotionalText": read_metadata_file("promo.txt", MAX_PROMO),
        "whatsNew": read_metadata_file("whats_new.txt", MAX_WHATS_NEW),
    }
    # Drop empties so we don't overwrite a populated field with "".
    attrs = {k: v for k, v in attrs.items() if v}
    if not attrs:
        log("no metadata to patch")
        return
    api("PATCH", f"/appStoreVersionLocalizations/{loc_id}", json={
        "data": {
            "type": "appStoreVersionLocalizations",
            "id": loc_id,
            "attributes": attrs,
        },
    })
    log(f"patched localization: {', '.join(attrs.keys())}")


# ---- screenshots ----------------------------------------------------------


def find_or_create_screenshot_set(loc_id: str, display_type: str):
    sets = api(
        "GET",
        f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets?limit=20",
    )["data"]
    for s in sets:
        if s["attributes"].get("screenshotDisplayType") == display_type:
            return s
    body = {"data": {
        "type": "appScreenshotSets",
        "attributes": {"screenshotDisplayType": display_type},
        "relationships": {"appStoreVersionLocalization": {"data": {
            "type": "appStoreVersionLocalizations", "id": loc_id,
        }}},
    }}
    return api("POST", "/appScreenshotSets", json=body)["data"]


def clear_screenshots(set_id: str):
    shots = api("GET", f"/appScreenshotSets/{set_id}/appScreenshots?limit=20")["data"]
    for shot in shots:
        api("DELETE", f"/appScreenshots/{shot['id']}")
    log(f"cleared {len(shots)} old screenshots from set {set_id[:8]}")


def upload_screenshot(set_id: str, path: Path):
    data = path.read_bytes()
    reserve = api("POST", "/appScreenshots", json={
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileName": path.name, "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {
                "type": "appScreenshotSets", "id": set_id,
            }}},
        },
    })["data"]
    for op in reserve["attributes"]["uploadOperations"]:
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        r = requests.request(
            op["method"], op["url"],
            headers=headers, data=chunk, timeout=120,
        )
        r.raise_for_status()
    api("PATCH", f"/appScreenshots/{reserve['id']}", json={
        "data": {
            "type": "appScreenshots",
            "id": reserve["id"],
            "attributes": {
                "uploaded": True,
                "sourceFileChecksum": hashlib.md5(data).hexdigest(),
            },
        },
    })


def replace_screenshots(loc_id: str):
    pngs = sorted(SCREENSHOT_DIR.glob("*.png"))
    if not pngs:
        log(f"no screenshots in {SCREENSHOT_DIR} — skipping")
        return
    set_row = find_or_create_screenshot_set(loc_id, SCREENSHOT_DISPLAY_TYPE)
    clear_screenshots(set_row["id"])
    for png in pngs:
        log(f"uploading {png.name}")
        upload_screenshot(set_row["id"], png)
    log(f"uploaded {len(pngs)} new screenshots")


# ---- review detail --------------------------------------------------------


def ensure_review_detail(version_id: str, version_string: str):
    rd = api("GET", f"/appStoreVersions/{version_id}/appStoreReviewDetail")
    if rd.get("data"):
        rid = rd["data"]["id"]
    else:
        body = {"data": {
            "type": "appStoreReviewDetails",
            "relationships": {"appStoreVersion": {"data": {
                "type": "appStoreVersions", "id": version_id,
            }}},
        }}
        rid = api("POST", "/appStoreReviewDetails", json=body)["data"]["id"]

    notes = (
        f"BowPress v{version_string} — Reviewer test account:\n"
        f"  Email: {DEMO_EMAIL}\n"
        f"  Password: {DEMO_PASSWORD}\n\n"
        "Purchase flow:\n"
        "1. Sign in with the account above (or your own Apple ID via Sign in with Apple).\n"
        "2. Settings tab (bottom right) - Upgrade to Pro in Subscription section.\n"
        "3. Paywall presents Monthly ($4.99/mo, 1-month trial) and Annual ($49.99/yr, 1-month trial).\n"
        "4. Tap a plan - StoreKit sheet - complete sandbox purchase.\n"
        "5. Paywall closes; Settings reflects active subscription.\n\n"
        "5.1.1(v) note: BowPress is a personal data-logging app. Every session and "
        "configuration is tied to a user account for personalized analytics and "
        "cross-device sync. Sign in with Apple is the primary sign-in option.\n\n"
        "Paid Apps Agreement is active."
    )

    api("PATCH", f"/appStoreReviewDetails/{rid}", json={
        "data": {
            "type": "appStoreReviewDetails",
            "id": rid,
            "attributes": {
                "contactFirstName": "Andrew",
                "contactLastName": "Nguyen",
                "contactEmail": "bowpresssupport@gmail.com",
                "demoAccountRequired": True,
                "demoAccountName": DEMO_EMAIL,
                "demoAccountPassword": DEMO_PASSWORD,
                "notes": notes,
            },
        },
    })
    log("set App Review demo account + notes")


# ---- submit (optional) ----------------------------------------------------


def submit(app_id: str, version_id: str):
    # Reuse logic from submit-to-review.py's submit() — tolerant of the
    # "version not yet submittable" transient that sometimes follows a
    # fresh screenshot upload.
    r = api(
        "GET",
        f"/reviewSubmissions?filter[app]={app_id}"
        "&filter[state]=READY_FOR_REVIEW&limit=3",
    )
    if r.get("data"):
        rsid = r["data"][0]["id"]
        log(f"reusing READY_FOR_REVIEW submission {rsid[:8]}")
    else:
        body = {"data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {
                "type": "apps", "id": app_id,
            }}},
        }}
        rsid = api("POST", "/reviewSubmissions", json=body)["data"]["id"]
        log(f"created submission {rsid[:8]}")

    for attempt in range(20):
        try:
            api("POST", "/reviewSubmissionItems", json={
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {"data": {
                            "type": "reviewSubmissions", "id": rsid,
                        }},
                        "appStoreVersion": {"data": {
                            "type": "appStoreVersions", "id": version_id,
                        }},
                    },
                },
            })
            break
        except requests.HTTPError as e:
            txt = e.response.text
            if "not ready" in txt or "try again later" in txt:
                log(f"version not yet submittable ({attempt+1}/20)")
                time.sleep(15)
                continue
            raise

    r = api("PATCH", f"/reviewSubmissions/{rsid}", json={
        "data": {
            "type": "reviewSubmissions",
            "id": rsid,
            "attributes": {"submitted": True},
        },
    })
    log(f"submission state: {r['data']['attributes'].get('state')}")


# ---- main -----------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--version-string", required=True,
                    help="the appStoreVersion to finalize, e.g. 1.1.0")
    ap.add_argument("--submit", action="store_true",
                    help="after patching, submit the version to App Review")
    args = ap.parse_args()

    load_env()
    bundle_id = os.environ.get("BUNDLE_ID", BUNDLE_ID_DEFAULT)
    app_id = find_app_id_by_bundle(bundle_id)
    log(f"app_id={app_id} bundle={bundle_id} version={args.version_string}")

    version = find_version(app_id, args.version_string)
    log(f"version id={version['id']} state={version['attributes'].get('appStoreState')}")

    loc = find_or_create_en_us(version["id"])
    log(f"en-US localization id={loc['id']}")

    patch_localization(loc["id"])
    replace_screenshots(loc["id"])

    if args.submit:
        ensure_review_detail(version["id"], args.version_string)
        submit(app_id, version["id"])
        log("done — listing patched + submitted")
    else:
        log("done — listing patched. Run again with --submit once you've "
            "reviewed it in App Store Connect.")


if __name__ == "__main__":
    main()
