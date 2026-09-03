# Phase 3E — Medical Core Consolidation Contract

## Purpose

Phase 3E prepares the Medical Core for bounded consolidation after Phase 3A registry ownership hardening and after the emergency-correlation, dispatch-ownership, and MDT integration phases are integrated. This contract is intentionally documentation-only. It defines the safety, ownership, compatibility, validation, and migration rules that runtime consolidation must satisfy before any historical implementation layer can be retired.

## Core invariant

`dpn-medical-core` must have one authoritative runtime owner for each Medical Core responsibility while preserving every unique capability currently supplied by historical and numerical layers until behavioral parity is proven by code review and CI.

Consolidation is not permission to delete functionality. Duplicate ownership may be removed only after the surviving owner demonstrably preserves the same public behavior, persistence semantics, event/export compatibility, and integration contracts.

## Consolidation boundaries

Runtime Phase 3E should inventory and classify every loaded Medical Core server/client/shared layer by responsibility, including:

- module registration and heartbeat ownership;
- patient medical state and life-state authority;
- injury, wound, treatment, medication, and vital-sign state;
- persistence and database synchronization;
- emergency correlation and incident linkage;
- hospital/EMS/dispatch/MDT integration surfaces;
- simulation, training, test-lab, dashboard, board, and administrative capabilities;
- commands, callbacks, events, exports, NUI messages, and framework integration;
- compatibility shims supporting historical consumers.

Each responsibility must resolve to exactly one canonical runtime owner, or to an explicitly documented multi-owner design where ownership is intentionally partitioned and non-overlapping.

## Required inventory before code consolidation

Before changing runtime load order or removing any historical owner, produce an auditable matrix containing at minimum:

1. resource-relative file path;
2. current load order;
3. responsibility/capability set;
4. events registered and emitted;
5. exports and callbacks provided;
6. database tables/columns read or written;
7. state bags or replicated state touched;
8. commands and administrative surfaces;
9. downstream resources known to consume the surface;
10. whether behavior is unique, duplicated, superseded, or unknown.

Unknown behavior must be treated as unique until proven otherwise.

## Canonical authority rules

The consolidated Medical Core must preserve the Phase 3A authority model:

- runtime resource identity derives from `GetCurrentResourceName()`;
- runtime version derives from manifest metadata;
- module registration and heartbeat ownership remain singular and authoritative;
- historical numerical layers must not regain lifecycle ownership;
- server-side medical state changes remain server authoritative;
- client requests must not become a substitute for server-side validation;
- emergency correlation identifiers remain immutable once assigned.

The consolidation must not introduce competing authoritative copies of patient state.

## State model requirements

For each patient, canonical state must have one normalized server-side representation. Historical aliases may remain temporarily for compatibility, but they must either derive from the canonical representation or be updated through one explicit adapter path.

Required properties:

- idempotent application of repeated updates;
- deterministic merge behavior for partial updates;
- bounded and explicit defaults;
- no silent downgrade from authoritative server state to client-provided state;
- no circular replication loops between legacy and canonical models;
- restart-safe persistence for durable medical records;
- clear separation between durable clinical history and ephemeral runtime observations.

## Emergency correlation compatibility

Phase 3E must consume, not redefine, the emergency-correlation contract established by preceding phases. Where applicable, medical records and active patient state must preserve immutable linkage for:

- `eventId`;
- `medicalCallId`;
- `dispatchCallId`;
- `incidentId`;
- `mdtCaseId`;
- `sourceResource`.

Missing downstream dependencies must degrade safely without manufacturing conflicting identifiers.

## Compatibility guarantee

No existing public integration surface may be removed merely because a cleaner canonical implementation exists. Existing events, exports, callbacks, commands, configuration names, and documented data shapes must either:

1. remain available unchanged; or
2. be routed through a compatibility adapter that preserves the existing contract.

Any later removal of a compatibility surface requires separate evidence of zero active consumers and explicit migration documentation.

## Historical-layer retirement rule

