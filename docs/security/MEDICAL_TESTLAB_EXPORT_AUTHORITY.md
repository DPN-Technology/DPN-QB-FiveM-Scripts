# Medical Test Lab Export Authority Contract

Baseline: `main` at `6bea5b82dd09764584e9e6ea9664c23a15b580e4`.

## Current finding

`dpn-medical-core/server/testlab.lua` still exposes mutation-capable server exports without a server-derived invoking-resource authorization boundary.

- `RestoreTestSnapshot(target, actor)` can commit a stored snapshot back into canonical medical state.
- `ApplyTestScenario(target, scenarioId, options, actor)` can replace/mutate canonical patient state, persist it, and emit downstream life-state events.
- The free-form `actor` argument is audit metadata, not authority.

`dpn-medical-admin-tools` is a legitimate current caller of `ApplyTestScenario`, so hardening must preserve that workflow through an explicit trusted-resource policy.

## Required authority model

- Derive the invoking resource from server runtime context such as `GetInvokingResource()` or one centralized equivalent.
- Default deny unknown external resources for privileged mutation exports.
- Explicitly allow bounded legitimate Medical Admin/Test Lab integrations.
- Preserve existing export names and argument ordering.
- Keep read-only exports under separate risk review.
- Fail before snapshots, state mutation, persistence, or downstream events when caller authority is not established.
- Add additive Quality Gate coverage for the boundary.

No client-supplied resource name or free-form actor string may become an authorization token.
