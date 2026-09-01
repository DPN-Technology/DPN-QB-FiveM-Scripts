# Phase 3C — Dispatch Ownership and Deduplication Design

## Status

Design/preparation only. This document is intentionally implementation-neutral so it can be reviewed independently of Phase 3B runtime changes and rebased without code conflict.

## Goal

Establish one authoritative dispatch-call owner across the unified emergency-services suite, prevent duplicate call creation, and preserve all existing integrations and unique resource behavior during migration.

## Current risk surface

The suite currently contains multiple resources capable of initiating or proxying dispatch work. At minimum, `dpn-le-operations` contains a `dispatchCall(data)` helper that calls the configured dispatch resource export `CreateDispatchCall`, while `dpn-emergency-network` maintains emergency-network call identifiers and records. This creates a risk that two upstream paths can describe the same real-world emergency as separate dispatch calls if ownership is not explicit.

## Ownership model

1. A single dispatch resource is the authoritative creator and state owner for dispatch calls.
2. Other resources may request dispatch creation, but must not mint competing authoritative dispatch identities.
3. A dispatch call must be linkable to the Phase 3B emergency correlation root when that contract is available.
4. Compatibility adapters may remain during migration, but must delegate to the authoritative owner.
5. Existing unique features, exports, notifications, MDT hooks, and department-specific behavior must be preserved unless separately proven redundant.

## Canonical creation contract

A dispatch creation request should include a normalized payload with:

- emergency correlation root/event identifier when available;
- stable dispatch call identifier assigned only by the owner;
- source resource resolved server-side;
- call type/code;
- priority;
- title/summary;
- location and coordinates;
- caller or reporting source metadata when permitted;
- department/service routing targets;
- timestamps generated or normalized by the server;
- optional medical, incident, and MDT linkage identifiers.

Client-supplied authoritative IDs must not be trusted as ownership proof.

## Deduplication strategy

Deduplication should be deterministic and conservative. The preferred matching order is:

1. Exact emergency correlation root match.
2. Exact already-linked dispatch call ID.
3. Explicit compatibility/migration alias previously registered by the server.
4. Time-bounded semantic fingerprint only when no canonical correlation ID exists.

A semantic fallback fingerprint may consider normalized call type, rounded coordinates/location bucket, source resource, department routing, and a short server-side time window. It must never merge clearly distinct incidents solely because they occur near each other.

## Idempotency

Repeated creation requests for the same canonical emergency root should return the existing authoritative dispatch call rather than create a second call. Replayed network events and duplicate integration callbacks must therefore be safe.

## Update ownership

Only the authoritative dispatch owner should mutate core dispatch state such as call status, primary ID, assignment set, closure state, and canonical timestamps. Department modules may request changes through explicit server exports/events and retain their unique side effects.

## Migration sequence

1. Inventory every dispatch creator, proxy, export, event, callback, and direct table mutation.
2. Classify each path as owner, adapter, consumer, or legacy compatibility surface.
3. Add tests/CI checks that detect multiple authoritative creators.
4. Introduce idempotent owner APIs while preserving legacy wrappers.
5. Route legacy creation paths through the owner.
6. Add correlation-aware deduplication after Phase 3B is merged and verified.
7. Validate MDT, law-enforcement, fire, EMS, and medical integrations.
8. Remove no compatibility path until equivalent behavior is proven and separately reviewed.

## Required validation

Phase 3C implementation is not complete until CI proves:

- there is one authoritative dispatch creator;
- repeated correlated requests are idempotent;
- uncorrelated distinct incidents remain distinct;
- client-controlled IDs cannot seize ownership;
- no existing public export/event disappears without an intentional compatibility adapter;
- Lua syntax and manifests remain valid;
- existing quality gates remain at least as strict as before.

## Initial audit finding

On the current `main` baseline, `dpn-le-operations/server/main.lua` contains a helper that delegates to `exports[Config.DispatchResource]:CreateDispatchCall(data, 0)`. `dpn-emergency-network/server/main.lua` also manages emergency-network call records/identifiers. Phase 3C implementation should begin by tracing all callers of these surfaces before changing behavior.

## Non-goals for this design branch

- No runtime dispatch behavior changes.
- No deletion of legacy or compatibility paths.
- No MDT mutation.
- No medical/EMS consolidation.
- No branch-protection, licensing, release, secret, or visibility changes.
