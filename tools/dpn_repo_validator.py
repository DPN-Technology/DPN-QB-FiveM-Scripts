#!/usr/bin/env python3
"""DPN Technology repository quality validator.

Created for DPN QB FiveM Scripts.
Project creator: Diesel, CEO of DPN Technology.
"""
from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FRAMEWORKS = ("qbcore", "standalone", "hybrid")
BLOCKED_NAMES = {
    ".env", "credentials.json", "service-account.json",
    "id_rsa", "id_ed25519", "server.cfg"
}
BLOCKED_SUFFIXES = {".pem", ".pfx", ".key"}

errors: list[str] = []
warnings: list[str] = []

def rel(path: pathlib.Path) -> str:
    return path.relative_to(ROOT).as_posix()

def error(path: pathlib.Path, message: str) -> None:
    errors.append(f"{rel(path)}: {message}")

def warning(path: pathlib.Path, message: str) -> None:
    warnings.append(f"{rel(path)}: {message}")

# Never allow obvious credential containers into the public repository.
for p in ROOT.rglob("*"):
    if not p.is_file() or ".git" in p.parts:
        continue
    if p.name.lower() in BLOCKED_NAMES or p.suffix.lower() in BLOCKED_SUFFIXES:
        error(p, "credential/private configuration file must not be committed")

resources: list[pathlib.Path] = []
for framework in FRAMEWORKS:
    fw_root = ROOT / framework
    if not fw_root.exists():
        errors.append(f"{framework}/: framework catalog is missing")
        continue
    for manifest in fw_root.rglob("fxmanifest.lua"):
        if "templates" in manifest.parts:
            continue
        resources.append(manifest.parent)

for resource in sorted(set(resources)):
    manifest = resource / "fxmanifest.lua"
    readme = resource / "README.md"
    metadata = resource / "resource.json"

    if not resource.name.startswith("dpn-"):
        error(resource, "resource folder should use the dpn- prefix")

    if not readme.exists():
        error(resource, "resource README.md is required")
    else:
        text = readme.read_text(encoding="utf-8", errors="ignore")
        if "DPN Technology" not in text:
            error(readme, "README must identify DPN Technology")
        if "Diesel" not in text:
            warning(readme, "README should identify Diesel as creator where applicable")

    manifest_text = manifest.read_text(encoding="utf-8", errors="ignore")
    if "DPN Technology" not in manifest_text:
        warning(manifest, "fxmanifest should identify DPN Technology")
    if "version" not in manifest_text:
        error(manifest, "fxmanifest should declare a version")

    if not metadata.exists():
        error(resource, "resource.json metadata is required for DPN indexing")
    else:
        try:
            data = json.loads(metadata.read_text(encoding="utf-8"))
        except Exception as exc:
            error(metadata, f"invalid JSON: {exc}")
            continue
        required = {
            "name", "display_name", "version", "framework", "category",
            "status", "description", "creator", "organization", "license"
        }
        missing = sorted(required - set(data))
        if missing:
            error(metadata, "missing required fields: " + ", ".join(missing))
        if data.get("organization") != "DPN Technology":
            error(metadata, "organization must identify DPN Technology")
        if data.get("framework") not in FRAMEWORKS:
            error(metadata, "framework must be qbcore, standalone, or hybrid")
        if data.get("name") != resource.name:
            error(metadata, "name must match the resource folder name")

# Catch Lua code placed in a likely resource folder with no manifest.
for framework in FRAMEWORKS:
    fw_root = ROOT / framework
    if not fw_root.exists():
        continue
    for directory in fw_root.rglob("*"):
        if not directory.is_dir():
            continue
        if "templates" in directory.parts:
            continue
        lua_here = list(directory.glob("*.lua"))
        if lua_here and not (directory / "fxmanifest.lua").exists():
            warning(directory, "Lua files found without fxmanifest.lua in this directory")

for msg in warnings:
    print(f"::warning::{msg}")

for msg in errors:
    print(f"::error::{msg}")

print(f"DPN Quality Gate: {len(resources)} resource(s), {len(warnings)} warning(s), {len(errors)} error(s).")
sys.exit(1 if errors else 0)
