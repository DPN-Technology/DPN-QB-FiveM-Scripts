#!/usr/bin/env python3
"""Inventory FiveM command/event ownership in the unified emergency suite.

This is a read-only audit tool. It intentionally does not fail on existing
ownership overlaps because Phase 3B begins with known compatibility aliases.
Use --strict to return non-zero when duplicate command registrations are found.
"""

from __future__ import annotations

import argparse
import collections
import pathlib
import re
import sys
from dataclasses import dataclass

ROOT = pathlib.Path(__file__).resolve().parents[1]
SUITE = ROOT / "qbcore/public-safety/dpn-unified-emergency-services-suite"

PATTERNS = {
    "command": re.compile(r"RegisterCommand\s*\(\s*['\"]([^'\"]+)['\"]"),
    "net_event": re.compile(r"RegisterNetEvent\s*\(\s*['\"]([^'\"]+)['\"]"),
    "event_handler": re.compile(r"AddEventHandler\s*\(\s*['\"]([^'\"]+)['\"]"),
    "trigger_server": re.compile(r"TriggerServerEvent\s*\(\s*['\"]([^'\"]+)['\"]"),
    "trigger_client": re.compile(r"TriggerClientEvent\s*\(\s*['\"]([^'\"]+)['\"]"),
    "trigger_local": re.compile(r"TriggerEvent\s*\(\s*['\"]([^'\"]+)['\"]"),
}

CORRELATION_FIELDS = ("eventId", "medicalCallId", "dispatchCallId", "incidentId", "mdtCaseId", "sourceResource")

@dataclass(frozen=True)
class Hit:
    kind: str
    name: str
    path: str
    line: int


def resource_for(path: pathlib.Path) -> str:
    rel = path.relative_to(SUITE)
    parts = rel.parts
    if not parts:
        return "unknown"
    if parts[0] == "core" and len(parts) > 1:
        return parts[1]
    if parts[0].startswith("[") and len(parts) > 1:
        return parts[1]
    return parts[0]


def scan() -> tuple[list[Hit], dict[str, set[str]]]:
    hits: list[Hit] = []
    correlation: dict[str, set[str]] = collections.defaultdict(set)
    if not SUITE.exists():
        raise SystemExit(f"Unified emergency suite not found: {SUITE}")

    for path in sorted(SUITE.rglob("*.lua")):
        if any(part in {"vendor", "node_modules"} for part in path.parts):
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        rel = path.relative_to(ROOT).as_posix()
        resource = resource_for(path)
        for line_no, line in enumerate(text.splitlines(), 1):
            for kind, pattern in PATTERNS.items():
                for match in pattern.finditer(line):
                    hits.append(Hit(kind, match.group(1), rel, line_no))
            for field in CORRELATION_FIELDS:
                if re.search(rf"\b{re.escape(field)}\b", line):
                    correlation[resource].add(field)
    return hits, correlation


def duplicate_commands(hits: list[Hit]) -> dict[str, list[Hit]]:
    owners: dict[str, list[Hit]] = collections.defaultdict(list)
    for hit in hits:
        if hit.kind == "command":
            owners[hit.name.lower()].append(hit)
    return {name: rows for name, rows in owners.items() if len({row.path for row in rows}) > 1}


def print_report(hits: list[Hit], correlation: dict[str, set[str]]) -> int:
    by_kind = collections.Counter(hit.kind for hit in hits)
    duplicates = duplicate_commands(hits)

    print("DPN Emergency Surface Audit")
    print(f"Lua declarations/usages scanned: {len(hits)}")
    for kind in PATTERNS:
        print(f"  {kind}: {by_kind[kind]}")

    print("\nDuplicate command registrations")
    if not duplicates:
        print("  none")
    else:
        for name in sorted(duplicates):
            print(f"  /{name}")
            for hit in duplicates[name]:
                print(f"    - {hit.path}:{hit.line}")

    print("\nCorrelation-field readiness by resource")
    resources = sorted({resource_for(path) for path in SUITE.rglob("*.lua")})
    for resource in resources:
        fields = correlation.get(resource, set())
        present = ", ".join(field for field in CORRELATION_FIELDS if field in fields) or "none"
        print(f"  {resource}: {present}")

    print("\nNotes")
    print("  - Duplicate commands are audit findings, not automatically bugs; compatibility aliases may be intentional.")
    print("  - Correlation readiness is lexical presence only. It does not prove end-to-end propagation or trust validation.")
    return len(duplicates)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true", help="fail if duplicate command registrations exist")
    args = parser.parse_args()
    hits, correlation = scan()
    duplicate_count = print_report(hits, correlation)
    return 1 if args.strict and duplicate_count else 0


if __name__ == "__main__":
    sys.exit(main())
