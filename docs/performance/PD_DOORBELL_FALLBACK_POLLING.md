# PD Doorbell Fallback Polling Performance Contract

## Scope

This document defines a safe optimization target for the fallback interaction loop in `qbcore/law-enforcement/dpn_police_qbdoorbell/client.lua`.

The current fallback path is only used when `qb-target` is unavailable or disabled. In that mode, the client runs a permanent `Wait(0)` loop, queries player coordinates every frame, computes distance to the PD reception point, draws the interaction prompt when in range, and checks the F3 control.

## Performance objective

Reduce idle client work while preserving frame-level responsiveness when the player is close enough to interact with the doorbell.

## Required behavior

A future runtime implementation should use dynamic polling rather than a permanent frame loop:

- When the player is well outside the interaction area, use a longer idle delay before checking position again.
- As the player approaches the reception point, reduce the delay so entering the interaction radius remains responsive.
- While the player is inside `Config.InteractDistance`, preserve frame-level polling so `DrawText3D` rendering and `IsControlJustPressed(0, 170)` remain reliable.
- Keep the existing `qb-target` path unchanged.
- Keep the existing `qb-pd-doorbell:ringBell` server event unchanged.
- Preserve `Config.PDReception`, `Config.InteractDistance`, `Config.RingText`, and the current F3 fallback binding.
- Do not remove or alter the existing server-side cooldown/authorization hardening.

## Safety invariants

The optimization must not:

- create duplicate fallback threads;
- miss normal F3 presses while the player is within interaction range;
- change the coordinates or interaction radius;
- alter notification, sound, cooldown, or server-authority behavior;
- depend on `qb-target` becoming available after startup unless that lifecycle is explicitly handled and tested;
- replace all `Wait(0)` usage mechanically. Frame polling remains appropriate while drawing the prompt and reading the interaction control.

## Suggested cadence model

Exact values should be benchmarked, but the implementation should follow a tiered model such as:

1. Far from PD reception: low-frequency coordinate polling.
2. Near PD reception but outside `Config.InteractDistance`: moderate-frequency polling.
3. Inside `Config.InteractDistance`: `Wait(0)` for prompt rendering and key detection.

The important contract is behavior-based rather than tied to one hard-coded sleep value.

## Validation requirements

Before merging a runtime implementation:

- confirm the existing DPN Quality Gate remains green;
- confirm the Pull Request Resource Summary remains green;
- verify the fallback prompt appears consistently on entry into the configured radius;
- verify F3 rings exactly once per valid press;
- verify moving out of range stops prompt drawing and returns to an idle polling cadence;
- verify the `qb-target` configuration path is unaffected;
- verify no new client errors appear if the player ped changes during respawn;
- compare idle resource time before and after the change with the fallback path active.

## Repository relationship

This optimization is independent of the Phase 3B-3G emergency architecture work and can be implemented from secured `main` without creating rebase debt. It is intentionally documentation-only in this preparation phase.