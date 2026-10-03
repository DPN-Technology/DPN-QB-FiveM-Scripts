# Phase 3G — Emergency Dispatch Ownership Coverage

Baseline: `main` commit `2c170fb4cf6d6a5a4e1ced69ec14122319aa5090`.

This document coordinates the Phase 3 emergency-network ownership cleanup.

## Ownership rule

`core/dpn-dispatch` is the canonical owner of the `dpn-dispatch:*` server namespace. Other emergency/medical resources may request dispatch behavior through an intentional bridge/router or integration event, but should not independently become a second canonical owner or fan the same logical event into multiple dispatch backends.

## Coverage matrix

| Surface | Evidence / behavior | Ownership classification | Phase 3G disposition |
| --- | --- | --- | --- |
| `core/dpn-dispatch/server/main.lua` | Owns canonical `dpn-dispatch:*` server/client behavior. | Canonical dispatch owner. | Preserve as the ownership target. |
| `dpn-digital-dispatch/server/main.lua` | Publishes an internal assignment notification into `dpn-dispatch:server:unitAssignedInternal`. | Explicit integration edge. | Preserve unless duplicate/payload evidence proves otherwise. |
| `dpn-medical-dispatch/server/compat_bridge.lua` | Routes to the first started configured resource; if none is started, selects one deterministic configured fallback owner. | Canonical medical compatibility router with single-owner fallback. | Hardened by PR #78; guard against fan-out regression. |
| `dpn-medical-dispatch/server/v9.lua` | Prefers `DPNMedicalDispatchCompatBridge`; bridge-unavailable fallback emits only `dpn-dispatch-system`. | Compatibility-routed publisher with one bounded historical fallback. | Integrated by PR #74; preserve and guard. |
| `dpn-medical-dispatch/server/v10.lua` | Prefers `DPNMedicalDispatchCompatBridge`; bridge-unavailable fallback emits only `dpn-dispatch-system`. | Compatibility-routed publisher with one bounded historical fallback. | Integrated by PR #74; preserve and guard. |
| `dpn-medical-dispatch/server/v11.lua` | Prefers `DPNMedicalDispatchCompatBridge`; bridge-unavailable fallback emits only `dpn-dispatch-system`. | Compatibility-routed publisher with one bounded historical fallback. | Integrated by PR #74; preserve and guard. |
| `dpn-medical-dispatch/server/v12.lua` | Prefers `DPNMedicalDispatchCompatBridge`; bridge-unavailable fallback emits only `dpn-dispatch-system`. | Compatibility-routed publisher with one bounded historical fallback. | Integrated by PR #74; preserve and guard. |
| `dpn-medical-dispatch/server/v13.lua` | Prefers the shared bridge; bridge-unavailable fallback selects the first valid configured resource and emits once. | Compatibility-routed publisher with configuration-driven single fallback owner. | Hardened by PR #78; preserve and guard. |
| `dpn-medical-dispatch/server/v14.lua` | Uses local `dpn-medical:v14:*` events; no direct external dispatch namespace is published. | Local-only medical dispatch layer. | No compatibility-router rewrite required without new evidence. |
| `dpn-medical-admin-tools/server/main.lua` | Exercises medical-to-dispatch health/test paths. | Diagnostic surface. | Retain as validation; runtime ownership claims require source evidence. |

## Guardrails

1. Start runtime slices from fresh `main`.
2. Prove the exact publisher, target event, and duplicate/ownership hazard before changing runtime code.
3. Prefer one compatibility/router boundary over per-version fan-out.
4. Preserve unique medical, EMS, law-enforcement, MDT, and dispatch behavior.
5. Preserve compatibility fallback only where required, with one deterministic owner per logical routing attempt.
6. Add deterministic repository checks for every ownership invariant.
7. Treat documentation as coordination evidence, not runtime proof.

## Phase 3G closeout criterion

Phase 3G medical-dispatch compatibility ownership is ready to close when current `main` confirms:

- v9-v13 select one active target or one historical fallback target;
- v14 remains local-only;
- the shared compatibility bridge cannot fan one logical fallback call across multiple configured dispatch namespaces;
- all relevant Quality Gate guards remain green;
- no newly discovered cross-resource publisher creates a second canonical dispatch owner.

Further security-authority work should proceed as separate focused hardening slices rather than being mixed into this compatibility-ownership boundary.
