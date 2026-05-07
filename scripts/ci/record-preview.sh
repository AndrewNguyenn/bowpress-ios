#!/bin/bash
# Boot the iPhone 16 Pro Max simulator, build + install BowPress, launch it,
# and start a screen recording to .build/preview/raw.mov. Stop with Ctrl-C
# when you've captured your demo flow (aim ~25s; cap is 30s).
#
#   scripts/ci/record-preview.sh                 # default device
#   scripts/ci/record-preview.sh "iPhone 16"     # override device
set -e

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$REPO/.build/preview"
RAW="$OUT_DIR/raw.mov"
DEVICE="${1:-iPhone 16 Pro Max}"

mkdir -p "$OUT_DIR"
cd "$REPO"

echo "[record-preview] xcodegen generate"
xcodegen generate >/dev/null

echo "[record-preview] booting '$DEVICE'"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator
sleep 2

echo "[record-preview] building Debug for simulator"
xcodebuild \
  -project BowPress.xcodeproj \
  -scheme BowPress \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath .build/xcode \
  build 2>&1 | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" || true

APP_PATH=$(find .build/xcode/Build/Products/Debug-iphonesimulator -name "BowPress.app" | head -1)
if [ -z "$APP_PATH" ]; then
  echo "[record-preview] BowPress.app not found in .build/xcode — build failed?"
  exit 1
fi

xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.andrewnguyen.bowpress

# Clear any previous capture so the encode step doesn't pick up a stale file.
rm -f "$RAW"

cat <<EOF

[record-preview] recording → $RAW
[record-preview] PRESS CTRL-C in this terminal when finished.
[record-preview] Aim for ~25 seconds. Apple's hard cap is 30s; longer captures
                 are trimmed by encode-preview.sh.
[record-preview] Tips: open with the Analytics tab (it's the most visual),
                 swipe through Session log, then end on the active session
                 with the target face.

EOF

# recordVideo runs until SIGINT; it traps Ctrl-C and finalizes the .mov.
xcrun simctl io booted recordVideo --codec=h264 "$RAW"
