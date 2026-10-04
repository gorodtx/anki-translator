#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TAG="${1:-}"
MODE="${2:---code-only}"
DB_BUNDLE_VERIFIED="0"
RELEASE_REPO="${TRANSLATOR_RELEASE_REPO:-gorodtx/selection_translator_anki}"
DB_BUNDLE_LOCK_PATH="${TRANSLATOR_DB_BUNDLE_LOCK_PATH:-${ROOT_DIR}/scripts/db-bundle.lock.json}"

log() {
  echo "[release-preflight] $*"
}

fail() {
  echo "[release-preflight] $*" >&2
  exit 1
}

usage() {
  cat <<USAGE
Usage:
  dev/scripts/release_preflight.sh vX.Y.Z [--code-only|--build-db]
  dev/scripts/release_preflight.sh vX.Y.Z-rc.N [--code-only|--build-db]

The script does not publish anything.
It validates immutable release constraints and builds code release assets.
Default --code-only verifies the existing published pinned DB assets without
copying, hashing or uploading SQLite. Use --build-db only for changed DB bytes.
USAGE
}

require_tag() {
  [[ -n "${TAG}" ]] || fail "missing tag"
  if [[ ! "${TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?$ ]]; then
    fail "tag must match vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-rc.N"
  fi
}

db_bundle_tag() {
  [[ -s "${DB_BUNDLE_LOCK_PATH}" ]] || fail "db bundle lock not found: ${DB_BUNDLE_LOCK_PATH}"
  uv run --no-sync python - <<'PY' "${DB_BUNDLE_LOCK_PATH}"
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
print(payload["tag"])
PY
}

ensure_immutable_target() {
  if git -C "${ROOT_DIR}" rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
    fail "tag already exists locally: ${TAG}"
  fi
  if git -C "${ROOT_DIR}" ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
    fail "tag already exists on origin: ${TAG}"
  fi
}

verify_assets() {
  local directory="$1" manifest="$2"
  (
    cd "${directory}"
    if command -v sha256sum >/dev/null 2>&1; then
      sha256sum -c "${manifest}"
    else
      shasum -a 256 -c "${manifest}"
    fi
  )
}

verify_existing_db_bundle() {
  uv run --no-sync python "${ROOT_DIR}/dev/scripts/release_metadata.py" \
    verify-db-release --db-lock "${DB_BUNDLE_LOCK_PATH}"
  DB_BUNDLE_VERIFIED="1"
}

build_and_verify_db_bundle() {
  "${ROOT_DIR}/dev/scripts/build_db_bundle_assets.sh"
  verify_assets "${ROOT_DIR}/dev/dist/db_bundle" db-assets.sha256
  cmp -s "${ROOT_DIR}/dev/dist/db_bundle/db-bundle.lock.json" "${DB_BUNDLE_LOCK_PATH}" || fail \
    "db bundle lock is out of sync with local sqlite files; run TRANSLATOR_DB_BUNDLE_WRITE_LOCK=1 dev/scripts/build_db_bundle_assets.sh"
}

build_and_verify_code_release() {
  TRANSLATOR_RELEASE_TAG="${TAG}" "${ROOT_DIR}/dev/scripts/build_release_assets.sh"
  verify_assets "${ROOT_DIR}/dev/dist/release" release-assets.sha256
  [[ -s "${ROOT_DIR}/dev/dist/release/release-manifest.json" ]] || fail "missing release-manifest.json"
}

print_next_steps() {
  local db_tag="$1"
  local db_on_origin="${DB_BUNDLE_VERIFIED}"

  cat <<STEPS

Preflight passed for ${TAG}.

DB bundle tag: ${db_tag}
DB bundle published assets verified: ${db_on_origin}

Next commands:
  git -C "${ROOT_DIR}" push origin gnome
STEPS

  if [[ "${db_on_origin}" != "1" ]]; then
    cat <<STEPS
  git -C "${ROOT_DIR}" tag ${db_tag}
  git -C "${ROOT_DIR}" push origin ${db_tag}
  gh release create ${db_tag} \\
    --title "${db_tag}" \\
    --notes "Immutable offline DB bundle" \\
    ${ROOT_DIR}/dev/dist/db_bundle/primary.sqlite3 \\
    ${ROOT_DIR}/dev/dist/db_bundle/fallback.sqlite3 \\
    ${ROOT_DIR}/dev/dist/db_bundle/definitions_pack.sqlite3 \\
    ${ROOT_DIR}/dev/dist/db_bundle/db-assets.sha256
STEPS
  fi

  cat <<STEPS
  git -C "${ROOT_DIR}" tag ${TAG}
  git -C "${ROOT_DIR}" push origin ${TAG}
  gh release create ${TAG} \\
    --title "${TAG}" \\
    --generate-notes \\
    ${ROOT_DIR}/dev/dist/release/install.sh \\
    ${ROOT_DIR}/dev/dist/release/release-manifest.json \\
    ${ROOT_DIR}/dev/dist/release/release-assets.sha256 \\
    ${ROOT_DIR}/dev/dist/release/translator-app.tar.gz \\
    ${ROOT_DIR}/dev/dist/release/translator-extension.zip
STEPS
}

main() {
  if [[ "${TAG}" == "-h" || "${TAG}" == "--help" ]]; then
    usage
    exit 0
  fi
  require_tag
  [[ "${MODE}" == "--code-only" || "${MODE}" == "--build-db" ]] || fail "mode must be --code-only or --build-db"
  [[ "$#" -le 2 ]] || fail "unexpected arguments"
  ensure_immutable_target
  if [[ "${MODE}" == "--build-db" ]]; then
    build_and_verify_db_bundle
  else
    verify_existing_db_bundle
  fi
  build_and_verify_code_release
  print_next_steps "$(db_bundle_tag)"
}

main "$@"
