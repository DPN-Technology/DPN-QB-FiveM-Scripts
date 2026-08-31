# DPN Unified Emergency Service Network - Advanced Edition

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


A FiveM/QBCore emergency-services network core that ties DPN Law Enforcement, EMS, Fire, Courts, Corrections, Bail Bonds, Tow/Mechanic, Dispatch, Bodycam, StarChase, MDT, and MIB/Admin systems together.

## What was upgraded

- Fixed duplicate units by using a stable citizenid-based unit key with source fallback.
- Server-side unit index cleanup on job changes, duty changes, stale units, and disconnects.
- Client-side de-dupe protection in the NUI.
- Advanced Command Center UI with dashboard, incidents, units, BOLOs, mutual aid, scene command, triage, and audit panels.
- Incident lifecycle: created, assigned, enroute, onscene, staged, transporting, hospital, resolved, archived.
- Scene commander tools with command-agency tracking.
- Multi-agency support requests for law, EMS, fire, justice, corrections, bail, tow, and MIB/admin.
- BOLO system with plate, suspect, vehicle, priority, and archive support.
- Mass-casualty triage counters for red/yellow/green/black patients.
- Incident objectives and notes for tactical scene management.
- Persistent incident payload storage for linked records, evidence, suspects, vehicles, triage, history, objectives, and notes.
- Audit logging for UI access, unit status changes, incident creation, assignment, support requests, and command changes.
- Integration exports for other DPN systems.

## Install

1. Place `dpn-unified-emergency-network` in your resources folder.
2. Import `sql/install.sql` into your database.
3. Add this to `server.cfg`:

```cfg
ensure oxmysql
ensure qb-core
ensure dpn-unified-emergency-network
```

4. Configure jobs in `shared/config.lua` to match your server job names.
5. Use `/unes` while on duty in an authorized emergency-service job.
6. Use `/panic` for responder panic activation.

## Recommended integrations

Other DPN scripts can create incidents with:

```lua
exports['dpn-unified-emergency-network']:CreateIncident(source, {
    type = 'shots_fired',
    title = 'Shots Fired',
    description = 'Automatic call generated from bodycam/shot detection.',
    priority = 1,
    agencies = {'law','ems'}
})
```

They can link records with:

```lua
exports['dpn-unified-emergency-network']:LinkRecord(incidentId, 'dpn-mdt', 'report', reportId, { officer = callsign })
```

Create BOLOs with:

```lua
exports['dpn-unified-emergency-network']:CreateBolo(source, {
    title = 'Armed robbery suspect',
    plate = 'ABC123',
    vehicle = 'Black Sultan',
    suspect = 'Unknown male',
    description = 'Last seen fleeing northbound.',
    priority = 1
})
```

## Notes

This is a production-ready foundation, but every city has different job names, hospital scripts, MDT APIs, dispatch APIs, and inventory systems. Update `shared/config.lua` and `server/integrations.lua` for your exact resources.

## v4 Mega Advanced Live Map Fix

### Fixed
- Live Operations Map no longer depends on any external map image or map library.
- Added GTA/FiveM world-coordinate projection fallback so unit and incident dots render even on fresh installs.
- Added on-demand GPS refresh from the NUI using `refreshSnapshot`.
- Added auto snapshot refresh every 30 seconds while the UI is open.
- Removed duplicate unit NUI handler from `client/agency.lua` to prevent double renders and unstable map data.
- Added stronger coordinate validation so bad `{0,0}` or missing coords do not break the map.

### Added
- Click-to-waypoint from live map dots and the map point list.
- Map point side list showing unit/incident location sources.
- Responder Safety Board for stale GPS, off-radio/out-of-service units, assigned units, and priority-1 calls.
- Hospital / EMS Coordination board for transports, MCI, medical, and collision calls.
- Fire / Rescue Operations board for fire, rescue, MCI, and collision calls.
- More opaque panel styling for cleaner section switching.

