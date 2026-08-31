#!/usr/bin/env python3
"""DPN FiveM Lua syntax checker.

Stock Lua 5.4 does not understand Cfx/FiveM backtick hash literals such as
`WEAPON_UNARMED`. This checker validates repository Lua using luac5.4 after
normalizing those Cfx-only literals in a temporary copy. Original source files
are never modified.
"""
from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
RESOURCE_ROOTS = ("qbcore", "hybrid", "standalone")
CFX_HASH = re.compile(r"`[^`\r\n]+`")

luac = shutil.which("luac5.4") or shutil.which("luac")
if not luac:
    print("ERROR: Lua compiler not found. Install lua5.4.", file=sys.stderr)
    raise SystemExit(2)

files: list[pathlib.Path] = []
for root_name in RESOURCE_ROOTS:
    root = ROOT / root_name
    if not root.exists():
        continue
    files.extend(p for p in root.rglob("*.lua") if p.is_file())

# fxmanifest.lua is already included by *.lua, but de-duplicate defensively.
files = sorted(set(files))

failures: list[tuple[pathlib.Path, str]] = []
cfx_literals = 0

with tempfile.TemporaryDirectory(prefix="dpn-lua-check-") as tmp:
    temp_root = pathlib.Path(tmp)
    for index, path in enumerate(files):
        source = path.read_text(encoding="utf-8", errors="strict")
        normalized, replaced = CFX_HASH.subn("0", source)
        cfx_literals += replaced

        temp_path = temp_root / f"{index:05d}.lua"
        temp_path.write_text(normalized, encoding="utf-8")

        proc = subprocess.run(
            [luac, "-p", str(temp_path)],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            message = (proc.stderr or proc.stdout or "unknown syntax error").strip()
            # Replace temporary filename with the real repository path for useful CI output.
            message = message.replace(str(temp_path), path.relative_to(ROOT).as_posix())
            failures.append((path, message))

if failures:
    for path, message in failures:
        rel = path.relative_to(ROOT).as_posix()
        print(f"::error file={rel}::{message}")
    print(
        f"DPN Lua syntax validation failed: {len(failures)} file(s) failed; "
        f"{len(files)} checked; {cfx_literals} Cfx hash literal(s) normalized.",
        file=sys.stderr,
    )
    raise SystemExit(1)

print(
    f"DPN Lua syntax validation passed: {len(files)} file(s) checked; "
    f"{cfx_literals} Cfx hash literal(s) normalized for stock Lua parsing."
)
