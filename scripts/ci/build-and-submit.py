#!/usr/bin/env python3
"""End-to-end: bump version → archive → upload to ASC → submit for review.

Run from the repo root. Reads ASC creds from scripts/asc/.env (ASC_KEY_ID,
ASC_ISSUER_ID, ASC_KEY_PATH); the .p8 is symlinked into ~/.appstoreconnect/
private_keys/ on first run so altool can find it without env trickery.

Pipeline (default):
  1. Compute next MARKETING_VERSION + CURRENT_PROJECT_VERSION via the existing
     next-marketing-version.py / next-build-number.py helpers and write them
     into project.yml.
  2. xcodegen regenerate.
  3. xcodebuild archive (Release, generic/iOS).
  4. xcodebuild -exportArchive against scripts/asc/ExportOptions.plist.
  5. xcrun altool --upload-app to push the .ipa to ASC.
  6. Poll /v1/builds until the new build reaches processingState=VALID
     (typical 5–15 min).
  7. submit-to-review.py to cancel any in-flight submission and submit.

Flags let you skip phases for re-runs; see --help.
"""
import argparse
import os
import re
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASC_DIR = REPO / "scripts" / "asc"
CI_DIR = REPO / "scripts" / "ci"
sys.path.insert(0, str(ASC_DIR))
from asc import api, load_env, find_app_id_by_bundle  # noqa: E402

BUNDLE_ID = "com.andrewnguyen.bowpress"
SCHEME = "BowPress"
PROJECT_PATH = REPO / "BowPress.xcodeproj"
PROJECT_YML = REPO / "project.yml"
ARCHIVE_PATH = REPO / ".build" / "release" / "BowPress.xcarchive"
IPA_DIR = REPO / ".build" / "release"
EXPORT_OPTIONS = ASC_DIR / "ExportOptions.plist"


def log(msg):
    print(f"[build-and-submit] {msg}", flush=True)


def run(cmd, **kw):
    pretty = " ".join(cmd) if isinstance(cmd, list) else cmd
    log(f"$ {pretty}")
    subprocess.run(cmd, check=True, **kw)


def ensure_altool_key():
    """altool looks for the .p8 in ~/.appstoreconnect/private_keys/ and a few
    other standard paths. If our ASC_KEY_PATH points elsewhere, drop a symlink
    in the standard location so altool's auth Just Works."""
    load_env()
    key_id = os.environ.get("ASC_KEY_ID")
    src_str = os.environ.get("ASC_KEY_PATH", "")
    if not key_id or not src_str:
        sys.exit("ASC_KEY_ID / ASC_KEY_PATH missing from scripts/asc/.env")
    src = Path(src_str).expanduser()
    if not src.exists():
        sys.exit(f"ASC_KEY_PATH file not found: {src}")
    dst_dir = Path.home() / ".appstoreconnect" / "private_keys"
    dst = dst_dir / f"AuthKey_{key_id}.p8"
    if dst.exists() or dst.is_symlink():
        return
    dst_dir.mkdir(parents=True, exist_ok=True)
    log(f"linking {src} → {dst}")
    dst.symlink_to(src)


def next_marketing():
    return subprocess.run(
        [sys.executable, str(CI_DIR / "next-marketing-version.py")],
        check=True, capture_output=True, text=True,
    ).stdout.strip()


def next_build():
    return subprocess.run(
        [sys.executable, str(CI_DIR / "next-build-number.py")],
        check=True, capture_output=True, text=True,
    ).stdout.strip()


def read_current_versions():
    text = PROJECT_YML.read_text()
    mv = re.search(r'MARKETING_VERSION:\s*"([^"]+)"', text)
    cv = re.search(r'CURRENT_PROJECT_VERSION:\s*"([^"]+)"', text)
    if not mv or not cv:
        sys.exit("could not parse MARKETING_VERSION / CURRENT_PROJECT_VERSION from project.yml")
    return mv.group(1), cv.group(1)


def bump_project_yml(version, build):
    text = PROJECT_YML.read_text()
    new = re.sub(r'MARKETING_VERSION:\s*"[^"]*"', f'MARKETING_VERSION: "{version}"', text)
    new = re.sub(r'CURRENT_PROJECT_VERSION:\s*"[^"]*"', f'CURRENT_PROJECT_VERSION: "{build}"', new)
    if new == text:
        log("project.yml already at target version/build — no rewrite needed")
        return
    PROJECT_YML.write_text(new)
    log(f"bumped project.yml → MARKETING_VERSION={version}, CURRENT_PROJECT_VERSION={build}")


def regen_xcodeproj():
    run(["xcodegen", "generate"])


