"""Check Python formatting, preserving only byte-identical legacy exceptions."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
IGNORED = frozenset(
    {
        ".git",
        ".venv",
        ".build",
        ".mypy_cache",
        ".pytest_cache",
        ".ruff_cache",
        "__pycache__",
    }
)


def main() -> int:
    baseline = json.loads(
        (ROOT / "scripts/python_format_baseline.json").read_text(encoding="utf-8")
    )
    if baseline.get("version") != 1:
        raise SystemExit("unsupported Python format baseline")
    exceptions: dict[str, str] = baseline["unchanged_legacy_files"]
    targets: list[str] = []
    preserved = 0
    for path in sorted(ROOT.rglob("*.py")):
        relative = path.relative_to(ROOT)
        if any(part in IGNORED for part in relative.parts):
            continue
        name = relative.as_posix()
        if exceptions.get(name) == hashlib.sha256(path.read_bytes()).hexdigest():
            preserved += 1
        else:
            targets.append(name)
    if not targets:
        raise SystemExit("no Python files found for formatting verification")
    print(
        f"format: {len(targets)} checked; {preserved} unchanged legacy files",
        flush=True,
    )
    return subprocess.run(
        ["uv", "run", "--no-sync", "ruff", "format", "--check", *targets],
        cwd=ROOT,
        check=False,
    ).returncode


if __name__ == "__main__":
    raise SystemExit(main())
