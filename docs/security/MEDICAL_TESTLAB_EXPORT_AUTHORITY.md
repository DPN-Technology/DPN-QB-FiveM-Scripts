# Medical Test Lab Export Authority Contract

## Status

Security hardening preparation only. This document does not change runtime behavior.

Base reviewed: `main` at `ee8a2d7a3542dcbf4457ee99c4956f19e16e7d4e`.

## Finding

`dpn-medical-core/server/testlab.lua` correctly gates the client-facing `requestTestCatalog` network event with `DPNMedicalServer.HasAdminPermission(source)`, but its server exports expose materially privileged test-laboratory operations without an equivalent caller trust boundary:

- `ApplyTestScenario(target, scenarioId, options, actor)` can replace or heavily mutate a patient's canonical medical state, alter life state, persist an administrative test scenario, and emit downstream state/event updates.
- `RestoreTestSnapshot(target, actor)` can restore previously captured canonical medical state and persist that restoration.
- `GetTestRunHistory(target)` exposes test-run history for a target.
- `RunMedicalSelfTest` and `GetTestScenarioCatalog` are lower-risk but still belong to the same administrative test surface.

Server exports are not player-triggered network events, but they remain a cross-resource trust boundary. Any loaded resource able to invoke the export should not automatically inherit medical-administrator authority merely because the call originates server-side.

## Security objective

Make privileged Medical Test Lab state mutation fail closed unless the caller is an explicitly trusted server resource or an already-authorized administrative pathway. Do not convert server export calls into client-controlled authority.

## Required authority model

### 1. Separate player authority from resource authority

Network-event authorization and server-export authorization are different boundaries.

- Player-triggered administrative actions must continue to derive the actor from server event context and use the existing administrator permission model.
- Server-export calls must derive the invoking resource from server runtime context (for example, `GetInvokingResource()` where supported) rather than accepting a client-supplied resource identity.
- A free-form `actor` string is audit metadata only. It must never grant permission.

### 2. Explicit trusted-caller policy

Privileged mutation exports must accept calls only from a bounded trusted-resource set owned by configuration or a single authoritative Medical Core policy.

The policy should:

- default to deny for unknown invoking resources;
- explicitly include the administrative/test resources that legitimately orchestrate Medical Test Lab scenarios;
- allow Medical Core internal execution where runtime semantics identify it as internal rather than external;
- avoid wildcard trust such as every `dpn-*` resource;
- avoid trusting based only on resource naming conventions;
- keep the allowlist small and documented.

If a compatibility path is required for an existing trusted integration, add that exact caller deliberately and cover it with CI.

### 3. Fail closed when caller identity cannot be established

For privileged state mutation, an unresolved or unexpected invoking-resource identity must not be interpreted as trusted.

The implementation must distinguish legitimate internal calls from external calls without creating a generic bypass for `nil`, empty, or malformed caller identities.

### 4. Preserve target validation

Existing target normalization and canonical patient-state lookup remain necessary but are not authorization.

A privileged export must require both:

1. a valid target/canonical patient state; and
2. a trusted invoking authority.

Failure of either requirement must stop before snapshot creation, state mutation, persistence, life-state events, or test-run logging.

### 5. Scope the strongest checks to mutation-capable exports

At minimum, caller authorization must protect:

- `ApplyTestScenario`;
- `RestoreTestSnapshot`.

Read-only exports should be reviewed separately. If `GetTestRunHistory` contains administrative or sensitive operational data, apply the same or an appropriately scoped trust policy. Do not weaken protections merely to keep all exports mechanically identical.

### 6. Preserve administrative functionality

Hardening must not remove the Medical Test Lab, trauma scenarios, self-test capability, snapshots, run history, persistence, downstream events, client state synchronization, or legitimate admin tooling.

Existing trusted workflows should continue to work through explicit authority rather than ambient cross-resource trust.

## Audit metadata requirements

For successful privileged mutations, record bounded metadata sufficient to identify:

- invoking resource;
- target server ID / canonical patient identifier where already available;
- scenario or restore action;
- administrative actor metadata supplied by the trusted integration;
- timestamp / existing test-run identifier.

Do not log secrets, connection tokens, or unbounded payloads.

Rejected calls may be counted or rate-limited for diagnostics, but logging must be bounded to prevent spam.

## Compatibility requirements

The implementation must preserve existing export names and argument ordering unless a separate migration is explicitly approved.

If a trusted caller currently invokes these exports, it should continue using the same public API. The authorization layer should sit behind the existing interface.

Do not silently reinterpret the `actor` argument as an authority token.

## CI hardening requirements

Add additive Quality Gate coverage that fails if the privileged Medical Test Lab mutation exports can again execute without a server-derived trusted-caller check.

Regression coverage should prove at least:

1. `ApplyTestScenario` has a caller-authority gate before mutation/persistence.
2. `RestoreTestSnapshot` has a caller-authority gate before commit/reset behavior.
3. authority derives from server runtime caller identity or the centralized trusted-resource helper, not from the `actor` argument;
4. unknown/untrusted resources are rejected fail closed;
5. required trusted admin/test integrations remain represented in the policy or compatibility test fixture;
6. existing `requestTestCatalog` player permission enforcement remains intact;
7. no Quality Gate or existing medical-registry guard is removed or weakened.

Prefer a small static repository guard if full FiveM runtime integration testing is not available in CI.

## Performance constraints

Caller authorization must be constant-time or effectively constant-time per invocation.

- Use a set/table lookup rather than repeated repository/resource scans.
- Do not add polling loops.
- Do not add database queries solely to determine export caller authorization.
- Keep rejection diagnostics bounded.

## Implementation sequence

1. Inventory every current caller of `ApplyTestScenario`, `RestoreTestSnapshot`, `GetTestRunHistory`, `RunMedicalSelfTest`, and `GetTestScenarioCatalog`.
2. Classify each caller as mutation-capable admin/test integration, read-only integration, or obsolete/duplicate caller.
3. Define the authoritative trusted-resource policy in Medical Core or configuration.
4. Gate privileged mutation exports before any state lookup that can cause side effects, snapshot changes, commit, persistence, or client events.
5. Preserve existing export signatures.
6. Add CI regression coverage.
7. Validate FiveM Lua syntax and the full DPN Quality Gate.
8. Exercise legitimate admin scenario apply/restore flows and verify unauthorized-resource rejection.

## Non-goals / prohibited changes

This hardening does **not** authorize:

- deleting Medical Test Lab scenarios or unique functionality;
- changing licensing or ownership terms;
- changing repository visibility, secrets, releases, or branch protection;
- weakening CI or existing permission checks;
- trusting arbitrary resources because they execute server-side;
- force-pushing or rewriting repository history.

## Acceptance criteria

The implementation phase is complete only when privileged Medical Test Lab state mutations require explicit server-derived cross-resource authority, legitimate administrative integrations still work, unauthorized callers fail before state mutation, CI enforces the boundary, and all existing repository quality checks remain green.