# Phase 3E — Medical Core Consolidation Preparation

## Purpose

Phase 3E consolidates medical-state authority without removing unique gameplay behavior or prematurely depending on unmerged Phase 3B–3D runtime changes. This document is intentionally preparation-only and is based on secured `main` at `2c642c267e250ebd8c9028572cc06c26559c7893`.

The current `dpn-medical-core` resource contains a long-lived sequence of versioned modules and compatibility surfaces (`v8` through `v14` are present in the current tree), plus shared API contracts and administrative tooling around revive/stabilize/reset actions. Phase 3E must reduce duplicated authority while preserving behavior.

## Primary consolidation objective

Create one server-authoritative patient state model inside `dpn-medical-core` and make all versioned/legacy modules adapters or feature providers around that state rather than competing state owners.

The canonical model must own, at minimum:

- patient identity and current medical-state revision;
- consciousness / incapacitation state;
- vital-sign snapshot and derived severity;
- injuries, wounds, affected body parts, and bleeding state;
- treatments already applied and their effects;
- stabilization / revive / death transitions;
- transport / hospital handoff metadata where currently supported;
- audit/history entries needed by existing medical gameplay;
- correlation identifiers introduced by later emergency-network integration.

## Current-tree observations

The resource exposes a shared event API for state request/sync, damage reporting, and treatment actions. The tree also contains multiple version-specific client/server modules, including telemetry/snapshot and prediction/autonomous-plan functionality. Those modules represent unique capabilities that must not be deleted simply because authority is consolidated.

Administrative medical tooling exposes high-impact actions including revive, stabilize, full heal, and reset-medical operations. These must remain server-authorized and must mutate the same canonical patient model rather than bypassing it.

## Authority invariants

### 1. One canonical state owner

Exactly one server-side component may authoritatively mutate a patient's medical state.

No client payload may be trusted as the authoritative source for:

- target state revision;
- injury severity;
- treatment completion;
- revived/stabilized flags;
- provider authorization;
- emergency correlation identity.

Client reports may request or report observations, but the server validates and applies every authoritative transition.

### 2. Monotonic state revisions

Every accepted state mutation should increment a monotonically increasing revision or equivalent transition identifier. Consumers should reject stale snapshots when practical.

This is required to prevent older telemetry, UI responses, or delayed network events from overwriting a newer patient state.

### 3. Idempotent treatments

Retried or duplicated treatment requests must not apply a treatment twice when the action is logically single-use.

A treatment mutation should be identifiable using a stable request/action identifier where available, or by a server-generated transition token. Duplicate requests should return the previously accepted result instead of repeating side effects.

### 4. Explicit transition rules

Transitions such as `injured -> critical -> stabilized -> revived` must be validated server-side. Modules may recommend or calculate a transition but may not bypass the central transition policy.

### 5. No privilege regression

Admin tools, EMS tools, hospital tools, and future MDT/dispatch integration must preserve or strengthen existing server-side authorization. Consolidation must not create a generic event that allows an untrusted client to revive, heal, reset, or overwrite another player's medical state.

## Versioned-module strategy

Version-numbered files are not to be bulk-deleted.

Each module should be classified into one of four categories before runtime consolidation:

1. **Canonical-state logic** — logic that currently mutates patient state and should migrate behind the single authority.
2. **Read-model / telemetry** — snapshot, prediction, UI, or reporting logic that should consume canonical state.
3. **Feature provider** — unique mechanics such as prediction or autonomous plan generation that should remain available but publish results through defined interfaces.
4. **Compatibility adapter** — legacy event/export names retained to preserve existing integrations while forwarding into the new authority.

Only demonstrably duplicate implementation may be removed later, and only after a compatibility check proves that no unique event, export, command, treatment, telemetry surface, or gameplay behavior is lost.

## Shared API contract

Phase 3E runtime work should converge on a stable server API with operations conceptually equivalent to:

- `GetPatientState(target)`
- `GetPatientRevision(target)`
- `ReportDamage(source, target, report)`
- `ApplyTreatment(source, target, treatment)`
- `SetStabilized(source, target, context)`
- `RevivePatient(source, target, context)`
- `ResetMedicalState(source, target, context)`
- `GetMedicalHistory(target)`

