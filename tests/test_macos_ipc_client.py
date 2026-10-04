"""Real native transport against explicitly synthetic, isolated UDS responders."""

from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
import json
from pathlib import Path
import subprocess
import sys
import time
from typing import cast
import uuid

import pytest

REPO = Path(__file__).resolve().parents[1]
PACKAGE = REPO / "macos/Translator"
pytestmark = pytest.mark.skipif(
    sys.platform != "darwin", reason="Darwin native transport"
)

HARNESS = r"""
import Foundation
import TranslatorCore

@MainActor final class Observation {
    var connected = false
    var failure: String? = nil
    var events: [String] = []
}

@main struct Harness {
    @MainActor static func main() async {
        let client = IPCClient(socketPath: CommandLine.arguments[1])
        let observed = Observation()
        client.onStateChange = { state in
            if state == .connected { observed.connected = true }
            if case let .failed(message) = state { observed.failure = message }
        }
        client.onEvent = { observed.events.append($0.name) }
        client.start()
        let deadline = Date().addingTimeInterval(4)
        while !observed.connected && observed.failure == nil && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        var sent = false
        do { _ = try await client.send("settings.get"); sent = true } catch {}
        try? await Task.sleep(for: .milliseconds(100))
        let connected = client.isConnected
        client.stop()
        let values: [String: Any] = ["connected": connected, "ever_connected": observed.connected,
                                    "request_sent": sent, "events": observed.events,
                                    "failure": observed.failure ?? ""]
        print(String(data: try! JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]), encoding: .utf8)!)
    }
}
"""


@pytest.fixture(scope="module")
def client_harness(tmp_path_factory: pytest.TempPathFactory) -> Path:
    subprocess.run(
        ["swift", "build", "-c", "release", "--package-path", str(PACKAGE)],
        check=True,
        capture_output=True,
    )
    build = PACKAGE / ".build/release"
    objects = sorted((build / "TranslatorCore.build").glob("*.o"))
    assert objects and (build / "Modules/TranslatorCore.swiftmodule").exists()
    root = tmp_path_factory.mktemp("native-ipc")
    source = root / "Harness.swift"
    source.write_text(HARNESS)
    binary = root / "Harness"
    subprocess.run(
        [
            "swiftc",
            "-parse-as-library",
            "-I",
            str(build / "Modules"),
            str(PACKAGE / "Sources/Translator/IPCClient.swift"),
            str(source),
            *map(str, objects),
            "-o",
            str(binary),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return binary


def frame(value: dict[str, object]) -> bytes:
    return (json.dumps(value) + "\n").encode()


async def exercise(
    harness: Path,
    response: Callable[[asyncio.StreamWriter, object], Awaitable[None]],
) -> tuple[dict[str, object], list[str], float]:
    socket = Path("/tmp/tr-client-" + uuid.uuid4().hex[:12] + ".sock")
    methods: list[str] = []
    tasks: list[asyncio.Task[None]] = []

    async def connected(
        reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) -> None:
        task = asyncio.current_task()
        assert task is not None
        tasks.append(task)
        try:
            raw = await reader.readline()
            request = cast(dict[str, object], json.loads(raw))
            methods.append(str(request["method"]))
            await response(writer, request["id"])
            while raw := await reader.readline():
                request = cast(dict[str, object], json.loads(raw))
                methods.append(str(request["method"]))
                # Longer than the handshake recv timeout: normal reads must be blocking.
                await asyncio.sleep(1.2)
                writer.write(frame({"id": request["id"], "ok": True, "result": {}}))
                await writer.drain()
        except (ConnectionError, BrokenPipeError):
            pass
        finally:
            writer.close()
            try:
                await writer.wait_closed()
            except ConnectionError:
                pass

    server = await asyncio.start_unix_server(connected, path=socket)
    started = time.monotonic()
    process: asyncio.subprocess.Process | None = None
    try:
        process = await asyncio.create_subprocess_exec(
            str(harness),
            str(socket),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=10)
        assert process.returncode == 0, stderr.decode()
        decoded: object = json.loads(stdout)
        assert isinstance(decoded, dict)
        return cast(dict[str, object], decoded), methods, time.monotonic() - started
    finally:
        if process is not None and process.returncode is None:
            process.terminate()
            try:
                await asyncio.wait_for(process.wait(), timeout=3)
            except TimeoutError:
                process.kill()
                await process.wait()
        server.close()
        await server.wait_closed()
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        socket.unlink(missing_ok=True)


def test_handshake_preserves_initial_and_partial_events_and_normal_read_timeout(
    client_harness: Path,
) -> None:
    async def response(writer: asyncio.StreamWriter, ident: object) -> None:
        partial = frame({"event": "fixture.partial", "payload": {}})
        writer.write(
            frame({"event": "fixture.before", "payload": {}})
            + frame(
                {
                    "id": ident,
                    "ok": True,
                    "result": {
                        "protocol": 1,
                        "pid": 123,
                        "capabilities": {"history_persistence": True},
                    },
                }
            )
            + frame({"event": "fixture.after", "payload": {}})
            + partial[:8]
        )
        await writer.drain()
        await asyncio.sleep(0.05)
        writer.write(partial[8:])
        await writer.drain()

    result, methods, elapsed = asyncio.run(exercise(client_harness, response))
    assert result["connected"] is True and result["ever_connected"] is True
    assert result["request_sent"] is True and methods == ["ping", "settings.get"]
    assert result["events"] == ["fixture.before", "fixture.after", "fixture.partial"]
    assert elapsed >= 1.2


@pytest.mark.parametrize(
    "capabilities", [None, {"history_persistence": False}, {"history_persistence": 1}]
)
def test_incompatible_listener_never_connects_or_receives_app_requests(
    client_harness: Path,
    capabilities: dict[str, object] | None,
) -> None:
    async def response(writer: asyncio.StreamWriter, ident: object) -> None:
        ping: dict[str, object] = {"protocol": 1, "pid": 123}
        if capabilities is not None:
            ping["capabilities"] = capabilities
        writer.write(
            frame({"event": "fixture.untrusted", "payload": {}})
            + frame({"id": ident, "ok": True, "result": ping})
        )
        await writer.drain()

    result, methods, _ = asyncio.run(exercise(client_harness, response))
    assert result["connected"] is False and result["ever_connected"] is False
    assert result["request_sent"] is False and methods == ["ping"]
    assert result["events"] == []
    assert "incompatible" in str(result["failure"])


@pytest.mark.parametrize("scenario", ["timeout", "oversized", "too-many-events"])
def test_handshake_is_bounded_and_does_not_expose_unverified_events(
    client_harness: Path,
    scenario: str,
) -> None:
    async def response(writer: asyncio.StreamWriter, ident: object) -> None:
        if scenario == "timeout":
            await asyncio.sleep(5)
        elif scenario == "oversized":
            writer.write(
                frame({"event": "fixture.large", "payload": {"text": "x" * 300_000}})
            )
            await writer.drain()
        else:
            writer.write(frame({"event": "fixture.many", "payload": {}}) * 1025)
            await writer.drain()

    result, methods, elapsed = asyncio.run(exercise(client_harness, response))
    assert result["ever_connected"] is False and result["request_sent"] is False
    assert result["events"] == [] and methods == ["ping"]
    assert elapsed < 5
