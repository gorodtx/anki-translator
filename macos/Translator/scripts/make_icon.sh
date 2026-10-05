#!/bin/sh
# Repack the optical PNG variants exported from the Penpot Mono icon system.
#
#   scripts/make_icon.sh [PREVIEW_DIR]
#   scripts/make_icon.sh --compile-appearances OUTPUT_DIR
#
# Every logical size has its own geometry, including Retina variants.
# With PREVIEW_DIR the master, 32 px and 16 px images are copied for review.
set -eu
cd "$(dirname "$0")/.."

# Resource-only compiler probe. It does not modify the curated ICNS or an app.
if [ "${1:-}" = "--compile-appearances" ]; then
  [ "$#" -eq 2 ] || { echo "expected appearance output directory" >&2; exit 2; }
  OUTPUT="$2"
  mkdir -p "$OUTPUT"
  OUTPUT="$(cd "$OUTPUT" && pwd)"
  xcrun --find actool > "$OUTPUT/compiler-path.txt"
  xcodebuild -version > "$OUTPUT/xcode-version.txt"
  xcrun --sdk macosx --show-sdk-version > "$OUTPUT/sdk-version.txt"
  if ! CORESVG_VERBOSE=1 xcrun actool Resources/AppIcon.icon \
    --compile "$OUTPUT" \
    --app-icon AppIcon \
    --platform macosx \
    --target-device mac \
    --minimum-deployment-target 26.0 \
    --output-partial-info-plist "$OUTPUT/partial-info.plist" \
    --output-format human-readable-text \
    --warnings --errors --notices > "$OUTPUT/actool.log" 2>&1; then
    cat "$OUTPUT/actool.log" >&2
    exit 1
  fi
  cat "$OUTPUT/actool.log"
  test -s "$OUTPUT/Assets.car"
  test -s "$OUTPUT/partial-info.plist"
  uv run --no-project python - "$OUTPUT" <<'PY'
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys

output = Path(sys.argv[1])
compiler_log = (output / "actool.log").read_text()
if "CoreSVG Error:" in compiler_log or "CoreSVG has logged an error" in compiler_log:
    raise SystemExit("native SVG parser errors; generated resources remain unaccepted")
resources = Path("Resources")
source_files = sorted((resources / "AppIcon.icon").rglob("*"))
source_files += sorted((resources / "AppIcon-layer-sources").rglob("*"))
source_files += [resources / "AppIcon-source.json", resources / "AppIcon.icns"]
source_hashes = {
    str(path.relative_to(resources)): hashlib.sha256(path.read_bytes()).hexdigest()
    for path in source_files
    if path.is_file()
}
source_digest = hashlib.sha256(
    json.dumps(source_hashes, sort_keys=True, separators=(",", ":")).encode()
).hexdigest()
with (output / "partial-info.plist").open("rb") as handle:
    partial = plistlib.load(handle)
generated_hashes = {
    str(path.relative_to(output)): hashlib.sha256(path.read_bytes()).hexdigest()
    for path in sorted(output.rglob("*"))
    if path.is_file()
}
manifest = {
    "version": 1,
    "source_sha256": source_digest,
    "source_files": source_hashes,
    "source_revision": subprocess.check_output(
        ["git", "rev-parse", "HEAD"], text=True
    ).strip(),
    "compiler": (output / "compiler-path.txt").read_text().strip(),
    "xcode": (output / "xcode-version.txt").read_text().strip(),
    "sdk": (output / "sdk-version.txt").read_text().strip(),
    "generated_files": generated_hashes,
    "partial_info": partial,
    "native_appearance_acceptance": "pending",
}
(output / "resource-provenance.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n"
)
print("Compiled resources recorded; native ClearDark appearance remains pending.")
PY
  exit 0
fi

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
