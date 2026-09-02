# DPN MIB Action Authorization Audit

Status: Security review / remediation design

Base reviewed: `main` at `eb9c43cafafef40cceb613215f901b37f61c7ff3`

## Executive summary

`dpn-mib-system` currently routes many high-impact server actions through the shared `requireAccess` gate. That gate verifies that the caller is an allowed MIB/admin user and, for configured high-risk actions, requires a reason. It does **not** currently establish a separate server-side privilege tier for each administrative action.

This creates a broad authorization surface: any caller who satisfies general MIB access can reach actions that affect other players or global runtime state, including `kick`, `set_bucket`, `lockdown`, `revive`, `bring`, `goto_player`, `spectate`, scene/memory wipe operations, and advanced neuralizer modes.

The director-loadout escalation is being remediated separately in PR #16. This document does not change runtime behavior; it defines the next safe hardening boundary without making an unapproved business-policy decision about which exact MIB grades should own which powers.

## Verified current trust boundary

The server-side `isMIB` check accepts configured allowed jobs or existing admin authority. `requireAccess` then checks only general MIB access plus an optional reason requirement for configured high-risk actions.

A reason is useful for auditability but is not an authorization control. A lower-privilege MIB member can still submit a reason and pass the same gate unless another action-specific check exists.

## High-impact actions sharing the general gate

The following actions should receive explicit server-side policy ownership before further expansion:

- `kick` — disconnects another player.
- `set_bucket` — moves another player into an arbitrary routing bucket.
- `lockdown` — broadcasts a local lockdown effect.
- `revive` — invokes a medical override on a target.
- `bring` — teleports another player to the caller.
- `goto_player` — teleports the caller to another player.
- `spectate` — starts remote observation.
- `wipe_scene` / `mass_wipe` — broadcasts scene memory effects.
- `neuralizer` / advanced neuralizer modes — affects another player's memory/visual state.
- threat/case-management operations where role boundaries may matter operationally.

## Required remediation design

Implement a server-owned action authorization layer before executing privileged branches. The design should:

1. Derive role/job/grade/ACE permission from the authoritative server-side player object.
2. Never trust a client-supplied role, grade, rank, permission, clearance, or admin flag.
3. Map each sensitive action to an explicit policy tier.
4. Keep existing admin/god authority compatible unless intentionally changed later.
5. Reject unauthorized actions before target validation or side effects.
6. Log denials with action, source, target when applicable, and supplied reason.
7. Preserve the existing reason requirement as an additional audit control, not as authorization.
8. Preserve unique gameplay functionality; hardening must only narrow unauthorized invocation paths.
9. Add CI regression checks so future handlers cannot silently fall back to a general-access-only gate for privileged actions.

## Policy decision intentionally deferred

The repository currently does not contain a sufficiently explicit approved mapping of MIB grades to administrative capabilities. Choosing, for example, whether `agent`, `director`, admin ACE, or another clearance tier may kick players or change routing buckets is an operational/business policy decision.

Therefore this audit does **not** hard-code a new grade matrix. Runtime changes should be implemented only after the policy can be derived from existing authoritative configuration or separately approved requirements.

## Immediate engineering recommendations

- Introduce a helper such as `canPerformAction(src, action)` backed by server-derived authority.
- Add a configuration table describing action tiers rather than scattering grade names through handlers.
- Treat `kick`, `set_bucket`, global/broadcast effects, and remote-player movement/observation as privileged by default.
- Validate numeric routing bucket bounds server-side before applying them.
- Add per-action cooldowns where repeated invocation can impact runtime stability.
- Add denial audit events distinct from successful action logs.
- Add a repository validator that rejects privileged `toolAction` branches without an action-specific authorization call.

## Acceptance criteria for a future remediation PR

A remediation is complete only when:

- general MIB access alone cannot execute actions assigned to a higher policy tier;
- server-derived authority is checked before every privileged side effect;
- all denied escalations are auditable;
- compatibility for properly authorized users remains intact;
- Lua syntax and repository validators pass;
- DPN Quality Gate and PR Resource Summary are green on the exact proposed head;
- no unique functionality is deleted and CI is not weakened.
