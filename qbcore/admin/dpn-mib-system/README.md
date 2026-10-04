# DPN MIB System V4 — Admin + Developer Operations Suite

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Advanced Men in Black admin/developer command center for QBCore/FiveM.

## Open Menu
- `/mib`
- `/mibmenu`
- `/openmib`
- Default key: `F7`
- Debug: `/mibdebug`
- Force NUI test: `/mibforce`
- PG7X command: `/pg7x 1` through `/pg7x 5`

## V4.1 Security Authority Upgrade
- Split normal MIB ACE access from full administrative authority.
- Added server-derived MIB / Director / Admin action policy tiers.
- Added explicit `dpn.mib.admin` ACE for administrative MIB operations.
- Added per-mode neuralizer privilege policy.
- Added routing-bucket integer/range validation and denied-escalation audit evidence.
- Added deterministic CI regression coverage for the privilege boundary.

## Major V4 Upgrades

### Full Admin Suite
- Heal self
- Revive target
- Armor protocol
- Godmode toggle
- Invisibility toggle
- Noclip toggle
- Freeze/contain target
- Goto player
- Bring player
- Spectate player
- Kick player with audit reason
- Routing bucket control
- Global announcement
- Weather/time override hooks
- Area/world cleanup
- Vehicle repair, clean, flip, delete

### Developer Suite
- Coordinate copy tool
- Entity inspector raycast
- Debug overlay
- Resource status checker
- NUI reload button
- Vehicle deep scan
- Cleanup test area
- PG7X aim portal tester

### PG7X Portal Integration
- Two-way portal bridge
- Preset destinations from config
- Aim-based portal support
- `/pg7x <destination index>` support
- MIB menu PG7X tab

### Advanced Neuralizer V4
- Alpha, Beta, Gamma, Omega, and Area Flash protocols
- Blackout, disorientation, weapon-disable effect, timecycle distortion
- Area neuralizer affects nearby players inside configurable radius
- Memory log integration
- High-risk reason requirement
- Cooldowns per class

### UI Rework
- Command-center dashboard
- Admin Tools tab
- Developer Ops tab
- Advanced Neuralizer tab
- PG7X portal tab
- Player list with target selector
- Case creation panel
- Diagnostics panel
- Better scaling and usability

## Permissions and action tiers
Authority is derived server-side. Client payloads never select their own role, grade, clearance, or admin state.

- **MIB:** configured jobs or ACE `dpn.mib` / `command.mib`.
- **Director:** MIB job with server-side grade name `director`.
- **Admin:** QBCore `admin` / `god`, or an explicit ACE in `Config.AdminAcePermissions` (default `dpn.mib.admin`).
- **Developer:** `dpn.dev`, `command.dpn-dev`, or QBCore `god`.

Sensitive defaults are config-driven through `Config.MIBActionPolicy`: scene wipes, revive, lockdown, remote movement/observation, and threat controls require Director; kick and routing-bucket controls require Admin. Gamma/Omega neuralizer protocols and Advanced Area mode require Director.

> **Migration note:** `dpn.mib` no longer implicitly grants full admin authority. Grant `dpn.mib.admin` only to principals that should keep kick/routing-bucket powers.

Example server.cfg:
```cfg
add_ace group.mib dpn.mib allow
add_ace group.admin dpn.mib allow
add_ace group.admin dpn.mib.admin allow
add_ace group.admin dpn.dev allow
add_ace group.admin command.mib allow
add_ace group.admin command.dpn-dev allow
ensure dpn-mib-v4
```

## Install
1. Drop folder into `resources/[dpn]/dpn-mib-v4`.
2. Import `sql/dpn_mib.sql`.
3. Add the ACE permissions above.
4. Add `ensure dpn-mib-v4` after `qb-core` and `oxmysql`.
5. Restart server.

## Required Dependencies
- `qb-core`
- `oxmysql` if database logging is enabled

## Notes
- Weather/time events use common `qb-weathersync` event names. If your weather script uses different events, edit `server/main.lua` in the `devAction` section.
- PG7X is built into this resource. If you also run a separate `dpn-pg-7x`, keep only one portal controller enabled to avoid duplicate controls.
