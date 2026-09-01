# Phase 3C — Dispatch Surface Inventory

Status: audit/preparation only. This inventory is derived from the current `main` baseline and does not change runtime behavior.

## Purpose

Phase 3C must establish one authoritative dispatch-call owner without removing compatibility integrations or unique behavior. This inventory records dispatch creation, proxy, persistence, consumer, and bridge surfaces that must be reviewed before runtime consolidation.

## Confirmed dispatch creation/proxy surfaces

### `core/dpn-dispatch`

`core/dpn-dispatch/server/main.lua` is a primary candidate for authoritative dispatch state ownership. Phase 3C implementation must verify its call lifecycle, exports, server events, reports, unit assignment, closure flow, persistence ownership, and outbound MDT integration before changing ownership semantics.

### `core/dpn-mdt`

`core/dpn-mdt/server/main.lua` contains a `createDispatchCall` path that inserts into `dpn_mdt_dispatch_calls`. This is a separate dispatch-shaped persistence surface and must be treated as an MDT mirror/consumer unless a later review proves it is intended to be the canonical dispatch owner.

The MDT documentation exposes `CreateDispatchCall(callData)` and existing integration examples call this export from dispatch/emergency-network bridges. Phase 3C and Phase 3D must preserve those integration contracts while preventing the MDT from accidentally becoming a competing authoritative call creator.

### `dpn-le-core`

`[dpn-lawenforcement]/dpn-le-core/server/main.lua` contains a `createDispatchCall(data, sourceId)` helper which delegates into the configured dispatch resource when dispatch is started. This should remain a compatibility/request adapter rather than an authoritative ID/state owner.

### `dpn-officer-safety`

`[dpn-lawenforcement]/dpn-officer-safety/server/main.lua` contains a `createDispatchCall(alert)` helper which calls `CreateDispatchCall` on its configured dispatch integration. Officer-down/panic behavior is unique functionality and must be preserved while routing creation through the single authoritative owner.

### `dpn-digital-dispatch`

`[dpn-lawenforcement]/dpn-digital-dispatch/server/main.lua` exposes its own dispatch server events including self-assignment and call closure behavior, while its README documents a `CreateDispatchCall` export. This resource requires explicit classification as owner, adapter, specialized view, or legacy compatibility layer before runtime consolidation.

### `dpn-medical-dispatch`

`[dpn-medical]/dpn-medical-dispatch/shared/config.lua` contains integration fallback configuration for multiple dispatch resources and exports including `CreateCall`, `CreateDispatchCall`, `CreateIncident`, and related names. It already supports `first_success` behavior and can suppress event emission after a successful export, which is an important existing duplicate-prevention behavior that must not be weakened.

`[dpn-medical]/dpn-medical-dispatch/server/main.lua` receives client distress events and participates in the medical-call creation path. Phase 3C/3F must keep medical dispatch functionality while ensuring only the selected dispatch owner mints authoritative dispatch IDs.

### `dpn-smart-city`

`[dpn-lawenforcement]/dpn-smart-city/config.lua` enables dispatch call creation, and its server implementation is another integration surface that must be classified during the ownership migration.

### Unified Emergency Network

`core/dpn-unified-emergency-network/server/dispatch.lua` receives/broadcasts emergency incident information. Existing MDT integration examples also bridge unified emergency-network incidents into `dpn-mdt:CreateDispatchCall`. Phase 3C must avoid allowing emergency-network broadcast/bridge code to become a second dispatch authority.

## MDT bridge surfaces

`core/dpn-mdt/integration_examples/dpn-dispatch.lua` subscribes to `dpn-dispatch:server:NewCall` and sends the resulting call into MDT storage through `exports['dpn-mdt']:CreateDispatchCall(...)`.

`core/dpn-mdt/integration_examples/unified_emergency_network.lua` listens for unified emergency-network incidents and creates corresponding MDT dispatch records.

`core/dpn-mdt/client/main.lua` listens for `dpn-dispatch:client:SendCallToMDT` and forwards updates into the MDT UI.

These are integration consumers/mirrors and should not independently determine canonical dispatch ownership.

## Preliminary ownership classification

| Surface | Preliminary role | Phase 3C requirement |
| --- | --- | --- |
| `core/dpn-dispatch` | Authoritative-owner candidate | Verify lifecycle, persistence, exports/events, ID authority, report/unit state |
| `core/dpn-mdt` | Mirror/persistence consumer | Keep MDT records synchronized but non-authoritative for dispatch identity |
| `dpn-le-core` | Adapter/request producer | Delegate to canonical owner and preserve public compatibility |
| `dpn-officer-safety` | Specialized producer | Preserve panic/officer-down behavior and delegate canonical creation |
| `dpn-digital-dispatch` | Owner/legacy-specialized candidate requiring review | Classify before changing any behavior; preserve assignment/closure functionality |
| `dpn-medical-dispatch` | Medical producer/integration adapter | Preserve first-success duplicate prevention and medical-specific behavior |
| `dpn-smart-city` | Producer/integration adapter | Delegate creation after ownership is finalized |
| Unified Emergency Network | Incident authority/bridge, not presumed dispatch owner | Correlate incidents to dispatch calls without minting competing dispatch authority |

## Required runtime audit before implementation

1. Enumerate every server export that creates, modifies, assigns, closes, deletes, or retrieves dispatch calls.
2. Enumerate every server `RegisterNetEvent` that can mutate dispatch state and verify authorization/source validation.
3. Identify every database table used for dispatch-shaped state and classify canonical state versus mirrors/history.
4. Identify all ID-generation paths and eliminate competing authoritative IDs only after compatibility equivalence is proven.
5. Trace all `TriggerEvent`/`TriggerClientEvent` dispatch fan-out so notifications, MDT UI updates, officer safety, medical dispatch, fire/EMS, and department-specific behavior are retained.
6. Preserve the medical dispatch `first_success`/`emitEventsAfterExport` duplicate-suppression behavior or provide demonstrably equivalent protection.
7. Add correlation-first idempotency only after the Phase 3B emergency-correlation contract is merged and verified on refreshed `main`.
8. Add CI that fails if more than one resource is classified as an authoritative dispatch-call creator after migration.

## Safety boundary

This document is intentionally read-only architecture preparation. It does not modify Lua runtime code, database schema, manifests, exports, events, licensing, repository settings, or compatibility behavior. No resource should be deleted or demoted until its unique behavior and public integration contract are fully inventoried and equivalence is tested.