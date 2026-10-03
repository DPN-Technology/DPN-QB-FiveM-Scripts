# Phase 3G — Medical Dispatch Compatibility Fallback Ownership

Baseline: `main` at `2c170fb4cf6d6a5a4e1ced69ec14122319aa5090`.

## Ownership decision

PR #78 establishes one deterministic historical fallback owner for the remaining Phase 3G compatibility paths.

The ownership rule is now:

1. When a configured dispatch resource is `started`, `DPNMedicalDispatchCompatBridge.Route(...)` selects the first started resource in `Config.ExternalDispatch.resources` and returns immediately after one emit.
2. When no configured dispatch resource is started, the shared bridge emits to exactly one fallback resource: the first valid configured resource.
3. When v13 cannot access the shared bridge object, v13 applies the same configuration-order fallback rule and emits exactly once.
4. The default configuration remains `{ 'dpn-dispatch-system', 'dpn-dispatch' }`, so the deterministic historical fallback is `dpn-dispatch-system` unless the operator intentionally changes resource priority.
5. v9 through v12 retain their previously integrated bounded `dpn-dispatch-system` bridge-unavailable fallback.

## Compatibility evidence

Repository-wide source search on the baseline found no in-repo consumers for the v13 `medicalContinuumCall` or `medicalSurge` legacy dispatch events outside the v13 runtime and its regression checker.

The repository already defines dispatch compatibility priority through `Config.ExternalDispatch.resources`, with `dpn-dispatch-system` first. Using that order for fallback ownership therefore aligns fallback routing with the existing active-resource selection model instead of inventing a second priority system.

## Preserved surfaces

The Phase 3G fallback-owner change preserves:

- compatibility event names for the selected target;
- payload objects passed by v9 through v13;
- `RouteMedicalDispatchCompatEvent`;
- `GetMedicalDispatchCompatBridgeStats`;
- the existing `fallbackBroadcasts` statistic for compatibility;
- the existing `lastResource` live-route semantic;
- the `false, 'legacy-fallback'` return contract;
- v13 exports, board state, calls, assets, surges, scoring, and escalation behavior.

The shared bridge adds `lastFallbackResource` to its stats snapshot so fallback ownership can be observed without changing the meaning of `lastResource`.

## Regression contract

The DPN Quality Gate guards must fail if:

- the shared bridge contains more than one active-route emit plus one fallback emit;
- the shared bridge returns to looping across every configured resource in the no-started-resource fallback;
- v13 reintroduces direct dual-target `dpn-dispatch-system` + `dpn-dispatch` fallback emits;
- v13 stops preferring `DPNMedicalDispatchCompatBridge`;
- configured-resource ordering stops driving the fallback owner;
- the existing compatibility exports or v13 public exports disappear.

## Phase 3G result

With PR #74 and PR #78 combined, medical dispatch v9-v13 now have a single-owner compatibility model: one selected active dispatch resource when available, otherwise one bounded historical fallback owner. v14 remains local-event-only and does not require compatibility-router insertion without new evidence.

No force push, history rewrite, CI weakening, visibility change, credential-material change, license or ownership-metadata change, release change, branch-protection change, schema change, or permission change is part of this ownership cleanup.
