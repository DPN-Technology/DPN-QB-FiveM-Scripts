# DPN MIB Action Authorization Audit

Status: current-main security review / remediation design

Baseline: `main` at `6bea5b82dd09764584e9e6ea9664c23a15b580e4`.

## Current trust boundary

`dpn-mib:server:toolAction` still routes many high-impact operations through the shared `requireAccess` gate. The director-loadout escalation previously identified in the older audit is now addressed in current source by `canUseDirectorLoadout(src)`, so that finding is no longer carried forward as open.

The broader action-policy issue remains: general MIB/admin access plus a required reason is not the same as action-specific privilege ownership.

High-impact operations that still deserve explicit server-owned policy include `kick`, `set_bucket`, `lockdown`, `revive`, `bring`, `goto_player`, `spectate`, scene/memory wipe operations, and advanced neuralizer modes.

## Required remediation design

- Derive role/job/grade/ACE authority from server-side state.
- Map sensitive actions to explicit policy tiers.
- Preserve admin/god compatibility unless intentionally changed.
- Reject unauthorized actions before target validation or side effects.
- Preserve reason requirements as audit controls, not authorization.
- Log bounded denial metadata.
- Add CI coverage preventing privileged branches from falling back to general-access-only authorization.

The exact grade/capability matrix is an operational policy decision and should come from authoritative configuration rather than client input.
