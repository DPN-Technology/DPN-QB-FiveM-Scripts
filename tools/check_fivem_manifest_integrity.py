#!/usr/bin/env python3
"""Validate FiveM resource manifests and repository placement."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
CATALOGS = ("qbcore", "standalone", "hybrid")
errors: list[str] = []
warnings: list[str] = []

DIRECTIVES = (
    "client_script", "client_scripts", "server_script", "server_scripts",
    "shared_script", "shared_scripts", "file", "files", "ui_page",
)


def rel(path: pathlib.Path) -> str:
    return path.relative_to(ROOT).as_posix()


def err(path: pathlib.Path, msg: str) -> None:
    errors.append(f"{rel(path)}: {msg}")


def warn(path: pathlib.Path, msg: str) -> None:
    warnings.append(f"{rel(path)}: {msg}")


resources: list[pathlib.Path] = []
legacy_manifests: list[pathlib.Path] = []
for catalog in CATALOGS:
    base = ROOT / catalog
    if not base.exists():
        err(ROOT, f"required catalog {catalog}/ is missing")
        continue
    legacy_manifests.extend(base.rglob("__resource.lua"))
    resources.extend(p.parent for p in base.rglob("fxmanifest.lua") if "templates" not in p.parts)

for legacy in sorted(legacy_manifests):
    err(legacy, "legacy __resource.lua is prohibited; migrate to fxmanifest.lua")

# Resource folder names should be globally unique so ensure/start commands are unambiguous.
by_name: dict[str, list[pathlib.Path]] = {}
for resource in sorted(set(resources)):
    by_name.setdefault(resource.name.lower(), []).append(resource)
for name, paths in sorted(by_name.items()):
    if len(paths) > 1:
        locations = ", ".join(rel(p) for p in paths)
        errors.append(f"duplicate resource name '{name}' found in: {locations}")

quoted = re.compile(r"['\"]([^'\"]+)['\"]")
for resource in sorted(set(resources)):
    manifest = resource / "fxmanifest.lua"
    text = manifest.read_text(encoding="utf-8", errors="ignore")

    if not re.search(r"(?m)^\s*fx_version\s+['\"][^'\"]+['\"]", text):
        err(manifest, "fx_version declaration is required")
    if not re.search(r"(?m)^\s*game\s+['\"][^'\"]+['\"]", text):
        err(manifest, "game declaration is required")

    lines = text.splitlines()
    for index, line in enumerate(lines):
        stripped = line.strip()
        directive = next((d for d in DIRECTIVES if re.match(rf"^{re.escape(d)}\b", stripped)), None)
        if not directive:
            continue

        # Gather quoted paths on the directive line and, for table forms, until the closing brace.
        block = stripped
        if "{" in stripped and "}" not in stripped:
            for follow in lines[index + 1:]:
                block += "\n" + follow
                if "}" in follow:
                    break

        for raw_path in quoted.findall(block):
            candidate = raw_path.strip()
            if not candidate or candidate.startswith(("@", "http://", "https://")):
                continue
            if any(ch in candidate for ch in "*?["):
                continue
            if directive == "ui_page" and candidate.startswith(("nui://",)):
                continue
            target = resource / candidate
            if not target.exists():
                err(manifest, f"{directive} references missing path: {candidate}")

    # Detect common accidental credential/config containers inside resources.
    for blocked in (".env", "server.cfg", "credentials.json", "service-account.json"):
        if (resource / blocked).exists():
            err(resource / blocked, "private runtime configuration must not be committed")

for message in warnings:
    print(f"::warning::{message}")
for message in errors:
    print(f"::error::{message}")

print(f"DPN FiveM Manifest Integrity: {len(set(resources))} resource(s), {len(warnings)} warning(s), {len(errors)} error(s).")
sys.exit(1 if errors else 0)
