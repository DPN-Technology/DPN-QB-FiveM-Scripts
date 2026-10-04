# MIB Target Proximity Authority v2

Baseline refreshed from `main` at `250e74ebf11e7a75965835bd0a41d406c3cf5919`.

## Resolution

Range-bound MIB actions now establish proximity from server-observed player entities before privileged effects execute:

- `freeze` validates the target with `validTargetInRange(..., Config.Tools.freeze.range, ...)`.
- `scan` validates the target with `validTargetInRange(..., Config.Tools.scan.range, ...)`.
- `revive` now validates the target with `validTargetInRange(..., Config.Tools.revive.range, ...)` and applies the configured server-side cooldown before issuing the revive event.
- Neuralizer target actions already use the same server-observed entity/coordinate authority model.

The client may still propose a target ID, but it cannot establish proximity by itself. The server resolves caller and target peds, derives coordinates, applies the configured maximum distance, and fails closed when either entity cannot be validated.

Remote administrative operations such as `goto_player`, `bring`, `spectate`, routing-bucket management, and kick intentionally preserve remote semantics and are not forced through proximity checks.

## Runtime contract

1. Resolve caller and target entities server-side.
2. Derive coordinates from server-observed entities.
3. Apply configuration-owned maximum range only to local/range-bound actions.
4. Fail closed when caller/target entities cannot be validated.
5. Preserve existing authorization, reasons, events, payloads, logging, notifications, and unique behavior.
6. Enforce action cooldowns server-side before effects.
7. Keep explicitly remote administrative operations remote.
8. Protect the contract with the additive `check_mib_target_proximity_authority.py` Quality Gate regression check.

## Acceptance criteria

Range-bound MIB actions cannot execute solely because the client supplied a target ID; server-observed proximity must be established before the effect. CI fails if the required proximity guard, configured revive range, revive cooldown, or remote-action separation is removed.
