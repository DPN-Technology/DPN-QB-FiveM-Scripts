#!/usr/bin/env python3
"""Audit FiveM fxmanifest references without changing repository contents.

Checks local file references from common fxmanifest directives and reports missing
paths/globs. External resource references such as @oxmysql/lib/MySQL.lua are
recorded but not treated as local missing files.
"""
from __future__ import annotations

import argparse
import glob
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIRECTIVES = (
    "client_script", "client_scripts", "server_script", "server_scripts",
    "shared_script", "shared_scripts", "file", "files", "ui_page",
    "loadscreen", "data_file",
)
DIRECTIVE_RE = re.compile(r"\b(" + "|".join(DIRECTIVES) + r")\b")
STRING_RE = re.compile(r"(['\"])(.*?)\1")
SKIP_DIRS = {".git", "node_modules", "vendor", ".venv", "venv"}


def manifests():
    for path in ROOT.rglob("fxmanifest.lua"):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        yield path


def extract_refs(text: str):
    lines = text.splitlines()
    refs = []
    i = 0
    while i < len(lines):
        line = lines[i]
        match = DIRECTIVE_RE.search(line)
        if not match:
            i += 1
            continue
        directive = match.group(1)
        block = line[match.end():]
        if "{" in block and "}" not in block:
            j = i + 1
            while j < len(lines):
                block += "\n" + lines[j]
                if "}" in lines[j]:
                    break
                j += 1
            i = j
        values = [m.group(2).strip() for m in STRING_RE.finditer(block)]
        # data_file has a type token followed by the path; only the path matters.
        if directive == "data_file" and len(values) >= 2:
            values = values[1:]
        for value in values:
            refs.append((directive, value))
        i += 1
    return refs


def local_reference_status(resource_dir: Path, ref: str):
    if not ref or ref.startswith("@") or ref.startswith("http://") or ref.startswith("https://"):
        return "external", []
    if ref.startswith("nui://"):
        return "external", []
    pattern = resource_dir / ref
    if any(ch in ref for ch in "*?["):
        matches = [Path(p) for p in glob.glob(str(pattern), recursive=True)]
        return ("ok" if matches else "missing"), matches
    return ("ok" if pattern.exists() else "missing"), ([pattern] if pattern.exists() else [])


def audit():
    resources = []
    missing = []
    external = []
    total_refs = 0
    for manifest in sorted(manifests()):
        resource_dir = manifest.parent
        text = manifest.read_text(encoding="utf-8", errors="replace")
        refs = extract_refs(text)
        row = {"manifest": str(manifest.relative_to(ROOT)), "references": len(refs), "missing": []}
        total_refs += len(refs)
        for directive, ref in refs:
            status, _ = local_reference_status(resource_dir, ref)
            entry = {"manifest": row["manifest"], "directive": directive, "reference": ref}
            if status == "missing":
                row["missing"].append(entry)
                missing.append(entry)
            elif status == "external":
                external.append(entry)
        resources.append(row)
    return {
        "schemaVersion": 1,
        "manifestsScanned": len(resources),
        "referencesScanned": total_refs,
        "missingReferenceCount": len(missing),
        "externalReferenceCount": len(external),
        "missingReferences": missing,
        "resources": resources,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true", help="emit JSON instead of text")
    parser.add_argument("--strict", action="store_true", help="exit non-zero if missing local references are found")
    args = parser.parse_args()
    report = audit()
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print("DPN FiveM Manifest Integrity Audit")
        print(f"Manifests scanned: {report['manifestsScanned']}")
        print(f"References scanned: {report['referencesScanned']}")
        print(f"Missing local references: {report['missingReferenceCount']}")
        print(f"External references: {report['externalReferenceCount']}")
        for item in report["missingReferences"]:
            print(f" - {item['manifest']}: {item['directive']} -> {item['reference']}")
    if args.strict and report["missingReferenceCount"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
