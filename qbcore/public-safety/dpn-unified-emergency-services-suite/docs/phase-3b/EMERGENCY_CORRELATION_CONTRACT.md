# Phase 3B Emergency Correlation Contract

Status: Design contract — preparatory, no runtime behavior changed

## Objective

Every real-world emergency should have one immutable root identity even when it is represented by multiple DPN systems. Dispatch, Medical Dispatch, Incident Command, MDT, Officer Safety, Digital Dispatch, Vehicle Computer, and future emergency-network components must be able to refer to the same event without creating unrelated duplicate records.

## Root identity

### `eventId`

`eventId` is the immutable root identifier for one emergency.

Recommended format:

`EVT-YYYYMMDD-<unix-or-monotonic-component>-<random-suffix>`

Properties:

- generated server-side;
- immutable after creation;
- globally unique enough for one server deployment and durable persistence;
- never based solely on a FiveM player source ID;
- preserved across resource boundaries;
- never replaced just because another subsystem creates its own local record.

## Correlated subsystem identifiers

A correlation record may contain:

```lua
{
    eventId = 'EVT-20260901-1725170000-A1B2C3',
    dispatchCallId = 4812,
    medicalCallId = 'MED-...',
    incidentId = 'INC-...',
    mdtCaseId = 'CASE-...',
    sourceResource = 'dpn-medical-dispatch',
    sourceType = 'medical_distress',
    legacyIds = {
        digitalDispatchId = 123,
        oldCaseId = 'DPN-20260901-4812'
    },
    createdAt = 1725170000,
    updatedAt = 1725170000
}
```

Subsystem identifiers are mutable only in the sense that they may be attached later. The root `eventId` never changes.

## Trust model

### Trusted producers

Server-side DPN resources may pass an existing `eventId` when they are forwarding or enriching an emergency.

### Untrusted producers

Client-originated payloads may suggest context but must not be trusted to assert ownership of a durable `eventId`, `dispatchCallId`, `incidentId`, `medicalCallId`, or `mdtCaseId` without server-side validation.

Recommended server behavior:

1. accept a client request;
2. normalize and validate the payload;
3. resolve an existing correlation only through trusted server mappings;
4. otherwise create a new server-side `eventId`;
5. attach the new local subsystem ID;
6. emit a normalized server-side correlation payload.

## Canonical normalized payload

All participating systems should gradually support a shared envelope:

```lua
{
    correlation = {
        eventId = 'EVT-...',
        dispatchCallId = nil,
        medicalCallId = nil,
        incidentId = nil,
        mdtCaseId = nil,
        sourceResource = 'dpn-dispatch',
        sourceType = '911',
        legacyIds = {}
    },
    event = {
        code = '911',
        title = 'Emergency Call',
        description = '...',
        priority = 2,
        departments = { 'law', 'ems', 'fire' },
        location = '...',
        coords = { x = 0.0, y = 0.0, z = 0.0 }
    },
    metadata = {}
}
```

Legacy flat payloads remain accepted during migration.

## Correlation ownership

### Core Dispatch

`dpn-dispatch` should own the canonical `dispatchCallId` and maintain a fast lookup from `eventId -> dispatchCallId`.

### Medical Dispatch

`dpn-medical-dispatch` owns `medicalCallId` and must preserve the root `eventId` when bridging to core Dispatch.

### Incident Command

`dpn-incident-command` owns `incidentId`. Creating an incident from an existing dispatch call must attach to the same `eventId`. It should create a new dispatch call only when no correlated call exists and the incident genuinely originated outside Dispatch.

### MDT

`dpn-mdt` owns `mdtCaseId`. Sync operations must be idempotent by `eventId` and/or `dispatchCallId` so repeated calls update the same MDT case.

### Digital Dispatch

`dpn-digital-dispatch` should evolve into a specialized presentation/operations companion. During migration it may keep its own local IDs, but those IDs must be stored under `legacyIds` or a dedicated companion field and tied to the same root event.

## Required core APIs

Recommended shared/canonical APIs:

```lua
exports('EnsureEmergencyCorrelation', function(payload) end)
exports('GetEmergencyCorrelation', function(eventId) end)
exports('FindEmergencyByDispatchCall', function(dispatchCallId) end)
exports('AttachEmergencyIdentifier', function(eventId, identifierType, value) end)
exports('ResolveOrCreateEmergency', function(payload) end)
```

These functions should be server-only where possible and reject malformed identifiers.

## Dispatch changes

