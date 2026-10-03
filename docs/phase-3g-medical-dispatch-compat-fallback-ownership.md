# Phase 3G — Medical Dispatch Compatibility Fallback Ownership

Baseline: `main` at `71c3f27dab3a9311d7482654f801277ea7735ae3`.

## Current state

PR #74 is integrated into current `main`. Medical Dispatch v9 through v12 now prefer `DPNMedicalDispatchCompatBridge.Route(...)` and retain one bounded direct historical fallback to the `dpn-dispatch-system` namespace when the shared bridge is unavailable.

Two fallback-ownership surfaces remain distinct:

1. `dpn-medical-dispatch/server/compat_bridge.lua` selects the first configured dispatch resource whose FiveM resource state is `started` and returns immediately after live routing. When no configured resource is started, however, the bridge still emits the compatibility event once for every configured historical resource name before returning `false, 'legacy-fallback'`.
2. `dpn-medical-dispatch/server/v13.lua` uses the shared bridge when available, but its direct bridge-unavailable fallback still emits both `dpn-dispatch-system:server:<event>` and `dpn-dispatch:server:<event>`.

The fallback behavior is preserved for compatibility until repository-wide evidence supports a single deterministic historical owner.

## Target ownership contract

A later runtime change may reduce fallback fan-out only after all of the following are demonstrated:

1. Exactly one compatibility target is selected for every logical routing attempt.
2. A started configured dispatch resource remains preferred in configured priority order.
3. When no configured resource is started, the historical fallback target is deterministic and documented rather than broadcast to multiple namespaces.
4. Existing event names and payload structures remain unchanged for the selected target.
5. The bridge continues returning an explicit success/fallback result that callers can observe.
6. Bridge statistics distinguish successful live-resource routing from fallback routing.
7. No historical layer, export, board, command surface, medical-call payload, or dispatch-call payload is removed as part of this ownership cleanup.
8. v9 through v13 preserve their unique medical-dispatch behavior while sharing one ownership rule for compatibility routing.

## Completed remediation

PR #74 consolidated the v9-v12 compatibility-routing work and added dedicated v9, v10, v11, and v12 regression guards to the DPN Quality Gate. Those layers no longer carry the previous two-name direct fallback pattern.

## Compatibility proof required before the next runtime change

Before reducing the remaining fallback fan-out, verify repository-wide that:

- no loaded resource depends exclusively on the non-selected historical fallback namespace while the corresponding dispatch resource is stopped;
- no external compatibility adapter documented in this repository requires both fallback events;
- configuration order is the accepted source of dispatch target priority;
- v13 can move to the same deterministic fallback ownership rule without changing payloads, boards, exports, or escalation behavior;
- the shared bridge can preserve its statistics and explicit return contract with one fallback owner;
- the DPN Quality Gate gains regression coverage preventing a return to unconditional multi-target fallback fan-out.

If any of those checks cannot be proven, retain the current fallback behavior and document the dependency instead of deleting it.

## Regression acceptance criteria

The eventual runtime PR should fail if one logical compatibility call can target more than one historical dispatch namespace in the same fallback execution path. The guard should also verify configured-resource priority, resource-state checks, exported bridge APIs, statistics, payload forwarding, explicit fallback results, and the existing v9-v13 medical-dispatch surfaces.

No force push, history rewrite, CI weakening, visibility change, secret change, licensing/ownership change, release change, or branch-protection change is part of this work.
