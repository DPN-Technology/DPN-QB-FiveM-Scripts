# Phase 3G Integration Sequencing

Baseline: `main` at `76d3ae559d48f17ed1665fc2d75e34efa4076210`.

This document records a low-debt integration order for the currently open Phase 3G medical-dispatch compatibility work. It does not authorize merges and does not change runtime behavior.

## Current focused queue

1. PR #62 — v9 medical-dispatch compatibility single-route cleanup.
2. PR #63 — v10 medical-dispatch compatibility single-route cleanup.
3. PR #64 — v11 medical-dispatch compatibility single-route cleanup.
4. PR #65 — v12 medical-dispatch compatibility single-route cleanup.
5. PR #66 — documentation-only shared fallback-ownership contract.

Each runtime PR was created independently from the same current-main baseline rather than stacked on another open PR. This avoids hidden dependency chains, but it also means later PRs must be refreshed from the newly updated `main` after any earlier runtime PR is merged.

## Safe integration rule

Before merging any Phase 3G runtime slice:

- Fetch fresh PR metadata and verify the exact head SHA has not changed since its successful validation.
- Require every current required workflow/check to be successful on that exact head.
- Require GitHub to report the PR mergeable and non-draft.
- Do not merge a red, pending, stale, conflicted, or unexpectedly changed PR.
- Never force-push `main`, rewrite history, or weaken CI to make a PR pass.

After each merge:

- Verify the exact new `main` commit and its workflows.
- Treat all remaining independent runtime PRs as needing freshness review against the new `main`.
- If a remaining PR no longer applies cleanly or would carry obsolete baseline debt, replace it with a fresh focused branch from the new `main` rather than rewriting history.
- Preserve all unique historical functionality and compatibility surfaces unless a separate proof demonstrates they are redundant and safe to retire.

## Shared fallback ownership

PR #66 defines the proof requirements for reducing the compatibility bridge's no-target fallback fan-out. The eventual runtime change must remain separate from the v9-v12 slices and should only proceed when repository-wide compatibility evidence shows that selecting one fallback owner will not remove unique behavior.

Required proof should cover:

- all configured historical dispatch resource names and their event consumers;
- resource load/start ordering;
- event payload compatibility;
- behavior when the preferred dispatch resource is stopped or absent;
- explicit regression coverage for exactly one active compatibility target;
- preservation of exports, boards, commands, state, statistics, and emergency-network behavior.

## Older audit/preparation PRs

Older security/performance documentation PRs based on pre-Phase-3G `main` should not be used as foundations for new runtime branches. Their findings may remain valid, but any implementation should begin from fresh `main` and revalidate the finding before writing code. Documentation can be refreshed or superseded later without rewriting branch history.

## Non-goals

This sequencing document does not change repository visibility, secrets, licensing or ownership terms, releases, branch protection, runtime code, resource manifests, database schemas, permissions, or CI requirements.
