# Phase 3F — EMS / Medical Dispatch Consolidation Contract

## Purpose

Phase 3F prepares the EMS and Medical Dispatch layers for bounded consolidation after the emergency-correlation, dispatch-ownership, MDT-integration, and Medical Core consolidation contracts are integrated. This document is intentionally preparation-only. It defines authority, compatibility, deduplication, migration, performance, observability, and validation rules that runtime consolidation must satisfy before any duplicate EMS or medical-dispatch owner is retired.

## Core invariant

Each emergency-medical responsibility must have one canonical runtime owner, while every unique gameplay, clinical, dispatch, notification, persistence, assignment, telemetry, and compatibility behavior remains available until parity is proven.

Consolidation is not permission to remove functionality because two files appear similar. Unknown or unclassified behavior must be treated as unique until repository-wide evidence proves otherwise.

## Required ownership inventory

Before runtime changes, build an auditable inventory of all EMS and medical-dispatch server/client/shared layers. Record at minimum:

1. resource and file path;
2. load order;
3. public events, callbacks, exports, commands, and NUI messages;
4. dispatch-call creation/update/close behavior;
5. EMS assignment and responder-state behavior;
6. patient/call linkage behavior;
7. database tables and durable fields touched;
8. state bags or replicated state touched;
9. timers, polling loops, background reconciliation, and retry behavior;
10. downstream consumers and optional integrations;
11. whether each responsibility is unique, duplicated, adapter-only, superseded, or unknown.

No historical layer may be retired while any responsibility remains unknown.

## Canonical ownership boundaries

Runtime Phase 3F must make ownership explicit and non-overlapping.

### Medical Core

Medical Core remains authoritative for canonical patient medical state and medical-state persistence according to Phase 3E. EMS and Medical Dispatch may reference patient state but must not become competing canonical owners.

### Emergency correlation

The immutable emergency-correlation contract established by preceding phases remains authoritative. EMS and Medical Dispatch consume and preserve existing identifiers rather than minting conflicting replacements.

Where applicable, preserve linkage for:

- `eventId`;
- `medicalCallId`;
- `dispatchCallId`;
- `incidentId`;
- `mdtCaseId`;
- `sourceResource`.

Identifiers must remain immutable after assignment except through an explicitly documented migration adapter.

### Dispatch call ownership

One canonical server-side owner must create and mutate each dispatch-call identity. EMS-specific presentation, notification, unit assignment, and clinical context may extend that call without creating duplicate canonical dispatch identities.

Repeated submissions carrying the same canonical correlation identity must be idempotent.

### EMS responder ownership

Responder availability, assignment, en-route, on-scene, transporting, hospital-arrival, and clear states must have an explicit server-side authority. Client requests may request transitions but must not authoritatively assign or clear another responder without server validation.

### Medical Dispatch ownership

Medical Dispatch may own EMS-facing emergency workflow coordination, but it must not duplicate generic dispatch ownership, Medical Core patient authority, or MDT record authority.

## Dispatch deduplication rules

Consolidation must preserve one logical medical emergency as one canonical dispatch identity even when multiple compatibility paths, resource events, exports, or retries fire.

Runtime implementation must provide bounded idempotency using stable keys such as the immutable emergency-correlation identity and canonical dispatch identifier.

Deduplication must:

- reject or reuse duplicate creates safely;
- preserve legitimate distinct emergencies involving the same player or location;
- avoid unbounded in-memory deduplication tables;
- survive routine retry/replay behavior where practical;
- avoid suppressing later legitimate calls after the configured deduplication window;
- expose enough diagnostics to explain reuse versus creation decisions.

## Assignment and lifecycle rules

A canonical medical dispatch call should have a deterministic lifecycle. Runtime implementation must define valid transitions, including as applicable:

- created;
- pending;
- assigned;
- acknowledged;
- en route;
- on scene;
- transporting;
- at hospital;
- cleared;
- cancelled;
- expired.

Invalid, stale, duplicate, or unauthorized transitions must fail closed without corrupting the call.

Closing a call must not silently delete durable medical, incident, or MDT history that is owned elsewhere.

## Server-authority requirements

All security-sensitive or authoritative operations must derive authority from server-observed state where practical.

At minimum, runtime consolidation must validate:

- caller identity from server event context;
- job/role/permission requirements;
- responder ownership of assignment-sensitive transitions;
- target/player/entity existence where required;
- current call/session state;
- immutable correlation identifiers;
- proximity or routing-bucket requirements where gameplay semantics depend on physical presence;
- stale or replayed requests.

Client-provided identifiers may be references but must not by themselves prove authorization.

## Compatibility guarantee

Existing public events, exports, callbacks, commands, configuration names, data shapes, and optional integration hooks must remain compatible unless a separate approved migration explicitly replaces them.

If duplicate historical entry points exist, they should route through a single canonical implementation through compatibility adapters rather than each retaining independent authority.

