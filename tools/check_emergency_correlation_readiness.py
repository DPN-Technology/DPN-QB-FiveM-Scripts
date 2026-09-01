#!/usr/bin/env python3
"""Fail CI only when reviewed emergency correlation readiness regresses.

The lexical readiness audit is intentionally conservative: it proves only that
known correlation field names still exist in a resource's Lua surface. New
fields are treated as improvements. Baseline expansion must be deliberate and
is never performed automatically by CI.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

SCHEMA_VERSION = 1


def load_json(path: pathlib.Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"File not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}") from exc


def normalize_resources(raw: object, label: str) -> dict[str, set[str]]:
    if not isinstance(raw, dict):
        raise SystemExit(f"{label} resources must be an object")
    normalized: dict[str, set[str]] = {}
    for resource, fields in raw.items():
        if not isinstance(resource, str) or not isinstance(fields, list) or not all(isinstance(v, str) for v in fields):
            raise SystemExit(f"Invalid {label} readiness entry for {resource!r}")
        normalized[resource] = set(fields)
    return normalized


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audit", type=pathlib.Path, required=True, help="JSON output from audit_emergency_surface.py --json")
    parser.add_argument("--baseline", type=pathlib.Path, required=True, help="reviewed correlation readiness baseline")
    args = parser.parse_args()

    audit = load_json(args.audit)
    baseline = load_json(args.baseline)
    if baseline.get("schemaVersion") != SCHEMA_VERSION:
        raise SystemExit(
            f"Correlation readiness baseline schema mismatch: expected {SCHEMA_VERSION}, got {baseline.get('schemaVersion')!r}"
        )

    current = normalize_resources(audit.get("correlationReadiness"), "audit")
    expected = normalize_resources(baseline.get("resources"), "baseline")

    regressions: dict[str, list[str]] = {}
    improvements: dict[str, list[str]] = {}
    missing_resources: list[str] = []

    for resource, fields in expected.items():
        if resource not in current:
            missing_resources.append(resource)
            continue
        missing = sorted(fields - current[resource])
        added = sorted(current[resource] - fields)
        if missing:
            regressions[resource] = missing
        if added:
            improvements[resource] = added

    new_resources = sorted(set(current) - set(expected))
    event_id_ready = sorted(resource for resource, fields in current.items() if "eventId" in fields)

    print("DPN Emergency Correlation Readiness Guard")
    print(f"Reviewed resources: {len(expected)}")
    print(f"Current resources: {len(current)}")
    print(f"Resources with lexical eventId presence: {len(event_id_ready)}")
    print(f"Readiness regressions: {len(regressions) + len(missing_resources)}")
    print(f"Readiness improvements: {sum(len(v) for v in improvements.values()) + len(new_resources)}")

    for resource in missing_resources:
        print(f" - REGRESSION: reviewed resource disappeared from audit surface: {resource}")
    for resource, fields in sorted(regressions.items()):
        print(f" - REGRESSION: {resource} lost reviewed field(s): {', '.join(fields)}")
    for resource, fields in sorted(improvements.items()):
        print(f" + IMPROVEMENT: {resource} gained field(s): {', '.join(fields)}")
    for resource in new_resources:
        print(f" + IMPROVEMENT: new audited resource: {resource}")

    if missing_resources or regressions:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
