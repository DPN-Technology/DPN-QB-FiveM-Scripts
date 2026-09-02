# Officer Safety Shots-Fired Loop Performance Contract

## Baseline

This preparation note is based on secured `main` commit `2c642c267e250ebd8c9028572cc06c26559c7893`.

The current `dpn-officer-safety` client keeps the shots-fired detector in a permanent `Wait(0)` loop. That per-frame cadence is justified while an authorized on-duty officer has the feature enabled because `IsPedShooting` is a frame-sensitive signal, but the same cadence is unnecessary while the player is off duty, has an unauthorized job, or the feature is disabled.

## Target optimization

A later focused runtime change should preserve per-frame detection only while all of these conditions are true:

1. `isAllowedJob()` is true.
2. `Config.ShotsFired.Enabled` is true.
3. The resource is in normal active gameplay state.

When those conditions are false, the detector should use a bounded idle sleep rather than running every frame. The idle sleep should be short enough that duty/job/config transitions become active promptly, but it must materially reduce unnecessary polling.

A safe implementation shape is a dynamic sleep value selected before the ped/shooting check. The exact sleep should be validated in-game before it becomes a repository-wide convention.

## Behavior that must not change

- Do not reduce detection cadence while an authorized, on-duty officer has shots-fired detection enabled.
- Do not remove or rename `dpn-officer-safety:server:createAlert` or the `shotsFired` alert type.
- Preserve the current weapon metadata, coordinates, dispatch flag, priority, and stress increase.
- Preserve the existing one-second post-alert suppression that limits repeated alerts during continuous fire.
- Do not move authorization authority from the server to the client; this optimization is client scheduling only.
- Do not change job eligibility, duty semantics, config defaults, or emergency-correlation behavior in this performance change.

## Validation requirements

Before runtime implementation is considered complete:

- Lua syntax validation must pass.
- Existing DPN Quality Gate and PR Resource Summary must remain green.
- Off-duty and unauthorized players must no longer execute the detector every frame.
- Disabling `Config.ShotsFired.Enabled` must put the detector into the idle cadence.
- Authorized on-duty officers with the feature enabled must retain frame-level shot detection.
- Single shots and automatic-fire bursts must still create the same alert payload and preserve the one-second suppression behavior.
- Duty and job transitions must activate/deactivate the detector without requiring a resource restart.
- No unique officer-safety functionality may be removed.

## Scope boundary

This note deliberately does not classify every `Wait(0)` loop as a defect. Several loops in the repository legitimately need frame-level input or control handling. Performance work must remain evidence-driven and should replace only idle frame polling that has a clearly safe slower state.
