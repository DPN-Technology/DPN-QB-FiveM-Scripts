#!/usr/bin/env python3
"""Inventory FiveM command/event ownership in the unified emergency suite.

This is a read-only audit tool. It intentionally does not fail on existing
ownership overlaps because Phase 3B begins with known compatibility aliases.
Use --strict to return non-zero when any duplicate command registrations exist.
Use --baseline PATH --fail-on-regression to fail only when duplicate ownership
expands beyond an explicitly reviewed baseline.
Use --write-baseline PATH to create or refresh that reviewed baseline.
Use --json to emit a stable machine-readable report for CI and migration tools.
"""

from __future__ import annotations

import argparse
import collections
import json
import pathlib
import re
import sys
from dataclasses import asdict, dataclass

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

CORRELATION_FIELDS = (
    "eventId",
    "medicalCallId",
    "dispatchCallId",
    "incidentId",
    "mdtCaseId",
    "sourceResource",
)

BASELINE_SCHEMA_VERSION = 1
REPORT_SCHEMA_VERSION = 2


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


def lua_files() -> list[pathlib.Path]:
    if not SUITE.exists():
        raise SystemExit(f"Unified emergency suite not found: {SUITE}")
    return [
        path
        for path in sorted(SUITE.rglob("*.lua"))
        if not any(part in {"vendor", "node_modules"} for part in path.parts)
    ]


def scan() -> tuple[list[Hit], dict[str, set[str]], int]:
    hits: list[Hit] = []
    correlation: dict[str, set[str]] = collections.defaultdict(set)
    files = lua_files()

    for path in files:
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
    return hits, correlation, len(files)


def duplicate_commands(hits: list[Hit]) -> dict[str, list[Hit]]:
    owners: dict[str, list[Hit]] = collections.defaultdict(list)
    for hit in hits:
        if hit.kind == "command":
            owners[hit.name.lower()].append(hit)
    return {
        name: rows
        for name, rows in owners.items()
        if len({row.path for row in rows}) > 1
    }


def owner_signature(rows: list[Hit]) -> list[str]:
    return sorted({row.path for row in rows})


def baseline_payload(duplicates: dict[str, list[Hit]]) -> dict[str, object]:
    return {
        "schemaVersion": BASELINE_SCHEMA_VERSION,
        "description": "Reviewed duplicate command ownership baseline. Entries are command -> owning file paths.",
        "duplicateCommands": {
            name: owner_signature(rows)
            for name, rows in sorted(duplicates.items())
        },
    }


def write_baseline(path: pathlib.Path, duplicates: dict[str, list[Hit]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(baseline_payload(duplicates), indent=2, sort_keys=True) + "\n", encoding="utf-8")


def load_baseline(path: pathlib.Path) -> dict[str, list[str]]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"Emergency surface baseline not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Emergency surface baseline is invalid JSON: {path}: {exc}") from exc

    if payload.get("schemaVersion") != BASELINE_SCHEMA_VERSION:
        raise SystemExit(
            f"Emergency surface baseline schema mismatch: expected {BASELINE_SCHEMA_VERSION}, "
            f"got {payload.get('schemaVersion')!r}"
        )
    raw = payload.get("duplicateCommands")
    if not isinstance(raw, dict):
        raise SystemExit("Emergency surface baseline duplicateCommands must be an object")

    out: dict[str, list[str]] = {}
    for name, owners in raw.items():
        if not isinstance(name, str) or not isinstance(owners, list) or not all(isinstance(v, str) for v in owners):
            raise SystemExit(f"Invalid baseline entry for command {name!r}")
        out[name.lower()] = sorted(set(owners))
    return out


def compare_baseline(duplicates: dict[str, list[Hit]], baseline: dict[str, list[str]]) -> dict[str, object]:
    current = {name: owner_signature(rows) for name, rows in duplicates.items()}
    new_commands: dict[str, list[str]] = {}
    expanded_owners: dict[str, dict[str, list[str]]] = {}
    resolved_commands: dict[str, list[str]] = {}
    reduced_owners: dict[str, dict[str, list[str]]] = {}

    for name, owners in current.items():
        expected = baseline.get(name)
        if expected is None:
            new_commands[name] = owners
            continue
        extra = sorted(set(owners) - set(expected))
        removed = sorted(set(expected) - set(owners))
        if extra:
            expanded_owners[name] = {"baseline": expected, "current": owners, "addedOwners": extra}
        if removed:
            reduced_owners[name] = {"baseline": expected, "current": owners, "removedOwners": removed}

    for name, owners in baseline.items():
        if name not in current:
            resolved_commands[name] = owners

    regressions = len(new_commands) + len(expanded_owners)
    improvements = len(resolved_commands) + len(reduced_owners)
    return {
        "regressionCount": regressions,
        "improvementCount": improvements,
        "newDuplicateCommands": new_commands,
        "expandedDuplicateOwners": expanded_owners,
        "resolvedDuplicateCommands": resolved_commands,
        "reducedDuplicateOwners": reduced_owners,
    }


