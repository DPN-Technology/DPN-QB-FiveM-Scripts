# Phase 3G — Emergency Dispatch Ownership Coverage

Baseline: `main` commit `6bea5b82dd09764584e9e6ea9664c23a15b580e4`.

This document coordinates the Phase 3 emergency-network ownership cleanup. It does not change runtime behavior.

## Ownership rule

`core/dpn-dispatch` is the canonical owner of the `dpn-dispatch:*` server namespace. Other emergency/medical resources may request dispatch behavior through an intentional bridge/router or integration event, but should not independently become a second canonical owner or fan the same logical event into multiple dispatch backends.

## Current-main coverage matrix

| Surface | Current-main evidence | Ownership classification | Phase 3G disposition |
| --- | --- | --- | --- |
| `core/dpn-dispatch/server/main.lua` | Owns canonical `dpn-dispatch:*` server/client behavior. | Canonical dispatch owner. | Preserve as the ownership target. |
| `dpn-digital-dispatch/server/main.lua` | Publishes an internal assignment notification into `dpn-dispatch:server:unitAssignedInternal`. | Explicit integration edge. | Keep under ownership review; change only with duplicate/payload evidence. |
| `dpn-medical-dispatch/server/v9.lua` | Current `main` still directly emits legacy `dpn-dispatch-system` events. | Legacy direct external publisher. | Current-main remediation is consolidated in PR #74. |
| `dpn-medical-dispatch/server/v10.lua` | Current `main` still directly emits legacy `dpn-dispatch-system` events. | Legacy direct external publisher. | Current-main remediation is consolidated in PR #74. |
| `dpn-medical-dispatch/server/v11.lua` | Uses the medical compatibility bridge with two-name legacy fallback. | Compatibility-routed publisher with fallback fan-out. | Current-main remediation is consolidated in PR #74. |
| `dpn-medical-dispatch/server/v12.lua` | Uses the medical compatibility bridge with two-name legacy fallback. | Compatibility-routed publisher with fallback fan-out. | Current-main remediation is consolidated in PR #74. |
| `dpn-medical-dispatch/server/v13.lua` | Uses compatibility routing and has dedicated Quality Gate coverage. | Single-route migration surface. | Evidence-driven follow-up only. |
| `dpn-medical-dispatch/server/v14.lua` | Uses local `dpn-medical:v14:*` events; no direct external dispatch namespace was found on current `main`. | Local-only medical dispatch layer. | No compatibility-router rewrite required. |
| `dpn-medical-admin-tools/server/main.lua` | Exercises medical-to-dispatch health/test paths. | Diagnostic surface. | Retain as validation; runtime ownership claims require source evidence. |

## Guardrails

1. Start runtime slices from fresh `main`.
2. Prove the exact publisher, target event, and duplicate/ownership hazard before changing runtime code.
3. Prefer one compatibility/router boundary over per-version fan-out.
4. Preserve unique medical, EMS, law-enforcement, MDT, and dispatch behavior.
5. Keep legacy fallback only where compatibility requires it and verify it cannot double-publish when the router succeeds.
6. Add deterministic repository checks for every ownership invariant.
7. Treat documentation as coordination evidence, not runtime proof.

## Completion criterion

Phase 3G is ready to close when every cross-resource dispatch publisher on current `main` is classified as canonical ownership, a deliberate single integration edge, a compatibility fallback proven not to double-publish, or an obsolete duplicate removed only after its unique behavior is preserved and regression checks prove the consolidation.
