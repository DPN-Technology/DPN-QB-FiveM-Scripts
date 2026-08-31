# Phase 3A Registry Migration Status

Status: In progress

## Completed foundation

- Medical Core runtime version now derives from its manifest.
- Medical Core self-registration no longer writes conflicting v5/v6 identities.
- RegisterModule accepts legacy varargs temporarily and normalizes them into capability arrays.
- Repeated module registration merges capabilities rather than replacing them.
- Registration and heartbeat health use the same Medical Core registry.
- Module state classifications added: healthy, degraded, stale, offline.
- Medical Core health output now reports the manifest-derived runtime version.

## Remaining in this PR

- Convert malformed advanced medical registrations to proper capability tables.
- Replace hard-coded runtime versions in medical registration and heartbeat owners.
- Reduce each physical medical resource to one registration owner and one heartbeat owner.
- Add CI validation for malformed medical module registration and version drift.
- Re-run the DPN Quality Gate and resolve any migration regressions before marking the PR ready.