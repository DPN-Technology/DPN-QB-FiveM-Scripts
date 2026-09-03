# DPN Real Traffic Density Idle Polling Contract

## Context

This preparation document is based on secured `main` commit `2c642c267e250ebd8c9028572cc06c26559c7893`.

`qbcore/world/dpn-real-traffic/client/main.lua` correctly applies GTA/FiveM density multipliers every frame while `Config.Density.Enabled` is true. However, the density thread still executes `Wait(0)` continuously when density control is disabled, even though no per-frame native calls are required in that state.

## Goal

Reduce idle client CPU usage without changing active density behavior or weakening traffic simulation fidelity.

## Required behavior

1. When `Config.Density.Enabled == true`, preserve frame-level execution and the current density-native call set.
2. When density control is disabled, use a bounded idle delay instead of a permanent `Wait(0)` loop.
3. A runtime transition from disabled to enabled must be observed promptly enough that users do not perceive a delayed traffic-density activation.
4. Do not alter configured density multipliers, vehicle/ped population budgets, emergency yielding, anti-gridlock behavior, traffic-light priority behavior, or any public event/export contract.
5. Do not merge the density loop with unrelated driver or emergency loops if doing so would couple independent timing requirements.

## Implementation shape

A safe implementation should select the wait duration dynamically:

- active density control: `Wait(0)`
- disabled density control: short bounded idle interval, such as 250-1000 ms, preferably configuration-backed if a new tuning value is introduced

The active path must remain every-frame because `SetVehicleDensityMultiplierThisFrame`, `SetRandomVehicleDensityMultiplierThisFrame`, `SetParkedVehicleDensityMultiplierThisFrame`, `SetPedDensityMultiplierThisFrame`, and `SetScenarioPedDensityMultiplierThisFrame` are frame-scoped natives.

## Validation requirements

Before runtime implementation is promoted:

- verify density behavior is unchanged while enabled;
- verify disabled mode no longer runs the density thread every frame;
- verify toggling the feature from disabled to enabled resumes density control promptly;
- verify no regression to `Config.Driver.ScanInterval` or `Config.Emergency.ScanInterval` loops;
- run the existing repository validator and FiveM Lua syntax validation;
- require DPN Quality Gate and DPN Pull Request Resource Summary to pass on the exact implementation head.

## Safety boundaries

This optimization must not:

- weaken CI;
- remove unique functionality;
- change licensing, ownership, visibility, secrets, releases, or branch protection;
- change density values or traffic gameplay semantics;
- replace frame-level polling while density control is active.

## Rebase-debt policy

This preparation branch is documentation-only and intentionally independent of Phase 3B-3G architecture branches. Runtime implementation should be created from fresh `main` after the owning preparation work is accepted or otherwise explicitly authorized.
