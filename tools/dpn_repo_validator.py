#!/usr/bin/env python3
"""DPN Technology repository quality and security validator.

Created for DPN QB FiveM Scripts.
Project creator: Diesel, CEO of DPN Technology.
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FRAMEWORKS = ("qbcore", "standalone", "hybrid")
BLOCKED_NAMES = {
    ".env", "credentials.json", "service-account.json",
    "id_rsa", "id_ed25519", "server.cfg"
}
BLOCKED_SUFFIXES = {".pem", ".pfx", ".key"}
WORKFLOW_WRITE_ALLOWLIST = {
    "dpn-auto-script-index.yml",
    "dpn-build-release.yml",
}
TEXT_SCAN_SUFFIXES = {
    ".lua", ".js", ".mjs", ".cjs", ".ts", ".json", ".yml", ".yaml",
    ".cfg", ".ini", ".txt", ".md", ".py", ".html", ".css", ".xml",
}
MAX_TEXT_SCAN_BYTES = 2_000_000

errors: list[str] = []
warnings: list[str] = []

def rel(path: pathlib.Path) -> str:
    return path.relative_to(ROOT).as_posix()

def error(path: pathlib.Path, message: str) -> None:
    errors.append(f"{rel(path)}: {message}")

def warning(path: pathlib.Path, message: str) -> None:
    warnings.append(f"{rel(path)}: {message}")

# Deliberately constructed in fragments so the validator does not contain
# realistic sample credentials that would trigger its own checks.
secret_patterns = [
    ("GitHub token", re.compile("gh" + r"[pousr]_" + r"[A-Za-z0-9]{36,255}")),
    ("GitHub fine-grained token", re.compile("github" + r"_pat_[A-Za-z0-9_]{60,255}")),
    ("AWS access key", re.compile("AK" + r"IA[0-9A-Z]{16}")),
    ("OpenAI-style secret", re.compile("sk" + r"-[A-Za-z0-9_-]{24,}")),
    ("Discord webhook", re.compile(r"https://(?:canary\.|ptb\.)?discord(?:app)?\.com/api/webhooks/\d+/[A-Za-z0-9._-]{20,}")),
    ("Private key", re.compile("-----BEGIN " + r"(?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
]
generic_assignment = re.compile(
    r"(?i)\b(password|passwd|token|secret|api[_-]?key)\s*[:=]\s*['\"]([^'\"\r\n]{12,})['\"]"
)
placeholder_terms = ("example", "placeholder", "change-me", "changeme", "your-", "your_", "replace-me", "replace_me", "test-only")

# Never allow obvious credential containers or private-key files in the public repo.
for p in ROOT.rglob("*"):
    if ".git" in p.parts:
        continue
    if p.is_symlink():
        warning(p, "symbolic links are discouraged in the public repository and are rejected by release packaging")
        continue
    if not p.is_file():
        continue

    if p.name.lower() in BLOCKED_NAMES or p.suffix.lower() in BLOCKED_SUFFIXES:
        error(p, "credential/private configuration file must not be committed")

    if p.stat().st_size > MAX_TEXT_SCAN_BYTES:
        continue
    if p.suffix.lower() not in TEXT_SCAN_SUFFIXES and p.name not in {".env", "server.cfg"}:
        continue

    try:
        raw = p.read_bytes()
    except OSError as exc:
        warning(p, f"could not read file for secret review: {exc}")
        continue
    if b"\x00" in raw:
        continue

    text = raw.decode("utf-8", errors="ignore")
    for label, pattern in secret_patterns:
        if pattern.search(text):
            error(p, f"possible {label} detected; remove and rotate any real credential before publishing")

    for match in generic_assignment.finditer(text):
        value = match.group(2).strip().lower()
        if any(term in value for term in placeholder_terms):
            continue
        warning(p, f"possible hard-coded {match.group(1)} assignment; verify this is not a real secret")

# GitHub Actions supply-chain guardrails.
workflow_dir = ROOT / ".github" / "workflows"
if workflow_dir.exists():
    for workflow in sorted(list(workflow_dir.glob("*.yml")) + list(workflow_dir.glob("*.yaml"))):
        text = workflow.read_text(encoding="utf-8", errors="ignore")

        if re.search(r"(?m)^\s*pull_request_target\s*:", text):
            error(workflow, "pull_request_target is prohibited by the DPN security baseline")
        if re.search(r"(?m)^\s*permissions\s*:\s*write-all\s*$", text):
            error(workflow, "permissions: write-all is prohibited")
        if re.search(r"(?m)^\s*id-token\s*:\s*write\s*$", text):
            error(workflow, "OIDC id-token write permission is not approved for current DPN workflows")
        if re.search(r"(?m)^\s*contents\s*:\s*write\s*$", text) and workflow.name not in WORKFLOW_WRITE_ALLOWLIST:
            error(workflow, "contents: write is not approved for this workflow")

        for match in re.finditer(r"(?m)^\s*uses:\s*([^#\s]+)", text):
            ref = match.group(1)
            if ref.startswith("./") or ref.startswith("docker://"):
                continue
            if "@" not in ref:
                error(workflow, f"external action is missing an immutable ref: {ref}")
                continue
            action, action_ref = ref.rsplit("@", 1)
            if not re.fullmatch(r"[0-9a-fA-F]{40}", action_ref):
                error(workflow, f"external action must be pinned to a full 40-character commit SHA: {action}")

        if re.search(r"(?m)^\s*run:\s*.*(?:curl|wget).*\|\s*(?:ba)?sh\b", text):
            error(workflow, "download-and-execute shell pipeline is prohibited")

# DPN Medical Phase 3A registry/version/heartbeat guardrails.
medical_root = (
    ROOT
    / "qbcore"
    / "public-safety"
    / "dpn-unified-emergency-services-suite"
    / "[dpn-medical]"
)
if medical_root.exists():
    loose_capability_call = re.compile(
        r"RegisterModule\s*\(\s*[^,\n]+\s*,\s*[^,\n]+\s*,\s*['\"]",
        re.MULTILINE,
    )
    literal_registration_version = re.compile(
        r"RegisterModule\s*\(\s*[^,\n]+\s*,\s*['\"]\d+(?:\.\d+){1,3}['\"]",
        re.MULTILINE,
    )
    literal_heartbeat_version = re.compile(
        r"moduleHeartbeat['\"]\s*,\s*[^,\n]+\s*,\s*['\"]\d+(?:\.\d+){1,3}['\"]",
        re.MULTILINE,
    )
    hardcoded_version_assignment = re.compile(
        r"(?m)^\s*local\s+(?:ADV_)?VERSION\s*=\s*['\"]\d+(?:\.\d+){1,3}['\"]"
    )

    for resource in sorted(p for p in medical_root.iterdir() if p.is_dir() and p.name.startswith("dpn-medical-")):
        server_dir = resource / "server"
        if not server_dir.exists():
            continue

        registration_owners: list[pathlib.Path] = []
        heartbeat_owners: list[pathlib.Path] = []

        for lua_file in sorted(server_dir.rglob("*.lua")):
            text = lua_file.read_text(encoding="utf-8", errors="ignore")
            produces_registration = "exports['dpn-medical-core']:RegisterModule(" in text or 'exports["dpn-medical-core"]:RegisterModule(' in text
            produces_heartbeat = "TriggerEvent('dpn-medical-core:server:moduleHeartbeat'" in text or 'TriggerEvent("dpn-medical-core:server:moduleHeartbeat"' in text

            if produces_registration:
                registration_owners.append(lua_file)
                if loose_capability_call.search(text):
                    error(lua_file, "medical RegisterModule capabilities must be passed as a table, not loose string varargs")
                if literal_registration_version.search(text):
                    error(lua_file, "medical RegisterModule must not use a literal runtime version; derive it from the resource manifest")

            if produces_heartbeat:
                heartbeat_owners.append(lua_file)
                if literal_heartbeat_version.search(text):
                    error(lua_file, "medical heartbeat must not use a literal runtime version; derive it from the resource manifest")

            if (produces_registration or produces_heartbeat) and hardcoded_version_assignment.search(text):
                error(lua_file, "medical registration/heartbeat owner has a hard-coded VERSION; use GetResourceMetadata(..., 'version', 0)")

        # Medical Core is the registry authority itself; its internal implementation
        # is not a feature-resource producer and is therefore exempt from owner counts.
        if resource.name != "dpn-medical-core":
            if len(registration_owners) > 1:
                owners = ", ".join(rel(p) for p in registration_owners)
                error(resource, f"multiple medical registration owners detected ({owners}); Phase 3A allows one per physical resource")
            if len(heartbeat_owners) > 1:
                owners = ", ".join(rel(p) for p in heartbeat_owners)
                error(resource, f"multiple medical heartbeat owners detected ({owners}); Phase 3A allows one per physical resource")

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

    if resource.name.startswith("dpn_"):
        warning(resource, "legacy dpn_ resource name preserved for compatibility; new DPN resources should use dpn-")
    elif not resource.name.startswith("dpn-"):
        error(resource, "resource folder should use the dpn- prefix")

    if any(p.is_symlink() for p in resource.rglob("*")):
        error(resource, "resource contains a symbolic link; release resources must contain only real files/directories")

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
