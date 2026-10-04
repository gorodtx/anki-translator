from __future__ import annotations

import sys
import hashlib

import pytest

from scripts.store_notary_credentials import store_credentials


def test_secure_prompt_keeps_synthetic_password_out_of_argv_env_and_output(
    capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
) -> None:
    password = "synthetic-password-for-test"
    monkeypatch.setenv("APPLE_APP_PASSWORD", password)
    digest = hashlib.sha256(password.encode()).hexdigest()
    command = [
        sys.executable,
        "-c",
        f"""
import getpass, os, sys, hashlib
assert 'APPLE_APP_PASSWORD' not in os.environ
assert len(sys.argv) == 1
password = getpass.getpass('App-specific password: ')
print(password)
assert hashlib.sha256(password.encode()).hexdigest() == '{digest}'
""",
    ]
    assert store_credentials(command, password, timeout=5) == 0
    assert password not in capsys.readouterr().out


def test_unexpected_cli_without_password_prompt_fails_closed() -> None:
    assert (
        store_credentials(
            [sys.executable, "-c", "print('no secure prompt')"],
            "test-password",
            timeout=2,
        )
        == 1
    )


def test_secure_prompt_propagates_failed_credential_validation() -> None:
    command = [
        sys.executable,
        "-c",
        "import getpass,sys; getpass.getpass('Password: '); sys.exit(7)",
    ]
    assert store_credentials(command, "test-password", timeout=5) == 7
