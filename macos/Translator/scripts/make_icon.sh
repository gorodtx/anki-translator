#!/bin/sh
# Repack the optical PNG variants exported from the Penpot Mono icon system.
#
#   scripts/make_icon.sh [PREVIEW_DIR]
#   scripts/make_icon.sh --compile-appearances OUTPUT_DIR
#   scripts/make_icon.sh --compile-appearance-diagnostics OUTPUT_DIR
#
# Every logical size has its own geometry, including Retina variants.
# With PREVIEW_DIR the master, 32 px and 16 px images are copied for review.
set -eu
cd "$(dirname "$0")/.."

# Two isolated compiler cases. Neither modifies the production icon input.
if [ "${1:-}" = "--compile-appearance-diagnostics" ]; then
  [ "$#" -eq 2 ] || { echo "expected diagnostic output directory" >&2; exit 2; }
  mkdir -p "$2"
  OUTPUT="$(cd "$2" && pwd)"
  uv run --no-project python - "$OUTPUT" <<'PY'
import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

output = Path(sys.argv[1])
resources = Path("Resources")
baseline = resources / "AppIcon-diagnostics/known-valid-icon.json"
known = json.loads(baseline.read_text())
for case in ("control", "preferred"):
    target = output / case / "inputs/Resources"
    target.mkdir(parents=True)
    for folder in ("AppIcon.icon", "AppIcon-layer-sources"):
        shutil.copytree(resources / folder, target / folder)
    shutil.copy2(resources / "AppIcon.icns", target / "AppIcon.icns")
    config = copy.deepcopy(known)
    config["groups"].reverse()
    for group in config["groups"]:
        group["layers"].reverse()
        if case == "preferred":
            for layer in group["layers"]:
                default = layer.pop("fill")
                layer["fill-specializations"] = [
                    {"value": default},
                    *[
                        item
                        for item in layer["fill-specializations"]
                        if item.get("appearance") == "dark"
                    ],
                ]
    config_file = target / "AppIcon.icon/icon.json"
    config_file.write_text(json.dumps(config, indent=2) + "\n")
    manifest = json.loads((resources / "AppIcon-source.json").read_text())
    manifest["diagnostic_variant"] = {
        "case": case,
        "baseline_revision": "305a485a3f51584f7d5e5a8575952231a231c3ce",
        "baseline_config_sha256": hashlib.sha256(baseline.read_bytes()).hexdigest(),
        "config_sha256": hashlib.sha256(config_file.read_bytes()).hexdigest(),
        "changes": ["reverse group/layer arrays"]
        + (
            ["exclusive layer default/dark; remove layer mono entries"]
            if case == "preferred"
            else []
        ),
        "selected_for_production": False,
    }
    manifest["composition"]["appearance_fill_serialization"] = (
        "known compiler-PASS declarations"
        if case == "control"
        else "known root; Apple sample exclusive default/dark layers"
    )
    manifest["status"] = "diagnostic-only; compiler and native appearance pending"
    (target / "AppIcon-source.json").write_text(json.dumps(manifest, indent=2) + "\n")
    source_hashes = {
        str(path.relative_to(target)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(target.rglob("*"))
        if path.is_file()
    }
    input_provenance = {
        "variant": manifest["diagnostic_variant"],
        "source_files": source_hashes,
        "source_sha256": hashlib.sha256(
            json.dumps(source_hashes, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest(),
        "source_revision": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], text=True
        ).strip(),
        "compiler_outcome": "pending",
    }
    (output / case / "input-provenance.json").write_text(
        json.dumps(input_provenance, indent=2, sort_keys=True) + "\n"
    )
PY
  for CASE in control preferred; do
    mkdir -p "$OUTPUT/$CASE/compiled"
    if "$(pwd)/scripts/make_icon.sh" --compile-appearances \
      "$OUTPUT/$CASE/compiled" "$OUTPUT/$CASE/inputs/Resources" \
      > "$OUTPUT/$CASE/compiler-driver.log" 2>&1; then
      printf '0\n' > "$OUTPUT/$CASE/compiler-exit.txt"
    else
      printf '%s\n' "$?" > "$OUTPUT/$CASE/compiler-exit.txt"
    fi
  done
  uv run --no-project python - "$OUTPUT" <<'PY'
import json
from pathlib import Path
import sys

output = Path(sys.argv[1])
variants = {}
for case in ("control", "preferred"):
    directory = output / case
    status = int((directory / "compiler-exit.txt").read_text())
    provenance_present = (directory / "compiled/resource-provenance.json").is_file()
    variants[case] = {
        "compiler_exit": status,
        "compiler_success": status == 0 and provenance_present,
        "provenance_present": provenance_present,
        "input_source_sha256": json.loads(
            (directory / "input-provenance.json").read_text()
        )["source_sha256"],
        "native_appearance_acceptance": "pending",
    }
summary = {
    "variants": variants,
    "selected_candidate": None,
    "production_changed": False,
}
(output / "diagnostic-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
if all(result["compiler_exit"] != 0 for result in variants.values()):
    raise SystemExit("both diagnostic compiler cases failed; inspect individual logs")
PY
  exit 0
fi

# Resource-only compiler probe. It does not modify the curated ICNS or an app.
if [ "${1:-}" = "--compile-appearances" ]; then
  [ "$#" -eq 2 ] || [ "$#" -eq 3 ] || { echo "expected output directory and optional resource input" >&2; exit 2; }
  OUTPUT="$2"
  RESOURCE_INPUT="${3:-Resources}"
  mkdir -p "$OUTPUT"
  OUTPUT="$(cd "$OUTPUT" && pwd)"
  xcrun --find actool > "$OUTPUT/compiler-path.txt"
  xcodebuild -version > "$OUTPUT/xcode-version.txt"
  xcrun --sdk macosx --show-sdk-version > "$OUTPUT/sdk-version.txt"
  if ! CORESVG_VERBOSE=1 xcrun actool "$RESOURCE_INPUT/AppIcon.icon" \
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
  uv run --no-project python - "$OUTPUT" "$RESOURCE_INPUT" <<'PY'
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
resources = Path(sys.argv[2])
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
