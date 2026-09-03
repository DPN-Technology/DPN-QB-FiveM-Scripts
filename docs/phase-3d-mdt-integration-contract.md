# Phase 3D — MDT Integration Contract

This document prepares Phase 3D MDT integration from secured `main` at `ee8a2d7a3542dcbf4457ee99c4956f19e16e7d4e` without introducing runtime changes or rebase debt.

## Objective

Phase 3D will integrate emergency-network records with MDT case/incident workflows while preserving server authority, correlation identity, compatibility surfaces, and unique gameplay behavior.

## Dependency boundary

Runtime Phase 3D must begin from then-current `main` only after the preceding emergency-correlation and dispatch-ownership phases are integrated. This preparation document is intentionally independent of unmerged Phase 3B/3C runtime code.

## Canonical correlation fields

The MDT integration layer must consume and preserve immutable correlation identifiers when present:

- `eventId` — root emergency event identity.
- `medicalCallId` — medical dispatch identity where applicable.
- `dispatchCallId` — canonical dispatch identity.
- `incidentId` — emergency-network incident identity.
- `mdtCaseId` — MDT-owned case identity.
- `sourceResource` — originating resource identity.

No downstream consumer may silently replace the root correlation identity with a newly generated unrelated identifier.

## MDT ownership

The MDT owns MDT case identifiers, MDT-specific persistence, officer-facing case metadata, report/citation links, and MDT lifecycle state. Dispatch remains the owner of dispatch-call identity and assignment state. Medical systems remain owners of clinical state. Cross-system synchronization must link records rather than transfer ownership implicitly.

## Server authority

All create/link/update operations must be validated server-side. Client-provided identifiers are references, never proof of authority. The server must validate:

1. caller identity and job/permission context;
2. existence and current state of the referenced record;
3. correlation compatibility;
4. allowed transition for the requested operation;
5. target ownership boundary before mutation.

Invalid or stale references must fail closed without creating orphaned duplicate records.

## Idempotent linking

Repeated delivery of the same emergency event must reuse the same MDT association when one already exists. Retries, reconnects, duplicate exports/events, and restart recovery must not create duplicate MDT cases for one canonical event unless an explicit user workflow intentionally creates a separate case.

## Compatibility and fallback

Existing exports, server events, callbacks, NUI contracts, commands, and resource-facing compatibility surfaces must remain available until replacement parity is proven. Fallback adapters may translate legacy payloads into the canonical contract, but must not create two independent write paths for the same record.

## Persistence

Persistence changes must be additive and migration-safe. Existing records must remain readable. Any new columns or tables must be nullable/default-safe during rollout and must not require destructive schema rewrites. Correlation writes should be atomic where supported and recoverable where not.

## Reconciliation

On resource restart or delayed dependency startup, the integration layer should reconcile linked records using immutable identifiers rather than timestamps or display labels. Reconciliation must be bounded and should avoid full-table scans during normal gameplay.

## Assignment and status propagation

MDT status displays may reflect dispatch or incident state, but the originating subsystem remains authoritative for its own lifecycle. Bidirectional propagation must use explicit transition rules and loop-prevention markers so one update cannot bounce indefinitely between resources.

## Medical data boundary

Clinical detail must remain owned by the medical stack. MDT integration should link permitted incident/patient references and operational summaries without turning MDT into a second clinical state store.

## Observability

Phase 3D runtime work should add structured logs/metrics for:

- new MDT link creation;
- existing-link reuse;
- rejected stale or unauthorized links;
- duplicate-prevention decisions;
- reconciliation repairs;
- dependency fallback usage.

Logs must avoid secrets and unnecessary sensitive player data.

## Performance requirements

Hot paths must avoid unbounded polling, repeated full-table scans, or synchronous fan-out across every emergency subsystem. Prefer event-driven updates, indexed lookups, bounded reconciliation, and cached dependency capability detection where appropriate.

## Failure behavior

If MDT is unavailable, emergency/dispatch/medical gameplay must continue according to existing behavior unless MDT is a documented hard dependency for that action. Deferred linkage may be queued in a bounded server-side structure when safe; it must never trust a client queue as authority.

## CI requirements

Phase 3D runtime implementation must add or extend automated guards that verify:

- canonical correlation identifiers are preserved;
- duplicate MDT creation is rejected/reused;
- unauthorized/stale client references fail closed;
- compatibility surfaces remain present;
- dependency fallback does not introduce a second write owner;
- repository validator and Lua syntax checks remain green.

CI additions must be additive and must not weaken existing checks.

## Non-goals

This preparation does not merge Phase 3B or Phase 3C, remove historical functionality, rewrite database history, alter licensing/ownership terms, change secrets, change repository visibility, modify releases, or change branch protection.

## Implementation gate

Before runtime Phase 3D begins, verify the exact current `main` commit and required workflows, then create a fresh focused branch from that exact commit. Do not rebase this preparation branch forward as a shortcut if doing so would create dependency ambiguity.
