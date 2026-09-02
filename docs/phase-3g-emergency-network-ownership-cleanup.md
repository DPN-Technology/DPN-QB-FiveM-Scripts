# Phase 3G — Emergency-Network Ownership Cleanup Invariants

## Status

**Preparation/design only.** This document intentionally introduces no runtime behavior changes, deletes no resources, changes no database schema, and does not depend on unmerged Phase 3B–3F implementation branches.

It is based on the secured `main` baseline and defines the ownership and compatibility rules required before any emergency-network runtime consolidation is attempted.

## Why Phase 3G Exists

The DPN Unified Emergency Services Suite currently contains multiple legitimate integration surfaces around emergency-network behavior:

- `core/dpn-unified-emergency-network` is the cross-agency Unified Emergency Network resource.
- `[dpn-lawenforcement]/dpn-emergency-network` maintains logical-system aliases and network-event integration across emergency-service resources.
- `core/dpn-mdt` publishes and consumes Unified Emergency Network integration events and retains compatibility aliases.
- Dispatch, medical dispatch, Medical Core, law-enforcement, fire, EMS, and other public-safety resources may publish emergency data into these surfaces.

Those integrations are valuable and must be preserved. The cleanup goal is therefore **not** to delete overlapping resources simply because they touch the same domain. The goal is to make ownership explicit so an emergency fact is accepted once, correlated once, and safely fanned out without loops or duplicate side effects.

## Canonical Ownership Model

### 1. Unified Emergency Network owns cross-system emergency orchestration

The canonical Unified Emergency Network SHOULD own only the cross-system orchestration envelope for an accepted emergency event:

- canonical emergency event identity;
- immutable correlation identity after acceptance;
- originating resource/system identity derived by trusted server-side code;
- parent/child emergency relationships;
- routing metadata;
- delivery/hop metadata;
- lifecycle metadata required for cross-system fan-out;
- replay/idempotency metadata;
- audit metadata for network-level transitions.

It MUST NOT become a second database of record for subsystem-owned business state.

### 2. Domain resources retain their domain state

Ownership boundaries SHOULD remain explicit:

- General dispatch owns canonical dispatch-call state and dispatch assignment lifecycle.
- MDT owns records/cases/reports/warrants and MDT-specific presentation/linkage state.
- Medical Core owns canonical patient/clinical state and treatment transitions.
- EMS/Medical Dispatch owns medical-dispatch-specific call/assignment lifecycle where distinct from general dispatch.
- Incident Command owns incident-command structures and command-specific state.
- Law-enforcement, fire, EMS, rescue, and specialty resources retain their unique operational state.

The Unified Emergency Network may correlate and route these facts, but MUST NOT silently become authoritative for all of them.

### 3. Compatibility/integration layers are adapters, not competing owners

`dpn-emergency-network`, MDT compatibility aliases, legacy events, and other bridges SHOULD be treated as adapters around canonical ownership.

An adapter MAY:

- normalize an existing payload;
- add trusted origin metadata;
- forward a canonical event;
- translate a legacy event/export into a canonical request;
- translate a canonical notification back to a legacy consumer;
- expose health/readiness information.

An adapter MUST NOT independently mint a second canonical identity for an already accepted emergency or apply the same state transition twice.

## Canonical Emergency Envelope

Future runtime work SHOULD normalize cross-system emergency messages into one server-authored envelope similar to:

```text
emergency_id        immutable canonical emergency identity
correlation_id      immutable correlation identity
parent_id           optional immutable parent relationship
source_resource     server-derived original resource
source_system       normalized logical system/domain
source_event_id     source-native identity when available
revision            monotonic network-envelope revision
kind                normalized event kind
occurred_at         source occurrence time when trusted/available
accepted_at         server acceptance time
origin              first trusted origin
hop_path            bounded routing path or equivalent loop marker
idempotency_key     stable duplicate-suppression key
payload             domain payload; not automatically authoritative
metadata            bounded non-authoritative integration metadata
```

Exact implementation names may differ. The invariants matter more than field spelling.

## Identity and Correlation Invariants

1. Canonical `emergency_id` and `correlation_id` become immutable after server acceptance.
2. A client MUST NOT be allowed to author or overwrite trusted origin/resource metadata.
3. An adapter MUST preserve canonical IDs when forwarding an already accepted event.
4. A legacy message without canonical identity may be normalized exactly once by the server-side authority.
5. Child events MAY receive their own canonical event identity while retaining the immutable parent/correlation link.
6. Retries and bridge fallbacks MUST reuse the same idempotency identity rather than minting a new emergency.
7. Subsystem-native identifiers SHOULD be retained as linkage metadata instead of replacing canonical emergency identity.

