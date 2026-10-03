# Phase 3G Integration Sequencing

Baseline: `main` at `6bea5b82dd09764584e9e6ea9664c23a15b580e4`.

This document records a low-debt integration order for the current Phase 3G medical-dispatch compatibility work. It does not authorize merges and does not change runtime behavior.

## Current focused queue

1. PR #74 — fresh current-main replacement for stale v9-v12 routing PRs #62-#65.
2. Shared compatibility fallback ownership proof — documentation only until repository-wide compatibility evidence supports a runtime reduction.
3. v14 ownership proof — no runtime rewrite unless current source shows direct external dispatch ownership.
4. Emergency-dispatch ownership coverage — keep cross-resource publishers classified against current `main`.

## Safe integration rule

Before merging any Phase 3G runtime slice:

- Fetch fresh PR metadata and verify the exact head SHA has not changed since successful validation.
- Require every current required workflow/check to be successful on that exact head.
- Require GitHub to report the PR mergeable and non-draft.
- Do not merge a red, pending, stale, conflicted, or unexpectedly changed PR.
- Never force-push `main`, rewrite history, or weaken CI to make a PR pass.

After each merge:

- Verify the exact new `main` commit and its workflows.
- Treat remaining independent runtime PRs as needing freshness review against the new `main`.
- Replace stale integration candidates with fresh current-main branches rather than rewriting branch history.
- Preserve all unique historical functionality and compatibility surfaces unless separate evidence proves they are redundant and safe to retire.

## Shared fallback ownership

The no-target fallback in `compat_bridge.lua` still fans out to each configured historical dispatch namespace when no configured resource is started. A runtime reduction remains separate from PR #74 and should proceed only after repository-wide compatibility proof.

Required proof should cover:

- all configured historical dispatch resource names and their event consumers;
- resource load/start ordering;
- event payload compatibility;
- behavior when the preferred dispatch resource is stopped or absent;
- explicit regression coverage for exactly one active compatibility target;
- preservation of exports, boards, commands, state, statistics, and emergency-network behavior.

## Older audit/preparation PRs

Older security/performance documentation PRs based on pre-current `main` should not be used as implementation foundations without revalidation. Their findings may remain valid, but runtime work should begin from fresh `main`.

## Non-goals

This sequencing document does not change repository visibility, secrets, licensing or ownership terms, releases, branch protection, runtime code, resource manifests, database schemas, permissions, or CI requirements.
