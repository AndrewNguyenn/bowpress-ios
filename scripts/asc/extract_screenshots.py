#!/usr/bin/env python3
"""Extract UI-test screenshot attachments from an xcresult bundle to PNG files.

Usage: ./extract_screenshots.py <path/to/result.xcresult> <output-dir>
"""
import json
import re
import subprocess
import sys
from pathlib import Path


def run(*cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    xcresult = sys.argv[1]
    out_dir = Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)

    # find the test id
    tests = json.loads(run("xcrun", "xcresulttool", "get", "test-results", "tests", "--path", xcresult))

    def walk_tests(node):
        for child in node.get("children", []):
            yield from walk_tests(child)
        if node.get("nodeType") == "Test Case":
            yield node["nodeIdentifier"]

    test_ids = list({tid for root in tests["testNodes"] for tid in walk_tests(root)})

    count = 0
    for tid in test_ids:
        activities = json.loads(run(
            "xcrun", "xcresulttool", "get", "test-results", "activities",
            "--path", xcresult, "--test-id", tid,
        ))
        for att in find_attachments(activities):
            name = clean_name(att["name"])
            target = out_dir / name
            subprocess.run([
                "xcrun", "xcresulttool", "export", "object", "--legacy",
                "--path", xcresult, "--id", att["payloadId"],
                "--type", "file", "--output-path", str(target),
            ], check=True)
            print(f"  {target}")
            count += 1

    print(f"\nextracted {count} screenshots to {out_dir}")


def find_attachments(node):
    if isinstance(node, dict):
        if isinstance(node.get("attachments"), list):
            for a in node["attachments"]:
                if "payloadId" in a and "name" in a:
                    yield a
        for v in node.values():
            yield from find_attachments(v)
    elif isinstance(node, list):
        for item in node:
            yield from find_attachments(item)


def clean_name(raw):
    """Strip trailing _N_UUID.png added by the test runner."""
    m = re.match(r"^(.+?)_\d+_[A-F0-9-]+\.png$", raw)
    return f"{m.group(1)}.png" if m else raw


if __name__ == "__main__":
    main()
