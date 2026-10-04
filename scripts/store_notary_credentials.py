"""Feed notarytool's documented secure prompt without putting secrets in argv."""

from __future__ import annotations

import os
import fcntl
import pty
import re
import select
import subprocess
import sys
import termios
import time


def store_credentials(
    command: list[str], password: str, *, timeout: float = 120
) -> int:
    """Use an echo-disabled PTY; refuse an unexpected or repeated prompt."""
    master, slave = pty.openpty()
    attributes = termios.tcgetattr(slave)
    attributes[3] &= ~termios.ECHO
    termios.tcsetattr(slave, termios.TCSANOW, attributes)
    environment = dict(os.environ)
    environment.pop("APPLE_APP_PASSWORD", None)
    output = bytearray()
    sent = False

    def child_terminal() -> None:
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    process = subprocess.Popen(
        command,
        stdin=slave,
        stdout=slave,
        stderr=slave,
        env=environment,
        preexec_fn=child_terminal,
    )
    os.close(slave)
    try:
        deadline = time.monotonic() + timeout
        while process.poll() is None and time.monotonic() < deadline:
            if not select.select([master], [], [], 0.1)[0]:
                continue
            try:
                chunk = os.read(master, 8192)
            except OSError:
                break
            output.extend(chunk)
            if not sent and re.search(rb"password[^\r\n]*:", output, re.I):
                os.write(master, (password + "\n").encode())
                sent = True
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        while select.select([master], [], [], 0)[0]:
            try:
                chunk = os.read(master, 8192)
            except OSError:
                break
            if not chunk:
                break
            output.extend(chunk)
    finally:
        os.close(master)
    # Be safe even if a changed CLI unexpectedly echoes its input.
    print(output.decode(errors="replace").replace(password, "[REDACTED]"))
    return process.returncode if sent and process.returncode is not None else 1


def main() -> int:
    password = os.environ.get("APPLE_APP_PASSWORD", "")
    apple_id = os.environ.get("APPLE_ID", "")
    team_id = os.environ.get("APPLE_TEAM_ID", "")
    if not all((password, apple_id, team_id)) or len(sys.argv) != 3:
        print(
            "Apple credentials, profile and temporary keychain are required.",
            file=sys.stderr,
        )
        return 1
    return store_credentials(
        [
            "xcrun",
            "notarytool",
            "store-credentials",
            sys.argv[1],
            "--apple-id",
            apple_id,
            "--team-id",
            team_id,
            "--keychain",
            sys.argv[2],
        ],
        password,
    )


if __name__ == "__main__":
    raise SystemExit(main())
