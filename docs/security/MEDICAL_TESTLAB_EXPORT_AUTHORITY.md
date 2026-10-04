# Medical Test Lab Export Authority Contract

Baseline refreshed from `main` at `e4916bfeda81b3599c6c156f252c29cb1b942249`.

## Resolution

Mutation-capable Medical Test Lab exports now use a server-derived invoking-resource trust boundary.

- `ApplyTestScenario(target, scenarioId, options, actor)` and `RestoreTestSnapshot(target, actor)` call a centralized `authorizeMutationCaller()` guard before privileged mutation work.
- Authority comes from FiveM runtime context via `GetInvokingResource()`; neither the free-form `actor` string nor any client-provided resource name participates in authorization.
- The allowlist is explicit and default-deny. The currently verified integration is `dpn-medical-admin-tools`.
- Unknown, missing, or unapproved invoking resources fail closed before canonical medical state is mutated, snapshots are restored, persistence is written, or downstream life-state events are emitted.
- Snapshot restoration is implemented as a private `restoreTestSnapshot()` function. `ApplyTestScenario(..., 'restore_snapshot', ...)` calls that internal function after its own authorization rather than re-entering the public export and depending on self-invocation semantics.
- Server-derived invoking-resource identity is added to medical mutation audit metadata and persisted test-run evidence.
- Read-only Test Lab exports remain separate from the privileged mutation boundary.

## Compatibility

Existing export names and argument ordering are unchanged. `dpn-medical-admin-tools` continues using `ApplyTestScenario` through the existing export proxy, while untrusted resources can no longer invoke Test Lab mutations merely by supplying a convincing actor string.

## Regression coverage

`tools/check_medical_testlab_export_authority.py` is wired into DPN Quality Gate. It verifies the explicit allowlist, runtime caller derivation, default-deny behavior, pre-mutation authorization ordering, internal restore path, audit evidence, and preservation of read-only exports.