Core Dispatch `CreateCall` should eventually:

1. normalize correlation input;
2. resolve existing trusted `eventId`;
3. if an active call already exists for that `eventId`, return the existing call instead of creating another;
4. otherwise allocate a new call ID;
5. attach `dispatchCallId` to correlation;
6. persist both call and correlation metadata;
7. sync MDT using the same `eventId`;
8. broadcast only one canonical new-call event.

## Legacy deduplication

Not all callers will provide `eventId` immediately. A temporary compatibility deduplication layer may compare:

- source resource;
- source player/citizen ID where appropriate;
- incident type/code;
- rounded coordinates or postal;
- message/title fingerprint;
- short time window.

Heuristic deduplication must never silently merge clearly different active emergencies. `eventId` remains authoritative when present.

## Idempotency rules

- `CreateCall(eventId=X)` called twice returns the same canonical dispatch call while active unless explicitly forced by a trusted administrative path.
- `CreateCaseFromDispatch(eventId=X)` called twice returns/updates the same MDT case.
- `CreateIncident(eventId=X)` called twice should return or update the same active Incident Command record when appropriate.
- Medical-to-dispatch bridging with the same `eventId` must not create duplicate CAD calls.
- Companion notifications may repeat if required, but durable records must not duplicate.

## Lifecycle states

Correlation should survive local subsystem state changes:

`created -> active -> stabilized/resolved -> closed -> archived`

Subsystems may have their own statuses. Closing one subsystem record does not erase the root correlation.

## Persistence

Preferred long-term schema:

```sql
CREATE TABLE IF NOT EXISTS dpn_emergency_correlations (
    event_id VARCHAR(96) PRIMARY KEY,
    dispatch_call_id VARCHAR(96) NULL,
    medical_call_id VARCHAR(96) NULL,
    incident_id VARCHAR(96) NULL,
    mdt_case_id VARCHAR(96) NULL,
    source_resource VARCHAR(96) NOT NULL,
    source_type VARCHAR(64) NOT NULL,
    legacy_ids LONGTEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_dispatch_call (dispatch_call_id),
    INDEX idx_medical_call (medical_call_id),
    INDEX idx_incident (incident_id),
    INDEX idx_mdt_case (mdt_case_id)
);
```

Exact SQL should be adapted to the repository's existing database conventions before implementation.

## Events

Recommended normalized server events:

- `dpn-emergency:server:correlationCreated`
- `dpn-emergency:server:correlationUpdated`
- `dpn-emergency:server:identifierAttached`
- `dpn-emergency:server:eventResolved`

Compatibility aliases remain resource-specific until later deprecation phases.

## Validation rules

- Maximum identifier lengths.
- Strict allowed identifier characters.
- Bounded metadata sizes.
- Bounded `legacyIds` entries.
- Valid finite coordinates.
- Valid source resource names from server context when possible.
- Reject client attempts to overwrite an existing root correlation.
- Reject changing `eventId` on an existing durable record.

## Observability

Every durable subsystem record should expose the root `eventId` in admin/debug views. Logs should include both root and local IDs, for example:

`[DPN Dispatch] event=EVT-... dispatch=4812 incident=INC-... status=updated`

This makes duplicate-routing and cross-resource failures diagnosable.

## Migration stages

### Stage 1 — compatibility foundation

Add the correlation structure and server helpers without removing any existing event or command.

### Stage 2 — canonical Dispatch adoption

Add `eventId` to core Dispatch create/update/database/MDT payloads and return existing calls for duplicate trusted `eventId` values.

### Stage 3 — producer propagation

Update Medical Dispatch, Incident Command, Officer Safety, Vehicle Computer, and Digital Dispatch to preserve the root ID.

### Stage 4 — MDT implementation

Implement the documented MDT sync exports with idempotent correlation behavior.

### Stage 5 — heuristic legacy deduplication

Protect old integrations that do not yet send root IDs.

### Stage 6 — ownership consolidation

Move Digital Dispatch and other companions away from creating competing canonical emergency records while preserving their specialized UI/operational features.

## Non-goals for Phase 3B

- Removing historical medical feature layers.
- Removing Digital Dispatch.
- Removing compatibility command aliases immediately.
- Merging Phase 3A automatically.
- Replacing all subsystem IDs with one ID.
- Making every emergency resource hard-dependent on MDT or Medical Dispatch.

Phase 3B establishes identity and correlation first. Ownership consolidation follows only after the correlation contract is proven.