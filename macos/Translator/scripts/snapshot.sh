#!/usr/bin/env bash
# Render the shell's real windows to PNG, without the Screen Recording grant.
#
#   scripts/snapshot.sh OUT_DIR [--no-build]
#
# Brings up an isolated backend on its own socket and config directory — real lookups,
# real dictionaries, but nothing written to the user's history or settings — then runs
# the built app with TRANSLATOR_DEBUG_SNAPSHOT, which walks the popup, Settings and
# History scenes and writes one PNG per scene (see Sources/Translator/SnapshotHarness.swift).
#
# Pass-through knobs: TRANSLATOR_DEBUG_SNAPSHOT_TEXTS ("a|b|c"),
# TRANSLATOR_DEBUG_APPEARANCE (light|dark|both), TRANSLATOR_DEBUG_SNAPSHOT_SCENES
# (popup,settings,history), TRANSLATOR_BACKEND_REPO (checkout whose backend and .venv to run),
# TRANSLATOR_SNAPSHOT_APP (a binary to render instead of the debug build).
set -euo pipefail

OUT="${1:?usage: scripts/snapshot.sh OUT_DIR [--no-build]}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The backend can run from another checkout (a worktree has no .venv of its own).
REPO="${TRANSLATOR_BACKEND_REPO:-$(cd "${HERE}/../.." && pwd)}"
mkdir -p "${OUT}"
OUT="$(cd "${OUT}" && pwd)"
# Refuse stale renders rather than counting a previous run's PNG as new evidence.
if find "${OUT}" -maxdepth 1 -name '*.png' -print -quit | grep -q .; then
  echo "snapshot output already contains PNG files; use a fresh directory" >&2
  exit 1
fi

if [[ "${2:-}" != "--no-build" ]]; then
  if (cd "${HERE}" && swift build -c release) >"${OUT}/build.log" 2>&1; then
    grep -E "Build complete" "${OUT}/build.log" || true
  else
    BUILD_STATUS=$?
    cat "${OUT}/build.log" >&2
    exit "${BUILD_STATUS}"
  fi
fi
# TRANSLATOR_SNAPSHOT_APP renders a built bundle's binary instead, e.g.
# dist/Translator.app/Contents/MacOS/Translator: then Info.plist is real (About's version).
APP_BIN="${TRANSLATOR_SNAPSHOT_APP:-${HERE}/.build/release/Translator}"
[[ -x "${APP_BIN}" ]] || { echo "no build at ${APP_BIN}" >&2; exit 1; }

# AF_UNIX allows 103 bytes, so the socket gets a short path of its own; everything else
# stays under OUT.
SOCK="/tmp/trsnap-$$.sock"
STATE="${OUT}/.backend"
mkdir -p "${STATE}/cfg" "${STATE}/log"
rm -f "${SOCK}"

