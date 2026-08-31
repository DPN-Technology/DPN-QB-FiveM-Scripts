# dpn-officer-safety

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Advanced DPN Technology officer safety system for FiveM.

## Features
- Panic button
- Automatic officer down alerts
- Crash severity detection
- Shots fired alerts
- Weapon drawn monitoring
- Welfare checks
- Vehicle pursuit and foot pursuit detection
- Simulated heart rate and stress
- NUI safety dashboard
- GPS alert blips
- Dispatch and incident command integration hooks
- SQL logging and Discord webhook support

## Install
1. Put `dpn-officer-safety` in your resources folder.
2. Run `sql/install.sql` in your database.
3. Add this after your DPN core resources:

```cfg
ensure oxmysql
ensure dpn-le-core
ensure dpn-digital-dispatch
ensure dpn-vehicle-computer
ensure dpn-incident-command
ensure dpn-officer-safety
```

## Permissions
Optional ACE permissions:

```cfg
add_ace group.admin dpn.officersafety allow
add_ace group.admin dpn.officersafety.supervisor allow
add_ace group.admin dpn.leo allow
```

## Commands
- `/safety` opens the dashboard.
- Panic key defaults to `F10`.
- UI key defaults to `F7`.

## Exports
Client:
```lua
exports['dpn-officer-safety']:Panic()
exports['dpn-officer-safety']:CreateAlert('custom', { title='Custom Alert', message='Details' })
exports['dpn-officer-safety']:GetVitals()
```

Server:
```lua
exports['dpn-officer-safety']:CreateSafetyAlert(source, 'custom', {
  title = 'Custom Safety Alert',
  message = 'Details',
  priority = 2
})
exports['dpn-officer-safety']:GetUnits()
exports['dpn-officer-safety']:GetAlerts()
```

## Notes
The server validates jobs/ACE permissions. Configure allowed jobs in `config.lua`.