### Live Map Notes
- Responders must be on-duty in a configured emergency job.
- The client sends GPS when the responder first loads and whenever they move more than 2 meters.
- If the map looks empty, press **Refresh GPS** in the map legend, verify duty status, and make sure the player has moved slightly.

## v5 Live Map Hard Fix + Advanced Command Upgrade

This build replaces the previous live map marker logic with a FiveM-safe self-contained coordinate board.

### What was fixed
- Fixed the broken marker projection bug where the UI passed the full map-point object instead of the `coords` object, causing `left: NaN%` / `top: NaN%` and no visible live map markers.
- Added forced GPS sync when the UI opens.
- Added forced GPS sync when the dispatcher presses **Refresh GPS**.
- Added delayed snapshot reload after opening the UI so the map can recover even if the first payload is stale.
- Added GPS diagnostics showing units without usable coordinates and incidents without coordinates.
- Added zone labels and rough operational regions for Los Santos, Sandy Shores, Paleto/Blaine County, west county, east LS, and port/south LS.

### New advanced features
- Operations Intelligence panel.
- Run Cards panel for quick incident command summaries.
- Zone load summary inside the live map side panel.
- Better no-GPS troubleshooting visibility for dispatchers and command staff.
- Stronger waypoint support for both unit and incident markers.

### Live map troubleshooting
1. Make sure the player is on duty in a configured emergency-service job.
2. Open `/uen`.
3. Press **Live Map**.
4. Press **Refresh GPS**.
5. If a unit appears under “Units without GPS,” verify that client location events are not being blocked and that the player ped exists.

This map does not depend on Leaflet, external tile servers, custom minimap images, or browser permissions. It uses GTA/FiveM world coordinates directly.

## v6 Live Map Hard Rebuild + Advanced Call/BOLO Workflow

This build replaces the live map with an internal NUI-safe GTA coordinate projection. It does **not** depend on external map JS, leaflet tiles, image assets, internet access, or CEF features that commonly fail in FiveM NUI. The map is a self-contained tactical radar grid with:

- Forced GPS refresh every 10 seconds while the UI is open.
- Server snapshot refresh button.
- Unit and incident waypoint support.
- No-GPS unit warnings.
- Stale-unit visual warning.
- Incident and responder dots rendered directly from GTA world X/Y coordinates.

Advanced incident creation now supports caller, callback, staging location, hazard level, auto-start objectives, priority routing, and multi-agency routing. BOLOs now support priority, last-seen location, threat/officer-safety notes, tags, vehicle, plate, suspect, and linked intelligence display.

New command-center panels:

- Critical Risk Board
- Advanced Call Queue
- BOLO Intelligence Center
- Self-contained Live Operations Map

If the map still appears empty, verify that the unit is on duty in a configured emergency job, open `/uen`, press **Force GPS Refresh**, and check the **No GPS Units** list. Units are only shown after the server receives their player coordinates.


## v7 Oulsen Satmap Live Map Fix

This version is built for servers using `oulsen_satmap`. The important part: `oulsen_satmap` streams the in-game minimap as `.ytd` textures. A FiveM NUI page cannot directly display those streamed `.ytd` files as an HTML background. To make the dispatch map work, this resource now uses the same GTA world-coordinate alignment as Oulsen and expects a static exported map image at:

`dpn-unified-emergency-network/html/img/oulsen_satmap.png`

Recommended setup:
1. Keep `ensure oulsen_satmap` above `ensure dpn-unified-emergency-network` in `server.cfg`.
2. Export or screenshot your Oulsen satmap image as a PNG/JPG.
3. Place it at `html/img/oulsen_satmap.png`.
4. Restart the resource.
5. Open `/unes`, go to **Oulsen Live Map**, and click **Force GPS Refresh**.

The live dots will still render even if the PNG is missing. The right-side diagnostics will show how many units have GPS, stale GPS, and no GPS.

### New v7 advanced workflow fields
- Incident cross street / landmark
- Tactical radio channel
- Response mode: normal, hot, silent, or staged
- BOLO risk indicators
- BOLO notify-agency routing
- Server console GPS debug button
