from __future__ import annotations

from pathlib import Path
import os
import plistlib
import re
import subprocess

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD_SCRIPT = REPO_ROOT / "scripts" / "build_macos_app.sh"
RUN_SCRIPT = REPO_ROOT / "scripts" / "run_backend_macos.sh"
BUNDLE_ROOT = Path(
    os.environ.get("TRANSLATOR_TEST_APP", str(REPO_ROOT / "dist" / "Translator.app"))
)


def _script() -> str:
    return BUILD_SCRIPT.read_text(encoding="utf-8")


def test_build_script_is_executable_and_strict() -> None:
    assert BUILD_SCRIPT.exists() and RUN_SCRIPT.exists()
    for script in (BUILD_SCRIPT, RUN_SCRIPT):
        assert script.stat().st_mode & 0o111, f"{script.name} is not executable"
        assert "set -euo pipefail" in script.read_text(encoding="utf-8")


def test_build_script_passes_shell_syntax_check() -> None:
    for script in (BUILD_SCRIPT, RUN_SCRIPT):
        result = subprocess.run(
            ["bash", "-n", str(script)], capture_output=True, text=True, check=False
        )
        assert result.returncode == 0, result.stderr


def test_build_script_never_ships_offline_databases() -> None:
    text = _script()

    # The 1.8 GB bundle is downloaded into Application Support at first run;
    # shipping it inside the .app would break the immutable release contract.
    assert (
        'rm -rf "${RESOURCES}/app/translate_logic/infrastructure/language_base/offline_language_base"'
        in text
    )
    assert "db-bundle.lock.json" in text
    assert ".sqlite3" not in text


def test_build_script_embeds_runtime_and_sidecar() -> None:
    text = _script()

    assert "Resources/bin/apple-lang-helper" in text
    assert "TRANSLATOR_APPLE_HELPER" in text
    assert "runtime-requirements.txt" in text
    assert "desktop_app.platform.macos.daemon" in text
    for excluded in (
        "lib/python3.13/test",
        "lib/python3.13/idlelib",
        "lib/python3.13/tkinter",
    ):
        assert f"--exclude '{excluded}'" in text, excluded


def test_info_plist_declares_agent_service_and_minimum_os() -> None:
    text = _script()
    match = re.search(r"<\?xml.*?</plist>", text, re.DOTALL)
    assert match is not None, "Info.plist template not found"
    template = match.group(0)
    rendered = (
        template.replace("${APP_NAME}", "Translator")
        .replace("${BUNDLE_ID}", "com.translator.desktop")
        .replace("${APP_VERSION}", "0.3.0")
        .replace("${APP_BUILD}", "281")
        .replace("${MIN_MACOS}", "26.0")
    )
    plist = plistlib.loads(rendered.encode("utf-8"))

    assert plist["CFBundleIdentifier"] == "com.translator.desktop"
    # About shows "Version 0.3.0 (281)": the build number, not the version twice.
    assert plist["CFBundleShortVersionString"] == "0.3.0"
    assert plist["CFBundleVersion"] == "281"
    assert plist["LSUIElement"] is True
    assert plist["LSMinimumSystemVersion"] == "26.0"
    service = plist["NSServices"][0]
    assert service["NSMessage"] == "translateSelection"
    assert service["NSSendTypes"] == ["NSStringPboardType"]
    assert service["NSPortName"] == "Translator"
    assert service["NSRequiredContext"] == {}


@pytest.mark.parametrize("directory", ["dist/", "macos/**/.build/"])
def test_build_outputs_are_git_ignored(directory: str) -> None:
    ignored = (REPO_ROOT / ".gitignore").read_text(encoding="utf-8").splitlines()
    assert directory in ignored


def test_build_script_strips_test_helpers_from_the_bundle() -> None:
    """A tool that imports a shipped test helper writes a .pyc beside it.

    That single file breaks the code seal, and `spctl` then reports the bundle
    as invalid rather than merely unsigned — which would fail notarisation far
    from the build.
    """
    text = _script()

    assert "-name 'test_*.py'" in text
    assert "-name 'pytest_plugin.py'" in text
    assert "-name 'conftest.py'" in text


def test_build_script_trims_versioned_tcl_packages() -> None:
    # The original globs only matched `lib/tcl*`, so `lib/thread3.0.6` and
    # friends rode along.
    text = _script()

    assert "-name 'thread*'" in text
    assert "-name 'libtcl*'" in text


def test_build_script_verifies_its_own_seal() -> None:
    text = _script()

    assert "codesign --verify --deep --strict" in text
    assert "the bundle signature is invalid" in text


