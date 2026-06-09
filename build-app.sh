#!/usr/bin/env bash
# build-app.sh
# Wrap the SwiftPM executable in a proper .app bundle so the system can attach
# an Info.plist (Calendar access prompt, LSUIElement for menu-bar-only mode, etc.)

set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="MissionControl"
BUNDLE_ID="us.noira.missioncontrol"
BUILD_DIR=".build"
APP_DIR="build/${APP_NAME}.app"

echo "→ Building $CONFIG configuration"
swift build -c "$CONFIG"

BIN="${BUILD_DIR}/${CONFIG}/${APP_NAME}"
if [[ ! -x "$BIN" ]]; then
    echo "✗ Binary not found at $BIN"
    exit 1
fi

echo "→ Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$BIN" "$APP_DIR/Contents/MacOS/${APP_NAME}"
cp Sources/MissionControl/Resources/Info.plist "$APP_DIR/Contents/Info.plist"

# Ad-hoc codesign so TCC accepts the bundle ID and prompts for Calendar access.
codesign --force --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "✓ Built $APP_DIR"
echo "  Launch with:  open $APP_DIR"
