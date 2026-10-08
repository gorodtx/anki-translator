#!/bin/sh
# Build a standalone native probe from the actual production sources. It never starts
# TranslatorApp/AppDelegate or the snapshot runner, so no backend or user app is launched.
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
OUT="${1:?usage: popup-appearance-check.sh /absolute/evidence-directory}"
case "$OUT" in /*) ;; *) echo "evidence directory must be absolute" >&2; exit 2 ;; esac
mkdir -p "$OUT"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/translator-popup-appearance.XXXXXXXX")"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir -p "$WORK/Sources/TranslatorCore" "$WORK/Sources/AppearanceProbe"
cp "$HERE"/Sources/TranslatorCore/*.swift "$WORK/Sources/TranslatorCore/"
for source in "$HERE"/Sources/Translator/*.swift; do
    case "${source##*/}" in TranslatorApp.swift|SnapshotHarness.swift) continue ;; esac
    cp "$source" "$WORK/Sources/AppearanceProbe/"
done
cp "$HERE/scripts/popup-appearance-check.swift" "$WORK/Sources/AppearanceProbe/AppearanceCheck.swift"
cat > "$WORK/Package.swift" <<'PACKAGE'
// swift-tools-version:6.2
import PackageDescription
let package = Package(name: "PopupAppearanceCheck", platforms: [.macOS(.v26)], targets: [
    .target(name: "TranslatorCore", swiftSettings: [.swiftLanguageMode(.v5)]),
    .executableTarget(name: "AppearanceProbe", dependencies: ["TranslatorCore"],
        swiftSettings: [.swiftLanguageMode(.v5)], linkerSettings: [
            .linkedFramework("AppKit"), .linkedFramework("SwiftUI"),
            .linkedFramework("Carbon"), .linkedFramework("ApplicationServices"),
            .linkedFramework("Translation"),
        ]),
])
PACKAGE
shasum -a 256 "$HERE/Sources/Translator/PopupPanel.swift" \
    "$HERE/Sources/Translator/TranslationPopupView.swift" \
    "$HERE/scripts/popup-appearance-check.swift" > "$OUT/sources.sha256"
status=0
swift build --package-path "$WORK" -c debug > "$OUT/build.log" 2>&1 || status=$?
if [ "$status" -ne 0 ]; then
    cat "$OUT/build.log"
    exit "$status"
fi
"$WORK/.build/debug/AppearanceProbe" > "$OUT/check.log" 2>&1 || status=$?
cat "$OUT/check.log"
exit "$status"
