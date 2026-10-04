# Repository Security and Performance Audit

Status: current-main evidence index

Baseline refreshed through `main` at `efb9eef0055c823775e04282815c66a5c7780ffa`.

## Current state

The repository has materially advanced since the original September audit, so old PR heads should not be treated as current implementation baselines.

### Confirmed remediated or actively refreshed

- MIB director-loadout escalation: current source now uses a server-side `canUseDirectorLoadout(src)` check.
- MIB range-bound target authority: `freeze`, `scan`, neuralizer target actions, and `revive` use server-observed entity proximity; revive also enforces its server-side cooldown.
- MIB action-specific privilege policy: MIB ACE access is separated from admin authority; sensitive tool and neuralizer actions use server-derived MIB/Director/Admin policy tiers with denial auditing and bounded routing-bucket validation.
- Training Academy scenario authority: instructor sessions are owner-bound, trainee enrollment is server-authoritative, grading requires exact-session membership, and stale ownership is cleaned on closure/disconnect.
- Medical Test Lab export authority: mutation exports are default-deny by server-derived invoking resource, with `dpn-medical-admin-tools` explicitly trusted and invoking-resource evidence recorded.
- LE forced vehicle placement: PR #100 resolves client-selected network IDs server-side, verifies a real vehicle entity, and requires server-observed officer/target proximity before placement.
- Medical dispatch v9-v12 single-route remediation: refreshed from current main in PR #74.
- PD doorbell unconditional fallback polling: refreshed from current main in PR #75.

### Confirmed current-main hardening targets

- No previously confirmed current-main hardening targets remain open from this audit wave.

## Engineering rules

1. Runtime hardening starts from fresh `main`.
2. No red, pending, stale, or conflicted PR is merged.
3. Exact tested head SHA must match the merged candidate.
4. Existing CI is additive; checks are not weakened to obtain green.
5. Client-provided IDs, targets, coordinates, ranks, and selectors remain untrusted where they affect authoritative state.
6. Unique gameplay and compatibility surfaces are preserved.
7. Performance changes distinguish true frame-required loops from work that can use adaptive sleep.

## Next runtime sequence

Re-audit current `main` for the next authority, performance, and abuse-resistance targets. Preserve deterministic regression coverage for every completed hardening contract.