cleanup() {
  [[ -n "${APP_PID:-}" ]] && kill "${APP_PID}" 2>/dev/null || true
  [[ -n "${APP_PID:-}" ]] && wait "${APP_PID}" 2>/dev/null || true
  [[ -n "${BACKEND_PID:-}" ]] && kill "${BACKEND_PID}" 2>/dev/null || true
  [[ -n "${BACKEND_PID:-}" ]] && wait "${BACKEND_PID}" 2>/dev/null || true
  rm -f "${SOCK}"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# The isolated backend must not reach the user's real Anki: point AnkiConnect at a closed
# port unless the caller brings a stand-in of their own.
export ANKI_CONNECT_URL="${ANKI_CONNECT_URL:-http://127.0.0.1:18799}"

(
  cd "${REPO}"
  TRANSLATOR_SOCKET_PATH="${SOCK}" \
  TRANSLATOR_CONFIG_DIR="${STATE}/cfg" \
  TRANSLATOR_LOG_DIR="${STATE}/log" \
  TRANSLATOR_DB_DIR="${TRANSLATOR_DB_DIR:-${HOME}/Library/Application Support/Translator/db}" \
    exec uv run --frozen python -m desktop_app.platform.macos.daemon
) >"${STATE}/backend.log" 2>&1 &
BACKEND_PID=$!

for _ in $(seq 1 200); do [[ -S "${SOCK}" ]] && break; sleep 0.1; done
[[ -S "${SOCK}" ]] || { echo "backend did not start; see ${STATE}/backend.log" >&2; exit 1; }

TRANSLATOR_SOCKET_PATH="${SOCK}" TRANSLATOR_DEBUG_SNAPSHOT="${OUT}" \
  "${APP_BIN}" >"${OUT}/app.log" 2>&1 &
APP_PID=$!
# Eight lookups, two appearances, four windows and the behaviour probes: about three
# minutes; eight is the ceiling.
for _ in $(seq 1 960); do kill -0 "${APP_PID}" 2>/dev/null || break; sleep 0.5; done
if kill -0 "${APP_PID}" 2>/dev/null; then
  kill "${APP_PID}" 2>/dev/null || true
  echo "snapshot run timed out; see ${OUT}/app.log" >&2
  exit 1
fi
APP_STATUS=0
wait "${APP_PID}" || APP_STATUS=$?
if [[ "${APP_STATUS}" == 3 ]]; then
  echo "the screen is locked: renders would be blank and focus probes would fail; unlock it and run again" >&2
  exit 3
fi
if [[ "${APP_STATUS}" != 0 ]]; then
  echo "snapshot app failed (exit ${APP_STATUS}); see ${OUT}/app.log" >&2
  exit "${APP_STATUS}"
fi

count="$(find "${OUT}" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"
echo "${count} images in ${OUT}"
if ! grep -Fq '[snapshot] done' "${OUT}/app.log"; then
  echo "snapshot runner did not complete; see ${OUT}/app.log" >&2
  exit 1
fi
failure_pattern='could not capture|could not encode|not visible|write failed|blank composite .*attempt 3|PROBE [^ ]+ FAIL'
if grep -E "${failure_pattern}" "${OUT}/app.log" >&2; then
  echo "snapshot output or behaviour failed; see ${OUT}/app.log" >&2
  exit 1
fi
scenes="${TRANSLATOR_DEBUG_SNAPSHOT_SCENES:-popup,settings,history,anki,probes}"
IFS=',' read -r -a selected_scenes <<< "${scenes}"
for scene in "${selected_scenes[@]}"; do
  scene="$(printf '%s' "${scene}" | tr -d '[:space:]')"
  case "${scene}" in
    probes) ;;
    popup|settings|history|anki)
      if ! find "${OUT}" -maxdepth 1 -name "${scene}-*.png" -print -quit | grep -q .; then
        echo "snapshot run produced no ${scene} images; see ${OUT}/app.log" >&2
        exit 1
      fi
      ;;
    *) echo "unknown snapshot scene: ${scene}" >&2; exit 1 ;;
  esac
done
while IFS= read -r written; do
  if [[ ! -f "${OUT}/${written}" ]]; then
    echo "declared snapshot is missing: ${written}; see ${OUT}/app.log" >&2
    exit 1
  fi
done < <(sed -nE 's/.*\[snapshot\] wrote ([^ ]+\.png) .*/\1/p' "${OUT}/app.log")
if [[ "${scenes}" == "probes" ]]; then
  if ! grep -Eq 'PROBE [^ ]+ (PASS|SKIP)' "${OUT}/app.log"; then
    echo "probe-only run produced no verdicts; see ${OUT}/app.log" >&2
    exit 1
  fi
elif [[ "${count}" == 0 ]]; then
  echo "snapshot run produced no images; see ${OUT}/app.log" >&2
  exit 1
fi
# SKIP remains explicitly visible; it never becomes a claimed behaviour PASS.
grep -E 'PROBE [^ ]+ SKIP' "${OUT}/app.log" || true
