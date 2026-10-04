"""Exercise actual launcher import precedence and argument forwarding."""

from __future__ import annotations

import json
from pathlib import Path
import shutil
import subprocess
import sys
from typing import cast

import pytest

ROOT = Path(__file__).resolve().parents[1]
pytestmark = pytest.mark.skipif(
    sys.platform != "darwin", reason="macOS Mach-O launcher"
)


@pytest.fixture(scope="module")
def launch_fixture(
    tmp_path_factory: pytest.TempPathFactory, request: pytest.FixtureRequest
) -> dict[str, Path]:
    directory = tmp_path_factory.mktemp("backend-import-boundary")
    request.addfinalizer(lambda: shutil.rmtree(directory))
    app = directory / "Application With Spaces.app"
    resources = app / "Contents/Resources"
    binaries = resources / "bin"
    executable = app / "Contents/MacOS/TranslatorBackend"
    executable.parent.mkdir(parents=True)
    binaries.mkdir(parents=True)
    (binaries / "TranslatorEngine").symlink_to(sys.executable)
    subprocess.run(
        [
            "swiftc",
            str(ROOT / "macos/Translator/Sources/TranslatorBackend/main.swift"),
            "-o",
            str(executable),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    builder = (ROOT / "scripts/build_macos_app.sh").read_text()
    runner = builder.split("<<'RUNNER'\n", 1)[1].split("\nRUNNER", 1)[0]
    shim = binaries / "run-backend"
    shim.write_text(runner + "\n")
    shim.chmod(0o755)
    packaged = resources / "app/desktop_app/platform/macos"
    poison = directory / "unrelated working directory/desktop_app/platform/macos"
    for package in [packaged, poison]:
        package.mkdir(parents=True)
        for parent in [package, package.parent, package.parent.parent]:
            (parent / "__init__.py").write_text("")
    (packaged / "daemon.py").write_text(
        "import json, sys\n"
        "print(json.dumps({'origin': __file__, 'args': sys.argv[1:]}))\n"
    )
    (poison / "daemon.py").write_text(
        "raise RuntimeError('UNRELATED_CWD_MODULE_EXECUTED')\n"
    )
    return {
        "native": executable,
        "shell": shim,
        "cwd": poison.parents[2],
        "packaged_module": packaged / "daemon.py",
        "socket": directory / "profile with spaces/backend.sock",
    }


@pytest.mark.parametrize("entry", ["native", "shell"])
def test_bundle_entry_ignores_unrelated_cwd_and_forwards_arguments(
    launch_fixture: dict[str, Path], entry: str
) -> None:
    arguments = ["--socket", str(launch_fixture["socket"]), "--log-level", "DEBUG"]
    result = subprocess.run(
        [str(launch_fixture[entry]), *arguments],
        cwd=launch_fixture["cwd"],
        env={"PATH": "/usr/bin:/bin", "LANG": "en_US.UTF-8"},
        capture_output=True,
        text=True,
        check=False,
        timeout=15,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    decoded: object = json.loads(result.stdout)
    assert isinstance(decoded, dict)
    reply = cast(dict[str, object], decoded)
    assert Path(str(reply["origin"])).samefile(launch_fixture["packaged_module"])
    assert reply["args"] == arguments
    assert "UNRELATED_CWD_MODULE_EXECUTED" not in result.stderr