def test_pytest_never_collects_from_build_output() -> None:
    """Collecting inside `dist/` imports from the bundle and breaks its seal."""
    conftest = (REPO_ROOT / "conftest.py").read_text(encoding="utf-8")

    assert '"dist",' in conftest
    assert '"out",' in conftest


@pytest.mark.skipif(
    not BUNDLE_ROOT.exists(),
    reason="no bundle built (scripts/build_macos_app.sh)",
)
def test_built_bundle_seal_is_intact() -> None:
    """Guards the whole toolchain: nothing may write into a signed bundle."""
    result = subprocess.run(
        [
            "codesign",
            "--verify",
            "--deep",
            "--strict",
            str(BUNDLE_ROOT),
        ],
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr


def test_service_is_offered_on_any_selection() -> None:
    """An empty required context makes Services visible without filtering text."""
    text = _script()
    match = re.search(r"<\?xml.*?</plist>", text, re.DOTALL)
    assert match is not None
    # Dollar substitutions are valid XML text, so this checks the actual plist
    # template rather than merely finding the key in a comment or another entry.
    service = plistlib.loads(match.group(0).encode("utf-8"))["NSServices"][0]
    assert service["NSSendTypes"] == ["NSStringPboardType"]
    assert service["NSRequiredContext"] == {}


def test_bundle_identifier_matches_the_project_identity() -> None:
    # The same string is the D-Bus bus name on Linux and the launchd label in
    # the installer; a second identifier would earn a second, separate
    # Accessibility grant from the user.
    text = _script()
    installer = (REPO_ROOT / "scripts" / "install_macos.sh").read_text(encoding="utf-8")

    assert 'BUNDLE_ID="com.translator.desktop"' in text
    assert 'BUNDLE_ID="com.translator.desktop"' in installer
    # The SwiftPM bundle used during development has to claim the same identity, or a
    # grant given to the dev build does not carry over to the installed one.
    dev_script = REPO_ROOT / "macos" / "Translator" / "scripts" / "build_app.sh"
    dev_plist = REPO_ROOT / "macos" / "Translator" / "Resources" / "Info.plist"
    assert 'BUNDLE_ID="com.translator.desktop"' in dev_script.read_text(
        encoding="utf-8"
    )
    assert "<string>com.translator.desktop</string>" in dev_plist.read_text(
        encoding="utf-8"
    )


def test_dev_plist_declares_the_service_without_a_context_filter() -> None:
    # Apple requires this key even with no filters; omitting it registers the
    # service but does not automatically show it in the Services menu.
    dev_plist = REPO_ROOT / "macos" / "Translator" / "Resources" / "Info.plist"
    service = plistlib.loads(dev_plist.read_bytes())["NSServices"][0]
    assert "NSStringPboardType" in service["NSSendTypes"]
    assert service["NSMessage"] == "translateSelection"
    assert service["NSPortName"] == "Translator"
    assert service["NSRequiredContext"] == {}


@pytest.mark.skipif(
    not (BUNDLE_ROOT / "Contents" / "Info.plist").exists(),
    reason="no bundle built (scripts/build_macos_app.sh)",
)
def test_built_plist_declares_the_service_without_a_context_filter() -> None:
    plist = plistlib.loads((BUNDLE_ROOT / "Contents" / "Info.plist").read_bytes())

    assert plist["CFBundleIdentifier"] == "com.translator.desktop"
    assert plist["LSUIElement"] is True
    service = plist["NSServices"][0]
    assert service["NSSendTypes"] == ["NSStringPboardType"]
    assert service["NSMessage"] == "translateSelection"
    assert service["NSRequiredContext"] == {}


def test_a_real_identity_gets_the_hardened_runtime() -> None:
    """Notarisation refuses a bundle without it.

    `codesign --sign <identity>` alone leaves `flags=0x2`; adding
    `--options runtime` makes it `0x10002(runtime)`, which is what Apple
    checks. Ad-hoc builds stay unhardened on purpose: with no team identity,
    library validation refuses the embedded Python's extension modules.
    """
    text = (REPO_ROOT / "scripts/sign_macos_app.sh").read_text(encoding="utf-8")

    assert "if [[ \"${IDENTITY}\" != '-' ]]; then" in text
    assert "SIGN_FLAGS+=(--options runtime --timestamp)" in text


def test_nested_signing_failures_stop_the_build() -> None:
    # `-exec codesign ... 2>/dev/null || true` hid a broken nested signature
    # until notarisation, which happens on a tag, far from the change.
    text = _script()

    assert "|| true" not in text.split('log "signing')[1].split('log "verifying')[0]
    signing = (REPO_ROOT / "scripts/sign_macos_app.sh").read_text(encoding="utf-8")
    assert "set -euo pipefail" in signing
    assert "file -b" in signing and "Mach-O" in signing
    assert "|| true" not in signing
