# Phase 3G — Emergency Network Ownership Cleanup

## Purpose

Phase 3G defines the ownership boundaries for the repository-wide emergency network after the preceding correlation, dispatch, MDT, Medical Core, and EMS/Medical Dispatch phases. The goal is to remove ambiguous duplicate ownership without deleting unique functionality, changing public contracts, or weakening failure handling.

## Non-negotiable invariants

- The server remains authoritative for emergency lifecycle state.
- The immutable root `eventId` established by Phase 3B must survive every emergency-network hop unchanged.
- `medicalCallId`, `dispatchCallId`, `incidentId`, and `mdtCaseId` remain linked identities, not interchangeable primary keys.
- A single logical emergency must not create duplicate canonical incidents because multiple resources observe the same event.
- Compatibility events, exports, commands, and callbacks remain supported unless a separately approved migration explicitly retires them after parity proof.
- No unique police, fire, EMS, medical, MDT, dispatch, notification, responder, audit, or persistence behavior may be removed as part of ownership cleanup.
- Existing CI remains additive and must not be weakened.

## Canonical ownership model

### Emergency correlation
The correlation layer owns creation and propagation of the immutable root `eventId`. Downstream resources may consume and attach local identifiers but may not replace or regenerate a valid existing root identifier.

### Dispatch
The canonical dispatch owner owns creation, deduplication, lifecycle state, responder assignment state, and dispatch-side identifiers. Producer resources request dispatch work; they do not independently become dispatch authorities.

### MDT
The MDT owner owns MDT persistence, case linkage, MDT-specific workflow state, and operator-facing MDT records. Dispatch or medical resources may synchronize through explicit adapters but must not directly own MDT persistence semantics.

### Medical Core
Medical Core owns canonical patient/clinical state and the medical runtime registry established in Phase 3A. Dispatch and MDT resources may reference medical state but must not duplicate Medical Core authority.

### EMS / Medical Dispatch
The consolidated EMS/Medical Dispatch owner owns EMS-facing emergency routing and responder workflow that is not already canonical dispatch or Medical Core state. Shared identifiers must be references to canonical owners, not locally re-created authorities.

### Producer resources
Police, fire, civilian, sensor, command, panic, callout, and other producer resources may originate emergency requests. Producers must submit normalized requests to canonical owners and retain only producer-specific gameplay state.

## Duplicate-owner cleanup rules

Before any runtime owner is removed, disabled, or converted into an adapter:

1. Inventory every event, export, callback, command, persistence write, timer, background thread, notification, responder action, and external integration owned by the candidate layer.
2. Map each capability to its canonical destination.
3. Prove behavioral parity for all unique functionality.
4. Add regression coverage for the migrated capability.
5. Preserve compatibility shims where external callers may still use the historical surface.
6. Confirm restart, dependency-loss, and replay behavior.
7. Only then remove duplicate ownership from runtime execution.

Deleting a historical layer merely because another similarly named layer exists is forbidden.

## Event and export boundaries

- Public events and exports should become thin adapters when their historical implementation is no longer canonical.
- Adapters must validate inputs, preserve correlation identifiers, and forward to the canonical server owner.
- Adapters must not silently fall back to creating a second local emergency record when the canonical dependency is unavailable.
- Dependency failure should fail closed for authority-changing operations and produce bounded diagnostics rather than unbounded retry loops.
- Event rebroadcasting must include loop prevention so compatibility bridges cannot bounce the same emergency indefinitely.

## Deduplication

Deduplication must prefer stable canonical identity over heuristic matching.

Priority order:

1. Existing valid `eventId`.
2. Existing canonical dispatch/incident linkage associated with that `eventId`.
3. Explicit compatibility mapping from a historical identifier to a canonical identifier.
4. Bounded heuristic reconciliation only for legacy data that predates canonical correlation.

Heuristic deduplication must never merge clearly distinct active emergencies solely because they are spatially close or occur within a similar time window.

## Persistence ownership

Each persistent record type must have exactly one canonical writer.

- Other resources may request writes through the canonical owner.
- Read models and caches are allowed but must be reconstructable from canonical state.
- Migration code must be idempotent and safe to rerun.
- Historical tables or fields may not be dropped in Phase 3G without separate explicit approval.
- Unknown or partially migrated records must remain recoverable and observable.

## Restart and recovery behavior

- Canonical identifiers must survive resource restart where persistence already exists.
- Reconciliation on startup must be bounded and idempotent.
- Compatibility adapters should rebuild mappings without generating new canonical incidents for already-known emergencies.
- In-memory caches must tolerate canonical owner restart and recover from authoritative persisted state or explicit re-query.
- A downstream resource restart must not seize ownership from the canonical owner.

## Security boundaries

- Client-supplied ownership claims are untrusted.
- Server-side role, job, entity, proximity, session, and lifecycle validation remain required where applicable.
- Network entity identifiers must be resolved and validated server-side before authority-changing actions.
- Administrative bypasses must remain explicit, auditable, and limited to already-authorized behavior.
- Cleanup work must not broaden who can create, modify, assign, close, admit, grade, transport, or otherwise mutate emergency state.

## Performance requirements

- Remove duplicate polling and duplicate persistence only after ownership parity is proven.
- Prefer event-driven synchronization over new permanent high-frequency loops.
- Reconciliation scans must be bounded, indexed where persistence is involved, and rate-limited where repeated.
- Compatibility adapters should add negligible steady-state cost.
- Any retry mechanism must use bounded backoff and terminate or degrade safely.

## Observability

Canonical owners should expose enough structured diagnostics to identify:

- root `eventId`;
- linked dispatch, incident, MDT, and medical identifiers;
- source resource;
- current canonical owner;
- compatibility adapter path when used;
- duplicate suppression/reuse decisions;
- rejected ownership mutations;
- reconciliation/migration outcomes;
- dependency degradation and recovery.

Logs must avoid leaking secrets or unnecessary personal information.

## CI hardening requirements

Phase 3G runtime implementation should add additive guards that detect at least:

- more than one canonical owner for the same emergency lifecycle responsibility;
- unauthorized regeneration of a valid existing `eventId`;
- direct persistence writes from resources designated as adapters/readers;
- compatibility bridges that can recursively rebroadcast without loop protection;
- historical runtime layers that regain duplicate ownership after consolidation;
- removal of required public compatibility surfaces without an approved migration;
- unbounded retry/polling patterns introduced by ownership cleanup.

Repository validation, Lua syntax checks, existing authority guards, medical-registry ownership checks, and all current required workflows must continue to pass.

## Implementation order

1. Re-audit then-current `main` and build the full emergency-network ownership matrix.
2. Identify canonical owner candidates and duplicate writers/emitters.
3. Add tests/guards before behavior changes where practical.
4. Convert one duplicate-owner path at a time into a compatibility adapter.
5. Validate exact-head CI after each focused PR.
6. Confirm no unique behavior or persistence path was lost.
7. Proceed to further repository-wide security/performance/docs/CI work only from the newest secured `main`.

## Out of scope without separate approval

- Deleting unique functionality.
- Dropping database tables or destructive migrations.
- Changing repository visibility.
- Modifying secrets or credentials.
- Changing licensing or ownership terms.
- Publishing or changing releases.
- Modifying branch protection or weakening required checks.
- Force-pushing `main` or rewriting repository history.

## Exit criteria

Phase 3G is ready for runtime implementation when the ownership matrix is complete, every duplicate authority has an identified canonical destination, compatibility obligations are documented, migration/recovery behavior is defined, and additive CI coverage exists for the highest-risk ownership regressions.
