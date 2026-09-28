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
# (popup,settings,history), TRANSLATOR_BACKEND_REPO (checkout whose backend and .venv to run).
set -euo pipefail

OUT="${1:?usage: scripts/snapshot.sh OUT_DIR [--no-build]}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The backend can run from another checkout (a worktree has no .venv of its own).
REPO="${TRANSLATOR_BACKEND_REPO:-$(cd "${HERE}/../.." && pwd)}"
mkdir -p "${OUT}"
OUT="$(cd "${OUT}" && pwd)"

if [[ "${2:-}" != "--no-build" ]]; then
  (cd "${HERE}" && swift build -c release 2>&1 | grep -E "error:|Build complete" || true)
fi
APP_BIN="${HERE}/.build/release/Translator"
[[ -x "${APP_BIN}" ]] || { echo "no build at ${APP_BIN}" >&2; exit 1; }

# AF_UNIX allows 103 bytes, so the socket gets a short path of its own; everything else
# stays under OUT.
SOCK="/tmp/trsnap-$$.sock"
STATE="${OUT}/.backend"
mkdir -p "${STATE}/cfg" "${STATE}/log"
rm -f "${SOCK}"

cleanup() {
  [[ -n "${BACKEND_PID:-}" ]] && kill "${BACKEND_PID}" 2>/dev/null || true
  wait "${BACKEND_PID:-}" 2>/dev/null || true
  rm -f "${SOCK}"
}
trap cleanup EXIT

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

count="$(find "${OUT}" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"
echo "${count} images in ${OUT}"
grep -c "could not capture\|not visible" "${OUT}/app.log" >/dev/null && grep "could not capture\|not visible" "${OUT}/app.log" >&2 || true
