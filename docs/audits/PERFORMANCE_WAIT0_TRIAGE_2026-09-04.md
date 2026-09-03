# DPN FiveM Performance Audit — Wait(0) Triage

Baseline: `main` commit `57f818967f9230443c24a67b0db29ac1bd58c6c0`.

## Purpose

This audit classifies current `Wait(0)` / `Citizen.Wait(0)` usage before any runtime optimization. A zero-wait is not automatically a bug in FiveM: frame-sensitive input suppression, drawing, deferral sequencing, model/network-control acquisition, fade synchronization, and bounded raycast loops can legitimately require per-frame execution. Optimization must therefore be evidence-driven and must not mechanically replace every zero-wait.

## Confirmed legitimate or bounded candidates

- `standalone/admin/dpn-queue/server/main.lua` — zero-wait is explicitly required between FiveM deferral method calls. Do not change without a protocol-level reason.
- `hybrid/admin/dpn_neuralizer/client.lua` — zero-wait occurs inside a bounded shape-test result loop with a timeout. Treat as frame-sensitive unless profiling proves otherwise.
- `qbcore/world/dpn-real-traffic/client/main.lua` — zero-wait occurs while requesting network control with an expiration bound. Retain unless profiling shows excessive contention.
- `qbcore/law-enforcement/dpn-starchase/client/main.lua` — model loading is bounded by a timeout and must remain responsive while the model streams.
- `qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-hospital/client/beds.lua` — fade synchronization is bounded and frame-sensitive.
- `hybrid/admin/dpn-pg-7x/client/client.lua` — while the UI is open, controls are disabled per frame. The idle path should remain slower when the UI is closed; the active per-frame path is intentional.
- `hybrid/communications/dpn_pasystem/client/main.lua` — push-to-talk control injection is frame-sensitive while active.
- `qbcore/admin/dpn-mib-system/client/tools.lua` — marker drawing must happen every frame for the bounded display duration.

## Higher-priority profiling candidates

### `qbcore/law-enforcement/dpn_police_qbdoorbell/client.lua`

A fallback proximity thread runs continuously with `Citizen.Wait(0)` and performs player-coordinate/distance work each frame. This is a strong candidate for adaptive sleep: use a slower interval while the player is far from the interaction point and switch to frame-rate polling only inside a small interaction radius. Preserve immediate key responsiveness when actually in range.

### `qbcore/law-enforcement/dpn_mobilespikes/client/main.lua`

Repository search identifies an unconditional `while true do Wait(0)` loop. This requires a focused code review to determine what work executes each frame and whether the loop can use state-aware/adaptive sleep. Do not modify until the full loop body and gameplay timing requirements are mapped.

### `qbcore/admin/dpn-mib-system/client/devtools.lua`

A zero-wait path appears while repeatedly forcing entity coordinates in a dev-overlay/tooling flow. Because this is privileged tooling rather than core gameplay, it should be profiled for an active-only execution gate and deterministic shutdown. Preserve exact developer behavior before changing cadence.

## Optimization acceptance rules

Any runtime performance patch from this audit must:

1. start from then-current `main`;
2. change one focused loop or tightly related group at a time;
3. preserve frame-sensitive behavior where required;
4. use adaptive/event-driven waits rather than arbitrary long sleeps;
5. avoid adding new permanent polling loops;
6. keep all existing repository validators and Lua syntax checks enabled;
7. add targeted regression coverage when a loop has security/gameplay side effects;
8. pass both required PR workflows on the exact candidate head;
9. preserve all public events, exports, commands, controls, notifications, and unique gameplay functionality.

## Recommended implementation order

1. Doorbell fallback proximity loop — highest-confidence adaptive-sleep opportunity.
2. Mobile spikes unconditional loop — inspect full body, then optimize only if state permits.
3. MIB devtools active loop — confirm it is strictly gated by active developer state and add slower idle behavior if needed.
4. Re-profile remaining zero-wait usages before touching bounded/frame-sensitive loops.

## Safety boundary

This audit does not authorize deleting functionality, weakening CI, force-pushing or rewriting history, changing repository visibility, secrets, licensing/ownership terms, releases, or branch protection. It intentionally records legitimate zero-wait use alongside optimization candidates so future cleanup does not introduce latency or break FiveM-specific behavior.
