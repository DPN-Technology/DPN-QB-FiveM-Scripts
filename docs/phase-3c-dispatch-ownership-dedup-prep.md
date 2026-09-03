# Phase 3C — Dispatch Ownership & Deduplication Preparation

## Baseline

This refreshed preparation branch is created directly from secured `main` at `ee8a2d7a3542dcbf4457ee99c4956f19e16e7d4e`.

Phase 3B emergency correlation is currently represented by PR #18 at exact head `f05e040b108cc3f9d78e10e3b453dbd47874ac25`; both required repository workflows are successful on that exact head. Phase 3C runtime implementation must not be stacked on that unmerged branch. This document therefore defines only the ownership, deduplication, compatibility, security, and validation contract that can be prepared independently from current `main`.

## Objective

Phase 3C will converge dispatch creation on one server-authoritative decision path while preserving every unique dispatch UI, agency behavior, MDT sink, law-enforcement producer, medical producer, compatibility API, notification path, and fallback behavior until parity is proven.

The implementation must prevent one logical emergency from becoming multiple canonical dispatch calls because the same payload crosses exports, events, integration examples, compatibility shims, or fallback paths.

## Current ownership surfaces requiring classification

The repository contains multiple dispatch-producing, dispatch-persisting, and dispatch-fan-out surfaces. Phase 3C must classify each one before runtime consolidation rather than treating every duplicate-looking API as redundant.

Focused surfaces include:

- `core/dpn-dispatch/`
- `core/dpn-unified-emergency-network/server/dispatch.lua`
- `core/dpn-mdt/server/main.lua`
- `core/dpn-mdt/integration_examples/`
- `[dpn-lawenforcement]/dpn-digital-dispatch/`
- `[dpn-lawenforcement]/dpn-officer-safety/server/main.lua`
- `[dpn-lawenforcement]/dpn-le-core/server/main.lua`
- `[dpn-medical]/dpn-medical-dispatch/`

Each surface must be assigned exactly one architectural role:

1. canonical dispatch creator,
2. compatibility adapter,
3. specialized producer,
4. persistence sink/read model,
5. notification/fan-out consumer,
6. assignment/ownership consumer,
7. UI/read-only presentation surface.

A resource may contain multiple roles internally, but each mutation path must have one explicit ownership classification.

## Phase 3C invariants

### 1. One canonical dispatch-call identity

For a correlated emergency, exactly one canonical `dispatchCallId` may exist. Downstream consumers must reuse that identity and must not silently mint another canonical dispatch identity.

When Phase 3B is merged, the immutable root `eventId` and its linked `dispatchCallId` become the primary deduplication authority for correlated emergencies.

### 2. Server authority

Clients may submit gameplay facts needed to request dispatch creation, but client-supplied `eventId`, `dispatchCallId`, source-resource identity, ownership state, or deduplication authority must never become trusted merely because it is present in a payload.

Canonical IDs, trusted origin metadata, and acceptance decisions must be produced or validated server-side.

### 3. Idempotent creation

Repeated delivery of the same canonical emergency must:

- reuse the existing dispatch record,
- update it only through an allowed monotonic/state-aware mutation path, or
- no-op safely.

It must not create a second canonical record.

### 4. No export-plus-event multiplication

Adapters that attempt an export and then fall back to an event must stop immediately after confirmed canonical acceptance. Fallback behavior may execute only when the preferred path was unavailable or explicitly rejected in a way that permits fallback.

A timeout, thrown export error, missing resource, or unsupported API may permit fallback. A successful canonical acceptance may not.

### 5. Persistence is not identity ownership

MDT or any other database sink may persist a dispatch representation without becoming the canonical dispatch identity authority. Existing persistence remains supported, but repeated correlated ingestion must resolve to the same canonical record.

### 6. Assignment ownership is separate from creation ownership

Unit assignment, acknowledgment, responding status, scene arrival, escalation, supervisor ownership, transfer, and closure must not create a new dispatch identity. Those operations mutate the existing canonical call under server-authoritative state rules.

### 7. Immutable correlation links

