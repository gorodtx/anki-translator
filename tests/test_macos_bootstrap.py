"""Exercise the production Foundation bootstrap with isolated real processes."""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid
from typing import cast

import pytest

REPO = Path(__file__).resolve().parents[1]
pytestmark = pytest.mark.skipif(
    sys.platform != "darwin", reason="Foundation/Darwin bootstrap"
)

HARNESS = r"""
import Darwin
import Foundation

@main
struct Harness {
    @MainActor
    static func main() async {
        let args = CommandLine.arguments
        let bootstrap = BackendBootstrap(executable: URL(fileURLWithPath: args[1]),
                                         readinessTimeout: 1.5)
        let first = await bootstrap.start(socketPath: args[2])
        if args[3] == "exhaust" {
            try? await Task.sleep(for: .seconds(6))
            _ = await bootstrap.start(socketPath: args[2])
        }
        if args[3] == "retry" || args[3] == "exhaust" {
            let path = ProcessInfo.processInfo.environment["FAKE_RECORD"]!
            let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            if let pid = text.split(separator: "\n").last.flatMap({ Int32($0) }) {
                _ = Darwin.kill(pid, SIGTERM)
            }
            try? await Task.sleep(for: .seconds(2))
        }
        let final = await bootstrap.start(socketPath: args[2])
        bootstrap.stop()
        print("{\"first_ready\":\(first == nil),\"final_ready\":\(final == nil)}")
    }
}
"""

SERVER = r"""
import json, os, signal, socket, sys
from pathlib import Path

record = Path(os.environ["FAKE_RECORD"])
previous = record.read_text().splitlines() if record.exists() else []
with record.open("a") as stream:
    stream.write(str(os.getpid()) + "\n")
if len(previous) < int(os.environ.get("FAKE_CRASHES", "0")):
    sys.exit(0)
path = os.environ["TRANSLATOR_SOCKET_PATH"]
Path(path).unlink(missing_ok=True)
server = socket.socket(socket.AF_UNIX)
server.bind(path)
server.listen()
Path(os.environ["FAKE_PARENT"]).write_text(json.dumps({
    "pid": os.getpid(), "ppid": os.getppid(),
    "declared_parent": os.environ.get("TRANSLATOR_PARENT_PID")
}))
def stop(*args):
    server.close()
    Path(path).unlink(missing_ok=True)
    sys.exit(0)
signal.signal(signal.SIGTERM, stop)
while True:
    connection, _ = server.accept()
    with connection:
        request = json.loads(connection.recv(4096))
        result = {"protocol": int(os.environ.get("FAKE_PROTOCOL", "1")), "pid": os.getpid()}
        capability = os.environ.get("FAKE_CAPABILITY", "true")
        if capability != "missing":
            result["capabilities"] = {"history_persistence": json.loads(capability)}
        connection.sendall((json.dumps({"id": request["id"], "ok": True,
            "result": result}) + "\n").encode())
"""


