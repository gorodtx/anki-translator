from __future__ import annotations

import asyncio
from pathlib import Path

import pytest

from desktop_app.platform.macos.daemon import (
    _configured_parent_pid,
    _monitor_parent,
    _write_pid_file,
)


@pytest.mark.parametrize("value", ["", "invalid", "0", "1", "-8"])
def test_external_daemon_does_not_opt_in_from_invalid_pid(
    monkeypatch: pytest.MonkeyPatch, value: str
) -> None:
    monkeypatch.setenv("TRANSLATOR_PARENT_PID", value)
    assert _configured_parent_pid() is None


def test_explicit_parent_pid_is_parsed(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("TRANSLATOR_PARENT_PID", " 12345 ")
    assert _configured_parent_pid() == 12345


def test_parent_death_requests_graceful_shutdown(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def scenario() -> None:
        stopped = asyncio.Event()
        parent = [12345]
        monkeypatch.setattr("os.getppid", lambda: parent[0])
        watch = asyncio.create_task(_monitor_parent(12345, stopped.set, interval=0.001))
        await asyncio.sleep(0.01)
        assert not stopped.is_set()
        parent[0] = 1
        await asyncio.wait_for(stopped.wait(), 1)
        await watch

    asyncio.run(scenario())


def test_parent_already_gone_during_startup_stops_without_signalling(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def scenario() -> None:
        stopped = asyncio.Event()
        monkeypatch.setattr("os.getppid", lambda: 1)
        await _monitor_parent(12345, stopped.set)
        assert stopped.is_set()

    asyncio.run(scenario())


def test_parallel_custom_sockets_do_not_overwrite_or_remove_peer_pid_marker(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr("os.getpid", lambda: 1001)
    first = _write_pid_file(tmp_path / "first.sock")
    monkeypatch.setattr("os.getpid", lambda: 1002)
    second = _write_pid_file(tmp_path / "second.sock")
    assert first is not None and second is not None
    assert first.read_text() == "1001"
    assert second.read_text() == "1002"
    first.unlink()
    assert second.read_text() == "1002"
    # Preserve the installer contract for the default production socket.
    standard = _write_pid_file(tmp_path / "backend.sock")
    assert standard is not None and standard.name == "backend.pid"