After a canonical dispatch call has been linked to an emergency correlation record, downstream resources must not rebind it to a different root event or replace the canonical link with a caller-supplied value.

Conflicting immutable-link attempts must fail closed and produce an auditable diagnostic.

### 8. Compatibility preservation

Existing public events, exports, aliases, resource-specific producer APIs, and user-facing workflows may remain as compatibility facades. They should route into the canonical authority rather than be deleted merely because another API is preferred.

No unique gameplay behavior may be removed as part of deduplication work.

### 9. Bounded legacy deduplication

Legacy callers that cannot yet provide Phase 3B correlation may temporarily use a server-derived bounded deduplication fingerprint. Such a key must:

- be generated server-side,
- use stable normalized inputs,
- have a bounded lifetime,
- avoid treating nearby but genuinely separate calls as duplicates,
- be observable for migration diagnostics,
- be explicitly temporary until the caller adopts canonical correlation.

### 10. Restart and replay safety

A resource restart, reconnect, retry, or persistence replay must not generate a second canonical dispatch call when the correlation can be recovered.

If the canonical authority is temporarily unavailable, producers must fail safely or use an explicitly documented compatibility fallback without multiplying calls once the authority returns.

## Security requirements

Runtime Phase 3C must include focused negative testing for:

- spoofed client-supplied canonical IDs,
- spoofed source-resource identity,
- duplicate event replay,
- conflicting immutable correlation links,
- unauthorized assignment or closure mutations,
- malformed payloads,
- stale revisions,
- unknown target resources,
- export failure followed by accidental duplicate fallback emission.

Mutation handlers must validate authority before persistence or fan-out.

## Performance requirements

Deduplication must not introduce unbounded scans over historical dispatch calls. Runtime implementation should prefer indexed lookup by canonical correlation/dispatch identity and bounded temporary legacy caches.

Hot paths must avoid repeated serialization, full-table scans, or N-times adapter fan-out when a canonical decision has already been made.

Any cache must have explicit eviction behavior and bounded memory growth.

## Observability requirements

Runtime Phase 3C should expose enough structured diagnostic information to distinguish:

- new canonical call accepted,
- duplicate delivery reused,
- fallback compatibility path used,
- immutable-link conflict rejected,
- unauthorized mutation rejected,
- stale update rejected,
- persistence sink failure,
- downstream notification failure.

Diagnostics must avoid leaking secrets or unnecessary personal/player data.

## Required CI regression coverage

Phase 3C runtime work must add additive checks covering at minimum:

- canonical dispatch ownership is singular,
- correlated `dispatchCallId` values are propagated instead of regenerated,
- duplicate canonical delivery is idempotent,
- successful export integration does not also emit fallback events,
- MDT correlated ingestion does not create duplicate canonical records,
- client-triggerable mutation paths cannot mint trusted canonical IDs,
- compatibility APIs remain available where currently supported,
- pre-existing Quality Gate checks remain enabled.

CI must not be weakened to make Phase 3C pass.

## Implementation order after Phase 3B merges

1. Re-read then-current `main` and verify the exact merged Phase 3B commit and workflows.
2. Build an exact producer/adapter/sink ownership map from that merged baseline.
3. Select the canonical dispatch creation authority.
4. Add canonical create-or-reuse behavior keyed by Phase 3B correlation.
5. Route one producer family at a time through the authority.
6. Make MDT ingestion idempotent.
7. Harden export/event fallback semantics.
8. Add regression checks before retiring any duplicated internal path.
9. Preserve compatibility facades until call-site migration and parity are proven.
10. Only consider removing truly redundant internals in a separate reviewed change after evidence proves no unique behavior is lost.

## Non-goals for this preparation branch

This branch intentionally performs no runtime dispatch changes, no database migration, no resource deletion, no Phase 3B code copy/cherry-pick, no MDT ownership change, no compatibility removal, no workflow weakening, and no release/visibility/secret/licensing/ownership/branch-protection changes.

It is safe to review independently and can be superseded cleanly by runtime Phase 3C work built from then-current `main` after Phase 3B integration.