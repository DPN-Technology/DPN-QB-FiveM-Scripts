# dpn-dispatch

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.



## Live View / Browser Preview

You can open `html/index.html` directly in a normal browser to preview the live CAD/RMS/MDT interface with mock data. This is only a visual and workflow demo outside FiveM. In-game, the same UI uses real NUI callbacks, QBCore server events, SQL logging, unit status updates, GPS, and `dpn-mdt` sync.

See `docs/live_view_workflow.md` for the full live workflow.

Advanced DPN Unified Dispatch System for QBCore/FiveM.

This resource connects law enforcement, EMS, fire/rescue, justice/courts, corrections, and MIB/admin response into one unified dispatch command center. It now includes a full reporting/RMS UI, department-colored agency modes, a live command board, and a safe bridge for `dpn-mdt`.

## Core Features

- Unified CAD dispatch center using FiveM NUI.
- Department-based call routing:
  - Law Enforcement
  - EMS
  - Fire / Rescue
  - Justice / Courts
  - Corrections / Detention
  - MIB / Admin Response
- Active call board with priorities, statuses, notes, caller info, location, GPS, assigned units, case IDs, and linked reports.
- Unit roster with callsigns, jobs, departments, status, radio channel, assignment, and last-seen tracking.
- Panic button system with priority panic dispatch calls.
- `/911` public emergency call command.
- `/panic` emergency unit panic command.
- `/unitstatus` command for quick unit status changes.
- F7 default dispatch UI keybind.
- CAD analytics bar showing active calls, critical calls, available units, open reports, pending review, and sealed reports.
- Optional Discord webhook logging.
- Optional `oxmysql` SQL logging.
- Server/client exports and events for DPN police, EMS, fire, court, MIB/admin, traffic, medical, and justice scripts.


## Department Color Modes / Live Command View

The NUI now has agency mode buttons across the top. Selecting a mode changes the entire command center theme and preloads that agency's incident classes and SOP checklist.

Requested colors are built in:

- Law Enforcement: dark blue
- EMS: orange
- Fire / Rescue: red
- Justice / Courts: grey
- MIB / Admin: black
- Corrections / Detention: brown

The new **Live Command** tab gives a realistic CAD command-board view with:

- Agency-specific active call count
- Critical-call count
- Available-unit/AVL-style roster
- Current focus incident
- Risk and safety flags
- BOLO-style safety alerts
- SOP / recommended response checklist
- Supervisor/RMS review queue
- MDT/RMS link awareness

## Advanced Reporting UI

The new reporting module adds a full RMS-style report workflow inside the dispatch NUI.

Included report tools:

- Searchable report board.
- Advanced report builder.
- Convert a live dispatch call into a linked report.
- Link reports to CAD calls and shared case IDs.
- Report types:
  - General Incident Report
  - Law Enforcement Incident
  - Arrest / Booking Report
  - Traffic Stop / Collision Report
  - EMS Patient Care Report
  - Fire / Rescue Incident Report
  - HazMat / Utility Report
  - Court / DOJ Action Report
  - Corrections / Detention Report
  - MIB / Admin Sensitive Report
- Structured report sections:
  - Involved persons
  - Vehicles
  - Witnesses
  - Evidence and attachment links
  - Charges / citations
  - Medical notes
  - Fire / rescue notes
  - Court / DOJ notes
  - Corrections / detention notes
  - Risk / safety flags
  - Dispatch timeline
  - Supervisor notes
  - Disposition / outcome
  - MDT/external links
  - QA checklist
  - NCIC/warrant/records checks
  - Property / chain-of-custody
  - MIB / admin actions
- Report statuses:
  - Draft
  - Submitted
  - Supervisor Review
  - DOJ / Court Review
  - Approved
  - Returned for Correction
  - Rejected / Voided
  - Archived
- Sealed, confidential, and locked report options.
- Restricted access for sealed/confidential reports when enabled.
- Report audit trail with creator and update actions.
- SQL table support through `dpn_dispatch_reports`.

## dpn-mdt Integration

`dpn-dispatch` is designed to work with `dpn-mdt` without hard-crashing if your MDT uses different export names.

The bridge does three things:

1. Fires generic server events that `dpn-mdt` can listen for.
2. Calls optional `dpn-mdt` exports using protected `pcall`.
3. Stores MDT references on calls/reports so both systems can cross-link records.

Default MDT events fired by dispatch:

```lua
dpn-mdt:server:dispatchCallCreated
dpn-mdt:server:dispatchCallUpdated
dpn-mdt:server:dispatchReportCreated
dpn-mdt:server:dispatchReportUpdated
dpn-mdt:server:dispatchUnitUpdated
```

Default optional MDT exports dispatch attempts to call:

```lua
exports['dpn-mdt']:CreateCaseFromDispatch(payload)
exports['dpn-mdt']:SyncDispatchCall(payload)
exports['dpn-mdt']:UpdateDispatchCall(payload)
exports['dpn-mdt']:SyncDispatchReport(payload)
exports['dpn-mdt']:UpdateDispatchReport(payload)
exports['dpn-mdt']:AttachDispatchReport(payload)
```

If your `dpn-mdt` uses different names, edit this block in `shared/config.lua`:

```lua
Config.MDT.exports = {
    enabled = true,
    syncCall = 'SyncDispatchCall',
    updateCall = 'UpdateDispatchCall',
    syncReport = 'SyncDispatchReport',
    updateReport = 'UpdateDispatchReport',
    createCaseFromCall = 'CreateCaseFromDispatch',
    attachReportToCase = 'AttachDispatchReport'
}
```

