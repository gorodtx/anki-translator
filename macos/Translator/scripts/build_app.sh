#!/bin/sh
# Build Translator.app from the SwiftPM executable.
#
# SwiftPM emits a bare binary; macOS needs a bundle for LSUIElement (menu-bar only),
# NSServices (the "Translate with Translator" item on any selection) and code signing.
#
#   scripts/build_app.sh [debug|release]   -> .build/Translator.app
set -eu
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_NAME="Translator"
# The one identity the project uses: the D-Bus name on Linux and the bundle
# built by scripts/build_macos_app.sh both say
# this. Two identifiers would mean two separate Accessibility grants, so a user
# would authorise the dev build and be asked again by the installed app.
BUNDLE_ID="com.translator.desktop"
APP_BUILD="${TRANSLATOR_APP_BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
OUT=".build/${APP_NAME}.app"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/${APP_NAME}"
[ -x "$BIN" ] || { echo "binary not found: $BIN" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "$OUT/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_BUILD" "$OUT/Contents/Info.plist"
# Verify the exact compiler inputs and pack CAR, optical fallback and template masks.
uv run --no-project python ../../scripts/macos_bundle_manifest.py --pack-artwork "$OUT"
printf 'APPL????' > "$OUT/Contents/PkgInfo"

# Ad-hoc signature: enough for local runs (a Developer ID identity is needed for
# distribution and notarisation).
codesign --force --sign - --identifier "$BUNDLE_ID" --timestamp=none "$OUT" >/dev/null 2>&1 || \
  codesign --force --sign - "$OUT"
codesign --verify --deep --strict "$OUT"

echo "$OUT"
