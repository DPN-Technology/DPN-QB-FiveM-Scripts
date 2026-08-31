# DPN Dispatch Live View Workflow

This resource now includes a browser preview mode for the CAD/RMS/MDT interface.

## Browser Preview

Open:

```text
html/index.html
```

outside FiveM. If the file is opened in a normal browser, the UI automatically loads mock live data and lets you click through the workflow without needing a running server.

The preview demonstrates:

- Active CAD calls
- Agency color modes: law dark blue, EMS orange, fire red, justice grey, MIB black, corrections brown
- Live Command tab with agency-specific SOPs, AVL/unit view, BOLO/safety alerts, current focus incident, and supervisor queue
- Unit roster and unit status updates
- Manual call creation with incident class, response level, staging, command, radio channel, risk flags, units requested, and response plan
- Panic button creation
- Report board
- Report builder
- Report submission workflow
- MDT sync references
- Audit and call notes

In browser preview mode, button actions mutate local mock data only. Inside FiveM, the same buttons call real NUI callbacks and server events.

## In-Game Live Flow

1. Start the resource:

```text
ensure dpn-dispatch
```

2. Open CAD as an authorized dispatcher/unit:

```text
/dispatch
```

or press the configured dispatch keybind.

3. A civilian or staff member can create a 911 call:

```text
/911 I need police, EMS, and fire at Postal 302 for a crash with fire.
```

4. Dispatch sees the call appear in Active Calls with priority, location, departments, caller, tags, notes, GPS, incident class, response level, staging area, command, radio channel, units requested, risk flags, and SOP response plan.

5. Units assign themselves or dispatch manually assigns units.

6. Responding units update status:

```text
/unitstatus enroute
/unitstatus onscene
/unitstatus transporting
/unitstatus corrections
/unitstatus available
```

7. Dispatch or the responding unit opens the report builder from the call card and creates an RMS report linked to the CAD case ID. The report builder includes involved persons, vehicles, evidence, medical/fire/court/corrections/admin notes, risk flags, dispatch timeline, supervisor notes, QA checklist, and property/chain-of-custody fields.

8. Reports move through:

```text
Draft -> Submitted -> Supervisor Review -> Court/DOJ Review -> Approved/Returned/Rejected/Archived
```

9. If `dpn-mdt` is running and configured, the dispatch system mirrors calls, units, and reports through the MDT bridge events and optional exports.

## dpn-mdt Bridge Events

The dispatch system emits these events:

```lua
dpn-mdt:server:dispatchCallCreated
dpn-mdt:server:dispatchCallUpdated
dpn-mdt:server:dispatchReportCreated
dpn-mdt:server:dispatchReportUpdated
dpn-mdt:server:dispatchUnitUpdated
```

The bridge can also call optional exports if they exist:

```lua
exports['dpn-mdt']:CreateCaseFromDispatch(payload)
exports['dpn-mdt']:SyncDispatchCall(payload)
exports['dpn-mdt']:UpdateDispatchCall(payload)
exports['dpn-mdt']:SyncDispatchReport(payload)
exports['dpn-mdt']:UpdateDispatchReport(payload)
exports['dpn-mdt']:AttachDispatchReport(payload)
```

If your `dpn-mdt` uses different export names, update `Config.MDT.exports` in `shared/config.lua`.
