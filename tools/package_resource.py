#!/usr/bin/env python3
"""Build a distributable ZIP for one DPN FiveM resource."""
from __future__ import annotations

import argparse
import json
import pathlib
import shutil
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
ALLOWED_ROOTS = {"qbcore", "standalone", "hybrid"}
EXCLUDED_NAMES = {
    ".DS_Store", "Thumbs.db", "desktop.ini", ".env",
    "credentials.json", "service-account.json"
}
EXCLUDED_SUFFIXES = {".log", ".pem", ".pfx", ".key", ".tmp", ".bak"}

def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)

parser = argparse.ArgumentParser()
parser.add_argument("resource_path", help="Path such as qbcore/law-enforcement/dpn-example")
parser.add_argument("--output", default="dist")
args = parser.parse_args()

requested = pathlib.Path(args.resource_path)
if requested.is_absolute() or ".." in requested.parts:
    fail("resource path must be a safe repository-relative path")

resource = (ROOT / requested).resolve()
try:
    relative = resource.relative_to(ROOT)
except ValueError:
    fail("resource path escaped the repository")

if not relative.parts or relative.parts[0] not in ALLOWED_ROOTS:
    fail("resource must be inside qbcore/, standalone/, or hybrid/")

if not resource.is_dir():
    fail("resource directory does not exist")

for required in ("fxmanifest.lua", "README.md", "resource.json"):
    if not (resource / required).is_file():
        fail(f"missing required file: {required}")

try:
    metadata = json.loads((resource / "resource.json").read_text(encoding="utf-8"))
except Exception as exc:
    fail(f"resource.json is invalid: {exc}")

name = metadata.get("name")
version = metadata.get("version")
framework = metadata.get("framework")
if not isinstance(name, str) or not name.startswith("dpn-"):
    fail("resource metadata name must start with dpn-")
if name != resource.name:
    fail("resource metadata name must match the folder name")
if not isinstance(version, str) or not version.strip():
    fail("resource metadata version is required")
if framework not in ALLOWED_ROOTS:
    fail("resource metadata framework must be qbcore, standalone, or hybrid")
if framework != relative.parts[0]:
    fail("resource metadata framework must match its top-level folder")

out_dir = ROOT / args.output
out_dir.mkdir(parents=True, exist_ok=True)
archive = out_dir / f"{name}-v{version}.zip"

if archive.exists():
    archive.unlink()

with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for path in sorted(resource.rglob("*")):
        if not path.is_file():
            continue
        if path.name in EXCLUDED_NAMES or path.suffix.lower() in EXCLUDED_SUFFIXES:
            continue
        if any(part in {"node_modules", ".git", "dist", "build", "cache"} for part in path.parts):
            continue
        arcname = pathlib.Path(name) / path.relative_to(resource)
        zf.write(path, arcname.as_posix())

print(archive.relative_to(ROOT).as_posix())
