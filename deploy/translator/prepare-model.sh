#!/bin/sh
set -eu
image=${1:?Pass the confirmed translator-demo image tag}
root=/opt/translator/models
archive="$root/opus-en-ru.zip"
expected=798027c7e4ae7ddf89fea13ce80de517b6726d7e710fa5a9b5a376316dbf1677
mkdir -p "$root"
if [ ! -f "$archive" ] || [ "$(sha256sum "$archive" | cut -d ' ' -f1)" != "$expected" ]; then
  curl -fL --retry 2 --max-time 180 https://object.pouta.csc.fi/OPUS-MT-models/en-ru/opus-2020-02-11.zip -o "$archive.part"
  [ "$(sha256sum "$archive.part" | cut -d ' ' -f1)" = "$expected" ]
  mv "$archive.part" "$archive"
fi
docker run -i --rm --user 0 --memory 768m --cpus 1 --cap-drop ALL \
  --security-opt no-new-privileges:true --read-only --tmpfs /tmp:rw,size=32m \
  -v "$root:/models" "$image" uv run --no-sync python - <<'PY'
from pathlib import Path
import hashlib
import json
import shutil
import zipfile
from ctranslate2.converters import OpusMTConverter

root = Path('/models')
model = root / 'en-ru'
source_hash = '798027c7e4ae7ddf89fea13ce80de517b6726d7e710fa5a9b5a376316dbf1677'
manifest_path = model / 'source.json'
if manifest_path.exists():
    manifest = json.loads(manifest_path.read_text())
    assert manifest['archive_sha256'] == source_hash
    for name, expected in manifest['files'].items():
        assert hashlib.sha256((model / name).read_bytes()).hexdigest() == expected
    print('REUSE verified OPUS-MT model')
else:
    if model.exists():
        raise RuntimeError('Unverified model directory already exists; preserve it and investigate')
    original = root / 'opus-original'
    original.mkdir(exist_ok=True)
    with zipfile.ZipFile(root / 'opus-en-ru.zip') as archive:
        for name in archive.namelist():
            path = Path(name)
            if path.is_absolute() or '..' in path.parts:
                raise ValueError('Unsafe model archive path')
            archive.extract(name, original)
    OpusMTConverter(str(original)).convert(str(model), quantization='int8')
    for name in ('source.spm', 'target.spm', 'README.md'):
        shutil.copyfile(original / name, model / name)
    files = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in model.iterdir() if p.is_file()}
    manifest_path.write_text(json.dumps({'archive_sha256': source_hash, 'converter': 'CTranslate2 4.8.2', 'quantization': 'int8', 'files': files}, indent=2) + '\n')
    print('MODEL_READY verified OPUS-MT en-ru')
PY
