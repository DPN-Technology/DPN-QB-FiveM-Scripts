# MIB Target Proximity Authority v2

Baseline: `main` at `76d3ae559d48f17ed1665fc2d75e34efa4076210`.

## Current finding

The MIB server validates MIB/admin access and checks that a supplied target exists before several privileged target actions, but range-bound actions still rely on client-side nearest-player selection rather than an independent server-observed proximity check.

Current examples include targeted neuralizer effects plus `freeze`, `scan`, and `revive`. These actions can mutate or disclose another player's state and therefore need a server-owned distance boundary whenever their intended gameplay semantics are local/range-bound.

Remote administrative actions such as `goto_player`, `bring`, `spectate`, routing-bucket management, and kick have intentionally different semantics and must not be mechanically forced through proximity checks.

## Required runtime contract

A later focused implementation from then-current `main` should:

1. Resolve caller and target server-side and fail closed when either ped/entity cannot be observed reliably.
2. Obtain caller and target coordinates server-side and compare distance using configuration-owned maximum ranges.
3. Apply the proximity guard only to actions whose existing semantics are explicitly range-bound.
4. Reject missing, nonnumeric, non-finite, stale, or otherwise invalid target/range inputs rather than trusting client assertions.
5. Preserve existing MIB/admin permission checks, cooldowns, reason requirements, event names, payloads, logging, notifications, and unique gameplay behavior.
6. Keep explicitly remote administrative operations remote unless a separate policy change is approved.
7. Add bounded diagnostics for denied proximity checks without logging sensitive payload contents.

## Regression requirements

The implementation PR should add an additive Quality Gate check proving that:

- Range-bound MIB target actions call one shared fail-closed server-side proximity helper before privileged effects.
- The helper derives coordinates from server-observed entities rather than client-provided coordinates.
- Each protected action uses a configuration-owned or explicitly bounded maximum distance.
- Invalid targets and unavailable server-side entity coordinates deny the action.
- Remote administrative actions are not accidentally converted into local-only actions.
- Existing authorization, cooldown, logging, and reason gates remain present.

## Scope safety

This document changes no runtime code. It does not remove historical functionality, change permissions, weaken CI, alter database/schema behavior, or modify repository visibility, secrets, licensing/ownership terms, releases, or branch protection.

The runtime fix must be a separate focused PR created from fresh `main` after this contract is reviewed, so it does not create rebase debt with the active Phase 3G queue.