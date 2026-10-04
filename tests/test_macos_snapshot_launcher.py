"""Проверки fail-closed launcher со явно обозначенными process/socket заглушками."""

from __future__ import annotations

from collections.abc import Callable, Iterator
from pathlib import Path
import os
import signal
import shlex
import shutil
import subprocess
import sys
import time

import pytest

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "macos/Translator/scripts/snapshot.sh"

pytestmark = pytest.mark.skipif(sys.platform != "darwin", reason="macOS launcher")


@pytest.fixture
def run_launcher(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> Iterator[Callable[[int, int, bool], subprocess.CompletedProcess[str]]]:
    real_uv = shutil.which("uv")
    assert real_uv is not None
    tools = tmp_path / "tools"
    tools.mkdir()
    backend = tmp_path / "synthetic_backend.py"
    backend.write_text(
        "import asyncio, os, signal\nfrom pathlib import Path\n"
        "async def handle(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:\n"
        "    writer.close()\n"
        "    await writer.wait_closed()\n"
        "async def main() -> None:\n"
        "    Path(os.environ['SNAPSHOT_TEST_ROOT'], 'backend.pid').write_text(str(os.getpid()))\n"
        "    stop = asyncio.Event()\n"
        "    asyncio.get_running_loop().add_signal_handler(signal.SIGTERM, stop.set)\n"
        "    server = await asyncio.start_unix_server(handle, path=os.environ['TRANSLATOR_SOCKET_PATH'])\n"
        "    async with server:\n"
        "        await stop.wait()\n"
        "asyncio.run(main())\n"
    )
    shim_uv = tools / "uv"
    shim_uv.write_text(
        "#!/bin/bash\nexec "
        + shlex.quote(real_uv)
        + " run --no-project python "
        + shlex.quote(str(backend))
        + "\n"
    )
    shim_uv.chmod(0o755)
    shim_swift = tools / "swift"
    shim_swift.write_text(
        '#!/bin/bash\nprintf "synthetic build failure\\n" >&2\nexit "$SNAPSHOT_TEST_BUILD_EXIT"\n'
    )
    shim_swift.chmod(0o755)
    app = tmp_path / "synthetic_app"
    app.write_text(
        "#!/bin/bash\n"
        'echo "$$" > "$SNAPSHOT_TEST_ROOT/app.pid"\n'
        'touch "$TRANSLATOR_DEBUG_SNAPSHOT/app-started"\n'
        'if [[ "$SNAPSHOT_TEST_MODE" == "interrupted" ]]; then exec /bin/sleep 30; fi\n'
        'if [[ "$SNAPSHOT_TEST_MODE" != "no-image" && "$SNAPSHOT_TEST_MODE" != "probes-only" ]]; then\n'
        '  printf "synthetic fixture, not a screenshot\\n" > "$TRANSLATOR_DEBUG_SNAPSHOT/popup-synthetic.png"\n'
        '  echo "[snapshot] wrote popup-synthetic.png 1x1"\n'
        "fi\n"
        'case "$SNAPSHOT_TEST_MODE" in\n'
        '  capture-error) echo "[snapshot] could not capture window 1" ;;\n'
        '  encode-error) echo "[snapshot] could not encode popup-synthetic.png" ;;\n'
        '  missing-written) echo "[snapshot] wrote popup-missing.png 1x1" ;;\n'
        '  probe-fail) echo "PROBE synthetic FAIL incorrect state" ;;\n'
        '  probes-only) echo "PROBE synthetic PASS controlled fixture"; echo "PROBE optional SKIP fixture" ;;\n'
        "esac\n"
        'if [[ "$SNAPSHOT_TEST_MODE" != "incomplete" ]]; then echo "[snapshot] done"; fi\n'
        'exit "$SNAPSHOT_TEST_APP_EXIT"\n'
    )
    app.chmod(0o755)
    monkeypatch.setenv("PATH", str(tools) + ":/usr/bin:/bin:/usr/sbin:/sbin")
    monkeypatch.setenv("TRANSLATOR_BACKEND_REPO", str(tmp_path))
    monkeypatch.setenv("TRANSLATOR_SNAPSHOT_APP", str(app))
    monkeypatch.setenv("ANKI_CONNECT_URL", "http://127.0.0.1:1")
    monkeypatch.setenv("SNAPSHOT_TEST_MODE", "success")
    monkeypatch.setenv("TRANSLATOR_DEBUG_SNAPSHOT_SCENES", "popup")
    monkeypatch.setenv("SNAPSHOT_TEST_ROOT", str(tmp_path))

    def run(
        app_exit: int, build_exit: int, build: bool
    ) -> subprocess.CompletedProcess[str]:
        monkeypatch.setenv("SNAPSHOT_TEST_APP_EXIT", str(app_exit))
        monkeypatch.setenv("SNAPSHOT_TEST_BUILD_EXIT", str(build_exit))
        arguments = ["/bin/bash", str(SCRIPT), str(tmp_path / "output")]
        if not build:
            arguments.append("--no-build")
        if os.environ["SNAPSHOT_TEST_MODE"] == "interrupted":
            process = subprocess.Popen(
                arguments, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
            )
            deadline = time.monotonic() + 10
            while not (tmp_path / "app.pid").exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            assert (tmp_path / "app.pid").exists(), "controlled app did not start"
            os.kill(int((tmp_path / "app.pid").read_text()), 0)
            process.terminate()
            stdout, stderr = process.communicate(timeout=10)
            result = subprocess.CompletedProcess(
                arguments, process.returncode, stdout, stderr
            )
        else:
            result = subprocess.run(
                arguments, capture_output=True, text=True, timeout=30
            )
        for name in ("backend.pid", "app.pid"):
            pid_file = tmp_path / name
            if pid_file.exists():
                with pytest.raises(ProcessLookupError):
                    os.kill(int(pid_file.read_text()), 0)
        return result

    yield run
    # Preserve the failing cleanup assertion, but do not leak this fixture's processes.
    for name in ("backend.pid", "app.pid"):
        pid_file = tmp_path / name
        if pid_file.exists():
            try:
                os.kill(int(pid_file.read_text()), signal.SIGTERM)
            except ProcessLookupError:
                pass


def test_failed_snapshot_app_exit_is_propagated(
    run_launcher: Callable[[int, int, bool], subprocess.CompletedProcess[str]],
) -> None:
    result = run_launcher(7, 0, False)
    assert result.returncode == 7, result.stdout + result.stderr


def test_failed_build_does_not_launch_an_existing_binary(
    run_launcher: Callable[[int, int, bool], subprocess.CompletedProcess[str]],
    tmp_path: Path,
) -> None:
    result = run_launcher(0, 9, True)
    assert result.returncode == 9, result.stdout + result.stderr
    assert not (tmp_path / "output/app-started").exists()


def test_successful_snapshot_app_exit_is_preserved(
    run_launcher: Callable[[int, int, bool], subprocess.CompletedProcess[str]],
) -> None:
    result = run_launcher(0, 0, False)
    assert result.returncode == 0, result.stdout + result.stderr


@pytest.mark.parametrize(
    "mode", ["no-image", "capture-error", "encode-error", "probe-fail", "incomplete"]
)
def test_failed_output_is_rejected_even_when_app_exits_zero(
    run_launcher: Callable[[int, int, bool], subprocess.CompletedProcess[str]],
    monkeypatch: pytest.MonkeyPatch,
    mode: str,
) -> None:
    monkeypatch.setenv("SNAPSHOT_TEST_MODE", mode)
    result = run_launcher(0, 0, False)
    assert result.returncode != 0, result.stdout + result.stderr


def test_existing_images_cannot_mask_missing_new_output(
    run_launcher: Callable[[int, int, bool], subprocess.CompletedProcess[str]],
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    output = tmp_path / "output"
    output.mkdir()
    stale = output / "previous.png"
    stale.write_text("previous synthetic fixture; not a screenshot")
    monkeypatch.setenv("SNAPSHOT_TEST_MODE", "no-image")
    result = run_launcher(0, 0, False)
    assert result.returncode != 0, result.stdout + result.stderr
    assert stale.read_text() == "previous synthetic fixture; not a screenshot"
    assert not (output / "app-started").exists()


def test_explicit_probe_only_run_does_not_require_images(
    run_launcher: Callable[[int, int, bool], subprocess.CompletedProcess[str]],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("TRANSLATOR_DEBUG_SNAPSHOT_SCENES", "probes")
    monkeypatch.setenv("SNAPSHOT_TEST_MODE", "probes-only")
    result = run_launcher(0, 0, False)
    assert result.returncode == 0, result.stdout + result.stderr


def test_interrupted_launcher_stops_only_its_owned_processes(
    run_launcher: Callable[[int, int, bool], subprocess.CompletedProcess[str]],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("SNAPSHOT_TEST_MODE", "interrupted")
    result = run_launcher(0, 0, False)
    assert result.returncode == 143, result.stdout + result.stderr


def test_missing_requested_scene_is_rejected(
    run_launcher: Callable[[int, int, bool], subprocess.CompletedProcess[str]],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("TRANSLATOR_DEBUG_SNAPSHOT_SCENES", "popup,settings")
    result = run_launcher(0, 0, False)
    assert result.returncode != 0, result.stdout + result.stderr


def test_declared_capture_must_exist_in_the_new_output(
    run_launcher: Callable[[int, int, bool], subprocess.CompletedProcess[str]],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("SNAPSHOT_TEST_MODE", "missing-written")
    result = run_launcher(0, 0, False)
    assert result.returncode != 0, result.stdout + result.stderr
