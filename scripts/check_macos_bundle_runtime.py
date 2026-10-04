"""Check both bundled launchers from an isolated cwd containing a poison package."""

from __future__ import annotations

import argparse
import asyncio
import json
from pathlib import Path
import tempfile
from typing import cast


def object_map(value: object) -> dict[str, object]:
    if not isinstance(value, dict):
        raise AssertionError("expected a JSON object")
    return cast(dict[str, object], value)


async def request(
    reader: asyncio.StreamReader,
    writer: asyncio.StreamWriter,
    number: int,
    method: str,
) -> dict[str, object]:
    writer.write((json.dumps({"id": number, "method": method}) + "\n").encode())
    await writer.drain()
    async with asyncio.timeout(10):
        for _ in range(1024):
            line = await reader.readline()
            if not line:
                raise AssertionError("backend closed before its reply")
            reply = object_map(json.loads(line))
            if reply.get("id") == number:
                if reply.get("ok") is not True:
                    raise AssertionError(f"backend refused {method}")
                return object_map(reply["result"])
    raise AssertionError("backend event stream did not reach its reply")


async def check_launcher(app: Path, name: str, report: Path) -> dict[str, object]:
    executable = app / (
        "Contents/MacOS/TranslatorBackend"
        if name == "native"
        else "Contents/Resources/bin/run-backend"
    )
    result: dict[str, object] = {"launcher": name, "executable": str(executable)}
    process: asyncio.subprocess.Process | None = None
    writer: asyncio.StreamWriter | None = None
    with tempfile.TemporaryDirectory(prefix="tr-bundle-", dir="/tmp") as temporary:
        root = Path(temporary)
        poison = root / "cwd/desktop_app"
        poison.mkdir(parents=True)
        marker = root / "poison-imported"
        (poison / "__init__.py").write_text(
            "from pathlib import Path\n"
            f"Path({str(marker)!r}).write_text('cwd package imported')\n"
            "raise RuntimeError('poisoned cwd package imported')\n"
        )
        socket = root / "run/backend.sock"
        (root / "db").mkdir()
        socket.parent.mkdir()
        environment = {
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "LANG": "en_US.UTF-8",
            "TRANSLATOR_CONFIG_DIR": str(root / "cfg"),
            "TRANSLATOR_DB_DIR": str(root / "db"),
            "TRANSLATOR_RUNTIME_DIR": str(socket.parent),
            "TRANSLATOR_SOCKET_PATH": str(socket),
            "TRANSLATOR_LOG_DIR": str(root / "logs"),
            "ANKI_CONNECT_URL": "http://127.0.0.1:1",
            "PYTHONDONTWRITEBYTECODE": "1",
        }
        log_path = report.with_name(report.stem + "-" + name + ".log")
        result.update(
            cwd=str(poison.parent), log=str(log_path), minimal_path=environment["PATH"]
        )
        with log_path.open("wb") as log:
            try:
                process = await asyncio.create_subprocess_exec(
                    str(executable),
                    "--log-level",
                    "INFO",
                    cwd=poison.parent,
                    env=environment,
                    stdout=log,
                    stderr=log,
                )
                result["pid"] = process.pid
                async with asyncio.timeout(30):
                    while not socket.is_socket():
                        if process.returncode is not None:
                            raise AssertionError(
                                f"launcher exited early: {process.returncode}"
                            )
                        await asyncio.sleep(0.1)
                reader, writer = await asyncio.open_unix_connection(str(socket))
                ping = await request(reader, writer, 1, "ping")
                result["ping"] = ping
                assert ping["pid"] == process.pid
                assert ping["protocol"] == 1
                assert object_map(ping["capabilities"])["history_persistence"] is True
                db = object_map(ping["db"])
                assert all(
                    db[key] is False for key in ("primary", "fallback", "definitions")
                )
                assert all(
                    value is None for value in object_map(db["sources"]).values()
                )
                assert db["pending_bytes"] == 1_896_546_304
                assert not marker.exists(), "launcher imported the poisoned cwd package"
                await request(reader, writer, 2, "shutdown")
                assert await asyncio.wait_for(process.wait(), 15) == 0
                assert not socket.exists()
                result["result"] = "PASS"
            except Exception as error:
                result["result"] = "FAIL"
                result["error"] = str(error)
            finally:
                if writer is not None:
                    writer.close()
                    try:
                        await writer.wait_closed()
                    except ConnectionError:
                        pass
                if process is not None and process.returncode is None:
                    process.terminate()
                    try:
                        await asyncio.wait_for(process.wait(), 10)
                    except TimeoutError:
                        process.kill()
                        await process.wait()
                result["exit"] = process.returncode if process is not None else None
                result["poison_imported"] = marker.exists()
                result["owned_process_stopped"] = (
                    process is None or process.returncode is not None
                )
                result["socket_removed"] = not socket.exists()
    result["owned_profile_removed"] = not root.exists()
    return result


async def check(app: Path, report: Path) -> int:
    app = app.resolve(strict=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    manifest = object_map(
        json.loads((app / "Contents/Resources/build-info.json").read_text())
    )
    results = [await check_launcher(app, name, report) for name in ("native", "shell")]
    verify = await asyncio.create_subprocess_exec(
        "/usr/bin/codesign",
        "--verify",
        "--deep",
        "--strict",
        str(app),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    _, seal_error = await verify.communicate()
    output = {
        "artifact": manifest,
        "scope": "реальные embedded launchers; poisoned cwd; минимальный PATH; пустой isolated DB",
        "launchers": results,
        "seal_after_exit": verify.returncode,
        "seal_error": seal_error.decode(),
    }
    report.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n")
    passed = verify.returncode == 0 and all(
        item["result"] == "PASS" for item in results
    )
    print(f"bundle launchers: {'PASS' if passed else 'FAIL'}; report: {report}")
    return 0 if passed else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    arguments = parser.parse_args()
    return asyncio.run(check(arguments.app, arguments.report))


if __name__ == "__main__":
    raise SystemExit(main())
