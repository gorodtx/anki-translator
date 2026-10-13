#!/usr/bin/env bash
set -euo pipefail
# First installation only. Existing hash-matched databases are reused on every
# code deployment. The repository URL is resolved by the operator, not baked in.
release_base=${1:?Pass the confirmed public DB release download URL}
db_dir=${2:-/opt/translator/db}
mkdir -p "$db_dir"
while read -r expected_hash filename; do
  destination="$db_dir/$filename"
  if [[ -f "$destination" ]] && printf '%s  %s\n' "$expected_hash" "$destination" | sha256sum --check --status; then
    printf 'REUSE %s\n' "$filename"
    continue
  fi
  curl --fail --location --retry 3 --silent --show-error "$release_base/$filename" --output "$destination.part"
  printf '%s  %s\n' "$expected_hash" "$destination.part" | sha256sum --check --status
  chmod 644 "$destination.part"
  mv "$destination.part" "$destination"
  printf 'VERIFIED %s\n' "$filename"
done <<'HASHES'
91a005c531fdb52f44627cab572de03c60d468c41c59ddeeff8de4b8572cc510 primary.sqlite3
c4f31145e0d414b59b151bf9010104696158af796b40d1a583738337d0cc1925 fallback.sqlite3
b2664e5949a3d6bb26b01afc3e78eae295b5adfdfb5c1191c4b1ca084b38f0fe definitions_pack.sqlite3
HASHES
