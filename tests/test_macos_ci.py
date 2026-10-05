from __future__ import annotations

from pathlib import Path
import plistlib
import subprocess
import os
import sys
from typing import Any, cast

import yaml
import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = REPO_ROOT / ".github" / "workflows" / "macos.yml"

type JobMap = dict[str, dict[str, Any]]
type Step = dict[str, Any]


def _workflow() -> dict[str, Any]:
    loaded: object = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    assert isinstance(loaded, dict)
    return cast(dict[str, Any], loaded)


def _jobs() -> JobMap:
    jobs = _workflow()["jobs"]
    assert isinstance(jobs, dict)
    return cast(JobMap, jobs)


def _steps(job: str) -> list[Step]:
    steps = _jobs()[job]["steps"]
    assert isinstance(steps, list)
    return cast(list[Step], steps)


def _commands(job: str) -> str:
    return " ".join(str(step.get("run", "")) for step in _steps(job))


def test_workflow_declares_the_expected_job_graph() -> None:
    jobs = _jobs()

    assert set(jobs) == {
        "gate",
        "linux-parity",
        "sidecar",
        "shell",
        "bundle",
        "notarize",
    }
    assert jobs["bundle"]["needs"] == ["gate", "sidecar", "shell", "linux-parity"]
    assert jobs["notarize"]["needs"] == ["bundle"]
    assert jobs["linux-parity"]["runs-on"] == "ubuntu-latest"
    assert all(
        str(job["runs-on"]).startswith("macos-")
        for name, job in jobs.items()
        if name != "linux-parity"
    )
    # Python's real IPC regression also builds the Swift package (tools 6.2).
    # All native build jobs need the macOS 26 SDK/toolchain.
    assert jobs["gate"]["runs-on"] == "macos-26"
    assert jobs["sidecar"]["runs-on"] == "macos-26"
    assert jobs["shell"]["runs-on"] == "macos-26"
    assert jobs["bundle"]["runs-on"] == "macos-26"


def test_sidecar_job_runs_its_swift_tests() -> None:
    commands = _commands("sidecar")

    assert "swift build -c release" in commands
    assert "scripts/swift-test.sh" in commands
    assert "macOS 26 SDK required" in commands


def test_shell_job_builds_tests_and_checks_protocol_parity() -> None:
    commands = _commands("shell")

    assert "swift build -c release" in commands
    assert "scripts/swift-test.sh" in commands
    assert "swift shell is missing" in commands


def test_bundle_verifies_a_real_shell_binary_not_the_placeholder() -> None:
    commands = _commands("bundle")

    assert 'test -x "${app}/Contents/MacOS/Translator"' in commands
    assert "Mach-O" in commands


def test_linux_job_proves_the_engine_is_not_forked() -> None:
    commands = _commands("linux-parity")

    assert "pytest" in commands
    assert "mypy" in commands
    assert "apple engines must stay off on Linux" in commands
    assert "/tmp/cfg/translator" in commands


def test_every_run_block_is_valid_shell() -> None:
    for name in _jobs():
        for step in _steps(name):
            run = step.get("run")
            if not isinstance(run, str):
                continue
            result = subprocess.run(
                ["bash", "-n"], input=run, text=True, capture_output=True, check=False
            )
            assert result.returncode == 0, f"{name}/{step.get('name')}: {result.stderr}"


def test_run_blocks_avoid_bash_4_builtins() -> None:
    # GitHub's macOS runners ship bash 3.2 as /bin/bash.
    for name in _jobs():
        for step in _steps(name):
            run = step.get("run")
            if not isinstance(run, str):
                continue
            for builtin in ("mapfile", "readarray", "declare -A"):
                assert builtin not in run, f"{name}/{step.get('name')} uses {builtin}"


def test_gate_runs_lint_types_and_tests() -> None:
    commands = _commands("gate")

    # The gate must cover every Python file in the repo, not a hand-picked list:
    # macos/Translator/scripts/mock_backend.py slipped past a narrower check.
    assert "ruff check ." in commands
    assert "ruff format --check" in commands
    assert "mypy" in commands
    assert "pytest" in commands


def test_bundle_job_refuses_to_ship_offline_databases() -> None:
    commands = _commands("bundle")

    assert "scripts/build_macos_app.sh" in commands
    assert "offline databases leaked into the bundle" in commands
    assert "codesign -v --deep --strict" in commands


def test_bundle_smoke_checks_both_actual_launchers_without_checkout_imports() -> None:
    commands = _commands("bundle")
    assert "scripts/check_macos_bundle_runtime.py" in commands
    assert (
        '--app dist/Translator.app --report "${RUNNER_TEMP}/bundle-runtime.json"'
        in commands
    )
    assert "python -m desktop_app.platform.macos.client" not in commands
    assert 'wait "${backend_pid}" 2>/dev/null || true' not in commands


