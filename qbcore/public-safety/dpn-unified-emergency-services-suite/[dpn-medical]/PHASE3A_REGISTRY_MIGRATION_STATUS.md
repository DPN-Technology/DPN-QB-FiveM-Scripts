# Phase 3A Registry Migration Status

Status: Validation in progress

## Completed foundation

- Medical Core runtime version now derives from its manifest.
- Medical Core self-registration no longer writes conflicting v5/v6 identities.
- RegisterModule accepts legacy varargs temporarily and normalizes them into capability arrays.
- Repeated module registration merges capabilities rather than replacing them.
- Registration and heartbeat health use the same Medical Core registry.
- Module state classifications added: healthy, degraded, stale, offline.
- Medical Core health output now reports the manifest-derived runtime version.
- All advanced medical registration owners use `GetCurrentResourceName()` and manifest-derived versions.
- Advanced registration capabilities are passed as capability tables instead of loose string varargs.
- Historical v6 registration/heartbeat ownership has been removed from the migrated medical resources while preserving feature logic.
- Historical v14 `RegisterModule` ownership has been removed from the 18 advanced medical resources while preserving v14 feature exports, persistence, boards, and startup messages.
- Added `tools/check_medical_registry_ownership.py` to reject lifecycle ownership in numerical `server/vN.lua` layers and malformed advanced registration ownership.
- DPN Quality Gate now runs the medical registry ownership guard on pull requests, main pushes, and manual workflow runs.

## Remaining before ready-for-review

- Run the updated DPN Quality Gate against the current PR head and resolve any lifecycle, repository, or Lua syntax findings.
- Verify the DPN Pull Request Resource Summary against the final Phase 3A head.
- Review any remaining lifecycle references that are intentionally outside numerical historical layers, including test helpers, before finalizing the migration.
- Update this status to complete only after all required checks are green.

Phase 3A intentionally avoids gameplay-behavior changes. Numerical historical feature layers remain loaded where required; they simply no longer own medical module registration or heartbeat lifecycle.