#!/bin/bash
set -e

echo "Generating Xcode project..."
xcodegen generate

echo "Opening BowPress.xcodeproj..."
open BowPress.xcodeproj

echo "Booting iPhone 16 simulator..."
xcrun simctl boot "iPhone 16" 2>/dev/null || true
open -a Simulator

echo "Building for simulator..."
xcodebuild \
  -project BowPress.xcodeproj \
  -scheme BowPress \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath .build/xcode \
  build | xcpretty 2>/dev/null || xcodebuild \
  -project BowPress.xcodeproj \
  -scheme BowPress \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath .build/xcode \
  build 2>&1 | grep -E "error:|Build succeeded|BUILD FAILED"

echo "Installing and launching app..."
APP_PATH=$(find .build/xcode/Build/Products/Debug-iphonesimulator -name "BowPress.app" | head -1)

if [ -z "$APP_PATH" ]; then
  echo "App bundle not found. Use Cmd+R in Xcode to launch."
  exit 1
fi

xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.andrewnguyen.bowpress

echo "BowPress is running on the simulator."