def build_report(
    hits: list[Hit],
    correlation: dict[str, set[str]],
    file_count: int,
    baseline_comparison: dict[str, object] | None = None,
) -> dict[str, object]:
    by_kind = collections.Counter(hit.kind for hit in hits)
    duplicates = duplicate_commands(hits)
    resources = sorted({resource_for(path) for path in lua_files()})

    report: dict[str, object] = {
        "schemaVersion": REPORT_SCHEMA_VERSION,
        "suite": SUITE.relative_to(ROOT).as_posix(),
        "luaFilesScanned": file_count,
        "declarationsAndUsages": len(hits),
        "countsByKind": {kind: by_kind[kind] for kind in PATTERNS},
        "duplicateCommandCount": len(duplicates),
        "duplicateCommands": {
            name: [asdict(hit) for hit in rows]
            for name, rows in sorted(duplicates.items())
        },
        "correlationFields": list(CORRELATION_FIELDS),
        "correlationReadiness": {
            resource: [field for field in CORRELATION_FIELDS if field in correlation.get(resource, set())]
            for resource in resources
        },
        "notes": [
            "Duplicate commands are audit findings, not automatically bugs; compatibility aliases may be intentional.",
            "Correlation readiness is lexical presence only and does not prove end-to-end propagation or trust validation.",
            "Regression mode fails only new duplicate commands or newly added owners relative to a reviewed baseline.",
        ],
    }
    if baseline_comparison is not None:
        report["baselineComparison"] = baseline_comparison
    return report


def print_text_report(report: dict[str, object]) -> None:
    print("DPN Emergency Surface Audit")
    print(f"Lua files scanned: {report['luaFilesScanned']}")
    print(f"Lua declarations/usages scanned: {report['declarationsAndUsages']}")
    counts = report["countsByKind"]
    assert isinstance(counts, dict)
    for kind in PATTERNS:
        print(f"  {kind}: {counts.get(kind, 0)}")

    print("\nDuplicate command registrations")
    duplicates = report["duplicateCommands"]
    assert isinstance(duplicates, dict)
    if not duplicates:
        print("  none")
    else:
        for name, rows in duplicates.items():
            print(f"  /{name}")
            for row in rows:
                print(f"    - {row['path']}:{row['line']}")

    comparison = report.get("baselineComparison")
    if isinstance(comparison, dict):
        print("\nBaseline comparison")
        print(f"  regressions: {comparison.get('regressionCount', 0)}")
        print(f"  improvements: {comparison.get('improvementCount', 0)}")
        for name, owners in comparison.get("newDuplicateCommands", {}).items():
            print(f"  NEW /{name}: {', '.join(owners)}")
        for name, detail in comparison.get("expandedDuplicateOwners", {}).items():
            print(f"  EXPANDED /{name}: +{', '.join(detail.get('addedOwners', []))}")
        for name in comparison.get("resolvedDuplicateCommands", {}):
            print(f"  RESOLVED /{name}")
        for name, detail in comparison.get("reducedDuplicateOwners", {}).items():
            print(f"  REDUCED /{name}: -{', '.join(detail.get('removedOwners', []))}")

    print("\nCorrelation-field readiness by resource")
    readiness = report["correlationReadiness"]
    assert isinstance(readiness, dict)
    for resource, fields in readiness.items():
        present = ", ".join(fields) or "none"
        print(f"  {resource}: {present}")

    print("\nNotes")
    for note in report["notes"]:
        print(f"  - {note}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true", help="fail if any duplicate command registrations exist")
    parser.add_argument("--json", action="store_true", dest="json_output", help="emit JSON instead of the human-readable report")
    parser.add_argument("--baseline", type=pathlib.Path, help="reviewed duplicate-command ownership baseline JSON")
    parser.add_argument("--write-baseline", type=pathlib.Path, help="write the current duplicate ownership as a reviewed baseline and exit")
    parser.add_argument("--fail-on-regression", action="store_true", help="fail only on duplicate ownership regressions versus --baseline")
    args = parser.parse_args()

    if args.fail_on_regression and args.baseline is None:
        parser.error("--fail-on-regression requires --baseline")

    hits, correlation, file_count = scan()
    duplicates = duplicate_commands(hits)

    if args.write_baseline is not None:
        write_baseline(args.write_baseline, duplicates)
        print(f"Wrote emergency surface baseline: {args.write_baseline}")
        return 0

    comparison = compare_baseline(duplicates, load_baseline(args.baseline)) if args.baseline else None
    report = build_report(hits, correlation, file_count, comparison)
    if args.json_output:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print_text_report(report)

    if args.strict and report["duplicateCommandCount"]:
        return 1
    if args.fail_on_regression and comparison and comparison["regressionCount"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
