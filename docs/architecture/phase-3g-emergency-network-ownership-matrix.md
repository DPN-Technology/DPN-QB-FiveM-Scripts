# Phase 3G — Emergency Network Ownership Matrix

Fresh baseline: `main` at `f653cb59e6e59684a0a2bcda7d1fa08818280e13`.

This document begins the refreshed Phase 3G ownership-cleanup foundation with an additive inventory only. It does not retire historical layers, remove public compatibility surfaces, change persistence, or broaden authority.

## Canonical ownership

| Responsibility | Canonical owner | Current authority surface | Phase 3G rule |
|---|---|---|---|
| Root emergency correlation identity | emergency correlation layer | immutable `eventId` contract from Phase 3B | downstream resources preserve existing IDs and never regenerate a valid root ID |
| Generic dispatch call identity and deduplication | dispatch | Phase 3C correlation-first dispatch ownership | producer resources request dispatch work; they do not become canonical dispatch writers |
| MDT case/report persistence and linkage | MDT | Phase 3D MDT correlation bridge | MDT-specific records remain MDT-owned; external resources link through adapters |
| Canonical patient/clinical state | `dpn-medical-core` | `server/authority.lua` / `DPNMedicalAuthority` | dispatch/EMS may consume state but may not create a competing patient-state owner |
| Medical dispatch call authority | `dpn-medical-dispatch` | `server/authority.lua` / `DPNMedicalDispatchAuthority` | medical call creation/mutation routes through the canonical authority |
| Medical dispatch duplicate suppression | `dpn-medical-dispatch` | `server/dedup.lua` / `DPNMedicalDispatchDedup` | dedup caches remain bounded and keyed by stable correlation identity where available |
| EMS responder lifecycle validation | `dpn-medical-dispatch` | `server/responder_authority.lua` / `DPNMedicalResponderAuthority` | responder transitions remain server-authoritative and validated before mutation |
| Producer-specific gameplay state | originating police/fire/EMS/civilian resource | resource-local state | producers retain unique gameplay state but must not seize canonical emergency ownership |

## Non-negotiable invariants

1. Existing `eventId`, `medicalCallId`, `dispatchCallId`, `incidentId`, and `mdtCaseId` linkage must remain stable once assigned.
2. One logical emergency must not create multiple canonical dispatch identities merely because multiple compatibility paths observe it.
3. Public events, exports, callbacks, commands, data shapes, and optional integrations remain compatible unless a separately approved migration replaces them.
4. Historical files are treated as potentially unique until a capability inventory proves parity.
5. No database table, durable field, or historical record is deleted by this phase without separate approval.
6. Client-provided IDs, coordinates, role claims, or ownership claims never establish authority by themselves.
7. Retry, deduplication, and reconciliation state must be bounded and cleaned deterministically.
8. Existing CI remains additive; Phase 3G may strengthen checks but may not weaken or remove them.
9. Security hardening already integrated on current `main`, including hospital staff-proximity authority, remains preserved while ownership cleanup proceeds.

## Cleanup classification

Every emergency-network runtime path must be classified before ownership cleanup:

- `canonical-owner` — authoritative writer or lifecycle owner;
- `adapter` — compatibility surface forwarding to a canonical owner;
- `producer` — creates normalized requests while retaining only producer-specific gameplay state;
- `reader` — consumes canonical state without mutating ownership;
- `duplicate-candidate` — appears to overlap a canonical responsibility but cannot be retired until parity is proven;
- `unique` — behavior not duplicated elsewhere and therefore must remain;
- `unknown` — insufficient evidence; must remain loaded and unchanged.

No `duplicate-candidate` may be removed while any exported symbol, event, callback, persistence write, timer, notification, or downstream consumer is still unmapped.

## First runtime-safe Phase 3G slice

The first implementation step is CI-backed ownership drift detection. It verifies the already-integrated Phase 3B–3F canonical surfaces remain present and that historical numerical layers do not reclaim those explicit authority symbols.

This guard is intentionally conservative: it detects obvious authority drift without deleting, disabling, or rewriting existing gameplay layers.

## Later Phase 3G slices

After the ownership matrix is expanded with complete repository evidence, later focused PRs may:

1. map producer and compatibility entry points to canonical owners;
2. identify direct persistence writes that conflict with the canonical ownership model;
3. add loop prevention to compatibility bridges where needed;
4. add bounded restart/reconciliation behavior;
5. convert proven duplicate owners into thin adapters one path at a time;
6. retire a historical duplicate only after explicit parity proof and green exact-head CI.

Unique functionality must remain available throughout the migration.
