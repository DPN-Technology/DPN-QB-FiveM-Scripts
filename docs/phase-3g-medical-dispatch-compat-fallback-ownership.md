# Phase 3G — Medical Dispatch Compatibility Fallback Ownership

Baseline: `main` at `76d3ae559d48f17ed1665fc2d75e34efa4076210`.

## Current state

`dpn-medical-dispatch/server/compat_bridge.lua` correctly selects the first configured dispatch resource whose FiveM resource state is `started` and returns immediately after routing the event. That prevents duplicate delivery when more than one supported dispatch resource is online.

The remaining edge case is the bridge's legacy fallback path. When none of the configured dispatch resources is started, the bridge currently emits the same compatibility event once for every configured resource name. With the default configuration this means both `dpn-dispatch-system:server:<event>` and `dpn-dispatch:server:<event>` are emitted before the bridge returns `false, 'legacy-fallback'`.

This preparation intentionally does not change that behavior yet. The historical fallback may be carrying compatibility assumptions outside the immediately visible resource state model, and Phase 3G must not remove unique behavior without proving those assumptions are unnecessary.

## Target ownership contract

A later runtime change may remove fallback fan-out only after the following contract is demonstrated:

1. Exactly one canonical compatibility target is selected for every routing attempt.
2. A started configured dispatch resource remains preferred, in configured priority order.
3. When no configured resource is started, the legacy fallback target is deterministic and documented rather than broadcast to multiple historical namespaces.
4. Existing event names and payload structures remain unchanged for the selected target.
5. The bridge continues returning an explicit success/fallback result that callers can observe.
6. Bridge statistics distinguish successful live-resource routing from fallback routing.
7. No historical layer, export, board, command surface, medical-call payload, or dispatch-call payload is removed as part of this ownership cleanup.

## Compatibility proof required before runtime change

Before reducing the fallback to one historical target, verify repository-wide that:

- no loaded resource depends exclusively on the non-selected fallback namespace while the corresponding dispatch resource is stopped;
- no external compatibility adapter documented in this repository requires both fallback events;
- configuration order is the accepted source of dispatch target priority;
- v9 through v13 callers continue using the shared bridge or an equivalent single-target compatibility path;
- the DPN Quality Gate has regression coverage preventing a return to unconditional multi-target fan-out.

If any of those checks cannot be proven, retain the current fallback behavior and document the dependency instead of deleting it.

## Regression acceptance criteria

The eventual runtime PR should be focused and should include an additive guard that fails if the shared bridge can route one compatibility call to more than one target in the same execution path. The guard should also verify that the configured-resource priority order, resource-state check, exported bridge API, statistics API, payload forwarding, and explicit fallback result remain intact.

The runtime PR must be created fresh from then-current `main`; it should not be stacked on the open v9/v10/v11/v12 cleanup PRs. No force push, history rewrite, CI weakening, visibility change, secret change, licensing/ownership change, release change, or branch-protection change is part of this work.
