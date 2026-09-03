# MIB Target Proximity Authority Hardening Contract

## Purpose

This contract defines the server-authoritative validation required for target-affecting MIB actions before any runtime implementation is changed. It is intentionally documentation-only so the hardening can be reviewed and implemented from a fresh `main` without deleting unique gameplay behavior or creating dependency on unmerged architecture branches.

## Current authority boundary

`qbcore/admin/dpn-mib-system/server/main.lua` already validates MIB/admin/developer access, high-risk reasons, cooldowns, and target existence for many operations. However, several target-affecting actions accept a client-supplied server ID and do not independently prove that the caller and target are within the configured gameplay range on the server.

The client may choose a nearby player, but client selection is not an authority boundary. A modified client can submit an arbitrary online server ID.

## Actions in scope

Runtime hardening should audit at minimum:

- `dpn-mib:server:neuralize`
- `dpn-mib:server:advancedNeuralizer` when a single target is used
- `dpn-mib:server:toolAction` action `freeze`
- `dpn-mib:server:toolAction` action `scan`
- any other target-affecting MIB action whose intended gameplay semantics are explicitly range-bound

Actions such as administrative `goto_player`, `bring`, `spectate`, `kick`, or routing-bucket management must not silently inherit a proximity requirement if their established administrative semantics intentionally permit remote use. Their authorization should be reviewed separately and preserved unless explicitly changed.

## Required server-authoritative validation

For each range-bound action, the server must fail closed unless all required checks succeed:

1. The caller still has the required MIB/admin authority at execution time.
2. The target identifier resolves to a currently connected player.
3. Both caller and target player peds resolve to valid server-side entities.
4. Server-observed coordinates can be obtained for both entities.
5. The server-computed distance is finite and does not exceed the action's configured range.
6. Any action-specific cooldown, reason, duty, rank, class, or state requirement continues to pass.

If entity or coordinate resolution fails, the action must be rejected rather than falling through.

## Range ownership

The server must derive allowed range from existing configuration where a suitable range already exists. Do not introduce a second drifting constant when `Config.Tools.<action>.range` or the relevant Neuralizer configuration already defines the intended value.

If a legacy action lacks a configured range but is clearly intended to be proximity-bound, add one through the normal configuration surface with a compatibility-safe default and document it.

## Compatibility guarantees

Hardening must preserve:

- existing event names and callback names;
- existing MIB job/admin/developer access semantics;
- required-duty behavior;
- director loadout restrictions;
- high-risk reason requirements;
- existing cooldown behavior;
- existing logging and case-generation behavior;
- Neuralizer classes, labels, blackout behavior, wipe duration, and bodycam interference;
- existing notification semantics where practical;
- all unique MIB gameplay functionality.

No historical or unique functionality may be deleted as part of this change.

## Fail-closed helper design

Prefer one small server-local helper that validates target existence and optional maximum distance, rather than duplicating coordinate logic in every event. The helper should return structured failure information suitable for existing notifications/logging while avoiding information leakage to unauthorized callers.

Suggested responsibilities:

- normalize target server ID;
- reject self-target only where the action's existing semantics require it;
- resolve source and target peds;
- validate entity existence;
- retrieve coordinates;
- compute distance safely;
- compare against an explicit maximum distance;
- return the validated target ID and distance.

The helper must not grant access. Role/permission checks remain separate and must execute before privileged effects.

## Abuse resistance

Do not trust client-supplied coordinates, distance, entity handles, or statements that a target was the closest player. Rate limiting/cooldowns remain defense in depth and are not a substitute for authorization or proximity validation.

Malformed target IDs, stale player IDs, missing peds, invalid coordinates, NaN/infinite values, and resource-transition edge cases must be rejected without applying the privileged effect.

## Logging and observability

Preserve successful-action audit logs. Add bounded diagnostic logging for rejected authority checks only where it is operationally useful; avoid log spam from repeated malicious events. Do not include secrets or unnecessary player-sensitive data in logs.

## CI regression coverage

Add an additive Quality Gate regression check when runtime hardening is implemented. It should prove that the protected server event paths call the shared server-authority validator before applying target effects.

The guard should detect regressions such as:

- target effect fired before validation;
- target existence checked without server-side proximity proof for range-bound actions;
- proximity based on client-supplied coordinates;
- fail-open handling when ped/coordinate resolution is unavailable;
- removal of existing access checks or cooldowns.

CI must be strengthened, never weakened, to land this hardening.

## Validation plan for implementation PR

Before an implementation PR can be considered merge-ready:

1. Rebase-free implementation branch is created from then-current `main`.
2. Existing repository validator passes.
3. Lua syntax validation passes.
4. New MIB target-authority regression guard passes.
5. DPN Quality Gate passes on the exact PR head SHA.
6. DPN Pull Request Resource Summary passes on the exact PR head SHA.
7. Manual review confirms remote administrative actions did not accidentally receive proximity restrictions.
8. Manual review confirms no unique gameplay behavior or public integration contract was removed.

## Non-goals

This preparation does not change repository visibility, branch protection, secrets, releases, licensing, ownership terms, or history. It does not authorize merging a red PR, force-pushing `main`, destructive refactors, or deletion of historical functionality.
