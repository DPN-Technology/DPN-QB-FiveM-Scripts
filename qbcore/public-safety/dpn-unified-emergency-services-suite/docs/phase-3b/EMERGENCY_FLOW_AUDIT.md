# Phase 3B Emergency Flow Audit

Status: Preparatory audit — no runtime behavior changed

## Purpose

This audit maps the current emergency call creation and synchronization paths before Phase 3B introduces immutable emergency correlation IDs. The goal is to prevent duplicate 911, panic, medical, incident-command, and MDT records while preserving compatibility with existing DPN resources.

## Current canonical systems

### Core Dispatch

`core/dpn-dispatch` is the strongest candidate for canonical dispatch ownership. Its server `Dispatch.CreateCall` creates an in-memory numeric call ID, a generated `caseId`, call metadata, department routing, caller identity, coordinates, reports, MDT sync hooks, database persistence, Discord logging, and client broadcasts.

Current limitation: dispatch calls do not have a root immutable `eventId`, `sourceResource`, or a standard correlation object. This makes reliable deduplication across separate resources difficult.

### Digital Dispatch

`[dpn-lawenforcement]/dpn-digital-dispatch` owns a separate call creation path and exposes its own `/d911`, `/digitalpanic`, `/digitaldispatch`, and F9 workflows. It accepts both `dpn_dispatch:server:createCall` and `dpn-digital-dispatch:server:createCall` compatibility events.

This resource should remain available as a specialized digital operations layer, but Phase 3C should stop it from becoming a competing canonical owner of the same emergency record.

### Medical Dispatch

`[dpn-medical]/dpn-medical-dispatch` has an independent medical-call lifecycle and bridging configuration. Its existing bridge policy uses a `first_success` style model and can suppress follow-up events after an export has already accepted an incident. This is a useful compatibility pattern for the broader deduplication design.

### Incident Command

`[dpn-lawenforcement]/dpn-incident-command/server/main.lua` currently creates a Digital Dispatch call directly through `exports['dpn-digital-dispatch']:CreateDispatchCall(...)` when dispatch notification is requested.

Risk: an incident can acquire a new dispatch record instead of linking to the dispatch call that caused the incident. Phase 3B/3C should change this to correlation-first linking and only create a new dispatch call when no correlated call exists.

### Vehicle Computer

`[dpn-lawenforcement]/dpn-vehicle-computer` prefers Digital Dispatch when it is started and otherwise falls back to the compatibility event `dpn_dispatch:server:createCall`.

This demonstrates that `dpn_dispatch:server:createCall` is an active compatibility alias, not simply a typo. It should remain supported during migration but become a routed compatibility entry point into the canonical dispatch owner.

### MDT bridge

Core Dispatch documentation and configuration reference the following intended MDT exports:

- `SyncDispatchCall`
- `UpdateDispatchCall`
- `SyncDispatchReport`
- `UpdateDispatchReport`
- `CreateCaseFromDispatch`
- `AttachDispatchReport`

Repository code search on the current `main` branch found these names in Dispatch documentation/configuration but not as implemented `dpn-mdt` exports. Phase 3D should implement the missing MDT side with idempotent behavior.

## Duplicate-risk surfaces

### 911

Core Dispatch owns `/911`, while Digital Dispatch exposes `/d911`. Both can represent the same real-world emergency. A bridge or operator workflow can therefore create two unrelated calls without a common identity.

### Panic

Core Dispatch owns its panic flow. Digital Dispatch exposes `/digitalpanic`. Officer Safety and Vehicle Computer also contain panic workflows. Phase 3C must ensure one physical panic action produces one root emergency event and one canonical dispatch call, even if multiple companion resources receive notifications.

### Incident Command

Incident Command can independently create a Digital Dispatch call. This is a duplicate risk when Incident Command was opened from an existing dispatch call.

### Medical emergencies

Medical Dispatch creates its own medical call records and can bridge to CAD/dispatch. Without a root event ID, a medical distress event can become a medical call plus one or more unrelated dispatch records.

### MDT cases

Dispatch already attempts optional MDT synchronization. Because the documented MDT exports are not currently present in code search, case creation can fall back to generic events or remain incomplete. A later implementation must be idempotent so repeated sync attempts update the same case rather than creating duplicates.

## Correlation gaps confirmed

The current core Dispatch call structure includes `id` and `caseId` but not a root `eventId` or dedicated linked identifiers for medical, dispatch, incident-command, and MDT records.

The following identifiers are therefore required by Phase 3B:

- `eventId` — immutable root identity for the real-world emergency.
- `dispatchCallId` — canonical `dpn-dispatch` call identity.
- `medicalCallId` — Medical Dispatch identity when applicable.
- `incidentId` — Incident Command identity when applicable.
- `mdtCaseId` — MDT case identity when applicable.
- `sourceResource` — resource that originated the root event.
- `sourceType` — semantic origin such as `911`, `panic`, `medical_distress`, `incident`, `system`, or `admin_test`.
- `legacyIds` — compatibility identifiers retained during migration.

## Phase 3B implementation order

1. Add a shared correlation contract and ID generator without changing existing call ownership.
2. Extend core Dispatch call payloads to preserve or generate `eventId`.
3. Preserve `sourceResource` and `sourceType` at ingress.
4. Return `dispatchCallId` alongside the root event ID.
5. Add lookup helpers by `eventId` and legacy call ID.
6. Add bounded in-memory correlation indexes.
7. Persist correlation metadata with dispatch records where database support exists.
8. Update Digital Dispatch compatibility ingress to forward or preserve `eventId` instead of minting unrelated identities.
9. Update Medical Dispatch bridge payloads to preserve the same `eventId`.
10. Update Incident Command to attach `incidentId` to the existing correlation record.
11. Implement MDT exports and attach `mdtCaseId` idempotently.
12. Add server-side deduplication by `eventId` before heuristic time/location deduplication.
13. Add compatibility-window deduplication for legacy callers that cannot yet send an `eventId`.
14. Add audit/self-test coverage.
15. Only after compatibility is proven, deprecate duplicate command/event ownership.

## Safety constraints

- Do not remove `/d911`, `/digitalpanic`, compatibility events, or legacy bridges in Phase 3B.
- Do not delete Digital Dispatch.
- Do not make Incident Command dependent on MDT availability.
- Do not make Medical Dispatch dependent on law-enforcement resources.
- Do not allow a client to choose trusted correlation fields without server validation.
- Do not use player source IDs as durable emergency identifiers.
- Do not regenerate an `eventId` when a valid trusted server-side value already exists.
- Do not create a second canonical dispatch call for the same `eventId`.

## Confirmed preparatory findings

- Core Dispatch already centralizes rich call state and is the correct place to begin canonical correlation.
- Digital Dispatch intentionally accepts a legacy underscore event alias and currently owns a parallel call store.
- Incident Command directly creates Digital Dispatch calls.
- Vehicle Computer routes into Digital Dispatch first and uses the underscore compatibility event as fallback.
- Medical Dispatch already contains a first-success bridge concept that can inform safe migration.
- Dispatch expects MDT synchronization capabilities that still need implementation on the MDT side.

This document is preparatory only. Runtime migration should begin after Phase 3A is merged or otherwise explicitly rebased onto its hardened lifecycle foundation.