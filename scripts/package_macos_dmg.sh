#!/usr/bin/env bash
# Package a complete, already signed app; never repair an incomplete bundle.
set -euo pipefail
APP="${1:?usage: package_macos_dmg.sh APP OUTPUT_DIR}"
OUT="${2:?usage: package_macos_dmg.sh APP OUTPUT_DIR}"
[[ "$(uname -s)" == Darwin ]] || { echo 'macOS only' >&2; exit 1; }
[[ -d "${APP}/Contents" ]] || { echo 'app bundle missing' >&2; exit 1; }
APP="$(cd "$(dirname "${APP}")" && pwd)/$(basename "${APP}")"
mkdir -p "${OUT}"
OUT="$(cd "${OUT}" && pwd)"
PLIST="${APP}/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${PLIST}")"
MINIMUM="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "${PLIST}")"
[[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'invalid app version' >&2; exit 1; }
[[ "${MINIMUM}" == 26.0 ]] || { echo 'unexpected minimum macOS' >&2; exit 1; }
for binary in Contents/MacOS/Translator Contents/MacOS/TranslatorBackend \
  Contents/Resources/bin/apple-lang-helper Contents/Resources/python/bin/python3.13; do
  [[ -x "${APP}/${binary}" ]] || { echo "missing binary: ${binary}" >&2; exit 1; }
  [[ "$(lipo -archs "${APP}/${binary}")" == arm64 ]] || { echo "unexpected architecture: ${binary}" >&2; exit 1; }
done
[[ -f "${APP}/Contents/Resources/build-info.json" ]] || { echo 'build identity missing' >&2; exit 1; }
if find "${APP}" -name '*.sqlite3' | grep -q .; then
  echo 'offline databases must not ship inside the app' >&2; exit 1
fi
codesign --verify --deep --strict "${APP}"
NAME="Translator-${VERSION}-macos-arm64.dmg"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/translator-dmg.XXXXXX")"
trap 'rm -rf "${STAGE}"' EXIT
ditto "${APP}" "${STAGE}/Translator.app"
ln -s /Applications "${STAGE}/Applications"
# Names are the complete Finder install instruction; no shell/installer on the image.
hdiutil create -ov -format UDZO -fs HFS+ -volname Translator \
  -srcfolder "${STAGE}" "${OUT}/${NAME}"
hdiutil verify "${OUT}/${NAME}"
(
  cd "${OUT}"
  shasum -a 256 "${NAME}" > "${NAME}.sha256"
  shasum -a 256 -c "${NAME}.sha256"
)
printf 'DMG: %s\nMinimum macOS: %s; architecture: arm64\n' "${OUT}/${NAME}" "${MINIMUM}"