def archive():
    if ARCHIVE_PATH.exists():
        log(f"removing stale archive at {ARCHIVE_PATH}")
        subprocess.run(["rm", "-rf", str(ARCHIVE_PATH)], check=True)
    ARCHIVE_PATH.parent.mkdir(parents=True, exist_ok=True)
    run([
        "xcodebuild",
        "-project", str(PROJECT_PATH),
        "-scheme", SCHEME,
        "-configuration", "Release",
        "-destination", "generic/platform=iOS",
        "-archivePath", str(ARCHIVE_PATH),
        "archive",
    ])


def export_ipa():
    for old in IPA_DIR.glob("*.ipa"):
        log(f"removing stale ipa: {old.name}")
        old.unlink()
    run([
        "xcodebuild",
        "-exportArchive",
        "-archivePath", str(ARCHIVE_PATH),
        "-exportPath", str(IPA_DIR),
        "-exportOptionsPlist", str(EXPORT_OPTIONS),
    ])
    ipas = list(IPA_DIR.glob("*.ipa"))
    if not ipas:
        sys.exit("no .ipa produced from -exportArchive")
    log(f"exported {ipas[0].name}")
    return ipas[0]


def upload(ipa_path):
    run([
        "xcrun", "altool", "--upload-app",
        "--type", "ios",
        "-f", str(ipa_path),
        "--apiKey", os.environ["ASC_KEY_ID"],
        "--apiIssuer", os.environ["ASC_ISSUER_ID"],
    ])


def wait_for_processing(build_version, timeout_min=20):
    load_env()
    app_id = find_app_id_by_bundle(BUNDLE_ID)
    log(f"polling /v1/builds for build {build_version} → VALID (timeout {timeout_min} min)")
    deadline = time.time() + timeout_min * 60
    last_state = None
    while time.time() < deadline:
        builds = api(
            "GET",
            f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=10",
        )["data"]
        match = next(
            (b for b in builds if b["attributes"].get("version") == str(build_version)),
            None,
        )
        if match is None:
            if last_state != "missing":
                log(f"build {build_version} not yet visible; waiting...")
                last_state = "missing"
        else:
            state = match["attributes"].get("processingState")
            if state != last_state:
                log(f"build {build_version} state={state}")
                last_state = state
            if state == "VALID":
                return
            if state in {"FAILED", "INVALID"}:
                sys.exit(f"build {build_version} failed processing (state={state})")
        time.sleep(30)
    sys.exit(f"build {build_version} did not reach VALID within {timeout_min} min")


def submit(version, build, whats_new=None):
    cmd = [
        sys.executable, str(CI_DIR / "submit-to-review.py"),
        "--version-string", version,
        "--build-version", str(build),
    ]
    if whats_new:
        cmd += ["--whats-new", whats_new]
    run(cmd)


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--version", help="Override marketing version (e.g. 1.2.1).")
    ap.add_argument("--build", help="Override build number (e.g. 23).")
    ap.add_argument("--no-bump", action="store_true",
                    help="Don't rewrite project.yml; use whatever's there now.")
    ap.add_argument("--no-archive", action="store_true",
                    help="Skip archive + export; reuse the .ipa already at .build/release/.")
    ap.add_argument("--no-upload", action="store_true",
                    help="Stop after archive/export.")
    ap.add_argument("--no-submit", action="store_true",
                    help="Upload + wait for VALID, but don't submit for review.")
    ap.add_argument("--whats-new",
                    help="What's-new copy for the App Store listing (defaults to "
                         "submit-to-review.py's default).")
    args = ap.parse_args()

    load_env()
    ensure_altool_key()

    # Resolve target version + build.
    if args.no_bump:
        version, build = read_current_versions()
        log(f"--no-bump: using project.yml as-is → version={version} build={build}")
    else:
        version = args.version or next_marketing()
        build = args.build or next_build()
        bump_project_yml(version, build)

    log(f"target → version={version}  build={build}")

    if not args.no_archive:
        regen_xcodeproj()
        archive()
        ipa = export_ipa()
    else:
        ipas = list(IPA_DIR.glob("*.ipa"))
        if not ipas:
            sys.exit("no .ipa at .build/release/; drop --no-archive or run a full build")
        ipa = ipas[0]
        log(f"--no-archive: reusing {ipa.name}")

    if args.no_upload:
        log("--no-upload: stopping after archive/export.")
        return

    upload(ipa)
    wait_for_processing(build)

    if args.no_submit:
        log("--no-submit: build is VALID on ASC; stopping before review submission.")
        return

    submit(version, build, whats_new=args.whats_new)
    log(f"done — version {version} / build {build} submitted to App Review.")


if __name__ == "__main__":
    main()
