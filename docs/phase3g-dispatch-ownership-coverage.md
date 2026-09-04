# Phase 3G — Emergency Dispatch Ownership Coverage

Baseline: `main` commit `76d3ae559d48f17ed1665fc2d75e34efa4076210`.

This document is a proof/coordination artifact for the Phase 3 emergency-network ownership cleanup. It does not change runtime behavior. Its purpose is to keep the remaining dispatch consolidation work focused, prevent duplicate compatibility patches, and make it clear which current-main publishers still cross a dispatch ownership boundary.

## Ownership rule

`core/dpn-dispatch` is the canonical owner of the `dpn-dispatch:*` server namespace. Other emergency/medical resources may request dispatch behavior through an intentional bridge/router or integration event, but should not independently become a second canonical owner or fan the same logical event into multiple dispatch backends.

## Current-main coverage matrix

| Surface | Current-main evidence | Ownership classification | Phase 3G disposition |
| --- | --- | --- | --- |
| `core/dpn-dispatch/server/main.lua` | Implements and emits `dpn-dispatch:*` server/client events, including the panic path. | Canonical dispatch owner. | Preserve as the ownership target; do not duplicate its namespace in satellite resources. |
| `dpn-digital-dispatch/server/main.lua` | Publishes an internal assignment notification into `dpn-dispatch:server:unitAssignedInternal`. | Explicit integration edge into canonical dispatch. | Keep under ownership review, but do not rewrite without evidence of duplicate handling or incompatible payload semantics. |
| `dpn-medical-dispatch/server/v9.lua` | Directly emits `dpn-dispatch-system:server:medicalEscalation` for a breached medical SLA. | Legacy direct external publisher. | Covered by the active compatibility/single-route cleanup stream; avoid a second overlapping patch. |
| `dpn-medical-dispatch/server/v10.lua` | Directly emits `dpn-dispatch-system:server:medicalCommandEscalation`. | Legacy direct external publisher. | Covered by the active compatibility/single-route cleanup stream; avoid a second overlapping patch. |
| `dpn-medical-dispatch/server/v11.lua` | Uses the medical compatibility bridge when available, with direct dispatch fallback behavior. | Compatibility-routed publisher with legacy fallback. | Existing Phase 3G routing work owns this slice; do not duplicate it from another branch. |
| `dpn-medical-dispatch/server/v12.lua` | Uses the medical compatibility bridge when available, with direct dispatch fallback behavior. | Compatibility-routed publisher with legacy fallback. | Existing Phase 3G routing work owns this slice; do not duplicate it from another branch. |
| `dpn-medical-dispatch/server/v13.lua` | Uses a router when available and retains legacy direct fallback to both dispatch namespaces. | Single-route migration surface with explicit legacy fallback. | Current main already contains a dedicated v13 single-route checker; treat further runtime edits as evidence-driven follow-up only. |
| `dpn-medical-dispatch/server/v14.lua` | Uses the local `dpn-medical:v14:*` namespace and no direct `dpn-dispatch-system` / `dpn-dispatch` publication was found in the Phase 3G v14 proof audit. | Local-only medical dispatch layer. | No compatibility-router rewrite required. Preserve unless new concrete cross-namespace evidence appears. |
| `dpn-medical-admin-tools/server/main.lua` | Describes health/test operations that exercise the medical-to-dispatch bridge. | Diagnostic/verification surface, not canonical dispatch ownership by description alone. | Retain as a validation surface; any runtime ownership claim must be based on the executed test path, not the label text. |

## Version boundary

Repository search on this baseline finds Medical Dispatch server versions through `v14.lua`; no `dpn-medical` `server/v15.lua` result was found. Phase 3G should therefore not invent a v15 migration task. The next runtime cleanup must come from a concrete uncovered publisher, duplicate consumer, payload mismatch, or fallback path on current main.

## Guardrails for remaining Phase 3G work

1. Start every runtime slice from fresh `main`; do not stack it on another open compatibility PR unless the dependency is intentional and documented.
2. Prove the exact publisher, target event, and duplicate/ownership hazard before changing a runtime file.
3. Prefer one compatibility/router boundary over fan-out from each versioned medical file.
4. Preserve unique medical, EMS, law-enforcement, MDT, and dispatch behavior; consolidation must not mean feature deletion.
5. Keep legacy fallback only where required for compatibility and verify it cannot double-publish the same logical event when the router succeeds.
6. Add or extend deterministic repository checks for every ownership invariant introduced by a runtime cleanup.
7. Never use a documentation classification as proof that an event is safe; source/runtime evidence remains authoritative.

## Next evidence-driven targets

The remaining audit should search current main for direct `TriggerEvent`/`TriggerClientEvent` publication into dispatch namespaces outside the canonical owner and already-tracked medical version files. High-value review surfaces include law-enforcement digital dispatch integration, MDT/dispatch synchronization, EMS/medical bridge code, and diagnostic test paths. A new runtime PR is warranted only when that search identifies an ownership conflict not already covered by an open focused PR.

## Completion criterion

Phase 3G dispatch ownership cleanup is ready to close when every cross-resource dispatch publisher on current main is classified as one of:

- canonical owner behavior;
- a deliberate single integration/bridge edge with a defined payload contract;
- a compatibility fallback proven not to double-publish; or
- an obsolete duplicate path removed only after its unique behavior is preserved elsewhere and regression checks prove the consolidation.
