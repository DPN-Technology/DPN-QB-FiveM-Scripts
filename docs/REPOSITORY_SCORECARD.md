# DPN Repository Certification Scorecard

**Repository:** DPN QB FiveM Scripts  
**Certification baseline:** DPN GitHub Governance v3  
**Reviewed:** 2026-09-01

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
| Branch/ruleset enforcement | MANUAL VERIFICATION REQUIRED |
| GitHub secret scanning / push protection | MANUAL VERIFICATION REQUIRED |
| CodeQL | NOT APPLICABLE TO LUA-FIRST RESOURCE SET |

## Certification policy

A FiveM resource is not release-ready if its manifest is malformed, a referenced file is missing, a duplicate resource name is introduced, prohibited runtime secrets are tracked, or required quality/security checks fail.

## Outstanding governance actions

1. Verify `main` is protected by a ruleset requiring pull requests and the DPN quality checks.
2. Verify force-push and branch deletion protections are enabled.
3. Enable GitHub secret scanning and push protection where supported.
4. Keep QBCore, standalone, hybrid, and interoperating resource groups correctly classified.
5. Do not weaken validation to make a failing resource pass; repair the resource instead.
