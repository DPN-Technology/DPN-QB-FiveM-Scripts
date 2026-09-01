# DPN Repository Certification Scorecard

**Repository:** DPN QB FiveM Scripts  
**Certification baseline:** DPN GitHub Governance v4  
**Reviewed:** 2026-09-01  
**Baseline commit:** `fd7648dbd5665ab5d41dc189e6d8b53a32cd45c7`  
**Certification:** CONDITIONAL — FiveM quality automation is green; GitHub settings enforcement requires external verification.

## Engineering controls

| Control | Status |
| --- | --- |
| DPN repository governance standard | PASS |
| FiveM quality gate | PASS |
| Manifest integrity validation | PASS |
| Lua/resource validation | PASS |
| Secret/workflow safety checks | PASS |
| Dependency automation / Dependabot | PASS |
| Automated script index | PASS |
| Release workflow | PASS |
| Contribution/support/changelog documentation | PASS |
| Immutable SHA-pinned core Actions | PASS |
| Branch/ruleset enforcement | MANUAL / INTEGRATION-LIMITED |
| GitHub secret scanning / push protection | MANUAL VERIFICATION REQUIRED |
| CodeQL | NOT APPLICABLE TO LUA-FIRST RESOURCE SET |

## Governance v4 certification

The latest audited `DPN Quality Gate` run on the baseline completed successfully. The stronger manifest/resource validator remains green after the Neuralizer missing-file repair. No Critical repository-file finding was confirmed during this pass.

## Certification policy

A FiveM resource is not release-ready if its manifest is malformed, a referenced file is missing, a duplicate resource name is introduced, prohibited runtime secrets are tracked, or required quality/security checks fail. Interdependent police, fire, EMS, MDT, dispatch, and other grouped systems must remain structurally intact during cleanup and packaging.

## Outstanding governance actions

1. Protect `main` with pull-request review and the DPN quality checks where supported.
2. Block force pushes and branch deletion.
3. Verify GitHub secret scanning and push protection.
4. Continue expanding static dependency/export/event validation conservatively to avoid false security claims.
5. Keep QBCore, standalone, hybrid, and interoperating resource groups correctly classified.
6. Never weaken validation to make a failing resource pass; repair the resource instead.
