# dpn-incident-command

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Advanced Incident Command System for FiveM law enforcement, fire, and EMS RP.

## Features
- Active incident command scenes
- Commander/supervisor permission support
- Staging area markers
- Roadblock markers
- Search grid markers
- Unit assignment and division tracking
- Dispatch integration hook
- Vehicle computer compatible export design
- QBCore, ESX, and standalone bridge support
- SQL logging for incident history

## Install
1. Place `dpn-incident-command` in your resources folder.
2. Import `sql/install.sql` into your database.
3. Ensure dependencies before this resource:
   ```cfg
   ensure oxmysql
   ensure dpn-le-core
   ensure dpn-digital-dispatch
   ensure dpn-incident-command
   ```
4. Configure jobs, ranks, and ACE permissions in `config.lua`.

## Commands
- `/ics` opens the incident command UI.
- Default keybind: `F7`.

## ACE permissions
```cfg
add_ace group.admin dpn.incident.command allow
add_ace group.admin dpn.incident.supervisor allow
```

## Exports
```lua
exports['dpn-incident-command']:OpenIncidentCommand()
exports['dpn-incident-command']:GetIncidents()
local incidentId = exports['dpn-incident-command']:CreateIncident('Major Crash', 'traffic', 'high', coords, 'Multiple vehicles involved')
```
