# dpn-vehicle-computer

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Advanced in-vehicle law enforcement terminal for FiveM by DPN Technology.

## Requirements
- dpn-le-core
- oxmysql if you want SQL logging
- Optional: dpn-digital-dispatch, dpn-starchase, dpn-bodycam, dpn-police-doorbell

## Install
1. Drop `dpn-vehicle-computer` into resources.
2. Import `sql/install.sql` if using database features.
3. Add to server.cfg after core/dispatch:
   ```cfg
   ensure dpn-le-core
   ensure dpn-digital-dispatch
   ensure dpn-vehicle-computer
   ```
4. Configure jobs and keys in `config.lua`.

## Commands
- `/vcomputer` opens the computer. Default key: F5.
- `/vpanic` sends panic alert.
- `/vstatus 10-8` updates status.
- `/vplate ABC123` runs a plate check.

## Exports
Server:
- `exports['dpn-vehicle-computer']:IsAllowed(source)`
- `exports['dpn-vehicle-computer']:GetHotlist()`
- `exports['dpn-vehicle-computer']:AddHotlistPlate(plate, reason)`

## Notes
This script is built as a clean plug-in terminal. Future DPN scripts can register modules into this UI by triggering or replacing the integration events in config.lua.
