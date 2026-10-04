# Repository Security and Performance Audit

Status: current-main evidence index

Baseline refreshed through `main` at `2d88c57091f178ceb964feaf4df1f5f52c8afc1e`.

## Current state

The repository has materially advanced since the original September audit, so old PR heads should not be treated as current implementation baselines.

### Confirmed remediated or actively refreshed

- MIB director-loadout escalation: current source now uses a server-side `canUseDirectorLoadout(src)` check.
- MIB range-bound target authority: `freeze`, `scan`, neuralizer target actions, and `revive` use server-observed entity proximity; revive also enforces its server-side cooldown.
- Training Academy scenario authority: instructor sessions are owner-bound, trainee enrollment is server-authoritative, grading requires exact-session membership, and stale ownership is cleaned on closure/disconnect.
- Medical dispatch v9-v12 single-route remediation: refreshed from current main in PR #74.
- PD doorbell unconditional fallback polling: refreshed from current main in PR #75.

### Confirmed current-main hardening targets

- MIB action-specific privilege policy remains broader than the existing general `requireAccess` gate.
- Medical Test Lab mutation exports still need a bounded server-derived invoking-resource trust boundary.
- LE forced vehicle placement still needs server-side validation of the client-selected vehicle network ID.

## Engineering rules

1. Runtime hardening starts from fresh `main`.
2. No red, pending, stale, or conflicted PR is merged.
3. Exact tested head SHA must match the merged candidate.
4. Existing CI is additive; checks are not weakened to obtain green.
5. Client-provided IDs, targets, coordinates, ranks, and selectors remain untrusted where they affect authoritative state.
6. Unique gameplay and compatibility surfaces are preserved.
7. Performance changes distinguish true frame-required loops from work that can use adaptive sleep.

## Next runtime sequence

Prefer small focused implementation PRs for the confirmed hardening targets above, each with a deterministic regression check integrated into DPN Quality Gate.