@pytest.mark.parametrize("failure", ["", "checksum", "obsolete_installer"])
def test_dmg_release_contract_checks_bytes_and_rejects_extra_installer(
    tmp_path: Path, failure: str
) -> None:
    from dev.scripts.release_metadata import sha256_file

    step = next(
        item
        for item in _steps("bundle")
        if item.get("name") == "Verify DMG release contract"
    )
    script = str(step["run"]).split("<<'PY'\n", 1)[1].rsplit("\nPY", 1)[0]
    contents = tmp_path / "dist/Translator.app/Contents"
    contents.mkdir(parents=True)
    (contents / "Info.plist").write_bytes(
        plistlib.dumps({"CFBundleShortVersionString": "9.9.9"})
    )
    output = tmp_path / "out"
    output.mkdir()
    name = "Translator-9.9.9-macos-arm64.dmg"
    image = output / name
    image.write_bytes(b"synthetic image for checksum contract")
    digest = "0" * 64 if failure == "checksum" else sha256_file(image)
    (output / f"{name}.sha256").write_text(f"{digest}  {name}\n", encoding="utf-8")
    (output / "Translator-macos.zip").write_bytes(b"internal CI transport")
    if failure == "obsolete_installer":
        (output / "obsolete-install.sh").write_text("#!/bin/sh\n", encoding="utf-8")
    result = subprocess.run(
        [sys.executable, "-c", script],
        cwd=tmp_path,
        env={
            "PATH": os.defpath,
            "PYTHONPATH": str(REPO_ROOT),
            "PYTHONDONTWRITEBYTECODE": "1",
        },
        capture_output=True,
        text=True,
        check=False,
    )
    assert (result.returncode == 0) == (failure == ""), result.stderr


def test_notarize_job_is_tag_gated_and_secret_gated() -> None:
    job = _jobs()["notarize"]

    assert "startsWith(github.ref, 'refs/tags/')" in str(job["if"])
    guarded = [
        step
        for step in _steps("notarize")
        if "steps.secrets.outputs.ready == 'true'" in str(step.get("if", ""))
    ]
    # Signing, notarizing and uploading all stay behind the secret check.
    assert len(guarded) >= 3
    commands = _commands("notarize")
    assert "notarytool submit" in commands
    assert "stapler staple" in commands
    assert "options runtime" in commands


@pytest.mark.parametrize(
    "missing",
    [
        "",
        "CERT_BASE64",
        "CERT_PASSWORD",
        "APPLE_APP_PASSWORD",
        "APPLE_SIGNING_IDENTITY",
        "APPLE_ID",
        "APPLE_TEAM_ID",
    ],
)
def test_tag_notarization_refuses_incomplete_credentials(
    tmp_path: Path, missing: str
) -> None:
    check = next(step for step in _steps("notarize") if step.get("id") == "secrets")
    names = {
        "APPLE_ID",
        "APPLE_TEAM_ID",
        "APPLE_APP_PASSWORD",
        "APPLE_SIGNING_IDENTITY",
        "CERT_BASE64",
        "CERT_PASSWORD",
    }
    assert set(check["env"]) == names
    environment = {"PATH": os.defpath, "GITHUB_OUTPUT": str(tmp_path / "output")}
    environment.update({name: "synthetic-test-value" for name in names})
    if missing:
        environment[missing] = ""
    result = subprocess.run(
        ["bash", "-c", str(check["run"])],
        env=environment,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == (1 if missing else 0)
    assert "synthetic-test-value" not in result.stdout + result.stderr
    assert environment["GITHUB_OUTPUT"]
    assert (tmp_path / "output").read_text().strip() == (
        "ready=false" if missing else "ready=true"
    )


def test_notarization_uses_shared_signing_and_final_dmg_checksums() -> None:
    commands = _commands("notarize")
    assert "scripts/sign_macos_app.sh" in commands
    assert "scripts/import_macos_certificate.swift" in commands
    assert "scripts/store_notary_credentials.py" in commands
    assert '--password "${APPLE_APP_PASSWORD}"' not in commands
    assert '-P "${CERT_PASSWORD}"' not in commands
    assert commands.count('== "Accepted"') == 2
    assert commands.count("stapler validate") == 2
    assert commands.index('stapler staple "${dmg}"') < commands.index(
        '> "$(basename "${dmg}").sha256"'
    )
    assert "Remove temporary signing material" in {
        step.get("name") for step in _steps("notarize")
    }


def test_bundle_job_reruns_the_toolchain_against_the_built_app() -> None:
    """The seal regression can only be caught where a bundle exists.

    The gate job runs the suite with no bundle present, so
    `test_built_bundle_seal_is_intact` skips there. Only the bundle job can
    prove that running the toolchain leaves the signed app untouched.
    """
    commands = _commands("bundle")

    names = [str(step.get("name", "")) for step in _steps("bundle")]
    assert "The toolchain must not write into a signed bundle" in names
    assert "codesign --verify --deep --strict dist/Translator.app" in commands
    assert "bytecode was written into the bundle after signing" in commands
    # All three tools that walk the tree, not just pytest.
    assert "python -m pytest -q" in commands
    assert "ruff check ." in commands
    assert "python -m mypy" in commands
