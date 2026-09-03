# Sit Anywhere fallback interaction performance contract

## Scope

This document defines a safe optimization contract for the fallback proximity interaction path in `qbcore/civilian/dpn_sitanywhere/client.lua` when `qb-target` is unavailable or disabled.

## Current behavior

The fallback thread currently sleeps for 500 ms on every iteration. During that same iteration it may:

- locate the nearest configured seat,
- draw the `[E] Sit` 3D interaction prompt, and
- test `IsControlJustPressed` for the configured sit key.

A 500 ms cadence is appropriate while no interactable seat is nearby, but it is too slow once the player is in interaction range because FiveM 3D text and just-pressed input checks are frame-sensitive. This can make the prompt appear intermittent and can miss short key presses.

## Required behavior

Implement dynamic polling rather than a single fixed cadence.

### Idle / far state

When the player is not sitting and no valid seat is within or near interaction range:

- use a bounded idle wait rather than frame polling;
- avoid repeated expensive object-pool scans more often than needed;
- preserve the existing seat-model filtering and interaction-distance semantics.

A target idle interval in the existing 250-500 ms range is acceptable unless profiling demonstrates a better bounded value.

### Near / interaction state

When a valid configured seat is within interaction range:

- switch to frame-level polling (`Wait(0)` or an equivalent per-frame path);
- draw the existing `[E] Sit` prompt every frame while it should be visible;
- evaluate the existing configured sit key every frame so short presses are not missed;
- preserve the existing `CanSit()` authorization/state checks before sitting.

### Transition behavior

The implementation must move promptly between idle and interaction polling states as player position or seat availability changes. It must not require restarting the resource or re-entering the area to recover the prompt.

## Functional invariants

The optimization must preserve all existing behavior and compatibility surfaces, including:

- `qb-target` integration when enabled and available;
- fallback interaction when `qb-target` is unavailable;
- `Config.SeatModels` filtering;
- `Config.InteractDistance` semantics;
- `Config.SitKey` input behavior;
- seat and ground-sitting animations;
- cooldown handling;
- vehicle/death/health restrictions;
- stand-up behavior and seated control suppression;
- resource-stop and revive cleanup;
- all existing events, commands, config names, and notifications.

No unique gameplay functionality may be removed as part of this optimization.

## Performance guidance

The expensive `GetGamePool('CObject')` scan should not be repeated separately for every configured seat model if the implementation is reworked. Prefer one object-pool scan per proximity sample with a lookup/set of configured model hashes, provided behavior remains identical.

Any such scan optimization must remain bounded and must not introduce stale seat references, incorrect model matches, or interaction with deleted entities.

## Validation requirements

Before runtime changes are considered complete, verify at minimum:

1. With `qb-target` running, target-based sitting behaves exactly as before.
2. With `qb-target` unavailable, the fallback prompt is continuously visible while in range.
3. A short tap of the configured sit key is reliably captured while the prompt is visible.
4. Moving out of range returns the loop to bounded idle polling.
5. Sitting and standing behavior remains unchanged for seats and `sitground`.
6. Cooldown, health, death, and vehicle restrictions remain intact.
7. Resource stop and revive cleanup still work.
8. Lua syntax validation and all existing repository quality gates remain green.

## CI / regression direction

A future implementation PR should add an additive focused regression guard that verifies:

- fallback idle polling remains bounded rather than permanent frame polling;
- the in-range prompt/input path uses frame-level polling;
- the existing target integration and key config surfaces remain present.

The regression guard must be added to existing CI without weakening or removing any current validation.

## Out of scope

This preparation does not authorize:

- changing resource ownership or licensing terms;
- deleting seat models, commands, events, or compatibility paths;
- weakening CI;
- changing repository visibility, branch protection, releases, or secrets;
- modifying unrelated sitting resources.