## Server Authority

All mutations to trusted network-envelope state MUST be server-authoritative.

Client-triggerable events MUST be treated as requests, not proof of:

- source resource;
- department;
- job/grade;
- role;
- unit ownership;
- incident ownership;
- dispatch authority;
- medical authority;
- administrative authority;
- canonical identity;
- correlation identity.

Where authorization is required, the server MUST derive current identity/job/role/permission information from authoritative state and reject unauthorized requests before any fan-out occurs.

## Fan-Out and Loop Suppression

### One accepted event, many deliveries

Fan-out SHOULD distribute one canonical event to zero or more consumers. Delivery count MUST NOT imply creation of additional canonical emergencies.

### Required loop controls

Every bridge path MUST have a deterministic way to recognize already-forwarded events. Acceptable strategies include a bounded hop path, canonical delivery ledger, stable message identity, or equivalent server-side mechanism.

At minimum:

- UEN → MDT → UEN MUST NOT create a loop.
- UEN → Dispatch → UEN MUST NOT create a loop.
- UEN → Medical Dispatch → Dispatch/UEN MUST NOT multiply calls.
- Legacy adapter → canonical network → compatibility adapter MUST NOT return as a new event.
- Export fallback and event fallback MUST NOT both commit the same side effect.

A hop limit alone is insufficient if it still permits duplicate state changes before the limit is reached. Idempotency is required at the receiving mutation boundary.

## Idempotency and Deduplication

Every state-changing cross-network operation SHOULD have a stable idempotency key derived from trusted immutable information.

Receiving systems MUST safely handle:

- duplicate event delivery;
- retry after timeout;
- resource restart and replay;
- export-to-event fallback;
- event-to-export fallback;
- reordered notifications;
- stale revisions;
- delayed consumers.

Duplicate suppression MUST occur before destructive or additive side effects such as creating a second dispatch call, assigning the same unit twice, duplicating an MDT record link, reapplying a medical transition, or generating repeated network notifications.

## Revision and Ordering Rules

1. Network-envelope revisions SHOULD be monotonic per canonical emergency when mutation is necessary.
2. Consumers SHOULD reject or no-op stale state-changing revisions.
3. Pure notifications that do not mutate canonical state MAY be independently timestamped but must preserve event/correlation identity.
4. Domain-resource revisioning remains owned by the domain resource; the network MUST NOT fabricate a newer domain revision to win a conflict.

## Restart and Replay Safety

Runtime cleanup MUST account for resource restarts and dependency startup order.

A safe implementation SHOULD:

- restore enough canonical network metadata to prevent duplicate recreation after restart;
- allow consumers to re-subscribe/reconcile without reminting emergencies;
- make replay explicitly distinguishable from new creation;
- avoid assuming every dependency started in one fixed order;
- fail closed for privileged mutations while allowing safe read-only health degradation where practical;
- preserve existing supported deployment ordering until a tested replacement exists.

## Compatibility Preservation

Phase 3G MUST preserve existing public contracts unless a separately reviewed migration explicitly replaces them.

That includes, where currently used:

- legacy network event names;
- MDT integration aliases;
- exports consumed by other DPN resources;
- resource aliases in `dpn-emergency-network` configuration;
- dispatch/medical/fire/EMS/law-enforcement bridge behavior;
- unique specialty-system events;
- existing deployment/resource naming compatibility.

Compatibility handlers SHOULD normalize into canonical ownership and then become thin adapters. They SHOULD NOT maintain a second business-state implementation.

## No Destructive Consolidation

Runtime implementation MUST NOT bulk-delete resources, events, exports, or version-specific functionality merely because names overlap.

Before removing any code path, the implementation PR MUST prove that either:

1. the path is behaviorally duplicated by the canonical owner and all consumers have migrated; or
2. the path is dead/unreachable and has no unique supported functionality.

If that proof is unavailable, preserve the path behind an adapter and document it for later review.

## Failure and Backpressure Rules

The Unified Emergency Network must degrade predictably when a consumer is unavailable.

Future implementation SHOULD:

