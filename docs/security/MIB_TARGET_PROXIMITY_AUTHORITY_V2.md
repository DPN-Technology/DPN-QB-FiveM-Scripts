# MIB Target Proximity Authority v2

Baseline: `main` at `6bea5b82dd09764584e9e6ea9664c23a15b580e4`.

## Current finding

Current `qbcore/admin/dpn-mib-system/server/main.lua` still validates general MIB/admin access and target existence for range-bound actions such as `freeze`, `scan`, and `revive`, but it does not independently prove caller-to-target distance on the server before those privileged effects. Client code selects nearby players, so proximity remains client-influenced.

Remote administrative operations such as `goto_player`, `bring`, `spectate`, routing-bucket management, and kick have intentionally different semantics and must not be mechanically forced through proximity checks.

## Required runtime contract

A focused runtime hardening change should:

1. Resolve caller and target entities server-side.
2. Derive coordinates from server-observed entities.
3. Apply a configuration-owned maximum range only to actions whose intended semantics are local/range-bound.
4. Fail closed when caller/target entities or coordinates cannot be validated.
5. Preserve existing authorization, cooldowns, reasons, events, payloads, logging, notifications, and unique behavior.
6. Keep explicitly remote administrative operations remote.
7. Add an additive Quality Gate regression check.

## Acceptance criteria

Range-bound MIB actions cannot execute solely because the client supplied a nearby target ID; server-observed proximity must be established before the effect.
