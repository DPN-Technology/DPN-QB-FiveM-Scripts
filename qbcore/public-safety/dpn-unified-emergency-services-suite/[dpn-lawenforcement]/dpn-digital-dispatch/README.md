# dpn-digital-dispatch

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Advanced dispatch resource for FiveM, designed to plug into `dpn-le-core`.

## Features
- /dispatch emergency operations UI
- /911 civilian emergency calls
- /panic officer panic button
- F7 dispatch console keybind
- F10 panic keybind
- Active call creation, assignment, closeout
- Unit status tracking
- GPS call blips and waypoints
- Automatic shots fired alerts
- Automatic officer crash alerts
- QBCore, ESX, and standalone support
- oxmysql persistence
- Discord webhook logging
- Exports for other DPN scripts

## Install
1. Put `dpn-digital-dispatch` in your resources folder.
2. Import `sql/install.sql`.
3. Ensure dependencies in server.cfg:

```cfg
ensure oxmysql
ensure dpn-le-core
ensure dpn-digital-dispatch
add_ace group.admin dpn.dispatch allow
add_ace group.admin dpn.dispatch.supervisor allow
```

## Exports
```lua
exports['dpn-digital-dispatch']:CreateDispatchCall({
  type = 'backup',
  title = 'Backup Request',
  description = 'Officer requesting backup.',
  coords = { x = 0.0, y = 0.0, z = 0.0 },
  priority = 2
})

local calls = exports['dpn-digital-dispatch']:GetActiveCalls()
local units = exports['dpn-digital-dispatch']:GetUnits()
```
