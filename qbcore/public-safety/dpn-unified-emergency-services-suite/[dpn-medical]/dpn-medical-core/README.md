# dpn-medical-core v4.0.0

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Standalone authoritative medical framework for QBCore. It owns injury detection, vitals, bleeding, conditions, medication history, incapacitation, death, revive, hospital respawn, persistence, and the DPN medical module registry.

There is no dependency on a separate ambulance job resource. Do not run another death, last-stand, injury, revive, or hospital respawn script beside this core.

## Commands
- `/medical`, `/medhud`, `/medinspect [id]`, `/medsummary`
- Admin: `/medstate`, `/injure`, `/healcore`, `/revivecore`, `/medmodules`

## Required
- qb-core
- oxmysql


## Version 5 Advanced Integration
Advanced physiology, safety checks, care episodes, protocols, care plans, devices, timelines, module health and deterioration alerts.


## v6 Clinical-Operations Layer
This resource includes its v6 operational workflow in `server/v6.lua` and integrates with the DPN Medical digital twin, orders, observations, safety alerts and structured handoffs.


## Version 9 adaptive network
This resource includes a `server/v9.lua` operational layer registered with DPN Medical Core v9. Use `V9_API.md` in the suite root for the supported exports.
