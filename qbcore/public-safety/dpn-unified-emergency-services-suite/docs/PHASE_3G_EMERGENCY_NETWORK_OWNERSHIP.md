# Phase 3G — Emergency-Network Ownership Cleanup Design

## Status

Design/preparation only. No runtime behavior is changed by this branch.

## Goal

Define clear ownership boundaries between the unified emergency network, dispatch, MDT, law-enforcement, medical, EMS, fire, and department-specific integrations so that each domain has one authoritative lifecycle owner while compatibility behavior remains intact.

## Current risk surface

The current suite exposes overlapping emergency concepts across multiple resources. `core/dpn-dispatch` presents unified emergency calls and multi-department command, `core/dpn-mdt` consumes and normalizes dispatch/call records, and law-enforcement/medical resources also create or proxy emergency activity. Without explicit boundaries, the same incident can acquire duplicate identifiers, state transitions, persistence writes, timers, or notifications.

## Ownership principles

1. The emergency network owns the cross-domain emergency correlation envelope and network-level lifecycle only.
2. Dispatch owns authoritative dispatch-call creation, unit assignment, dispatch status, and dispatch closure.
3. MDT owns case/report persistence and investigative/administrative state.
4. Medical Core owns canonical patient/clinical state.
5. EMS and Medical Dispatch own their domain workflows, not global emergency identity.
6. Department-specific resources remain adapters/consumers unless a capability is explicitly delegated.
7. Public compatibility events/exports remain available during migration and delegate to the authoritative owner.

## Canonical emergency-network responsibilities

The emergency network should be responsible for:

- linking a root emergency `eventId` to domain identifiers;
- recording source resource and trusted server timestamps;
- exposing lookup and correlation APIs;
- tracking cross-domain relationship metadata;
- emitting normalized cross-domain lifecycle notifications when appropriate;
- preventing identifier rebinding and split-brain ownership;
- exposing health/diagnostic information for integration monitoring.

It should not directly own dispatch unit assignments, MDT report bodies, medical patient state, hospital treatment state, or department-specific gameplay.

## Boundary contract

Every emergency-domain mutation should be classified as one of:

- **network correlation mutation** — emergency network;
- **dispatch mutation** — dispatch authority;
- **MDT mutation** — MDT authority;
- **medical mutation** — Medical Core or explicitly delegated medical domain owner;
- **department workflow mutation** — owning department resource;
- **adapter request** — compatibility layer forwarding into one of the authorities above.

A resource must not silently mutate another authority's canonical state table.

## Identifier rules

- Root `eventId` is server-authoritative.
- `dispatchCallId`, `medicalCallId`, `incidentId`, and `mdtCaseId` are minted by their authoritative domain owner and linked through the emergency-network correlation contract.
- Compatibility aliases may be recorded, but they do not replace canonical IDs.
- Unknown client-provided canonical IDs are never trusted as ownership proof.
- Once a domain ID is linked to an emergency root, rebinding requires an explicit migration/recovery path with audit evidence.

## Event and export rules

- Cross-resource writes use explicit server exports/events with validated payloads.
- Client events may request an action but cannot directly mutate canonical correlation or domain state.
- Every compatibility event/export must identify its authoritative downstream owner.
- Duplicate wrappers should converge on one internal implementation while preserving external signatures until separately approved for removal.

## Persistence rules

Each authoritative owner writes only its own canonical persistence tables. Cross-domain linkage is persisted through stable IDs rather than duplicate copies of mutable state. Cached copies must be treated as derived/read models and rebuilt after restart when possible.

## Restart and recovery

After resource restart or server recovery:

1. canonical domain owners restore their own state;
2. emergency-network correlation links are rehydrated or reconciled;
3. adapters resume without minting duplicate IDs;
4. unresolved links are surfaced as degraded health rather than silently duplicated;
5. retries are idempotent.

## Migration sequence

1. Inventory every emergency-network event, export, callback, table mutation, timer, and persistence write.
2. Map each operation to its intended authority.
3. Detect direct cross-domain writes and duplicate lifecycle ownership.
4. Add CI checks that block multiple canonical owners for the same responsibility.
5. Introduce adapters where legacy integrations bypass the selected owner.
6. Migrate writes incrementally after Phases 3B–3F are merged and verified.
7. Preserve all unique gameplay, notifications, UI, metrics, and departmental behavior.
8. Remove duplicate internal code only after parity and restart/recovery tests prove it redundant.

## Required validation

Phase 3G implementation is not complete until tests prove:

- one canonical owner per lifecycle responsibility;
- no client event can seize canonical identity;
- duplicate requests are idempotent;
- restarts do not create split-brain records;
- Dispatch, MDT, Medical Core, EMS, Medical Dispatch, law enforcement, and fire integrations retain their unique behavior;
- compatibility exports/events still resolve correctly;
- correlation links survive persistence/recovery;
- existing repository, manifest, medical-registry, emergency-correlation, and Lua syntax quality gates remain at least as strict as before.

## Initial audit findings

On the current `main` baseline, the suite includes a dedicated `core/dpn-dispatch` UI describing unified emergency calls and multi-department command, while `core/dpn-mdt/server/main.lua` normalizes incoming call identifiers and dispatch data. These are legitimate integrations but demonstrate why ownership must be explicit before runtime consolidation.

## Non-goals for this design branch

- No runtime ownership transfer.
- No deletion of emergency-network, dispatch, MDT, medical, EMS, fire, or law-enforcement behavior.
- No database migration.
- No public API removal.
- No branch-protection, visibility, licensing, secret, or release changes.
