#!/bin/sh
# Repack the optical PNG variants exported from the Penpot Mono icon system.
#
#   scripts/make_icon.sh [PREVIEW_DIR]
#
# Every logical size has its own geometry, including Retina variants.
# With PREVIEW_DIR the master, 32 px and 16 px images are copied for review.
set -eu
cd "$(dirname "$0")/.."

ICON_SOURCE="../../design/translator-icon/macOS"
ICON_SET="$ICON_SOURCE/AppIcon.iconset"
for size in 16 32 128 256 512; do
  test -f "$ICON_SET/icon_${size}x${size}.png"
  test -f "$ICON_SET/icon_${size}x${size}@2x.png"
done
node ../../design/translator-icon/pack-icns.mjs "$ICON_SET" Resources/AppIcon.icns >/dev/null

if [ "${1:-}" != "" ]; then
  mkdir -p "$1"
  cp "$ICON_SOURCE/png/light/1024.png" "$1/AppIcon-1024.png"
  cp "$ICON_SET/icon_32x32.png" "$1/AppIcon-32.png"
  cp "$ICON_SET/icon_16x16.png" "$1/AppIcon-16.png"
fi
echo Resources/AppIcon.icns
