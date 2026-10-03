# Phase 3G Integration Sequencing

Baseline: `main` at `2c170fb4cf6d6a5a4e1ced69ec14122319aa5090`.

This document records the Phase 3G medical-dispatch compatibility integration sequence and its closeout conditions.

## Integrated sequence

### PR #74 — v9-v12 routing consolidation

PR #74 consolidated the stale v9-v12 routing work and established dedicated v9-v12 single-route guards.

v9-v12 now:

- prefer `DPNMedicalDispatchCompatBridge`;
- retain one bounded direct `dpn-dispatch-system` fallback if the bridge object is unavailable;
- preserve existing exports, payloads, boards, state, and unique medical-dispatch behavior.

### PR #78 — deterministic fallback ownership

PR #78 closes the remaining shared-bridge/v13 fan-out condition.

The resulting routing contract is:

- first started configured dispatch resource wins;
- no-started-resource fallback selects one configured historical owner;
- v13 bridge-unavailable fallback follows the same configured priority;
- one logical compatibility event cannot intentionally fan out to both historical dispatch namespaces;
- shared bridge stats expose `lastFallbackResource` while retaining existing fields.

## Validation rule

Every Phase 3G runtime slice must:

- start from fresh `main`;
- prove the exact publisher, target, and duplication/ownership hazard;
- preserve unique compatibility surfaces;
- add deterministic regression coverage;
- pass the exact-head DPN Quality Gate, Security Baseline, Security & Supply Chain, and PR Resource Summary;
- be mergeable and non-draft immediately before merge;
- never require force-pushing, history rewriting, or CI weakening.

## Closeout review

After PR #78 is integrated, Phase 3G runtime closeout should verify:

1. v9-v13 all route through one active target or one historical fallback owner.
2. v14 remains local-event-only with no direct external dispatch namespace.
3. `core/dpn-dispatch` remains the canonical `dpn-dispatch:*` owner.
4. Other emergency-network publishers are intentional integration edges rather than duplicate canonical owners.
5. Quality-gate coverage prevents regression to multi-target medical compatibility fan-out.

If those conditions remain true on current `main`, Phase 3G medical-dispatch compatibility ownership can be treated as closed and further hardening can move to the separately documented security-authority findings.

## Non-goals

This sequencing work does not change repository visibility, secrets, licensing or ownership terms, releases, branch protection, database schemas, permissions, or unrelated runtime behavior.