Adapters must not create recursive event loops or duplicate fan-out.

## Historical-layer retirement rule

A duplicate EMS or Medical Dispatch runtime layer may be removed from loading only when all of the following are true:

- every capability is mapped to a surviving canonical owner or adapter;
- repository-wide search finds no unresolved consumer of removed symbols;
- all unique gameplay and workflow behavior is preserved;
- emergency-correlation propagation remains intact;
- dispatch creation remains deduplicated and server authoritative;
- responder assignments and lifecycle transitions remain correct;
- database and persistence behavior remains backward compatible;
- Lua syntax validation passes;
- DPN repository validation passes;
- targeted EMS/dispatch ownership regression checks pass;
- both required pull-request workflows pass on the exact candidate head;
- review finds no deleted unique functionality.

When any item is uncertain, retain the historical layer.

## Persistence and migration safety

Database changes must be additive and backward compatible first. Runtime Phase 3F must preserve existing call history, medical linkage, unit assignments where durable, and stable identifiers.

Migrations must be retry-safe and should avoid blocking emergency gameplay on optional backfill work.

No destructive migration is authorized by this preparation contract.

## Restart and dependency behavior

The consolidated system must degrade safely across resource restarts and optional dependency failures.

Required behavior includes:

- canonical owners rehydrate durable state without creating duplicate emergency calls;
- compatibility adapters do not replay already-applied creates indefinitely;
- missing optional MDT or dispatch integrations do not manufacture conflicting identifiers;
- temporary dependency failure uses bounded retry/backoff rather than tight loops;
- stale assignments are reconciled deterministically;
- resource restart does not grant client authority that was previously server-side.

## Performance requirements

Consolidation should reduce duplicate work while preserving responsiveness.

Runtime implementation should eliminate proven redundant:

- emergency-call creation paths;
- database writes for the same state transition;
- notification fan-out;
- responder-state polling;
- heartbeat or reconciliation loops;
- repeated normalization of the same dispatch payload;
- duplicate proximity scans;
- repeated optional-integration retries without backoff.

Idle work should use bounded polling or event-driven updates where practical. Frame-sensitive UI/input behavior must remain frame-sensitive when required.

Deduplication caches, retry queues, and correlation maps must be bounded and cleaned deterministically.

## Observability

The canonical architecture should provide structured diagnostics sufficient to identify:

- canonical owner of medical-dispatch creation;
- correlation identifiers for a call;
- whether a create was new, reused, rejected, or migrated;
- responder assignment and lifecycle transition failures;
- duplicate-suppression decisions;
- persistence failures;
- optional integration failures and bounded retries;
- compatibility-adapter usage during migration.

Diagnostics must not expose secrets or sensitive server configuration.

## CI hardening requirements

Runtime Phase 3F should add additive checks that fail on regressions such as:

- more than one canonical medical-dispatch call owner;
- historical layers reclaiming canonical dispatch authority;
- client-authoritative assignment or closure paths;
- loss of immutable emergency-correlation propagation;
- removed public events/exports/callbacks without compatibility adapters;
- duplicate canonical call creation for the same correlation identity;
- obvious unbounded deduplication/retry structures;
- broken Lua syntax;
- accidental removal of unique historical functionality.

CI must be strengthened, never weakened, to make consolidation pass.

## Implementation sequence

Runtime consolidation should proceed in small focused slices:

1. complete EMS / Medical Dispatch ownership inventory;
2. identify canonical dispatch-call creation owner;
3. identify canonical responder-assignment/lifecycle owner;
4. map all compatibility entry points;
5. route duplicate create paths through idempotent canonical ownership;
6. consolidate duplicate assignment/state machinery;
7. consolidate persistence writes and optional integration fan-out;
8. add targeted security/dedup/restart regression checks;
9. simplify load order only after parity proof;
10. retire historical duplicate layers only after every retirement condition is satisfied.

Each runtime slice must start from then-current secured `main` rather than rebasing this preparation branch onto unmerged phase work.

## Dependency boundary

This preparation branch intentionally has no runtime dependency on unmerged Phase 3B, 3C, 3D, or 3E branches. Runtime Phase 3F must begin from fresh `main` only after the preceding approved architecture phases are integrated.

## Out of scope without separate approval

This contract does not authorize:

- deletion of unique EMS or Medical Dispatch functionality;
- weakening or bypassing CI;
- force pushes or history rewrites;
- repository visibility changes;
- secrets or credential changes;
- licensing or ownership-term changes;
- release publication or modification;
- branch-protection changes;
- destructive database migrations.

## Exit criteria

Phase 3F runtime consolidation is complete only when EMS and Medical Dispatch have explicit non-overlapping canonical ownership, one logical emergency produces one canonical dispatch identity, responder lifecycle remains server authoritative, compatibility and unique historical behavior are preserved, restart/dependency behavior is bounded and deterministic, and all required repository workflows are green on the exact candidate head.