A historical layer may be removed from runtime loading only when all of the following are true:

- every capability it supplies is mapped to a surviving owner;
- all unique behavior has been migrated or intentionally preserved through an adapter;
- repository search identifies no unresolved direct consumer of a removed symbol;
- Lua syntax checks pass;
- DPN repository validation passes;
- Medical Core ownership guards pass;
- targeted regression checks cover the migrated responsibilities;
- both required pull-request workflows pass on the exact candidate head;
- review confirms no loss of gameplay, clinical, persistence, administrative, simulation, or integration behavior.

When evidence is incomplete, keep the layer loaded.

## Persistence and migration safety

Database changes, if later required, must be additive and backward compatible first. Do not perform destructive schema migration as part of consolidation preparation.

Runtime migration must:

- preserve existing records;
- preserve stable identifiers;
- tolerate records written by historical versions;
- avoid one-time transformations that cannot be safely retried;
- expose migration/version state for diagnostics;
- avoid blocking normal emergency gameplay on optional backfill work.

## Load-order cleanup

Load-order cleanup may occur only after ownership is proven. The final load order should make canonical ownership obvious and deterministic while keeping temporary compatibility adapters after canonical modules where appropriate.

Numerically named historical files must not be assumed obsolete based on filename alone.

## Performance requirements

Consolidation should reduce duplicate work without trading correctness for speed. Runtime implementation should seek to eliminate redundant:

- registration and heartbeat loops;
- duplicate polling loops;
- repeated database writes for equivalent state;
- duplicate event fan-out;
- repeated normalization of identical medical state;
- redundant persistence or reconciliation tasks.

Frame-sensitive work must remain frame-sensitive where required. Idle work should use bounded intervals and event-driven updates where practical.

## Observability

The canonical implementation should provide enough structured diagnostics to determine:

- active Medical Core version and resource identity;
- canonical owner of each major responsibility;
- registration/heartbeat health;
- patient-state reconciliation failures;
- persistence failures;
- emergency-correlation linkage failures;
- compatibility-adapter use where materially useful for migration.

Diagnostics must not leak secrets or sensitive server configuration.

## CI hardening requirements

Runtime Phase 3E should add or extend additive checks that fail on regressions such as:

- historical numerical layers reclaiming registration/heartbeat lifecycle;
- duplicate authoritative handlers for explicitly singular responsibilities;
- removed public events/exports/callbacks without approved adapters;
- broken Lua syntax;
- missing manifest-derived version/resource identity;
- accidental loss of loaded unique historical functionality;
- obvious duplicate persistence ownership where one canonical writer is required.

CI must be strengthened, never weakened, to make consolidation pass.

## Implementation sequence

The runtime consolidation should proceed in small reviewable slices:

1. inventory and ownership matrix;
2. canonical patient-state contract;
3. compatibility-adapter map;
4. responsibility-by-responsibility migration;
5. duplicate loop/write elimination;
6. targeted regression coverage;
7. load-order simplification only after parity proof;
8. optional historical file retirement only after all retirement conditions are satisfied.

Each slice should begin from then-current secured `main` to avoid rebase debt.

## Dependency boundary

This preparation branch intentionally contains no runtime dependency on unmerged Phase 3B, 3C, or 3D branches. Runtime Phase 3E must begin from fresh `main` after preceding approved architecture phases are integrated.

## Out of scope without separate approval

This contract does not authorize:

- deletion of unique Medical Core functionality;
- weakening or bypassing CI;
- force pushes or history rewrites;
- changes to repository visibility;
- secrets or credential changes;
- licensing or ownership-term changes;
- release publication or alteration;
- branch-protection changes;
- destructive database migrations.

## Exit criteria

Phase 3E runtime consolidation is complete only when one authoritative Medical Core architecture is demonstrably in place, compatibility is preserved, unique historical behavior remains available, persistence and emergency linkage are stable, duplicate ownership is removed where proven safe, and all required repository workflows are green on the exact candidate head.