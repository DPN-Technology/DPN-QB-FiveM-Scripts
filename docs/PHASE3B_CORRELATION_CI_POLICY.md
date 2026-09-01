# Phase 3B Emergency Correlation CI Policy

Status: Preparatory policy — runtime migration not yet active

## Purpose

This policy defines how the DPN repository will move from audit-only visibility of emergency call ownership to enforceable CI guarantees without breaking existing FiveM compatibility aliases or deleting unique functionality.

The Phase 3B migration centers on a root immutable `eventId` that correlates dispatch, medical, incident command, and MDT records. During preparation, CI must report current overlap accurately. Enforcement should increase only after each compatibility surface has an explicit migration owner and rollback path.

## Current audit behavior

`tools/audit_emergency_surface.py` scans the unified emergency suite and reports:

- FiveM command registrations
- registered network events
- local event handlers
- server/client/local event triggers
- duplicate command ownership across files
- lexical presence of correlation fields by resource
- a stable JSON schema for later automation
- reviewed-baseline comparisons for duplicate command ownership

Existing duplicate command registrations are intentionally informational by default. Some are compatibility aliases and cannot be removed safely without an owner-by-owner migration.

The auditor now supports two distinct enforcement modes:

- `--strict` fails on every duplicate command and is intentionally too aggressive for the current compatibility surface.
- `--baseline <file> --fail-on-regression` fails only when a new duplicate command appears or an existing duplicate gains a new owner relative to an explicitly reviewed baseline.

It also supports `--write-baseline <file>` as a maintainer convenience. That command must never be run automatically in CI because doing so would silently redefine expected behavior instead of detecting drift.

## Enforcement stages

### Stage 0 — inventory

Current state.

- Human-readable audit is available.
- JSON output is available.
- DPN Quality Gate also writes a concise emergency-surface summary to the GitHub Actions job summary.
- Duplicate commands do not fail CI.
- Correlation-field presence does not imply correctness.
- No runtime behavior is changed by the audit.

### Stage 1 — approved ownership baseline

Before regression enforcement, create an explicit baseline file containing the currently reviewed duplicate command names and owning file paths. New duplicate command registrations or newly added owners not present in that baseline should fail CI.

Requirements:

- generate a candidate with `python3 tools/audit_emergency_surface.py --write-baseline <path>`;
- review every generated command and owner before committing it;
- document the canonical resource, compatibility purpose, and planned migration for each accepted overlap in the Phase 3B ownership documentation;
- never automatically refresh or expand the baseline in CI;
- treat unknown duplicate commands and newly added owners as regressions;
- allow resolved duplicate commands or reduced owner sets to pass and report as improvements;
- never restore an owner merely to make the repository match an older baseline.

### Stage 2 — correlation contract enforcement

Once the root correlation helpers exist, CI should verify canonical emergency creation paths expose and preserve:

- `eventId`
- `sourceResource`
- relevant subsystem IDs (`dispatchCallId`, `medicalCallId`, `incidentId`, `mdtCaseId`)

The guard should validate source code structure and contract usage without pretending lexical presence proves end-to-end correctness.

### Stage 3 — canonical ownership enforcement

After dispatch and incident creation paths are consolidated:

- duplicate canonical creation commands become CI errors;
- unauthorized new emergency creation routes become CI errors;
- compatibility aliases must route into canonical server-side creation rather than creating independent records;
- legacy aliases may remain only when they preserve the existing `eventId`.

### Stage 4 — idempotency and persistence checks

After MDT and persistence migration:

- repeated sync using the same root `eventId` must not create duplicate case/call rows;
- database migrations must preserve correlation IDs;
- restart recovery must not generate a new root ID for an already persisted emergency;
- tests should cover duplicate deliveries and resource restart ordering.

## CI safety rules

The repository must not weaken a validator simply to make a pull request green. If a guard identifies legitimate historical compatibility behavior, the correct response is to document and baseline the compatibility path or migrate it deliberately.

The following are prohibited as cleanup shortcuts:

- deleting a command/event solely because it is duplicated without checking callers;
- replacing server authority with client-provided identifiers;
- generating a new `eventId` at every subsystem boundary;
- suppressing audit output for known duplicates;
- adding broad exclusions that hide future regressions;
- deleting loaded historical layers that still provide unique functionality.

## Machine-readable ownership fingerprint

The implemented baseline is intentionally small and mechanical. It records only the duplicate command name and the exact owning source-file paths:

```json
{
  "schemaVersion": 1,
  "description": "Reviewed duplicate command ownership baseline. Entries are command -> owning file paths.",
  "duplicateCommands": {
    "panic": [
      "qbcore/public-safety/dpn-unified-emergency-services-suite/core/dpn-dispatch/server/main.lua",
      "qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-lawenforcement]/dpn-officer-safety/server/main.lua"
    ]
  }
}
```

This fingerprint is not itself justification for an overlap. Human-readable architecture documentation remains authoritative for the canonical owner, compatibility reason, migration target, and rollback strategy. Keeping those concerns separate lets the audit compare source ownership deterministically while still requiring explicit architectural review.

A regression is one of the following:

- a duplicate command name that did not exist in the reviewed baseline;
- a new owning source path added to a duplicate that already existed.

An improvement is one of the following:

- a previously duplicated command is no longer duplicated;
- an existing duplicate has fewer owning source paths.

Improvements are reported but do not fail the audit.

## Promotion criteria

Phase 3B audit enforcement may move beyond Stage 0 only when:

1. Phase 3A is merged into the target base branch.
2. The Phase 3B preparation branch is rebased onto that hardened foundation.
3. Canonical ownership is documented for dispatch, medical dispatch, incident command, and MDT creation flows.
4. Compatibility aliases are mapped to known callers.
5. A candidate duplicate-ownership fingerprint is generated and reviewed command-by-command.
6. Rollback behavior is documented for the first runtime correlation changes.

## Current blocker

PR #7 remains intentionally unmerged pending explicit authorization. Runtime Phase 3B changes should therefore remain preparatory. Audit tooling, architecture documentation, health reports, and CI policy can continue safely without modifying live emergency behavior.
