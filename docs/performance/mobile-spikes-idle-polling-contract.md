# Mobile Spikes Idle Polling Performance Contract

## Purpose

This contract defines a safe performance optimization for `qbcore/law-enforcement/dpn_mobilespikes/client/main.lua` without changing gameplay behavior, server-authority rules, controls, deployment semantics, collision behavior, visuals, or synchronization.

## Current finding

The main control thread currently executes every frame with `Wait(0)` even when there is no work that requires frame-level polling. This includes states where the player is logged out, not assigned to an authorized job/grade, not inside a vehicle, or inside a vehicle that is not authorized for spike deployment.

The same resource already uses bounded waits in other loops, including a 200 ms collision cadence and a 500 ms visual backoff when no nearby spikes need frame rendering. This demonstrates that idle backoff can be introduced without weakening active behavior.

## Required behavior invariants

Any runtime optimization implementing this contract MUST preserve all of the following:

- Existing QBCore login and job-update handling.
- Existing authorized-job and grade semantics.
- Existing authorized-vehicle restrictions.
- Existing deploy and toggle control bindings.
- Existing requirement that the player be in the driver seat for deployment.
- Existing deployment cooldown behavior.
- Existing deployment animation and model-loading behavior.
- Existing spike placement, heading, object creation, and network synchronization.
- Existing player-owned spike removal semantics.
- Existing server-side authority introduced by the Mobile Spikes hardening work.
- Existing collision checks, tire/engine/body damage behavior, immune-vehicle handling, sounds, notifications, blips, markers, and 3D text.
- Existing auto-retract behavior and cleanup semantics.
- Existing public events and any exported compatibility surface.

## Dynamic-cadence requirements

The main control thread SHOULD use state-aware polling rather than unconditional frame polling.

Recommended states:

1. **Logged out / unavailable player state**
   - Use a bounded idle wait such as 750-1500 ms.
   - Do not perform vehicle or input checks.

2. **Logged in but unauthorized job/grade**
   - Use a bounded idle wait such as 500-1000 ms.
   - Job updates remain event-driven, so there is no need to poll authorization every frame while unauthorized.

3. **Authorized but not in a vehicle**
   - Use a moderate wait such as 250-500 ms.
   - Resume active polling when entering a vehicle.

4. **In a vehicle that is not authorized**
   - Use a moderate wait such as 200-500 ms.
   - Re-evaluate often enough that changing vehicles does not feel delayed.

5. **Authorized officer in an authorized vehicle**
   - Preserve frame-level polling with `Wait(0)` while deploy/toggle input must be captured reliably.
   - Do not debounce, delay, or coalesce control presses beyond current behavior.

The implementation MAY use a single `sleep` variable selected each iteration, provided the active authorized state remains frame-level.

## Visual-loop requirements

The existing visual loop already backs off when no nearby spikes are present. Any future optimization MUST continue to use frame-level rendering whenever markers or 3D text are visible, because draw natives are frame-scoped.

It MAY increase idle backoff only when no rendered spike is within the configured visual range, provided spike appearance remains responsive when entering range.

## Collision-loop requirements

The collision loop MUST remain independent from control-loop timing. Do not reduce collision fidelity merely to optimize input polling.

Any change to the current 200 ms collision cadence requires separate evidence, testing, and review.

## Security requirements

Performance work MUST NOT move authorization or ownership decisions from the server back to the client. Client checks remain usability gates only; the server remains authoritative for deployment/removal validation and configured limits.

Do not weaken payload validation, ownership validation, cooldown enforcement, global/per-player limits, minimum-distance enforcement, or disconnect/expiration cleanup.

## Validation requirements

Before runtime implementation is considered complete:

- Confirm deploy input remains responsive in an authorized vehicle.
- Confirm toggle/removal input remains responsive in an authorized vehicle.
- Confirm login/logout and job changes transition polling state correctly.
- Confirm entering/leaving authorized vehicles transitions polling state correctly.
- Confirm collision handling is unchanged.
- Confirm markers and 3D text render every frame when visible.
- Confirm synchronized spikes from other players remain unaffected.
- Confirm server-authority regression checks remain green.
- Confirm DPN repository validation remains green.
- Confirm FiveM Lua syntax checks remain green.
- Confirm DPN Quality Gate remains green.
- Confirm DPN Pull Request Resource Summary remains green.

## Scope boundary

This preparation change is documentation-only. It intentionally does not modify runtime Lua code and therefore does not alter gameplay behavior.

A later implementation PR should be focused on the polling change itself and should preserve every invariant above. It should not be combined with Phase 3B-3G emergency architecture work, feature removal, event renaming, licensing changes, repository-policy changes, or unrelated refactors.
