#!/usr/bin/env python3
"""Generate verifiable release evidence for one packaged DPN FiveM resource."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
ALLOWED_ROOTS = {"qbcore", "standalone", "hybrid"}


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def safe_resource_path(raw: str) -> pathlib.Path:
    requested = pathlib.Path(raw)
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
    return resource


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def manifest_version(manifest: pathlib.Path) -> str:
    text = manifest.read_text(encoding="utf-8", errors="strict")
    match = re.search(r"(?m)^\s*version\s+['\"]([^'\"]+)['\"]\s*$", text)
    if not match:
        fail("fxmanifest.lua must contain a quoted version declaration")
    return match.group(1).strip()


parser = argparse.ArgumentParser()
parser.add_argument("resource_path")
parser.add_argument("archive")
parser.add_argument("checksum")
parser.add_argument("--output", default="dist/release-evidence.json")
args = parser.parse_args()

resource = safe_resource_path(args.resource_path)
relative = resource.relative_to(ROOT)
metadata_path = resource / "resource.json"
manifest_path = resource / "fxmanifest.lua"

if not metadata_path.is_file():
    fail("resource.json is required")
if not manifest_path.is_file():
    fail("fxmanifest.lua is required")

try:
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
except Exception as exc:
    fail(f"resource.json is invalid: {exc}")

for field in ("name", "display_name", "version", "framework", "category", "status", "description", "creator", "organization", "license"):
    if not isinstance(metadata.get(field), str) or not metadata[field].strip():
        fail(f"resource.json field '{field}' must be a non-empty string")

if metadata["name"] != resource.name:
    fail("resource.json name must match the resource folder name")
if metadata["framework"] != relative.parts[0]:
    fail("resource.json framework must match the top-level resource folder")

fx_version = manifest_version(manifest_path)
if fx_version != metadata["version"]:
    fail(
        f"release version mismatch: resource.json={metadata['version']} "
        f"fxmanifest.lua={fx_version}"
    )

archive = pathlib.Path(args.archive)
if not archive.is_absolute():
    archive = ROOT / archive
archive = archive.resolve()
if not archive.is_file():
    fail("release archive does not exist")

checksum_path = pathlib.Path(args.checksum)
if not checksum_path.is_absolute():
    checksum_path = ROOT / checksum_path
checksum_path = checksum_path.resolve()
if not checksum_path.is_file():
    fail("checksum file does not exist")

actual_sha256 = sha256_file(archive)
checksum_tokens = checksum_path.read_text(encoding="utf-8").strip().split()
if not checksum_tokens:
    fail("checksum file is empty")
recorded_sha256 = checksum_tokens[0].lower()
if not re.fullmatch(r"[0-9a-f]{64}", recorded_sha256):
    fail("checksum file does not begin with a valid SHA-256 digest")
if recorded_sha256 != actual_sha256:
    fail("release archive SHA-256 does not match checksum file")

evidence = {
    "schema_version": 1,
    "generated_utc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
    "repository": os.environ.get("GITHUB_REPOSITORY", ""),
    "source_sha": os.environ.get("GITHUB_SHA", ""),
    "source_ref": os.environ.get("GITHUB_REF", ""),
    "workflow_run_id": os.environ.get("GITHUB_RUN_ID", ""),
    "workflow_run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", ""),
    "resource": {
        "path": relative.as_posix(),
        "name": metadata["name"],
        "display_name": metadata["display_name"],
        "version": metadata["version"],
        "manifest_version": fx_version,
        "framework": metadata["framework"],
        "category": metadata["category"],
        "status": metadata["status"],
        "license": metadata["license"],
    },
    "artifact": {
        "filename": archive.name,
        "sha256": actual_sha256,
        "size_bytes": archive.stat().st_size,
        "checksum_filename": checksum_path.name,
    },
}

output = pathlib.Path(args.output)
if not output.is_absolute():
    output = ROOT / output
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print(output.relative_to(ROOT).as_posix())
