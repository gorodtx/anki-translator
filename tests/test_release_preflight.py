from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

import pytest

from dev.scripts import release_metadata


def published_fixture() -> tuple[dict[str, object], dict[str, object]]:
    names = release_metadata.OFFLINE_BASE_FILES
    hashes = {name: str(index + 1) * 64 for index, name in enumerate(names)}
    manifest = release_metadata.build_db_assets_manifest_text(hashes)
    digest = hashlib.sha256(manifest.encode()).hexdigest()
    tag = f"db-{digest[:12]}"
    lock: dict[str, object] = {
        "repo": "example/repo",
        "tag": tag,
        "manifest_asset": "db-assets.sha256",
        "assets": {
            name: {"name": name, "sha256": hashes[name], "size": index + 10}
            for index, name in enumerate(names)
        },
    }
    remote: dict[str, object] = {
        "tag_name": tag,
        "draft": False,
        "assets": [
            {"name": name, "digest": f"sha256:{hashes[name]}", "size": index + 10}
            for index, name in enumerate(names)
        ]
        + [
            {
                "name": "db-assets.sha256",
                "digest": f"sha256:{digest}",
                "size": len(manifest.encode()),
            }
        ],
    }
    return lock, remote


def test_published_database_metadata_requires_exact_assets() -> None:
    lock, remote = published_fixture()
    release_metadata.verify_published_db_bundle(lock, remote)


@pytest.mark.parametrize("damage", ["draft", "tag", "missing", "digest", "size"])
def test_published_database_metadata_rejects_incomplete_or_changed_assets(
    damage: str,
) -> None:
    lock, remote = published_fixture()
    if damage == "draft":
        remote["draft"] = True
    elif damage == "tag":
        remote["tag_name"] = "db-another"
    else:
        assets = remote["assets"]
        assert isinstance(assets, list)
        if damage == "missing":
            assets.pop(0)
        elif damage == "digest":
            assets[0]["digest"] = "sha256:" + "f" * 64
        else:
            assets[0]["size"] = 999
    with pytest.raises(ValueError):
        release_metadata.verify_published_db_bundle(lock, remote)


@pytest.mark.parametrize("remote_state", ["valid", "mismatch", "unreadable"])
def test_default_preflight_requires_verified_bundle_without_local_databases(
    tmp_path: Path,
    remote_state: str,
) -> None:
    fixture = tmp_path / "fixture"
    scripts = fixture / "dev/scripts"
    scripts.mkdir(parents=True)
    for name in ("release_preflight.sh", "release_metadata.py"):
        shutil.copy2(Path("dev/scripts") / name, scripts / name)
    lock, remote = published_fixture()
    if remote_state == "mismatch":
        assets = remote["assets"]
        assert isinstance(assets, list)
        assets[0]["digest"] = "sha256:" + "f" * 64
    lock_dir = fixture / "scripts"
    lock_dir.mkdir()
    (lock_dir / "db-bundle.lock.json").write_text(json.dumps(lock))
    remote_path = fixture / "published.json"
    remote_path.write_text(json.dumps(remote))
    sentinel = fixture / "database-builder-was-called"
    db_builder = scripts / "build_db_bundle_assets.sh"
    db_builder.write_text(f"#!/bin/sh\ntouch '{sentinel}'\nexit 99\n", encoding="utf-8")
    db_builder.chmod(0o755)
    code_builder = scripts / "build_release_assets.sh"
    code_builder.write_text(
        '#!/bin/sh\nset -eu\ncd "$(dirname "$0")/../.."\n'
        "mkdir -p dev/dist/release\ncd dev/dist/release\n"
        "printf '{}\\n' > release-manifest.json\n"
        "shasum -a 256 release-manifest.json > release-assets.sha256\n",
        encoding="utf-8",
    )
    code_builder.chmod(0o755)
    bin_dir = fixture / "bin"
    bin_dir.mkdir()
    (bin_dir / "git").write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
    (bin_dir / "gh").write_text(
        "#!/bin/sh\nexit 7\n"
        if remote_state == "unreadable"
        else f"#!/bin/sh\ncat '{remote_path}'\n",
        encoding="utf-8",
    )
    for path in bin_dir.iterdir():
        path.chmod(0o755)
    test_env = dict(os.environ)
    test_env["PATH"] = f"{bin_dir}:{test_env['PATH']}"
    completed = subprocess.run(
        ["bash", str(scripts / "release_preflight.sh"), "v9.9.9"],
        env=test_env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert not sentinel.exists()
    assert not (fixture / "dev/dist/db_bundle").exists()
    if remote_state != "valid":
        assert completed.returncode != 0
        assert not (fixture / "dev/dist/release").exists()
        return
    assert completed.returncode == 0, completed.stdout + completed.stderr
    assert "existing published DB bundle verified" in completed.stdout
    assert "gh release create db-" not in completed.stdout


def test_unverified_database_tag_does_not_suppress_publication_instructions(
    tmp_path: Path,
) -> None:
    fake_git = tmp_path / "git"
    fake_git.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    fake_git.chmod(0o755)
    functions = tmp_path / "functions.sh"
    script = Path("dev/scripts/release_preflight.sh").read_text(encoding="utf-8")
    functions.write_text(script.rsplit('\nmain "$@"', 1)[0], encoding="utf-8")
    test_env = dict(os.environ)
    test_env["PATH"] = f"{tmp_path}:{test_env['PATH']}"
    completed = subprocess.run(
        [
            "bash",
            "-c",
            'source "$1"; print_next_steps db-unverified',
            "fixture",
            str(functions),
        ],
        env=test_env,
        capture_output=True,
        text=True,
        check=True,
    )
    assert "gh release create db-unverified" in completed.stdout