`dpn-mdt` can also create dispatch records using:

```lua
TriggerEvent('dpn-dispatch:server:mdtCreateCall', data)
TriggerEvent('dpn-dispatch:server:mdtCreateReport', data)
```

## Installation

1. Drop the folder into your server resources:

```text
resources/[dpn]/dpn-dispatch
```

2. Add this to `server.cfg`:

```text
ensure dpn-dispatch
```

3. Make sure `qb-core` starts before `dpn-dispatch`.

4. If using MDT, start `dpn-mdt` before or alongside dispatch:

```text
ensure dpn-mdt
ensure dpn-dispatch
```

5. Configure jobs in `shared/config.lua` to match your server job names.

6. Optional SQL logging:
   - Import `docs/install.sql`.
   - Set `Config.Database.enabled = true`.
   - Make sure `oxmysql` is started before this resource.

7. Optional ACE permission:

```text
add_ace group.admin dpn.dispatch allow
add_ace group.admin dpn.dispatch.admin allow
```

## Default Commands

```text
/dispatch              Opens dispatch center
/report                Opens dispatch directly to the report builder
/911 [message]         Sends a public emergency call to law/EMS/fire
/panic                 Activates emergency unit panic call
/unitstatus [status]   Sets unit status
```

Valid unit statuses:

```text
available, busy, enroute, onscene, transporting, court, corrections, unavailable
```

## Server Exports

Create a dispatch call from any server resource:

```lua
exports['dpn-dispatch']:CreateCall({
    code = '10-70',
    title = 'Structure Fire',
    description = 'Smoke showing from a commercial building.',
    departments = { 'fire', 'ems', 'law' },
    priority = 1,
    incidentClass = 'structure_fire',
    responseLevel = 'critical',
    riskFlags = { 'entrapment', 'gas meter exposed' },
    staging = 'Hydrant Alpha corner',
    command = 'Engine 1 Command',
    radioChannel = 'FIRE TAC 2',
    unitsRequested = { 'Engine', 'Medic', 'Law traffic control' },
    recommendedResponse = { 'Primary search', 'Utility shutoff', 'Hydrant/preplan check' },
    location = 'Downtown Los Santos',
    coords = { x = 215.22, y = -810.44, z = 30.73 },
    meta = {
        sourceResource = 'dpn-fire-system'
    }
})
```

Create a report from another resource:

```lua
exports['dpn-dispatch']:CreateReport({
    type = 'fire',
    title = 'Structure Fire After-Action',
    summary = 'Commercial structure fire with EMS standby.',
    narrative = 'Engine 1 arrived on scene and established command.',
    department = 'fire',
    callId = 1001,
    status = 'supervisor_review',
    involved = {
        fire = { 'Origin: rear storage room', 'Utilities secured', 'Primary search clear' },
        evidence = { 'Photo set: discord-cdn-link', 'Hydrant pressure report uploaded' },
        riskFlags = { 'Utility hazard', 'Smoke exposure' },
        dispatchTimeline = { 'Call received', 'Engine dispatched', 'Command established', 'Utilities secured' },
        qaChecklist = { 'Narrative complete', 'Evidence attached', 'Supervisor review ready' }
    }
})
```

Update a call:

```lua
exports['dpn-dispatch']:UpdateCall(1001, {
    status = 'onscene',
    note = 'First unit arrived on scene.'
})
```

Update a report:

```lua
exports['dpn-dispatch']:UpdateReport(5001, {
    status = 'approved',
    auditAction = 'approved_by_supervisor'
})
```

Get active records:

```lua
local calls = exports['dpn-dispatch']:GetCalls()
local units = exports['dpn-dispatch']:GetUnits()
local reports = exports['dpn-dispatch']:GetReports()
```

## Client Exports

Create a dispatch call from a client resource using the player location:

```lua
exports['dpn-dispatch']:CreateClientCall({
    code = 'MED-2',
    title = 'Trauma Response',
    description = 'Civilian down with major injuries.',
    departments = { 'ems', 'law' },
    priority = 1
})
```

Create a client-side report with the player GPS:

```lua
exports['dpn-dispatch']:CreateClientReport({
    type = 'medical',
    title = 'EMS Patient Care Report',
    summary = 'Patient treated and transported.',
    narrative = 'EMS assessment completed and patient transported to Pillbox.',
    department = 'ems',
    status = 'submitted'
})
```

## Recommended DPN Integrations

- `dpn-le-core`: pursuits, shots fired, officer panic, warrants, arrests, traffic stops, citations, booking reports.
- `dpn-medical-system`: injury alerts, EMS patient care reports, hospital transports, trauma, cardiac calls.
- `dpn-fire-system`: structure fires, vehicle fires, hazmat, rescue calls, weather-linked incidents, hydrants, utilities, fire reports.
- `dpn-justice-system`: summons, court transports, warrant review, subpoenas, bail bond requests, court action reports.
- `dpn-mib-system`: admin scenes, MIB callouts, sealed reports, sensitive incidents, scene security.
- `dpn-real-traffic`: automatic MVA alerts and road hazard dispatch calls.
- `dpn-mdt`: case records, warrant/citation/arrest records, evidence links, unit lookups, report review.

## Notes

This resource is built as an advanced production starter. Review job names, ACE permissions, SQL settings, Discord webhooks, and `dpn-mdt` export names before deploying to a live server.
