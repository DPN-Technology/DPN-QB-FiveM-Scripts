# Hospital Self-Check-In Distance Authority Preparation

## Scope

This preparation covers the server-side `dpn-hospital:server:selfCheckIn` path in `dpn-medical-hospital`.

It is documentation-only and does not change runtime behavior.

## Fresh finding

On current `main` `57f818967f9230443c24a67b0db29ac1bd58c6c0`, the server resolves the configured hospital and calls `GetDistanceFromCoords(src, hospital.checkIn)`. The current guard rejects only when a distance value exists and exceeds `Config.CheckInInteractionDistance`.

If the server cannot resolve the player's ped or otherwise cannot produce a numeric distance, `GetDistanceFromCoords` returns `nil`. That `nil` does not currently fail the check, so the self-check-in flow can continue without a positive server-side proximity proof.

## Security objective

NPC/self-service hospital check-in should proceed only when the server positively verifies that the player is physically within the configured check-in interaction radius.

Unavailable, stale, invalid, or non-measurable proximity information must fail closed before money is removed, a bed is claimed, an admission is written, or medical state is mutated.

## Required runtime contract

A focused runtime patch should preserve the existing public event name, hospital selection, EMS-online rules, bank charging/refund behavior, `AdmitPatient` flow, notifications, configuration names, and unique hospital gameplay.

Before charging or admitting a player, the server should:

1. derive the acting player from event `source`;
2. validate the requested hospital identifier against `Config.Hospitals`;
3. resolve the server-side player ped;
4. require a valid server-observed position;
5. calculate distance from the configured `hospital.checkIn` coordinates;
6. reject if distance cannot be established as a finite numeric value;
7. reject if distance exceeds `Config.CheckInInteractionDistance`;
8. continue only after a positive in-range proof.

Client-provided coordinates must not be used as the authority boundary.

## Failure safety

A failed proximity proof must occur before:

- checking or removing payment funds where practical;
- calling `AdmitPatient`;
- claiming a bed;
- writing admission persistence;
- creating billing/medical-record entries;
- setting Medical Core admission flags.

The user-facing rejection should remain bounded and should not expose server internals.

## Compatibility requirements

The hardening must preserve:

- `dpn-hospital:server:selfCheckIn` event compatibility;
- current hospital ID parameter handling;
- `Config.AutoCheckinEnabled`;
- `Config.RequireEMSOfflineForNPC` and `Config.MinEMSForNoNPC` behavior;
- `Config.CheckInInteractionDistance`;
- existing check-in cost and refund behavior;
- current `AdmitPatient` semantics;
- all existing records, billing, bed, Medical Core, and notification integrations.

No unique hospital functionality should be removed.

## CI expectations

A runtime implementation should add additive regression coverage proving that:

- self-check-in fails when the player ped cannot be resolved;
- self-check-in fails when distance cannot be measured;
- self-check-in fails when the server measures the player outside the configured radius;
- self-check-in remains functional when the player is server-observed within range and all other requirements pass;
- payment is not consumed on a rejected proximity proof;
- existing DPN Quality Gate and Lua syntax validation remain enabled.

## Safety boundary

This preparation does not authorize destructive migrations, removal of unique medical behavior, CI weakening, force pushes, history rewrites, visibility changes, secrets changes, licensing/ownership changes, releases, or branch-protection changes.
