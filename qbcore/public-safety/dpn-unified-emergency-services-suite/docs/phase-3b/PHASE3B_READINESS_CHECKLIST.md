# Phase 3B Emergency Correlation Readiness Checklist

Status: Preparatory work only — runtime migration not started.

This checklist gates the emergency-correlation implementation until Phase 3A is merged and the Phase 3B branch is rebased onto the new `main`.

## Preconditions

- [ ] Phase 3A PR #7 is merged only after explicit authorization.
- [ ] `phase-3b/emergency-correlation-prep` is rebased or recreated from the post-Phase-3A `main` head.
- [ ] DPN Quality Gate is green on the rebased Phase 3B branch before runtime edits begin.
- [ ] Emergency Flow Audit is reviewed against the rebased code.
- [ ] Officer Safety duplicate-panic finding is revalidated against the rebased code.
- [ ] `tools/audit_emergency_surface.py` is run and its command/event inventory is captured.

## Canonical identity contract

Every newly migrated emergency record must support these fields without breaking legacy callers:

- `eventId` — immutable root emergency identifier.
- `dispatchCallId` — canonical dispatch call identifier when dispatch exists.
- `medicalCallId` — medical call identifier when the event has a medical lifecycle.
- `incidentId` — Incident Command identifier when command is activated.
- `mdtCaseId` — MDT case identifier when a case is created.
- `sourceResource` — originating resource identity.

## Authority rules

- [ ] Server creates `eventId` when a trusted existing root identifier is not supplied.
- [ ] Client-supplied identifiers are never trusted solely because they are present.
- [ ] Existing server-side `eventId` is immutable after creation.
- [ ] Child identifiers may be added but must not replace the root `eventId`.
- [ ] Legacy calls lacking correlation metadata continue to work during migration.
- [ ] Correlation metadata is normalized into one predictable structure before persistence or downstream fan-out.

## Dispatch migration

- [ ] `dpn-dispatch` is treated as canonical primary dispatch owner.
- [ ] Current underscore compatibility path `dpn_dispatch:server:createCall` remains supported until all known consumers migrate.
- [ ] Digital Dispatch becomes a specialized companion/integration rather than an independent root-call owner.
- [ ] Officer Safety panic creates one canonical emergency record.
- [ ] Incident Command links to the existing emergency/dispatch record instead of creating an unrelated duplicate call.
- [ ] Short-window legacy deduplication exists for callers that cannot yet provide `eventId`.
- [ ] `eventId` deduplication is authoritative once correlation metadata is present.

## Incident Command migration

- [ ] Incident creation accepts correlation metadata.
- [ ] Existing `eventId` and `dispatchCallId` propagate into Incident Command.
- [ ] New `incidentId` is written back to the correlated record.
- [ ] Incident updates remain idempotent when replayed.
- [ ] Incident Command no longer creates a second root dispatch call for an already-correlated emergency.

## MDT migration

- [ ] Implement `SyncDispatchCall`.
- [ ] Implement `UpdateDispatchCall`.
- [ ] Implement `SyncDispatchReport`.
- [ ] Implement `UpdateDispatchReport`.
- [ ] Implement `CreateCaseFromDispatch`.
- [ ] Implement `AttachDispatchReport`.
- [ ] MDT synchronization is idempotent.
- [ ] Duplicate MDT cases are prevented using correlation identifiers.
- [ ] ACL/permission checks protect all write paths.
- [ ] Audit records include actor, source resource, event identifier, and target case/call identifier.

## Persistence and recovery

- [ ] Correlation columns/JSON fields are added through idempotent migrations.
- [ ] Existing records without correlation metadata remain readable.
- [ ] Indexes exist for `eventId` and child identifiers used for lookup/deduplication.
- [ ] Resource restart recovery can reconstruct active correlation links where persisted state exists.
- [ ] Completed/stale emergency correlation records have a retention/cleanup policy.

## Testing requirements

- [ ] One `/911` flow produces one root `eventId`.
- [ ] One panic flow produces one root `eventId` even when Officer Safety and Incident Command are both active.
- [ ] Medical Dispatch receives and preserves the root identifier.
- [ ] Incident Command activation preserves the root identifier.
- [ ] MDT case creation preserves the root identifier.
- [ ] Replayed synchronization does not duplicate calls/incidents/cases.
- [ ] Legacy callers without correlation metadata still function.
- [ ] Invalid client identifiers are rejected or replaced server-side.
- [ ] Restart tests verify correlation recovery where practical.

## CI guardrails to add after runtime migration begins

- [ ] Emergency correlation contract validator.
- [ ] Duplicate root-dispatch ownership validator.
- [ ] Command/event surface audit artifact or summary.
- [ ] Tests asserting canonical resources own root identifiers.
- [ ] Lua syntax and repository validators remain mandatory and are never weakened to make Phase 3B pass.

## Safety constraints

Phase 3B must not remove unique gameplay functionality merely because two resources currently overlap. Consolidation should migrate ownership first, preserve compatibility, measure behavior, and only then deprecate aliases with a documented migration path.