@pytest.fixture(scope="module")
def bootstrap_harness(tmp_path_factory: pytest.TempPathFactory) -> Path:
    assert shutil.which("swiftc"), "macOS bootstrap tests require Swift"
    directory = tmp_path_factory.mktemp("bootstrap-compile")
    source = directory / "Harness.swift"
    source.write_text(HARNESS)
    binary = directory / "Harness"
    subprocess.run(
        [
            "swiftc",
            "-parse-as-library",
            str(
                REPO
                / "macos/Translator/Sources/TranslatorCore/BackendCompatibility.swift"
            ),
            str(REPO / "macos/Translator/Sources/Translator/BackendBootstrap.swift"),
            str(source),
            "-o",
            str(binary),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return binary


def _environment(directory: Path) -> dict[str, str]:
    environment = dict(os.environ)
    environment.update(
        {
            "TRANSLATOR_CONFIG_DIR": str(directory / "cfg"),
            "TRANSLATOR_LOG_DIR": str(directory / "logs"),
            "TRANSLATOR_SOCKET_PATH": f"/tmp/tr-bootstrap-{uuid.uuid4().hex[:12]}.sock",
            "FAKE_RECORD": str(directory / "pids"),
            "FAKE_PARENT": str(directory / "parent.json"),
        }
    )
    return environment


def _server(directory: Path) -> Path:
    source = directory / "server.py"
    source.write_text(SERVER)
    launcher = directory / "backend"
    # The developer test uses the uv-selected interpreter; no user app relies on it.
    import shlex

    launcher.write_text(
        f"#!/bin/sh\nexec {shlex.quote(sys.executable)} {shlex.quote(str(source))}\n"
    )
    launcher.chmod(0o700)
    return launcher


def _run(
    harness: Path, backend: Path, environment: dict[str, str], mode: str
) -> dict[str, bool]:
    result = subprocess.run(
        [str(harness), str(backend), environment["TRANSLATOR_SOCKET_PATH"], mode],
        env=environment,
        text=True,
        capture_output=True,
        timeout=25,
        check=True,
    )
    loaded: object = json.loads(result.stdout.splitlines()[-1])
    assert isinstance(loaded, dict)
    return cast(dict[str, bool], loaded)


def _assert_children_gone(environment: dict[str, str]) -> list[int]:
    pids = [
        int(line) for line in Path(environment["FAKE_RECORD"]).read_text().splitlines()
    ]
    for pid in pids:
        with pytest.raises(ProcessLookupError):
            os.kill(pid, 0)
    return pids


def test_bootstrap_launches_embedded_child_and_retries_only_owned_pid(
    bootstrap_harness: Path, tmp_path: Path
) -> None:
    environment = _environment(tmp_path)
    assert _run(bootstrap_harness, _server(tmp_path), environment, "retry") == {
        "first_ready": True,
        "final_ready": True,
    }
    assert len(_assert_children_gone(environment)) == 2
    parent = json.loads(Path(environment["FAKE_PARENT"]).read_text())
    assert parent["declared_parent"] == str(parent["ppid"])
    assert not Path(environment["TRANSLATOR_SOCKET_PATH"]).exists()


def test_manual_retry_recovers_after_automatic_restart_budget(
    bootstrap_harness: Path, tmp_path: Path
) -> None:
    environment = _environment(tmp_path)
    environment["FAKE_CRASHES"] = "4"
    result = _run(bootstrap_harness, _server(tmp_path), environment, "exhaust")
    assert result == {"first_ready": False, "final_ready": True}
    assert len(_assert_children_gone(environment)) == 6


@pytest.mark.parametrize(
    "protocol,capability,ready",
    [
        ("1", "true", True),
        ("2", "true", False),
        ("1", "missing", False),
        ("1", "false", False),
        ("1", "1", False),
    ],
)
def test_bootstrap_never_launches_over_or_signals_existing_listener(
    bootstrap_harness: Path, tmp_path: Path, protocol: str, capability: str, ready: bool
) -> None:
    environment = _environment(tmp_path)
    environment["FAKE_PROTOCOL"] = protocol
    environment["FAKE_CAPABILITY"] = capability
    server = subprocess.Popen([str(_server(tmp_path))], env=environment)
    try:
        deadline = time.monotonic() + 5
        while (
            not Path(environment["TRANSLATOR_SOCKET_PATH"]).exists()
            and time.monotonic() < deadline
        ):
            time.sleep(0.05)
        assert Path(environment["TRANSLATOR_SOCKET_PATH"]).exists()
        # This executable cannot serve ping: any accidental launch breaks the assertion.
        assert _run(
            bootstrap_harness, Path("/usr/bin/false"), environment, "attach"
        ) == {"first_ready": ready, "final_ready": ready}
        assert server.poll() is None
        assert Path(environment["FAKE_RECORD"]).read_text().splitlines() == [
            str(server.pid)
        ]
    finally:
        server.terminate()
        server.wait(timeout=5)


def test_opt_in_defaults_store_writes_only_its_named_domain(tmp_path: Path) -> None:
    suite = "com.translator.distribution-test." + uuid.uuid4().hex
    source = tmp_path / "DefaultsHarness.swift"
    source.write_text(r"""
import Foundation
@main struct DefaultsHarness {
    static func main() {
        guard let suite = ProcessInfo.processInfo.environment["TRANSLATOR_DEFAULTS_SUITE"] else {
            print(AppDefaults.isIsolated ? "isolated" : "standard")
            return
        }
        let key = "probe-" + suite
        guard AppDefaults.isIsolated else { exit(1) }
        AppDefaults.store.set("isolated-probe", forKey: key)
        guard AppDefaults.store.string(forKey: key) == "isolated-probe",
              UserDefaults.standard.object(forKey: key) == nil else { exit(2) }
        AppDefaults.store.removePersistentDomain(forName: suite)
        AppDefaults.store.synchronize()
        print("named-domain-only")
    }
}
""")
    binary = tmp_path / "DefaultsHarness"
    subprocess.run(
        [
            "swiftc",
            "-parse-as-library",
            str(REPO / "macos/Translator/Sources/Translator/AppDefaults.swift"),
            str(source),
            "-o",
            str(binary),
        ],
        check=True,
        capture_output=True,
    )
    result = subprocess.run(
        [str(binary)],
        env={"PATH": os.defpath, "TRANSLATOR_DEFAULTS_SUITE": suite},
        text=True,
        capture_output=True,
        check=True,
    )
    assert result.stdout.strip() == "named-domain-only"
    ordinary = subprocess.run(
        [str(binary)],
        env={"PATH": os.defpath},
        text=True,
        capture_output=True,
        check=True,
    )
    assert ordinary.stdout.strip() == "standard"
