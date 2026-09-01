# Phase 3A Registry Migration Status

Status: Complete — validation green

## Completed foundation

- Medical Core runtime version now derives from its manifest.
- Medical Core self-registration no longer writes conflicting historical v5/v6 identities.
- `RegisterModule` accepts legacy varargs temporarily and normalizes them into deduplicated capability arrays.
- Repeated module registration merges capabilities rather than replacing prior capabilities.
- Registration and heartbeat health use the same authoritative Medical Core registry.
- Module lifecycle classifications are available as `healthy`, `degraded`, `stale`, and `offline`.
- Medical Core health output reports the manifest-derived runtime version.
- All advanced medical registration owners use `GetCurrentResourceName()` and manifest-derived versions.
- Advanced registration capabilities are passed as capability tables instead of loose string varargs.
- Historical registration and heartbeat ownership was removed from loaded numerical feature layers while preserving gameplay, clinical, persistence, board, simulation, test, and command functionality.
- Medical Core historical v8-v14 layers no longer register themselves as separate runtime modules.
- Medical Core `server/testlab.lua` no longer owns module registration and now derives its displayed version from the resource manifest.
- `dpn-medical-admin-tools/server/v14.lua` no longer duplicates the resource registration owned by its primary server layer.
- Added `tools/check_medical_registry_ownership.py` to reject lifecycle ownership in numerical `server/vN.lua` layers and malformed advanced registration ownership.
- DPN Quality Gate runs the medical registry ownership guard on pull requests, main pushes, and manual workflow runs.

## Final validation

Phase 3A was validated on pull request #7 at head `76deafffe42e8514b75ae2763b65a654411fd797` before this documentation update.

- DPN repository validator: PASS with 0 errors. Existing layout/compatibility warnings remain informational and are not Phase 3A blockers.
- Medical registry ownership guard: PASS. It checked 163 numerical medical server layers and 18 advanced registration owners.
- FiveM Lua syntax validation: PASS.
- DPN Quality Gate run #257: PASS.
- DPN Pull Request Resource Summary run #218: PASS.
- Pull request mergeability was `true` at the validated head.

## Phase 3A result

The medical suite now has a hardened lifecycle foundation with manifest-authoritative runtime identity, compatibility normalization for legacy registration callers, capability merging, unified registration/heartbeat health, and CI enforcement preventing historical numerical layers from becoming lifecycle owners again.

Phase 3A intentionally avoids removing historical feature layers or changing gameplay behavior. Numerical feature layers remain loaded where they provide unique functionality; they simply no longer own module registration or heartbeat lifecycle.

## Next architecture phase

Phase 3B introduces a shared immutable emergency correlation contract centered on a root `eventId`, with linked `medicalCallId`, `dispatchCallId`, `incidentId`, `mdtCaseId`, and `sourceResource`. This work should be developed separately from the completed Phase 3A lifecycle hardening and must preserve backward compatibility while the emergency stack migrates.