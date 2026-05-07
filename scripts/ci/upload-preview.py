#!/usr/bin/env python3
"""Upload an App Preview video to a localization on App Store Connect.

Apple's App Store search results render a richer auto-playing preview row
when a version has an App Preview video attached. Static screenshots alone
get the compact (no-preview) treatment in many search layouts. This script
pushes a single preview file into the matching slot on a given version's
localization.

Usage:
  python3 scripts/ci/upload-preview.py path/to/preview.mp4 \\
    --version 1.2.2 \\
    [--locale en-US] [--preview-type APP_IPHONE_67] \\
    [--frame-time 00:00:03] [--replace]

Flow:
  1. Resolve app + version + locale from the ASC API.
  2. Find or create an appPreviewSets entry for the requested previewType.
  3. POST /appPreviews to reserve an upload (returns chunked uploadOperations).
  4. PUT each chunk to the returned S3-style URLs.
  5. PATCH /appPreviews/{id} with uploaded=true, sourceFileChecksum (md5),
     and previewFrameTimeCode (HH:MM:SS — sets the still thumbnail).

Auth comes from scripts/asc/.env (same as the rest of the ASC tooling).
"""
import argparse
import hashlib
import sys
from pathlib import Path

import requests

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts" / "asc"))
from asc import api, load_env, find_app_id_by_bundle  # noqa: E402

BUNDLE_ID = "com.andrewnguyen.bowpress"


def find_version(app_id: str, version_string: str) -> dict:
    versions = api("GET", f"/apps/{app_id}/appStoreVersions?limit=50")["data"]
    for v in versions:
        if v["attributes"].get("versionString") == version_string:
            return v
    sys.exit(f"version {version_string} not found on app {app_id}")


def find_locale(version_id: str, locale: str) -> dict:
    locs = api(
        "GET",
        f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=20",
    )["data"]
    for loc in locs:
        if loc["attributes"].get("locale") == locale:
            return loc
    available = [l["attributes"].get("locale") for l in locs]
    sys.exit(f"locale {locale} not found on version {version_id} (have: {available})")


def find_or_create_set(loc_id: str, preview_type: str) -> dict:
    sets = api(
        "GET",
        f"/appStoreVersionLocalizations/{loc_id}/appPreviewSets?limit=20",
    )["data"]
    existing = next(
        (s for s in sets if s["attributes"].get("previewType") == preview_type),
        None,
    )
    if existing:
        print(f"[upload-preview] reusing previewSet {existing['id']} ({preview_type})")
        return existing
    body = {"data": {
        "type": "appPreviewSets",
        "attributes": {"previewType": preview_type},
        "relationships": {"appStoreVersionLocalization": {"data": {
            "type": "appStoreVersionLocalizations", "id": loc_id,
        }}},
    }}
    created = api("POST", "/appPreviewSets", json=body)["data"]
    print(f"[upload-preview] created previewSet {created['id']} ({preview_type})")
    return created


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("file", help="Path to encoded .mp4 / .mov / .m4v")
    ap.add_argument("--version", required=True, help="Marketing version, e.g. 1.2.2")
    ap.add_argument("--locale", default="en-US")
    ap.add_argument("--preview-type", default="APP_IPHONE_67",
                    help="ASC previewType. Default APP_IPHONE_67 covers 6.7\" and 6.9\" iPhones.")
    ap.add_argument("--frame-time", default="00:00:03",
                    help="Still-frame timecode shown in search before video plays. HH:MM:SS")
    ap.add_argument("--replace", action="store_true",
                    help="If a preview already exists in this set, delete it first.")
    args = ap.parse_args()

    f = Path(args.file).expanduser().resolve()
    if not f.exists():
        sys.exit(f"file not found: {f}")
    suffix = f.suffix.lower()
    mime = {
        ".mp4": "video/mp4",
        ".m4v": "video/mp4",
        ".mov": "video/quicktime",
    }.get(suffix)
    if mime is None:
        sys.exit(f"unsupported extension {suffix}; use .mp4, .m4v, or .mov")

    load_env()
    app_id = find_app_id_by_bundle(BUNDLE_ID)
    version = find_version(app_id, args.version)
    state = version["attributes"].get("appStoreState")
    print(f"[upload-preview] app={app_id} version={args.version} state={state}")

    loc = find_locale(version["id"], args.locale)
    target_set = find_or_create_set(loc["id"], args.preview_type)

    existing = api(
        "GET",
        f"/appPreviewSets/{target_set['id']}/appPreviews?limit=20",
    )["data"]
    if existing:
        if args.replace:
            for p in existing:
                api("DELETE", f"/appPreviews/{p['id']}")
                print(f"[upload-preview] deleted existing preview {p['id']}")
        else:
            sys.exit(
                f"set already has {len(existing)} preview(s); pass --replace to overwrite"
            )

    data = f.read_bytes()
    print(f"[upload-preview] uploading {f.name} ({len(data):,} bytes, {mime})")

    reserve = api("POST", "/appPreviews", json={
        "data": {
            "type": "appPreviews",
            "attributes": {
                "fileName": f.name,
                "fileSize": len(data),
                "mimeType": mime,
            },
            "relationships": {"appPreviewSet": {"data": {
                "type": "appPreviewSets", "id": target_set["id"],
            }}},
        },
    })["data"]
    ops = reserve["attributes"]["uploadOperations"]
    print(f"[upload-preview] reserved {reserve['id']} — {len(ops)} chunk(s)")

    for i, op in enumerate(ops, 1):
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        r = requests.request(
            op["method"], op["url"], headers=headers, data=chunk, timeout=300,
        )
        r.raise_for_status()
        print(f"[upload-preview]   chunk {i}/{len(ops)}: {len(chunk):,} bytes")

    api("PATCH", f"/appPreviews/{reserve['id']}", json={
        "data": {
            "type": "appPreviews",
            "id": reserve["id"],
            "attributes": {
                "uploaded": True,
                "sourceFileChecksum": hashlib.md5(data).hexdigest(),
                "previewFrameTimeCode": args.frame_time,
            },
        },
    })
    print(
        f"[upload-preview] committed (frame={args.frame_time}). "
        "Apple will process the video for a few minutes; check ASC."
    )


if __name__ == "__main__":
    main()
