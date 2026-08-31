# dpn-smart-city

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Advanced DPN Technology smart-city law enforcement network for FiveM.

## What it does

- Citywide traffic camera grid
- Gunshot/acoustic detection zones
- Speed camera alerts
- BOLO plate detection
- Smart dispatch event creation
- Traffic light override nodes for emergencies and scenes
- NUI command dashboard
- Webhook logging
- SQL event history
- Exports for other DPN resources

## Required

- FiveM artifact with Lua 5.4
- `oxmysql`
- Run `sql/install.sql`

## Optional integrations

This resource automatically attempts to integrate with:

- `dpn-le-core`
- `dpn-digital-dispatch`
- `dpn-vehicle-computer`
- `dpn-incident-command`
- `dpn-evidence-ai`
- QBCore / ESX / standalone mode

## Install

1. Drop `dpn-smart-city` into your resources folder.
2. Run `sql/install.sql` in your database.
3. Add this after dependencies in `server.cfg`:

```cfg
ensure oxmysql
ensure dpn-le-core
ensure dpn-digital-dispatch
ensure dpn-vehicle-computer
ensure dpn-incident-command
ensure dpn-evidence-ai
ensure dpn-smart-city
```

4. Set permissions if using ACE:

```cfg
add_ace group.admin dpn.smartcity allow
add_ace group.admin dpn.smartcity.admin allow
```

## Commands

- `/smartcity` opens the dashboard.
- Default keybind: `F7`.

## Main systems

### BOLO network

Officers can add flagged plates from the UI. When a player drives through a configured camera zone, the system checks the plate and creates an alert if matched.

### Gunshot detection

When shots are fired inside configured acoustic detection zones, the system creates a smart alert and dispatch call.

### Speed cameras

Traffic cameras detect vehicles driving over the configured threshold and create low-priority enforcement alerts.

### Traffic control

Configured traffic nodes can be switched to:

- `emergency`
- `scene`
- `normal`

This is designed to integrate with your traffic-light scripts later.

## Exports

### Server

```lua
exports['dpn-smart-city']:AddBolo(plate, reason, priority)
exports['dpn-smart-city']:ClearBoloByPlate(plate)
exports['dpn-smart-city']:CreateSmartAlert(eventType, title, message, coords, priority)
```

### Client

```lua
exports['dpn-smart-city']:OpenSmartCity()
exports['dpn-smart-city']:GetActiveBolos()
exports['dpn-smart-city']:IsPlateBolo(plate)
```

## Notes

This script is intentionally modular. It does not force compatibility with one traffic-light script. The override events are exposed so you can connect it to `ts_Trafficlights` or any other traffic-control resource.
