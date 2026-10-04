#!/usr/bin/env bash
# One signing path shared by local builds and the notarization workflow.
set -euo pipefail
APP="${1:?usage: sign_macos_app.sh APP IDENTITY}"
IDENTITY="${2:?usage: sign_macos_app.sh APP IDENTITY}"
[[ -d "${APP}/Contents" ]] || { echo 'app bundle missing' >&2; exit 1; }
[[ -x "${APP}/Contents/MacOS/TranslatorBackend" ]] || { echo 'native backend launcher missing' >&2; exit 1; }
SIGN_FLAGS=(--force --sign "${IDENTITY}")
if [[ "${IDENTITY}" != '-' ]]; then
  SIGN_FLAGS+=(--options runtime --timestamp)
fi
# All real Mach-O files, not only filename extensions: libpython and native launchers
# are nested code too. Symlinks are signed through their targets exactly once.
while IFS= read -r -d '' binary; do
  if file -b "${binary}" | grep -q 'Mach-O'; then
    codesign "${SIGN_FLAGS[@]}" "${binary}"
  fi
done < <(find "${APP}/Contents" -type f -print0)
codesign "${SIGN_FLAGS[@]}" --identifier com.translator.desktop.backend \
  "${APP}/Contents/MacOS/TranslatorBackend"
codesign "${SIGN_FLAGS[@]}" --identifier com.translator.desktop "${APP}"
codesign --verify --deep --strict "${APP}"
