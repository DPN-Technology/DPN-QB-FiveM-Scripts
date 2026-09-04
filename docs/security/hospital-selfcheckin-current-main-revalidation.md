# Hospital Self-Check-In Proximity — Current Main Revalidation

Baseline: `f653cb59e6e59684a0a2bcda7d1fa08818280e13`

## Fresh finding

The hospital staff-admission path is now fail-closed on current `main`, but the NPC/self-check-in path remains independently fail-open when server-side proximity cannot be measured.

Current self-check-in logic obtains server-side distance using `GetDistanceFromCoords(src, hospital.checkIn)` and rejects only when a distance value exists and exceeds `Config.CheckInInteractionDistance`. If the player ped or coordinates cannot be resolved and the helper returns `nil`, execution can continue into EMS availability checks, bank charging, and `AdmitPatient`.

## Required focused runtime delta

The replacement runtime slice must preserve all current-main changes, including the merged staff-admission proximity authority and all Phase 3F Quality Gate checks. It should change only the self-check-in proximity decision so that:

1. `GetDistanceFromCoords` must return a numeric server-observed distance.
2. A missing/non-numeric distance fails closed before any charge or admission mutation.
3. The maximum range is `tonumber(Config.CheckInInteractionDistance) or 6.0`.
4. A measured distance above that limit remains rejected.
5. Existing EMS-online gating, billing/refund behavior, bed allocation, notifications, Medical Core integration, event name, and configuration names remain unchanged.
6. Additive regression coverage must prove the fail-closed check executes before `RemoveMoney` or `AdmitPatient`.

## Safety boundary

This revalidation does not authorize deletion of unique functionality, destructive persistence changes, permission broadening, CI weakening, force pushes, history rewrites, visibility changes, secret changes, licensing/ownership changes, releases, or branch-protection changes.

The older runtime PR #54 was green on its original head but is stale against current `main`; its security intent remains valid. A replacement runtime implementation must be constructed from this current baseline rather than merging the stale head.