# Phase 3G Integration Sequencing

Baseline: `main` at `71c3f27dab3a9311d7482654f801277ea7735ae3`.

This document records the current low-debt integration order for Phase 3G medical-dispatch compatibility work. It does not authorize merges and does not change runtime behavior.

## Completed integration

PR #74 is integrated into `main`. It consolidated the stale v9-v12 routing PRs #62-#65 into one current-main runtime change and added dedicated v9-v12 single-route regression checks.

Current v9-v12 behavior is now:

- prefer `DPNMedicalDispatchCompatBridge`;
- preserve one bounded direct `dpn-dispatch-system` fallback when the shared bridge itself is unavailable;
- preserve existing exports, payloads, boards, state, and unique medical-dispatch behavior.

## Current focused queue

1. Shared compatibility fallback ownership — repository-wide proof before reducing the shared bridge's no-started-resource fan-out.
2. v13 bridge-unavailable fallback — current source still emits both historical dispatch namespaces when the shared bridge object is unavailable.
3. v14 ownership proof — no runtime rewrite unless current source shows direct external dispatch ownership.
4. Emergency-dispatch ownership coverage — keep every cross-resource publisher classified against current `main`.

## Safe integration rule

Before merging any future Phase 3G runtime slice:

- fetch fresh PR metadata and verify the exact head SHA has not changed since successful validation;
- require every current required workflow/check to be successful on that exact head;
- require GitHub to report the PR mergeable and non-draft;
- do not merge a red, pending, stale, conflicted, or unexpectedly changed PR;
- never force-push `main`, rewrite history, or weaken CI to make a PR pass.

After each runtime merge:

- verify the exact new `main` commit and its workflows;
- revalidate every remaining ownership finding against that new `main`;
- replace stale integration candidates with fresh current-main branches rather than rewriting branch history;
- preserve all unique historical functionality and compatibility surfaces unless separate evidence proves they are redundant and safe to retire.

## Remaining fallback ownership

The no-target fallback in `compat_bridge.lua` still fans out to each configured historical dispatch namespace when no configured resource is started. Separately, v13 retains a two-name direct fallback when the shared bridge object is unavailable.

The next runtime slice should only proceed after proof covers:

- configured historical dispatch resource names and their event consumers;
- resource load/start ordering;
- event payload compatibility;
- behavior when the preferred dispatch resource is stopped or absent;
- behavior when the compatibility bridge object is unavailable;
- explicit regression coverage for exactly one historical fallback owner;
- preservation of exports, boards, commands, state, statistics, and emergency-network behavior.

## Non-goals

This sequencing document does not change repository visibility, secrets, licensing or ownership terms, releases, branch protection, runtime code, resource manifests, database schemas, permissions, or CI requirements.