Existing public exports/events should remain available as adapters unless a later explicit breaking-change approval is given.

## Validation requirements

Every authoritative mutation must validate:

- caller/source validity;
- target player validity;
- job/role/permission when required;
- payload type and field bounds;
- treatment identifier against a server-owned allowlist/definition;
- target state preconditions;
- rate/idempotency constraints;
- revision ordering when supplied;
- any emergency-correlation identifiers through the canonical emergency-network authority once Phase 3B is merged.

## Observability and audit

High-impact transitions should generate structured audit data including:

- target;
- acting source;
- action type;
- previous revision/state;
- resulting revision/state;
- treatment/reason identifier;
- correlation IDs when available;
- denied-action reason for rejected privileged requests.

Audit logging must avoid excessive per-frame/per-tick writes.

## Performance requirements

The canonical state layer must avoid:

- per-frame server work;
- full-player scans for single-patient mutations;
- repeated serialization of unchanged large snapshots;
- duplicate persistence writes for idempotent requests;
- unbounded in-memory histories.

Telemetry/read models may use cached snapshots keyed by patient revision. Persistence, if currently used by a path being consolidated, should be batched/debounced where behavior permits and must not silently weaken durability guarantees.

## Emergency-network integration boundary

Phase 3E does not implement Phase 3B–3D runtime dependencies while those PRs remain unmerged.

Once the emergency-correlation authority is on `main`, medical state should carry/reference canonical emergency identifiers without becoming the authority that creates or rebinds them. The Medical Core owns patient medical state; the Unified Emergency Network owns emergency correlation; dispatch owns dispatch-call lifecycle; MDT owns MDT case lifecycle.

## Compatibility preservation checklist

Before any later deletion or retirement of old medical-core code, verify all of the following against the repository tree:

- registered network events;
- server/client exports;
- commands;
- callbacks;
- NUI callbacks/messages;
- treatment definitions;
- injury/body-part mechanics;
- revive/stabilize behavior;
- telemetry/snapshots;
- prediction/plan functionality;
- database/persistence interactions;
- admin-tool integration;
- EMS/hospital integration;
- dispatch/emergency-network hooks;
- documentation references.

If a behavior is unique, preserve it or provide a compatibility adapter.

## Required CI regressions for implementation

Runtime Phase 3E should add focused automated checks that fail if:

1. more than one server path becomes an unguarded authoritative patient-state writer;
2. a privileged heal/revive/reset route becomes client-authoritative;
3. canonical state transitions can move backward from stale revisions;
4. duplicate treatment IDs can apply the same single-use treatment twice;
5. a compatibility event/export is removed without an explicit migration entry;
6. the existing MIB authorization regression check is removed or weakened;
7. Phase 3B/3C/3D checks already present on then-current `main` are dropped.

## Runtime implementation sequence after dependencies merge

1. Re-audit then-current `main`; do not reuse stale assumptions from this prep branch.
2. Inventory all medical state writers and public compatibility surfaces.
3. Introduce the canonical server state service behind existing interfaces.
4. Route one mutation family at a time through the service, beginning with damage/treatment and then stabilize/revive/reset.
5. Convert versioned modules to consumers/adapters/feature providers where appropriate.
6. Add idempotency and revision enforcement.
7. Add focused CI regression checks.
8. Exercise EMS, admin, hospital, dispatch, MDT, and emergency-network paths.
9. Remove only code proven to be duplicate and behavior-neutral, in a separate focused change if needed.

## Non-goals of this preparation PR

This preparation PR does **not**:

- alter runtime medical behavior;
- modify schemas or persistence;
- remove versioned modules;
- rename public events/exports;
- change authorization policy;
- change emergency/dispatch/MDT ownership;
- weaken CI;
- change releases, visibility, secrets, licensing/ownership terms, or branch protection.

It exists to define the safe consolidation boundary so the eventual Phase 3E implementation can be rebuilt from fresh `main` after its dependencies are merged.