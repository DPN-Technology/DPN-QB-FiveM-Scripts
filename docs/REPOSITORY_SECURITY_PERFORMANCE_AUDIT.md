# Repository Security and Performance Audit

Status: evidence-gathering / hardening preparation only

Baseline: `main` at `eb9c43cafafef40cceb613215f901b37f61c7ff3`

This document records reviewed security and performance surfaces before any runtime hardening changes are attempted. It is intentionally additive and does not remove compatibility behavior, change licensing, alter branch protection, or weaken CI.

## Goals

- Identify server-side mutation events that require authorization, validation, rate limiting, or ownership checks.
- Identify hot loops and per-frame work that may be safely reduced without breaking gameplay behavior.
- Identify SQL construction patterns that deserve review for parameterization and bounded queries.
- Identify insecure transport references and distinguish real network usage from harmless schema/XML namespace strings.
- Preserve all unique FiveM functionality and compatibility paths while improving runtime safety.

## Initial Findings

### 1. Server-side event mutation surface

Repository-wide search shows a broad set of `RegisterNetEvent` handlers across admin, world, law-enforcement, communications, and emergency-suite resources. Several already resolve `source` and call explicit access helpers, which is the desired pattern. Examples include:

- `qbcore/admin/dpn-mib-system/server/main.lua` using `requireAccess` before neuralizer actions.
- `hybrid/admin/dpn_neuralizer/server.lua` resolving the caller as `source` and validating the target.
- `hybrid/admin/dpn-pg-7x/server/server.lua` resolving the caller and computing admin authorization server-side.
- `qbcore/law-enforcement/dpn-starchase/server/main.lua` using `IsAllowed` before synchronization.

The next runtime audit should classify every server mutation event into:

1. read-only/status request,
2. privileged administrative mutation,
3. gameplay mutation with job/duty requirements,
4. public gameplay action with server-side plausibility validation,
5. framework lifecycle event,
6. compatibility adapter.

No handler should be hardened by deleting a public event or compatibility alias unless equivalent behavior is proven and reviewed separately.

#### Confirmed finding: MIB loadout rank is client-controlled

`qbcore/admin/dpn-mib-system/server/main.lua` handles `dpn-mib:server:toolAction` and performs a general MIB access check before dispatching actions. For the `loadout` action, however, the server selects `Config.MIBLoadouts[payload.rank]` directly from the caller-supplied payload. The server does not independently derive or validate the requested loadout rank against the player's authoritative job grade or administrative permission.

The configured `director` loadout is materially more privileged than the normal packages and currently includes `weapon_pistol_mk2`, additional heavy armor, and `advancedlockpick`. As a result, any player who passes the general MIB access check may be able to request the director package by submitting `rank = 'director'` even if their actual MIB grade is lower.

Severity: **High** for servers that grant MIB access to non-director personnel.

Required focused remediation:

- derive the maximum permitted loadout rank exclusively from server-side player/job/permission data,
- treat `payload.rank` as a request only, never authoritative identity,
- deny or safely downgrade requests above the caller's authorized rank,
- preserve the existing recruit/agent/director packages and public event compatibility,
- log denied escalation attempts,
- add a regression validator/test proving a normal MIB user cannot obtain a director loadout by changing the client payload.

This should be fixed in a dedicated runtime PR from refreshed `main`; it should not be folded into Phase 3B–3G ownership changes.

### 2. Per-frame and zero-delay loops

`Wait(0)` / `Citizen.Wait(0)` usage exists throughout the repository. Not all occurrences are defects. Several are justified by FiveM behavior, including:

- deferral sequencing that requires a tick,
- model/entity control waits with explicit timeout boundaries,
- UI input suppression only while a UI is open,
- draw-marker loops that must render every frame,
- fade/model-loading waits bounded by timers.

Higher-priority review candidates are unconditional `while true do Wait(0)` proximity/input loops, especially where expensive coordinate or entity work is performed each frame. These should be reviewed for adaptive sleep intervals when the player is out of range while preserving responsive behavior in-range.

Known candidate surfaces include:

- `qbcore/law-enforcement/dpn_police_qbdoorbell/client.lua`
- `qbcore/law-enforcement/dpn_mobilespikes/client/main.lua`

Do not mechanically replace every `Wait(0)`; each loop must be classified by gameplay and rendering requirements first.

### 3. SQL construction and bounded-query review

Most reviewed SQL examples already use parameter placeholders and bounded result sets. Examples include the incident-command resource and law-enforcement operational queries.

One dynamic SQL construction surface exists in Medical Core persistence for event-pruning interval configuration. The interval is formatted into the SQL statement after conversion with `tonumber`, which reduces injection risk, but it should still be reviewed for strict numeric clamping and predictable upper bounds before being treated as fully hardened.

The runtime hardening pass should verify:

- all user-controlled values are parameterized,
- dynamic identifiers or SQL fragments cannot originate from clients,
- pruning/retention values are numeric and bounded,
- dashboard/history queries have explicit limits,
- bulk reads do not grow without operational bounds.

### 4. HTTP transport scan

The current default-branch search for literal `http://` did not reveal an obvious insecure outbound runtime endpoint. Hits reviewed were tooling exclusions and the standard SVG XML namespace. This is not proof that every external request is secure; future passes should inspect `PerformHttpRequest`, webhook, bridge, and configurable URL surfaces directly.

### 5. Emergency-suite ownership remains staged

Phases 3B through 3G already separate correlation, dispatch, MDT, Medical Core, EMS/Medical Dispatch, and emergency-network ownership concerns. Repository-wide hardening must not pre-empt those boundaries with duplicate runtime ownership changes.

## Hardening Sequence

1. Build a machine-readable inventory of server `RegisterNetEvent` mutation handlers.
2. Flag handlers lacking explicit source validation, permissions, job/duty checks, target validation, or rate limiting where applicable.
3. Review high-frequency client loops and classify frame-required versus adaptive-sleep candidates.
4. Review SQL construction and retention limits.
5. Review configurable HTTP/webhook/bridge endpoints and enforce secure defaults where compatibility permits.
6. Add CI/audit tooling before broad runtime edits so regressions are visible.
7. Apply runtime changes in small focused PRs from refreshed `main` after prerequisite architecture phases are merged.

## Acceptance Criteria

- No red PR is merged.
- No CI validator is weakened or bypassed.
- No unique gameplay feature or compatibility interface is deleted.
- Privileged server mutations are authorized server-side.
- Client-provided IDs/targets/coordinates are treated as untrusted where they affect authoritative state.
- Hot-loop optimization does not reduce responsiveness or break render/input behavior.
- SQL remains parameterized for user-controlled values and operational queries remain bounded.
- Network integrations default to secure transport where technically supported.
- Every runtime write is verified against the exact branch head before merge.

## Non-Goals

This audit does not change repository visibility, secrets, releases, licensing/ownership terms, branch protection, or Git history. It does not implement Phase 3B–3G runtime consolidation and does not authorize deletion of legacy compatibility behavior.