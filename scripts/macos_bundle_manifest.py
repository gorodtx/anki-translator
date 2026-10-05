"""Record the exact source/runtime identity of a macOS build before signing."""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path
import platform
import plistlib
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def source_digest() -> str:
    paths: list[Path] = []
    for folder, suffix in (
        ("desktop_app", ".py"),
        ("translate_logic", ".py"),
        ("macos/Translator/Sources", ".swift"),
        ("macos/AppleLangHelper/Sources", ".swift"),
    ):
        paths.extend((ROOT / folder).rglob(f"*{suffix}"))
    # Hash the exact shipped artwork and its appearance compiler inputs. Research
    # exports and reports outside these production resource directories are excluded.
    for folder in (
        "macos/Translator/Resources/AppIcon.icon",
        "macos/Translator/Resources/AppIcon-layer-sources",
        "macos/Translator/Resources/CompiledAppIcon",
    ):
        paths.extend(path for path in (ROOT / folder).rglob("*") if path.is_file())
    paths.extend(
        ROOT / name
        for name in (
            "macos/Translator/Package.swift",
            "macos/AppleLangHelper/Package.swift",
            "macos/Translator/Resources/AppIcon.icns",
            "macos/Translator/Resources/AppIcon-source.json",
            "macos/Translator/Resources/MenuBar/TranslatorMenuBar.png",
            "macos/Translator/Resources/MenuBar/TranslatorMenuBar@2x.png",
            "macos/Translator/Resources/MenuBar/TranslatorMenuBar@3x.png",
            "macos/Translator/scripts/make_icon.sh",
            "scripts/build_macos_app.sh",
            "scripts/sign_macos_app.sh",
            "scripts/macos_bundle_manifest.py",
            "scripts/runtime-requirements.txt",
            "scripts/db-bundle.lock.json",
        )
    )
    digest = hashlib.sha256()
    for path in sorted(paths):
        digest.update(path.relative_to(ROOT).as_posix().encode() + b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def write_manifest(app: Path, expected_digest: str) -> None:
    digest = source_digest()
    if digest != expected_digest:
        raise SystemExit("source changed during build; rebuild from a stable tree")
    contents = app / "Contents"
    resources = contents / "Resources"
    # Every symlink shipped in the app must stay inside it after relocation.
    resolved = app.resolve()
    for path in app.rglob("*"):
        if path.is_symlink() and not path.resolve(strict=True).is_relative_to(resolved):
            raise SystemExit(f"external bundle symlink: {path.relative_to(app)}")
    with (contents / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    for relative in (
        "AppIcon.icns",
        "MenuBar/TranslatorMenuBar.png",
        "MenuBar/TranslatorMenuBar@2x.png",
        "MenuBar/TranslatorMenuBar@3x.png",
    ):
        bundled = resources / relative
        expected = ROOT / "macos/Translator/Resources" / relative
        if bundled.read_bytes() != expected.read_bytes():
            raise SystemExit(f"bundle artwork differs from source: {relative}")
    if info.get("CFBundleIconName") == "AppIcon":
        if not (resources / "Assets.car").is_file():
            raise SystemExit("compiled AppIcon resource missing: Assets.car")
    dependencies = {
        distribution.metadata["Name"]: distribution.version
        for distribution in importlib.metadata.distributions(
            path=[str(resources / "site-packages")]
        )
    }
    manifest = {
        "schema": 1,
        "revision": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip(),
        "source_sha256": digest,
        "architecture": platform.machine(),
        "minimum_macos": info["LSMinimumSystemVersion"],
        "version": info["CFBundleShortVersionString"],
        "build": info["CFBundleVersion"],
        "runtime_dependencies": dict(sorted(dependencies.items())),
        "database_lock_sha256": hashlib.sha256(
            (resources / "db-bundle.lock.json").read_bytes()
        ).hexdigest(),
        "python_binary_unsigned_sha256": hashlib.sha256(
            (resources / "python/bin/python3.13").read_bytes()
        ).hexdigest(),
    }
    (resources / "build-info.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"source_sha256={digest}; revision={manifest['revision']}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-digest", action="store_true")
    parser.add_argument("--app", type=Path)
    parser.add_argument("--expected-source-digest")
    args = parser.parse_args()
    if args.source_digest:
        print(source_digest())
    elif args.app and args.expected_source_digest:
        write_manifest(args.app, args.expected_source_digest)
    else:
        parser.error("use --source-digest or --app with --expected-source-digest")


if __name__ == "__main__":
    main()
