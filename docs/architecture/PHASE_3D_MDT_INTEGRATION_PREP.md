# Phase 3D — MDT Integration Preparation

Status: design/preparation only. This document is intentionally independent of unmerged Phase 3B/3C runtime work and is based on `main` at `2c642c267e250ebd8c9028572cc06c26559c7893`.

## Objective

Prepare the DPN MDT to consume the canonical emergency/dispatch lifecycle without becoming a second source of truth for dispatch creation, ownership, identity, or correlation.

Phase 3D implementation must preserve all existing MDT capabilities while making its integration path deterministic, idempotent, server-authoritative, and compatible with the Phase 3B emergency-correlation contract and Phase 3C dispatch ownership/dedup rules once those phases are merged.

## Existing Integration Surface

Current repository state already exposes MDT-facing dispatch integration points, including:

- an MDT dispatch receive event;
- dispatch update, assignment, and unit-status events;
- a dispatch-side MDT bridge;
- MDT dispatch UI state;
- existing integration examples that carry MDT case identity through dispatch metadata.

These existing surfaces must be migrated or adapted rather than deleted merely to simplify the implementation.

## Ownership Rules

1. The MDT must not generate a second authoritative dispatch identity for an already-correlated emergency event.
2. Dispatch creation remains owned by the canonical dispatch path established in Phase 3C.
3. Emergency root identity and child-link correlation remain owned by the canonical server-side correlation authority established in Phase 3B.
4. MDT case creation may create an MDT-specific case identity, but linking that case to an emergency/dispatch record must use the server correlation authority and may not rebind an existing immutable link.
5. Client-provided `eventId`, `dispatchCallId`, `incidentId`, or `mdtCaseId` values must never be trusted as proof of ownership or authority.
6. The server must derive caller/resource authority before accepting any correlation-changing operation.

## Idempotent Dispatch Ingestion

The MDT receive path must become idempotent.

For each canonical dispatch call:

- receiving the same canonical dispatch identity more than once must update/refresh one MDT representation rather than create duplicates;
- export/event fallback paths must converge on the same ingestion function;
- duplicate notifications must not create duplicate MDT rows, alerts, cases, or timeline entries;
- repeated delivery after a resource restart must be safe;
- update ordering must not allow stale data to overwrite a newer canonical state without an explicit version/timestamp rule.

A normalized server-side ingestion key should prefer the canonical `dispatchCallId`, with the Phase 3B `eventId` retained as the root correlation identity.

## MDT Case Linking

When an officer, EMS user, or authorized workflow creates an MDT case from a dispatch/emergency record:

1. Resolve the canonical correlation record server-side.
2. Create or resolve the MDT case using existing MDT behavior.
3. Link `mdtCaseId` through the canonical correlation authority.
4. Reject conflicting attempts to bind a different MDT case to an already-linked immutable slot unless a separately approved correction workflow exists.
5. Record denied/conflicting link attempts in server logs with enough context for audit without exposing sensitive payloads.

The MDT database remains responsible for MDT-specific case content. The correlation authority remains responsible only for cross-system identity relationships.

## Update and Assignment Flow

MDT actions that update dispatch status, assign units, or change unit status must continue to use server-side dispatch APIs/events. The MDT must not directly mutate another resource's private persistence state.

Required behavior:

- validate the acting player server-side;
- validate job/role authorization server-side;
- validate referenced canonical dispatch identity;
- reject unknown or stale targets safely;
- preserve existing authorized assignment/status functionality;
- avoid broadcast loops between MDT and dispatch bridges.

## Loop Prevention

Phase 3D implementation must include origin metadata or equivalent server-side loop suppression so that:

`dispatch -> MDT -> dispatch`

cannot repeatedly rebroadcast the same logical update.

Loop suppression must not be based solely on client-supplied source strings.

## Restart and Recovery Behavior

MDT integration must tolerate either resource restarting independently.

- On MDT restart, rebuilding its dispatch view must not create new canonical dispatch calls.
- On dispatch restart, MDT must not promote cached records into new authoritative calls unless the canonical dispatch recovery path explicitly requests it.
- Rehydrated records must retain canonical identities and correlation links.
- Missing optional integrations must degrade cleanly rather than error-loop.

## Compatibility Requirements

Do not remove existing unique MDT functions, including law-enforcement records, EMS/patient workflows, warrants, BOLOs, bulletins, roster features, charges, or dispatch visibility.

Do not remove existing event/export compatibility paths until equivalent behavior is proven and an explicit migration/removal phase is approved.

Where multiple integration adapters currently exist, Phase 3D should funnel them into one normalized server-side ingestion/update layer while keeping compatibility wrappers thin.

## Security Requirements

Phase 3D runtime changes must ensure:

- no client can forge canonical correlation ownership;
- no client can create privileged MDT/dispatch state solely by naming a trusted source resource;
- all job/role checks are server-derived;
- free-form notes/descriptions are bounded and sanitized according to existing UI/database expectations;
- identifiers are length/character bounded before persistence/logging;
- failed authorization and immutable-link conflicts are auditable;
- no secret, token, webhook credential, or private endpoint is introduced into client code.

## Performance Requirements

- Avoid polling when an existing event-driven update is sufficient.
- Avoid full-table broadcasts for single-call changes.
- Reuse normalized payloads rather than re-querying the same call several times in one update path.
- Bound in-memory dedup/replay caches and expire entries safely.
- Keep database writes idempotent where possible.

## Required Regression Coverage

Before Phase 3D runtime work is eligible for merge, CI should verify at minimum:

1. duplicate delivery of one canonical dispatch call produces one MDT dispatch representation;
2. one `dispatchCallId` cannot silently map to multiple active MDT dispatch records;
3. one immutable correlation `mdtCaseId` link cannot be rebound by an untrusted request;
4. MDT update/assignment/status operations pass through server authorization;
5. fallback integration paths enter the same normalization/dedup layer;
6. dispatch-to-MDT update handling cannot create a rebroadcast loop;
7. existing MIB authorization and emergency-correlation checks remain present in the Quality Gate;
8. no existing MDT module is removed as collateral cleanup.

## Implementation Sequence After Dependencies Merge

1. Rebase is not required for this preparation branch; runtime work should instead start from the then-current `main` after Phase 3B and Phase 3C are merged.
2. Introduce the normalized MDT dispatch ingestion layer.
3. Route the existing MDT receive bridge through that layer.
4. Add canonical identity/correlation fields without deleting legacy fields.
5. Add server-authoritative MDT case linking.
6. Add origin/loop suppression.
7. Add regression validator(s) and wire them into the existing DPN Quality Gate without removing prior checks.
8. Validate resource startup/restart behavior and existing MDT functions.
9. Open a focused draft PR from fresh `main` and merge only after exact-head required checks are green.

## Explicit Non-Goals For This Preparation PR

This preparation PR does not:

- implement Phase 3B correlation runtime code;
- implement Phase 3C dispatch ownership/dedup runtime code;
- change MDT runtime behavior;
- change database schemas;
- delete compatibility events/exports;
- modify licensing, ownership, visibility, secrets, releases, or branch protection;
- weaken any CI check.
