#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c debug
BIN_DIR="$(swift build -c debug --show-bin-path)"
APP="$PWD/build/ArcLakeM0.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/ArcLakeM0" "$APP/Contents/MacOS/ArcLakeM0"
cp Packaging/M0-Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --entitlements Packaging/M0.entitlements "$APP"
codesign --verify --strict "$APP"
printf '\nBuilt %s\n' "$APP"
