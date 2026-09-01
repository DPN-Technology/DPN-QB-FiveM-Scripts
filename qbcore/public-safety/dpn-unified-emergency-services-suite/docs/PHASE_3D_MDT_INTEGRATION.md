# Phase 3D — MDT Integration Design

## Status

Design/preparation only. This document is intentionally independent of unmerged Phase 3B/3C runtime changes so it can be reviewed without introducing code-level rebase debt.

## Goal

Define a safe, idempotent, correlation-aware integration between dispatch, incident records, reports, and MDT case state while preserving existing MDT behavior and access controls.

## Canonical bridge surface

The implementation phase should expose explicit server-side bridge operations equivalent to:

- `SyncDispatchCall`
- `UpdateDispatchCall`
- `SyncDispatchReport`
- `UpdateDispatchReport`
- `CreateCaseFromDispatch`
- `AttachDispatchReport`

Each operation must be idempotent, permission-checked, payload-validated, and safe to retry after a resource restart or temporary dependency outage.

## Identity model

When Phase 3B is available, MDT records should retain the emergency correlation root `eventId` and link to `dispatchCallId`, `incidentId`, and `mdtCaseId` as applicable. No client-provided identifier should be accepted as ownership proof without server-side validation.

## Idempotency requirements

Repeated delivery of the same dispatch call or report must update or return the existing MDT record rather than create a duplicate. Case creation from dispatch must therefore use stable server-side linkage before considering fallback matching.

## ACL and trust boundaries

All bridge operations must enforce server-side authorization. The implementation audit should identify every client-triggerable MDT mutation path and verify that privileged case/report operations cannot be executed solely because a client supplies a job, role, case ID, or dispatch ID.

## Payload validation

Validate at minimum:

- identifier format and length;
- source resource where relevant;
- caller/player source where relevant;
- report title/body lengths;
- coordinates and numeric ranges;
- allowed status/state transitions;
- department and unit routing values;
- nested table shape;
- optional attachment metadata.

Malformed payloads should fail closed with useful server logs and no partial writes.

## Retry and recovery model

Bridge operations should be safe across:

- MDT restart;
- dispatch restart;
- emergency-network restart;
- out-of-order dispatch/report delivery;
- duplicate callbacks;
- delayed report attachment;
- temporary database failure.

Where durable retry queues are introduced, they must be bounded, observable, and avoid infinite retry loops.

## Audit logging

Record meaningful bridge actions including operation type, server-resolved source, correlation identifiers, target case/report identifiers, result, and conflict reason when an idempotency or immutable-link check rejects an operation. Do not log sensitive free-form report content unnecessarily.

## Database expectations

Any schema changes should be additive and idempotent. The implementation phase should review indexing for correlation and dispatch linkage fields, duplicate prevention constraints where safe, and query behavior for active-call synchronization.

## Migration sequence

1. Inventory existing MDT exports, server events, callbacks, case creators, dispatch bridges, and report attachment paths.
2. Classify each as authoritative mutation, adapter, consumer, or legacy compatibility path.
3. Add server-side bridge helpers without removing existing public surfaces.
4. Route legacy dispatch/MDT paths through the idempotent bridge where behavior is equivalent.
5. Add correlation linkage after Phase 3B is merged and verified.
6. Add duplicate-case and duplicate-report tests.
7. Validate ACL behavior and malformed payload rejection.
8. Test restart/recovery and out-of-order delivery.
9. Remove no compatibility surface until replacement behavior is proven.

## Required validation

Phase 3D implementation is not complete until CI/runtime tests demonstrate:

- repeated sync calls are idempotent;
- a dispatch call cannot create multiple MDT cases accidentally;
- a report cannot attach repeatedly as separate records;
- unauthorized mutation attempts are rejected server-side;
- malformed payloads fail without partial persistence;
- retry after dependency restart converges to one correct state;
- existing MDT public interfaces remain compatible or have explicit adapters;
- existing repository, manifest, Lua syntax, and security checks remain green.

## Non-goals for this design branch

- No runtime MDT mutation changes.
- No database migration.
- No removal of legacy exports/events.
- No dispatch ownership changes.
- No medical/EMS consolidation.
- No branch-protection, release, licensing, visibility, or secret changes.
