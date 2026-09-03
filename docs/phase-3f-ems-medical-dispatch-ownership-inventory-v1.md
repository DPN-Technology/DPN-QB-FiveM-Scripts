# Phase 3F — EMS / Medical Dispatch Ownership Inventory v1

## Purpose

This inventory is the first runtime-safe Phase 3F consolidation slice. It records the ownership boundary observed on current secured `main` after Phase 3E integration. No runtime behavior is changed by this document.

## Canonical ownership observed

### `dpn-medical-dispatch`

Canonical owner for medical emergency workflow coordination:

- active medical call registry (`activeCalls`)
- call creation and persistence
- caller/patient dispatch payload construction
- external dispatch bridge creation/update
- responder registry and responder lifecycle state
- call assignment/status transitions
- responder notifications and routing
- call expiry/cleanup
- public dispatch exports (`CreateMedicalCall`, `GetActiveMedicalCalls`, `GetResponderStatus`, `UpdateMedicalCall`, `GetDispatchBridgeHealth`)

This resource must remain the single medical-dispatch workflow authority unless a later focused migration explicitly changes ownership.

### `dpn-medical-ems`

Canonical owner for EMS field-treatment gameplay:

- treatment authorization and proximity checks
- field revive
- patient carry/release
- triage/vitals inspection
- EMS duty command
- patient care report creation
- Medical Core treatment/revive calls
- optional medical-record entry creation

This resource should consume dispatch state where required but must not become a second canonical medical-call or responder-lifecycle owner.

### `dpn-medical-core`

Remains canonical owner for patient medical state and persistence under Phase 3E. Neither EMS nor Medical Dispatch may create a competing patient-state cache or persistence authority.

### `dpn-dispatch`

Remains the generic cross-agency dispatch owner established by preceding phases. `dpn-medical-dispatch` may bridge medical incidents into it, but must not create duplicate generic dispatch identities for one correlated emergency.

## Historical layers

Both medical resources still load multiple historical `server/vN.lua` layers. These layers are treated as unique until capability parity is proven. Phase 3F v1 does not retire, unload, or rewrite historical layers.

## Phase 3F invariants

1. `dpn-medical-dispatch/server/main.lua` remains the only canonical owner of `activeCalls` and `responders`.
2. `dpn-medical-ems/server/main.lua` must not introduce a competing medical-call registry.
3. Medical Core remains the patient-state authority.
4. External dispatch integration must preserve one logical emergency as one canonical dispatch identity.
5. Responder lifecycle transitions remain server-authoritative.
6. Existing public events, commands, exports, configuration names, and unique gameplay behavior remain compatible.
7. Historical layers are not removed until repository-wide parity evidence exists.

## Next runtime slices

- add a bounded canonical medical-call identity/correlation adapter where needed;
- audit all historical EMS and Medical Dispatch layers for duplicate call/responder ownership;
- route duplicate creation paths through the canonical `dpn-medical-dispatch` owner;
- add targeted idempotency and responder-transition regression tests;
- preserve restart and persistence behavior;
- retire duplicate historical ownership only after explicit parity proof.
