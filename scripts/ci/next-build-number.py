#!/usr/bin/env python3
"""Print the next CFBundleVersion for CI.

Queries App Store Connect for the latest build number across all of this app's
builds (any platform, any state) and prints `max(build_number) + 1`. Falls back
to the `git rev-list --count HEAD` counter if ASC returns nothing (e.g. very
first run before any upload).
"""
import os
import subprocess
import sys
from pathlib import Path

# Re-use the helpers from scripts/asc/asc.py.
sys.path.insert(0, str(Path(__file__).parent.parent / "asc"))
from asc import api, load_env, find_app_id_by_bundle  # noqa: E402


def main():
    load_env()
    bundle_id = os.environ.get("BUNDLE_ID", "com.andrewnguyen.bowpress")
    app_id = find_app_id_by_bundle(bundle_id)

    builds = api("GET", f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=200")["data"]
    highest = 0
    for b in builds:
        v = b["attributes"].get("version")
        try:
            n = int(v)
            if n > highest:
                highest = n
        except (TypeError, ValueError):
            continue

    if highest == 0:
        # No prior builds — fall back to git commit count.
        count = subprocess.run(
            ["git", "rev-list", "--count", "HEAD"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
        print(int(count) + 1)
    else:
        print(highest + 1)


if __name__ == "__main__":
    main()
