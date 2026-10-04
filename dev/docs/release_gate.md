# Stable Release Gate (Linux GNOME)

This project ships production artifacts for **Linux GNOME**.

## 1) Immutable release policy

- Versioning: `vMAJOR.MINOR.PATCH` (+ optional `-rc.N`).
- Existing tags/releases are never replaced.
- Any hotfix after publish is a new PATCH tag.

## 2) Preflight before publishing

```bash
dev/scripts/release_preflight.sh vX.Y.Z
```

What it enforces:
- clean tracked git tree,
- valid release tag format,
- tag does not exist locally/remotely,
- existing published DB assets match the pinned lock (names, sizes and SHA256),
- code release assets are built from tracked files only,
- checksums verified.

The default preflight is code-only: it checks small GitHub asset metadata and
never copies, hashes or uploads SQLite. GitHub access must already be configured;
an inaccessible or mismatched DB release fails instead of assuming a tag is enough.
For an intentional DB update, run `dev/scripts/release_preflight.sh vX.Y.Z --build-db`.
This explicit mode builds and verifies local DB bytes and requires publishing
the new immutable DB bundle separately. A code release reuses the pinned bundle.
Checksum checks support both Linux `sha256sum` and macOS `shasum`.

## 3) Stable Linux production gate

1. Restart runtime:
   - `systemctl --user restart translator-desktop.service`
2. Installer healthcheck:
   - `bash scripts/install.sh healthcheck`
3. Direct D-Bus smoke:
   - `gdbus call --session --dest com.translator.desktop --object-path /com/translator/desktop --method com.translator.desktop.Translate "hello"`
   - `gdbus call --session --dest com.translator.desktop --object-path /com/translator/desktop --method com.translator.desktop.Translate "look up"`
   - `gdbus call --session --dest com.translator.desktop --object-path /com/translator/desktop --method com.translator.desktop.GetAnkiStatus`
4. Manual UI sanity:
   - hotkey opens/closes translation window,
   - tray menu opens History/Settings,
   - notification banner auto-hides (~1.2s).

## 4) Release model

This project now publishes two immutable artifact layers:

1. Code release per `vMAJOR.MINOR.PATCH`
   - `install.sh`
   - `release-manifest.json`
   - `release-assets.sha256`
   - `translator-app.tar.gz`
   - `translator-extension.zip`
2. DB bundle release only when sqlite bytes change
   - `primary.sqlite3`
   - `fallback.sqlite3`
   - `definitions_pack.sqlite3`
   - `db-assets.sha256`

`release-manifest.json` pins the exact immutable DB bundle tag.

## 5) Artifact cleanliness contract

- `translator-app.tar.gz` is built via `git archive` from explicit allowlist:
  - `desktop_app/`
  - `translate_logic/`
  - `icons/`
  - `scripts/runtime-requirements.txt`
- `.sqlite3` files are blocked inside the code release app archive.
- Code releases stay small and do not republish offline DB bytes when checksums are unchanged.
- Offline DB bytes are reused locally by checksum and fetched from a pinned DB bundle tag, never from `latest/download`.
