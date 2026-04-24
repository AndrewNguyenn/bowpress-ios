#!/usr/bin/env python3
"""Print the MARKETING_VERSION that TestFlight builds should be uploaded as.

Apple closes a version train (e.g. 1.0.1) to new build uploads as soon as
that version is approved (READY_FOR_SALE). A push-to-main workflow that always
uses whatever's in project.yml will fail until someone manually bumps the
version string. This script queries ASC and picks the right value:

- If the highest existing versionString is in an editable state
  (anything other than READY_FOR_SALE), reuse it so iterative TestFlight
  uploads accumulate against the same pending version.
- Otherwise (highest is READY_FOR_SALE), return that version with its patch
  incremented by 1.
"""
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "asc"))
from asc import api, load_env, find_app_id_by_bundle  # noqa: E402


LIVE_STATES = {"READY_FOR_SALE", "REPLACED_WITH_NEW_VERSION", "REMOVED_FROM_SALE"}


def parse(v: str) -> tuple[int, ...]:
    return tuple(int(x) for x in v.split("."))


def bump_patch(v: str) -> str:
    parts = list(parse(v))
    while len(parts) < 3:
        parts.append(0)
    parts[2] += 1
    return ".".join(str(p) for p in parts)


def main():
    load_env()
    bundle_id = os.environ.get("BUNDLE_ID", "com.andrewnguyen.bowpress")
    app_id = find_app_id_by_bundle(bundle_id)

    versions = api("GET", f"/apps/{app_id}/appStoreVersions?limit=20")["data"]
    if not versions:
        print("1.0.0")
        return

    # Apple returns in created order; re-sort by semver.
    versions.sort(
        key=lambda v: parse(v["attributes"]["versionString"]),
        reverse=True,
    )
    top = versions[0]
    version_string = top["attributes"]["versionString"]
    state = top["attributes"].get("appStoreState", "")

    if state in LIVE_STATES:
        print(bump_patch(version_string))
    else:
        print(version_string)


if __name__ == "__main__":
    main()
