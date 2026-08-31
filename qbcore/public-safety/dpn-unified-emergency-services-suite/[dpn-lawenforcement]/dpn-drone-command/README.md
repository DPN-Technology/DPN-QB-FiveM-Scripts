# dpn-drone-command

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Advanced deployable drone command module for the DPN law enforcement ecosystem.

## Features

- Police/Fire/EMS deployable drone
- NUI drone command panel
- First-person drone camera
- Battery simulation
- Low/critical battery failsafe
- Night vision and thermal camera modes
- Spotlight support
- Area scan for nearby vehicles and pedestrians
- Vehicle target lock helper
- Dispatch alert integration
- DPN ecosystem exports/events
- SQL logging and optional Discord webhook
- QBCore, ESX, and standalone-friendly permission bridge

## Install

1. Place `dpn-drone-command` in your resources folder.
2. Import `sql/install.sql`.
3. Ensure dependencies before this resource:

```cfg
ensure oxmysql
ensure dpn-le-core
ensure dpn-digital-dispatch
ensure dpn-drone-command
```

4. Give permissions if using ACE:

```cfg
add_ace group.admin dpn.drone allow
add_ace group.admin dpn.admin allow
```

## Commands

- `/drone` deploys or recalls a drone.
- Default key: `F7`.

## Controls

- W/A/S/D: Move
- Q/E: Altitude
- Shift: Boost
- H: Night vision
- G: Thermal / scan depending control conflict preference
- X: Spotlight
- Left click: Lock nearest visible vehicle
- Mouse wheel: Camera zoom
- Backspace: Recall drone

## Exports

```lua
exports['dpn-drone-command']:IsDroneActive()
exports['dpn-drone-command']:GetDroneEntity()
exports['dpn-drone-command']:RecallDrone('reason')
```

Server:

```lua
exports['dpn-drone-command']:GetActiveDrones()
exports['dpn-drone-command']:GetDroneByOwner(source)
exports['dpn-drone-command']:CreateDroneAlert({ title = 'Drone Alert', coords = coords })
```

## Integration Notes

This resource sends dispatch events through `dpn-digital-dispatch` when available. It is designed to be extended by future modules such as `dpn-smart-city`, `dpn-evidence-ai`, and `dpn-incident-command`.
