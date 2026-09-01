# Phase 3E — Medical Core Consolidation Design

## Status

Design/preparation only. This document is intentionally implementation-neutral so it can be reviewed independently of Phase 3B–3D runtime changes and rebased without code conflict.

## Goal

Consolidate duplicate Medical Core lifecycle, physiology, patient-state, persistence, timer, export, and background-thread behavior while preserving every unique clinical capability and compatibility surface that remains in use.

## Current baseline

The medical suite already completed Phase 3A registry/lifecycle hardening. The current `[dpn-medical]` tree still contains `dpn-medical-core` alongside many specialized medical resources, so consolidation must be evidence-driven rather than version-driven. Older files must not be removed simply because they are old.

## Consolidation principles

1. Preserve unique gameplay and clinical behavior before reducing duplication.
2. Treat runtime identity, registration, and heartbeat ownership as already centralized from Phase 3A.
3. Consolidate one concern at a time: patient state, physiology, persistence, timers, exports, events, threads, and diagnostics.
4. Keep public exports/events compatible through adapters until downstream callers are proven migrated.
5. Prefer one authoritative state mutation path per patient-domain concern.
6. Prevent duplicate writes and duplicate recalculation without weakening persistence guarantees.
7. Make restart and disconnect cleanup explicit and testable.

## Required inventory

Before runtime changes, build a machine-readable inventory of all active `dpn-medical-core` server/client/shared files and classify each function/event/export/thread as one of:

- authoritative owner;
- unique feature;
- compatibility adapter;
- duplicated implementation;
- migration candidate;
- test/diagnostic-only surface.

The inventory must record callers before any duplicate surface is removed or redirected.

## Patient-state authority

Phase 3E should establish explicit authoritative owners for:

- core patient identity/state;
- injuries and trauma state;
- vitals and physiology inputs;
- treatment/care state;
- incapacitation/death state;
- persistence snapshots;
- transient runtime-only state.

Multiple layers may read these domains, but there should not be competing authoritative mutation paths for the same field without a documented merge rule.

## Physiology and recalculation

Audit repeated calculations and timers for vitals, bleeding, pain, oxygenation, consciousness, shock, treatment effects, and derived status. Consolidation should:

- avoid recalculating unchanged inputs unnecessarily;
- keep clinically meaningful update cadence;
- separate fast transient simulation from slower persistence writes;
- prevent two historical layers from applying the same physiological effect twice;
- preserve deterministic ordering where calculations depend on previous state.

## Persistence

Audit every write path for duplicate or overlapping persistence. The target model should:

- coalesce safe repeated writes;
- keep critical state durable;
- avoid writing unchanged snapshots when practical;
- make restart recovery explicit;
- distinguish durable records from transient caches;
- preserve existing schema compatibility unless a separately reviewed additive migration is required.

No destructive schema migration belongs in this preparation branch.

## Threads and timers

Inventory every long-running thread, timeout, and interval. For each, record:

- purpose;
- cadence;
- state touched;
- whether another layer performs equivalent work;
- cleanup behavior;
- restart behavior;
- performance risk.

Duplicate loops should be consolidated only after equivalence is proven.

## Player disconnect and resource restart

Phase 3E implementation should ensure:

- transient patient state is cleaned when no longer valid;
- durable state is flushed when appropriate;
- stale references are removed;
- reconnect does not duplicate timers or handlers;
- resource restart reconstructs safe authoritative state without replaying treatments or physiological effects twice.

## Exports and events

Build an explicit compatibility map for Medical Core exports and events. New canonical APIs may be introduced, but historical interfaces should delegate to them until callers are migrated and validated. No public surface should silently disappear.

## Diagnostics

Standardize Medical Core diagnostics around:

- one log prefix family;
- clear startup summary;
- duplicate-owner warnings;
- stale-state warnings;
- persistence failures;
- restart recovery outcomes;
- self-test results.

Debug noise should be reduced without hiding actionable failures.

## Validation requirements

Phase 3E implementation is not complete until CI/runtime testing proves:

- no duplicate lifecycle ownership regresses;
- no duplicate physiology effect is applied for the same tick/event;
- repeated state updates are idempotent where required;
- disconnect cleanup removes stale runtime state;
- restart recovery does not double-apply treatment/state transitions;
- public exports/events remain available or have verified compatibility adapters;
- manifests and Lua syntax remain valid;
- existing DPN Quality Gate checks remain at least as strict as before.

## Migration sequence

1. Inventory files/functions/events/exports/threads.
2. Trace callers and downstream dependencies.
3. Mark authoritative owners and unique features.
4. Add detection/tests for duplicate ownership and duplicate effects.
5. Introduce canonical internal APIs.
6. Route compatibility paths through canonical APIs.
7. Consolidate duplicate calculations and writes in small reviewed changes.
8. Add restart/disconnect recovery tests.
9. Measure runtime behavior and performance before removing any compatibility layer.
10. Remove only proven redundant code in a separate reviewed change.

## Non-goals for this design branch

- No runtime Medical Core behavior changes.
- No deletion of historical layers.
- No schema migration.
- No EMS or Medical Dispatch consolidation.
- No branch-protection, licensing, release, visibility, or secret changes.