- bound retry queues;
- avoid unbounded Lua tables/history growth;
- avoid busy polling loops;
- avoid broadcast storms;
- cap retained hop/delivery metadata;
- record delivery failures without recursively generating emergencies;
- distinguish transient consumer failure from permanent validation rejection;
- prevent one failed optional integration from blocking unrelated emergency consumers.

## Security Requirements

Runtime Phase 3G MUST include explicit checks that:

- canonical creation/mutation authority is server-side;
- trusted origin cannot be spoofed by clients;
- network fan-out cannot be used as a privilege-escalation bypass into MDT, dispatch, Medical Core, or administrative actions;
- arbitrary resource/event names supplied by clients cannot cause unrestricted server event execution;
- payload size and untrusted strings are bounded/validated before persistence or rebroadcast;
- sensitive audit/context fields are not blindly broadcast to all clients;
- denial and validation failures are auditable without leaking secrets.

## Observability Requirements

The network SHOULD expose enough structured telemetry to answer:

- Which canonical emergency was accepted?
- Which resource originated it?
- Which correlation/parent does it belong to?
- Which consumers received it?
- Which deliveries were deduplicated?
- Which deliveries failed and why?
- Which stale revisions were rejected?
- Which compatibility adapter handled a legacy message?
- Did any message reach the loop/hop safeguard?

Telemetry MUST be bounded and SHOULD avoid high-frequency console spam in normal operation.

## Performance Requirements

Implementation review SHOULD reject patterns that add avoidable hot-path cost, including:

- full-player scans for every network event when indexed state is available;
- repeated JSON encode/decode chains between internal adapters;
- duplicate database writes per fan-out consumer;
- unbounded in-memory delivery history;
- per-frame polling for server-owned emergency state;
- recursive event fan-out;
- duplicate coordinate/unit resolution in multiple bridges when a trusted normalized value already exists.

## Required CI Regression Coverage

Before runtime ownership cleanup is merged, CI SHOULD verify at minimum:

1. canonical emergency/correlation IDs cannot be overwritten by client-controlled data;
2. trusted source resource/system metadata is server-derived;
3. duplicate delivery is idempotent;
4. UEN ↔ MDT compatibility cannot recursively create calls;
5. UEN ↔ Dispatch cannot recursively create calls;
6. medical-dispatch fan-out cannot create duplicate general-dispatch incidents;
7. export/event fallback paths execute a state-changing action at most once;
8. stale revisions cannot overwrite newer accepted state;
9. compatibility aliases route through canonical ownership rather than a second owner;
10. bounded replay/restart reconciliation does not mint new canonical emergencies;
11. existing repository security checks, including the MIB authorization regression, remain enabled;
12. unique existing resources/exports/events are not silently removed.

## Recommended Runtime Migration Sequence

When Phase 3G implementation begins after prerequisite phases are integrated:

1. inventory every producer/consumer/adapter and classify current ownership;
2. add tests around existing externally visible behavior;
3. introduce the canonical server-side envelope and idempotency boundary;
4. migrate one producer class at a time into canonical acceptance;
5. migrate one consumer class at a time into idempotent delivery;
6. turn legacy paths into thin adapters while preserving names/contracts;
7. add restart/replay reconciliation;
8. instrument loop/dedup metrics and validate under load;
9. remove only code conclusively proven redundant in a separately reviewed change;
10. update deployment/API documentation after runtime behavior is verified.

## Relationship to Earlier Phases

This preparation document is intentionally independent of unmerged branches, but the final runtime design should compose with the approved sequence:

- Phase 3B: emergency correlation contract;
- Phase 3C: dispatch ownership/dedup;
- Phase 3D: MDT integration;
- Phase 3E: Medical Core consolidation;
- Phase 3F: EMS/Medical Dispatch consolidation;
- Phase 3G: cross-network ownership cleanup after those ownership boundaries are concrete.

Phase 3G MUST consume those canonical ownership decisions rather than re-implement them.

## Exit Criteria for Phase 3G Runtime Work

Phase 3G runtime cleanup is complete only when:

- cross-network ownership is explicit and documented;
- each emergency is canonically accepted once;
- all fan-out paths are idempotent and loop-safe;
- clients cannot author trusted routing/authority metadata;
- restart/replay does not create duplicate emergencies;
- subsystem business-state ownership remains with its designated owner;
- existing supported integrations continue to work through compatibility adapters;
- unique functionality is preserved;
- required CI/security/performance checks are green;
- documentation matches the tested implementation.
