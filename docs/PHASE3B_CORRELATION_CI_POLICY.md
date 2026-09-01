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

Existing duplicate command registrations are intentionally informational by default. Some are compatibility aliases and cannot be removed safely without an owner-by-owner migration.

## Enforcement stages

### Stage 0 — inventory

Current state.

- Human-readable audit is available.
- JSON output is available.
- Duplicate commands do not fail CI.
- Correlation-field presence does not imply correctness.
- No runtime behavior is changed by the audit.

### Stage 1 — approved ownership baseline

Before strict enforcement, create an explicit baseline file that lists known intentional duplicate commands and their owners. New duplicate command registrations not present in that baseline should fail CI.

Requirements:

- every baseline exception must include a reason;
- every exception must name a canonical owner;
- every exception should identify a planned removal or compatibility strategy;
- the baseline must never be automatically expanded by CI;
- unknown duplicates are errors rather than silently accepted drift.

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

## Proposed machine-readable baseline

When runtime Phase 3B begins, add a JSON file similar to:

```json
{
  "schemaVersion": 1,
  "duplicateCommands": {
    "panic": {
      "canonicalResource": "dpn-dispatch",
      "compatibilityOwners": ["dpn-officer-safety"],
      "reason": "Legacy compatibility during dispatch consolidation",
      "targetPhase": "3C"
    }
  }
}
```

The audit tool can then compare discovered duplicates with approved exceptions. Unknown duplicates fail CI while documented compatibility remains visible.

## Promotion criteria

Phase 3B audit enforcement may move beyond Stage 0 only when:

1. Phase 3A is merged into the target base branch.
2. The Phase 3B preparation branch is rebased onto that hardened foundation.
3. Canonical ownership is documented for dispatch, medical dispatch, incident command, and MDT creation flows.
4. Compatibility aliases are mapped to known callers.
5. Rollback behavior is documented for the first runtime correlation changes.

## Current blocker

PR #7 remains intentionally unmerged pending explicit authorization. Runtime Phase 3B changes should therefore remain preparatory. Audit tooling, architecture documentation, health reports, and CI policy can continue safely without modifying live emergency behavior.
