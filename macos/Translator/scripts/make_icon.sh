#!/bin/sh
# Rebuild Resources/AppIcon.icns from scripts/make_icon.swift.
#
#   scripts/make_icon.sh [PREVIEW_DIR]
#
# Draws the 1024 px master, scales it into an .iconset with sips, and packs the set with
# iconutil. With PREVIEW_DIR the master and the 32 px image are kept there to look at.
set -eu
cd "$(dirname "$0")/.."

WORK="$(mktemp -d "${TMPDIR:-/tmp}/translator-icon.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
SET="$WORK/AppIcon.iconset"
mkdir -p "$SET"

swift scripts/make_icon.swift "$WORK/master.png" 1024

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$WORK/master.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$WORK/master.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns -o Resources/AppIcon.icns "$SET"

if [ "${1:-}" != "" ]; then
  mkdir -p "$1"
  cp "$WORK/master.png" "$1/AppIcon-1024.png"
  cp "$SET/icon_32x32.png" "$1/AppIcon-32.png"
  cp "$SET/icon_16x16.png" "$1/AppIcon-16.png"
fi
echo Resources/AppIcon.icns
