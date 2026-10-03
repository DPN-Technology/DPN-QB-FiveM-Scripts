# Phase 3G — Medical Dispatch Compatibility Fallback Ownership

Baseline: `main` at `6bea5b82dd09764584e9e6ea9664c23a15b580e4`.

## Current state

`dpn-medical-dispatch/server/compat_bridge.lua` selects the first configured dispatch resource whose FiveM resource state is `started` and returns immediately after routing the event. That prevents duplicate live delivery when more than one supported dispatch resource is online.

The remaining edge case is the bridge's legacy fallback path. When none of the configured dispatch resources is started, the bridge still emits the same compatibility event once for every configured resource name. With the default configuration this means both `dpn-dispatch-system:server:<event>` and `dpn-dispatch:server:<event>` are emitted before the bridge returns `false, 'legacy-fallback'`.

This document intentionally does not change that behavior. The fallback may still carry compatibility assumptions that require repository-wide proof before reduction.

## Target ownership contract

A later runtime change may remove fallback fan-out only after all of the following are demonstrated:

1. Exactly one canonical compatibility target is selected for every routing attempt.
2. A started configured dispatch resource remains preferred in configured priority order.
3. When no configured resource is started, the legacy fallback target is deterministic and documented rather than broadcast to multiple historical namespaces.
4. Existing event names and payload structures remain unchanged for the selected target.
5. The bridge continues returning an explicit success/fallback result that callers can observe.
6. Bridge statistics distinguish successful live-resource routing from fallback routing.
7. No historical layer, export, board, command surface, medical-call payload, or dispatch-call payload is removed as part of this ownership cleanup.

## Current remediation relationship

PR #74 refreshes the stale v9-v12 compatibility-routing work from current `main`. It does not change the shared bridge fallback policy itself. The shared fallback remains a separate evidence-gated change.

## Compatibility proof required before runtime change

Before reducing the fallback to one historical target, verify repository-wide that:

- no loaded resource depends exclusively on the non-selected fallback namespace while the corresponding dispatch resource is stopped;
- no external compatibility adapter documented in this repository requires both fallback events;
- configuration order is the accepted source of dispatch target priority;
- v9 through v13 callers use the shared bridge or an equivalent single-target compatibility path;
- the DPN Quality Gate has regression coverage preventing a return to unconditional multi-target fan-out.

If any of those checks cannot be proven, retain the current fallback behavior and document the dependency instead of deleting it.

## Regression acceptance criteria

The eventual runtime PR should be focused and should include an additive guard that fails if the shared bridge can route one compatibility call to more than one target in the same execution path. The guard should also verify configured-resource priority order, resource-state checks, exported bridge APIs, statistics, payload forwarding, and explicit fallback results.

No force push, history rewrite, CI weakening, visibility change, secret change, licensing/ownership change, release change, or branch-protection change is part of this work.
