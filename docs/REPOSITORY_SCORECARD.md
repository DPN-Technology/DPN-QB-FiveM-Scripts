# DPN Repository Certification Scorecard

**Repository:** DPN QB FiveM Scripts  
**Certification baseline:** DPN GitHub Governance v4  
**Reviewed:** 2026-10-04  
**Baseline commit:** `08172f53b785225096c23fb71fa9d730fe2b1cc3`  
**Repository release line:** `1.0.0`  
**Certification:** PASS — automated FiveM quality, security, supply-chain, indexing, manifest, and Lua validation are green on the current `main` baseline. GitHub settings enforcement remains subject to external organization-level verification.

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
| Live README QC status panel | PASS |
| DPN release baseline | PASS |
| Branch/ruleset enforcement | MANUAL / INTEGRATION-LIMITED |
| GitHub secret scanning / push protection | MANUAL VERIFICATION REQUIRED |
| CodeQL | NOT APPLICABLE TO LUA-FIRST RESOURCE SET |

## Current QC evidence

The current `main` baseline has passed the repository's active validation stack, including:

- **DPN Quality Gate**
- **DPN Security Baseline**
- **DPN Security & Supply Chain**
- **DPN Automatic Script Index**

The repository's controlled README status panel links these live workflow states rather than using a static quality claim.

## Certification policy

A FiveM resource is not release-ready if its manifest is malformed, a referenced file is missing, a duplicate resource name is introduced, prohibited runtime secrets are tracked, or required quality/security checks fail. Interdependent police, fire, EMS, MDT, dispatch, and other grouped systems must remain structurally intact during cleanup and packaging.

## Outstanding governance actions

1. Protect `main` with pull-request review and required DPN quality checks where supported.
2. Block force pushes and unintended branch deletion.
3. Verify GitHub secret scanning and push protection at the organization/repository settings level.
4. Continue expanding static dependency/export/event validation conservatively to avoid false security claims.
5. Keep QBCore, standalone, hybrid, and interoperating resource groups correctly classified.
6. Never weaken validation to make a failing resource pass; repair the resource instead.

**DPN Technology — Develop • Pioneer • Navigate**
