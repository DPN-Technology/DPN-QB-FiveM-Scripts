# Hospital Admission Distance Authority Preparation

## Scope

This preparation contract covers the server-side `dpn-hospital:server:admitNearest` admission path in `dpn-medical-hospital`.

It is intentionally documentation-only. Runtime behavior is not changed by this preparation branch.

## Current server-authority model

The admission event currently:

- derives the acting staff member from server event `source`;
- enforces the existing event cooldown;
- requires hospital-staff authorization;
- resolves the client-supplied target server ID to an online QBCore player;
- skips proximity enforcement for administrators;
- obtains server-side player-to-player distance for non-admin staff;
- rejects the request when a returned distance is greater than `Config.StaffAdmissionDistance`;
- proceeds into `AdmitPatient` otherwise.

The current non-admin condition only rejects when a distance value exists and exceeds the configured threshold. If `GetPlayerDistance` cannot produce a distance because either server-side ped cannot be resolved, the helper returns `nil`, and that `nil` result does not currently fail the authorization check.

## Security objective

A non-admin staff admission must be authorized only when the server can positively prove that both participants are represented by valid server-side player entities and that the measured distance is inside the configured admission radius.

Unavailable, stale, invalid, or non-measurable proximity information must fail closed.

## Required runtime contract

A future implementation should preserve the existing event name, public parameters, administrator behavior, staff authorization, cooldown behavior, notification semantics, and `AdmitPatient` workflow while tightening only the non-admin proximity decision.

For non-admin admission requests, the server should:

1. Resolve the acting staff player from `source`.
2. Resolve the requested target ID to an online QBCore player.
3. Resolve both server-side player peds.
4. Reject when either ped is unavailable or invalid.
5. Read both server-observed positions.
6. Reject when position/distance measurement cannot be completed.
7. Compare the measured distance against `Config.StaffAdmissionDistance` (falling back to the existing default only when the configuration value itself is absent or invalid).
8. Proceed only when the server positively observes the target inside the permitted radius.

The authorization decision must not rely on client-supplied coordinates or a client assertion that the patient is nearby.

## Fail-closed requirements

For non-admin callers, each of the following must reject the admission before `AdmitPatient` is invoked:

- invalid target server ID;
- target player no longer online;
- acting staff ped unavailable;
- target patient ped unavailable;
- server-side coordinate retrieval failure;
- distance helper returning `nil` or another non-numeric value;
- measured distance exceeding the configured threshold.

A failed proximity proof should produce a bounded user-facing error and should not mutate admission, bed, billing, medical-state, or persistence data.

## Compatibility requirements

The hardening must preserve:

- `dpn-hospital:server:admitNearest` event compatibility;
- current target ID, ward, minutes, and reason parameters;
- current hospital staff and admin access rules;
- administrator bypass of staff proximity restrictions unless separately redesigned later;
- existing cooldown behavior;
- existing target-online validation;
- `AdmitPatient` admission logic, state transitions, bed claiming, billing, records, flags, and client notifications;
- existing configuration names, including `Config.StaffAdmissionDistance`;
- existing cross-resource exports and events.

No unique medical or hospital functionality should be removed as part of this hardening.

## CI / regression expectations

A runtime implementation should add an additive repository guard or equivalent regression coverage that proves at minimum:

- non-admin admission does not proceed when distance cannot be established;
- non-admin admission does not proceed when the patient is outside the configured radius;
- non-admin admission can proceed when the server positively measures the patient within range and all other authorization requirements pass;
- administrator behavior remains intentionally unchanged;
- the public event contract remains compatible.

The existing DPN Quality Gate and Lua syntax validation must remain enabled. No existing check should be removed or weakened to land this change.

## Implementation boundary

This preparation does not authorize unrelated medical consolidation, dispatch rewrites, MDT changes, destructive historical-layer removal, branch-protection changes, release changes, visibility changes, secrets changes, or licensing/ownership changes.

The eventual runtime hardening should stay focused on converting the current non-admin proximity test from fail-open-on-unmeasurable-distance to fail-closed server authority.