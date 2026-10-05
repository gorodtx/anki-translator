"""Record the exact source/runtime identity of a macOS build before signing."""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ARTWORK = ROOT / "macos/Translator/Resources"
BUNDLE_ARTWORK = {
    "AppIcon.icns": "AppIcon.icns",
    "MenuBar/TranslatorMenuBar.png": "MenuBar/TranslatorMenuBar.png",
    "MenuBar/TranslatorMenuBar@2x.png": "MenuBar/TranslatorMenuBar@2x.png",
    "MenuBar/TranslatorMenuBar@3x.png": "MenuBar/TranslatorMenuBar@3x.png",
    "Assets.car": "CompiledAppIcon/Assets.car",
    "AppIcon-resource-provenance.json": "CompiledAppIcon/resource-provenance.json",
    "AppIcon-promotion-receipt.json": "CompiledAppIcon/promotion-receipt.json",
}


def read_record(path: Path) -> dict[str, object]:
    value: object = json.loads(path.read_text())
    if not isinstance(value, dict) or not all(isinstance(key, str) for key in value):
        raise SystemExit(f"invalid artwork record: {path.name}")
    return {key: entry for key, entry in value.items()}


def verify_compiled_artwork() -> None:
    compiled = ARTWORK / "CompiledAppIcon"
    provenance = read_record(compiled / "resource-provenance.json")
    receipt = read_record(compiled / "promotion-receipt.json")
    paths = sorted((ARTWORK / "AppIcon.icon").rglob("*"))
    paths += sorted((ARTWORK / "AppIcon-layer-sources").rglob("*"))
    paths += [ARTWORK / "AppIcon-source.json", ARTWORK / "AppIcon.icns"]
    source_hashes = {
        str(path.relative_to(ARTWORK)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in paths
        if path.is_file()
    }
    digest = hashlib.sha256(
        json.dumps(source_hashes, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    if (
        provenance.get("source_files") != source_hashes
        or provenance.get("source_sha256") != digest
    ):
        raise SystemExit("compiled AppIcon inputs differ from production source")
    car_sha = hashlib.sha256((compiled / "Assets.car").read_bytes()).hexdigest()
    generated = provenance.get("generated_files")
    if not isinstance(generated, dict) or generated.get("Assets.car") != car_sha:
        raise SystemExit("compiled AppIcon CAR differs from compiler provenance")
    if (
        receipt.get("source_sha256") != digest
        or receipt.get("assets_car_sha256") != car_sha
        or receipt.get("resource_provenance_sha256")
        != hashlib.sha256(
            (compiled / "resource-provenance.json").read_bytes()
        ).hexdigest()
        or receipt.get("unlaunched_clear_dark_small_render_check") != "passed"
    ):
        raise SystemExit("compiled AppIcon promotion receipt does not match resources")


def pack_artwork(app: Path) -> None:
    verify_compiled_artwork()
    resources = app / "Contents/Resources"
    for relative, source in BUNDLE_ARTWORK.items():
        target = resources / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ARTWORK / source, target)
    info_path = app / "Contents/Info.plist"
    with info_path.open("rb") as handle:
        info = plistlib.load(handle)
    info["CFBundleIconFile"] = "AppIcon"
    info["CFBundleIconName"] = "AppIcon"
    with info_path.open("wb") as handle:
        plistlib.dump(info, handle)
    verify_bundle_artwork(app)


def verify_bundle_artwork(app: Path) -> None:
    verify_compiled_artwork()
    with (app / "Contents/Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    if (
        info.get("CFBundleIconName") != "AppIcon"
        or info.get("CFBundleIconFile") != "AppIcon"
    ):
        raise SystemExit("bundle does not select the validated AppIcon")
    for relative, source in BUNDLE_ARTWORK.items():
        if (app / "Contents/Resources" / relative).read_bytes() != (
            ARTWORK / source
        ).read_bytes():
            raise SystemExit(f"bundle artwork differs from source: {relative}")


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
            "macos/Translator/scripts/build_app.sh",
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
    verify_bundle_artwork(app)
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
    parser.add_argument("--pack-artwork", type=Path)
    parser.add_argument("--verify-artwork", type=Path)
    parser.add_argument("--app", type=Path)
    parser.add_argument("--expected-source-digest")
    args = parser.parse_args()
    if args.pack_artwork:
        pack_artwork(args.pack_artwork)
    elif args.verify_artwork:
        verify_bundle_artwork(args.verify_artwork)
    elif args.source_digest:
        print(source_digest())
    elif args.app and args.expected_source_digest:
        write_manifest(args.app, args.expected_source_digest)
    else:
        parser.error(
            "use --pack-artwork, --verify-artwork, --source-digest or --app with --expected-source-digest"
        )


if __name__ == "__main__":
    main()
