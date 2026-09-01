# Phase 3F — EMS and Medical Dispatch Consolidation Plan

## Status

Design/preparation only. This document intentionally changes no runtime behavior and is based directly on the current `main` baseline. Implementation must be rebuilt from refreshed `main` after preceding architecture phases are merged.

## Goal

Consolidate duplicated EMS and Medical Dispatch lifecycle behavior while preserving all unique assessment, protocol, response, unit-assignment, hospital-handoff, reporting, mutual-aid, and compatibility features.

## Confirmed current scope

The medical suite contains dedicated `dpn-medical-ems` and `dpn-medical-dispatch` resources alongside `dpn-medical-core`, `dpn-medical-ambulance`, `dpn-medical-hospital`, and other specialized resources. Consolidation must therefore be evidence-driven across boundaries rather than based on resource age or version numbers alone.

## Required inventory before code changes

Produce a machine-readable inventory for EMS and Medical Dispatch covering:

- loaded client/server/shared files;
- numerical historical layers and load order;
- exported functions;
- server and client events;
- commands and keybinds;
- background threads and timers;
- database reads/writes and table ownership;
- dispatch-call lifecycle mutations;
- unit assignment and response-status ownership;
- care-episode creation and update ownership;
- hospital handoff and disposition paths;
- medical-core reads/writes;
- emergency-network integration;
- MDT/report integration;
- compatibility aliases and wrappers;
- restart/disconnect cleanup behavior.

No code path may be removed only because a newer numerical file exists. Removal requires proof that the behavior is duplicated and all unique side effects are preserved.

## EMS authority model

One authoritative EMS lifecycle should own responder/patient care episodes. It should define:

1. episode creation and identity;
2. responder assignment and participation;
3. assessment and protocol progression;
4. treatment/intervention recording;
5. transport decision and destination;
6. hospital handoff/disposition;
7. episode closure and persistence;
8. reconnect/restart recovery;
9. audit/history publication.

Specialized modules may contribute data or request transitions but should not create competing authoritative episode state.

## Medical Dispatch authority model

Medical Dispatch should own medical call-routing state that is distinct from the generic dispatch owner defined by Phase 3C. Responsibilities include:

- medical priority/triage metadata;
- EMS unit recommendations and assignment requests;
- response timing and status transitions;
- medical mutual-aid coordination;
- medical-specific escalation;
- EMS linkage to the canonical dispatch call;
- medical call lifecycle metadata;
- hospital/destination coordination when applicable.

It must not mint a second generic dispatch identity for an emergency that already has a canonical dispatch call.

## Phase 3B correlation integration

After Phase 3B is merged, EMS and Medical Dispatch should consume the canonical emergency correlation contract:

- `eventId` is the immutable root;
- `dispatchCallId` links to the authoritative generic dispatch call;
- `medicalCallId` links the medical-dispatch lifecycle;
- `incidentId` and `mdtCaseId` are attached when available;
- server-resolved `sourceResource` is preserved;
- repeated correlated requests are idempotent.

No client-controlled ID may seize ownership of an existing server-side emergency or medical call.

## Duplicate-behavior classes to audit

### Lifecycle creation
Find every path that creates EMS episodes or medical-dispatch calls. Classify each as authoritative owner, adapter, consumer, or legacy compatibility path.

### Timers and response metrics
Identify duplicated response timers, elapsed-time loops, SLA calculations, timeout threads, and status polling. Preserve one authoritative timing source wherever semantics are equivalent.

### Responder state
Find repeated in-memory responder/unit maps, duty-state caches, assignment tables, and patient links. Define one owner per state domain and convert duplicate writers to consumers/adapters.

### Persistence
Inventory duplicate inserts/updates for calls, episodes, treatments, assignments, reports, and metrics. Consolidate only where table/row ownership is proven equivalent.

### Events and exports
Map aliases and versioned wrappers to canonical contracts. Keep compatibility adapters until dependent resources are verified migrated.

## Unique functionality that must be preserved

At minimum, consolidation must retain any currently implemented unique behavior for:

- advanced patient assessment;
- clinical protocols;
- treatment and intervention history;
- care episodes;
- responder/unit assignment;
- response metrics;
- transport lifecycle;
- hospital handoff;
- disposition;
- medical priority/triage;
- mutual aid;
- notifications;
- reports/MDT linkage;
- admin/diagnostic surfaces;
- compatibility exports/events.

## Restart and reconnect recovery

Implementation must define explicit behavior for:

- resource restart during active EMS episode;
- Medical Dispatch restart during active call;
- player disconnect while assigned/responding;
- responder reconnect;
- stale assignment cleanup;
- duplicate callback replay;
- partial dependency outage;
- recovery when Dispatch, MDT, Medical Core, or emergency-network returns after downtime.

Recovery must be idempotent and must not create duplicate calls, episodes, or reports.

## Performance targets

Audit and reduce unnecessary:

- high-frequency polling;
- duplicate timers;
- duplicate JSON encoding/decoding;
- repeated export/resource-state calls;
- duplicate database writes;
- repeated full-table scans;
- unbounded in-memory histories.

Optimization must not weaken clinical simulation fidelity or remove required audit/history behavior.

## Validation requirements

Phase 3F implementation is not complete until automated checks prove:

- one authoritative EMS episode lifecycle;
- one medical-dispatch lifecycle per correlated emergency;
- no second generic dispatch call is created for the same `eventId`;
- repeated event delivery is idempotent;
- distinct simultaneous incidents remain distinct;
- hospital handoff survives consolidation;
- treatment/protocol history is preserved;
- responder assignment is not duplicated;
- restart/reconnect recovery does not duplicate state;
- legacy public exports/events remain available through adapters until intentionally retired;
- Lua syntax and manifests remain valid;
- existing DPN quality gates remain at least as strict as before.

## Migration sequence

1. Inventory EMS and Medical Dispatch layers and contracts.
2. Build an ownership matrix for state, events, exports, timers, and persistence.
3. Add CI/audit tooling that detects duplicate authoritative lifecycle owners.
4. Introduce canonical internal APIs without deleting compatibility wrappers.
5. Route duplicate creators through canonical owners.
6. Integrate Phase 3B correlation and Phase 3C dispatch ownership.
7. Integrate Phase 3D MDT synchronization.
8. Validate Medical Core interactions after Phase 3E consolidation.
9. Add restart/reconnect/idempotency tests.
10. Remove only proven duplicate internal behavior in focused reviewed changes.

## Non-goals for this design branch

- No runtime EMS behavior changes.
- No runtime Medical Dispatch behavior changes.
- No database schema changes.
- No removal of historical/versioned layers.
- No export/event deletion.
- No release, visibility, secret, licensing, ownership, or branch-protection changes.
