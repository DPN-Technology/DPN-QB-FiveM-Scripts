# DPN Unified Emergency Services Architecture

The suite uses layered integration rather than treating police, EMS, fire/rescue, dispatch, and MDT as isolated systems.

## Layer 1 — Framework and persistence

`qb-core` provides player/job state and `oxmysql` provides persistence where used.

## Layer 2 — Domain cores

- `dpn-le-core` owns the law-enforcement domain foundation.
- `dpn-medical-core` owns authoritative injury/medical state.
- `dpn-unified-emergency-network` provides cross-agency operational coordination.
- `dpn-emergency-network` provides canonical inter-resource event routing/health correlation for the DPN emergency ecosystem.

## Layer 3 — Dispatch and command

- `dpn-dispatch` is the broad unified CAD/RMS dispatch surface spanning law, EMS, fire/rescue, justice, corrections, and admin response.
- `dpn-digital-dispatch` plugs into the law-enforcement core.
- `dpn-medical-dispatch` handles EMS/medical response workflow.
- `dpn-incident-command` coordinates multi-agency incidents.

## Layer 4 — MDT and records

`dpn-mdt` is the cross-department terminal connecting law enforcement, EMS, fire/rescue, courts, corrections, dispatch, records, evidence, warrants, BOLOs, and audit data.

## Layer 5 — Specialist modules

Law-enforcement and medical specialist resources build on the shared cores and network layers.

## Integration Rule

When changing an event/export name, search the entire suite before renaming it. Cross-resource contracts are part of the platform API.
