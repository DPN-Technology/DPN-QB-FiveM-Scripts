# dpn-vehicle-computer

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.

Advanced in-vehicle law-enforcement terminal for FiveM by DPN Technology.

## Version

Current hardened release: **4.0.1**

## Requirements

- `dpn-le-core`
- `oxmysql`
- Optional: `dpn-digital-dispatch`, `dpn-starchase`, `dpn-bodycam`, `dpn-police-doorbell`

## Install

1. Drop `dpn-vehicle-computer` into resources.
2. Import `sql/install.sql`.
3. Start it after the law-enforcement core and dispatch resources:

   ```cfg
   ensure dpn-le-core
   ensure dpn-digital-dispatch
   ensure dpn-vehicle-computer
   ```

4. Configure jobs, keybinds, modules, webhooks, and `Config.Security` in `config.lua`.

## Commands

- `/vcomputer` — opens the computer. Default key: F5.
- `/vpanic` — sends an officer panic alert.
- `/vstatus 10-8` — updates unit status.
- `/vplate ABC123` — runs a plate check.

## Security model

Version 4.0.1 hardens every exposed server-side vehicle-computer event with independent per-player rate limits. The limits are configurable without weakening authorization checks and are cleaned up when the player disconnects.

The server also treats dispatch-call input as untrusted. It reconstructs the outbound dispatch object from a small allowlisted schema, verifies coordinates on the server, clamps priority, bounds strings, and assigns server-owned fields such as officer identity, departments, source metadata, and staff-only status.

Additional controls include:

- ACE / DPN LE authorization before privileged actions.
- Server-verified player and vehicle state.
- Parameterized SQL for plate lookups, notes, and hotlist changes.
- Bounded plate, reason, note, call-type, title, and description input.
- Rate-limit security audit messages with their own cooldown to avoid log flooding.
- Authorized-recipient filtering for panic broadcasts.
- Cleanup of per-source rate-limit state on `playerDropped`.

## Exports

Server:

- `exports['dpn-vehicle-computer']:IsAllowed(source)`
- `exports['dpn-vehicle-computer']:GetHotlist()`
- `exports['dpn-vehicle-computer']:AddHotlistPlate(plate, reason)`

## Integration notes

This script remains a plug-in terminal for the DPN public-safety ecosystem. Existing integration events and exports are preserved while server trust boundaries are tightened.

Security regression evidence is enforced in the repository Quality Gate through `tools/check_vehicle_computer_security.py`.
