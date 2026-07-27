#!/usr/bin/env bash
# Assembles build/prbar.app from the SwiftPM executable. Works with Command Line Tools
# only — no Xcode project, no xcodebuild.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${CONFIG:-release}"
VERSION="${VERSION:-0.0.0-dev}"
APP="$ROOT/build/prbar.app"

swift build -c "$CONFIG" --package-path "$ROOT"
BIN_PATH="$(swift build -c "$CONFIG" --package-path "$ROOT" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/prbar" "$APP/Contents/MacOS/prbar"
sed "s/__VERSION__/$VERSION/g" "$ROOT/Resources/Info.plist" > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature: enough for UNUserNotificationCenter and the Keychain to accept the app,
# and it gives the bundle a stable identity across rebuilds.
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
codesign --force --sign "$CODESIGN_IDENTITY" --identifier dev.mtib.prbar "$APP"
codesign --verify --verbose=1 "$APP"

echo "built $APP (version $VERSION)"
