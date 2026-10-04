# dpn-starchase

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


## v1.1.2 Database Hardening

- Database table identifiers are validated server-side before they are interpolated into SQL.
- Identifiers are limited to MySQL-safe alphanumeric/underscore names with a 64-character maximum.
- Invalid configured identifiers fail closed to `dpn_starchase_logs` and emit a bounded server warning.
- Row values continue to use parameterized placeholders.
- The resource is now marked `hardened` in DPN resource metadata after regression coverage was added.

Advanced QBCore police StarChase-style GPS tracker launcher system for FiveM.

This is a full from-scratch rebuild. It does not depend on Rockstar Editor, recording systems, weapons damage, bullets, explosions, or the old WIP code.

## New in this patched build

- Fixed tracker blips not clearing after remote/physical removal.
- Immediate local blip cleanup now runs even if a network event arrives late.
- Removal callbacks return a fresh tracker list and resync the officer UI.
- Replaced the bomb-looking prop with a compact low-profile GPS device model.
- Tightened attachment offsets so the tracker sits flush on the rear bumper instead of sticking far out.
- Added a live lock-on HUD before firing.
- Added a green target box/line/marker showing exactly what vehicle is locked.
- Added a red NO LOCK indicator when the launcher cone is not aligned.
- Added configurable keybind settings in `Config.Controls`.
- Added quick-deploy, remove-nearest, and lock-HUD toggle key mappings.
- Added safe visual-only deploy protections so it does not damage vehicles or players.

## Features

- Police/emergency vehicle StarChase launcher
- Forward cone + capsule target lock
- Live NUI remote inspired by radar-control layouts
- Active tracker dashboard
- GPS blips for authorized law enforcement
- Route/waypoint/ping controls
- Tracker physical prop attached to suspect vehicle
- Civilians can remove tracker from vehicle if enabled
- Officers can detach remotely or remove nearest physically
- Cooldowns, job/grade/on-duty checks, optional ammo, optional remote item
- Server-side active tracker sync
- Oxmysql logging with auto-create table support
- Dispatch hook placeholder
- Exports for other scripts

## Install

1. Drop the `dpn-starchase` folder into your server resources.
2. Add this to `server.cfg` after `qb-core`:

```cfg
ensure dpn-starchase
```

3. Optional database setup:
   - If `Config.Database.autoCreate = true`, the table is created when `oxmysql` is running.
   - Or manually import `sql/dpn_starchase.sql`.

4. Configure jobs, vehicle models, items, cooldowns, lock-on display, keybinds, and tracker settings in `config.lua`.

## Default controls

FiveM key mappings can be changed by players in:

`ESC > Settings > Key Bindings > FiveM`

Defaults from `Config.Controls`:

- `F10` / `/starchase` opens the remote UI.
- `F11` / `/starchasefire` quick-deploys a tracker at the current lock-on target.
- `F3` / `/starchaselockhud` toggles the lock-on HUD.
- `F9` / `/removestarchase` physically removes the nearest active tracker as law enforcement.

To change defaults server-wide, edit `Config.Controls` in `config.lua`. Players who already changed a key may need to rebind it in their FiveM settings.

## Lock-on HUD

When an authorized officer is in a fitted emergency vehicle, the lock-on HUD shows:

- Green vehicle outline when a target is locked.
- Plate, distance, and speed before firing.
- Green line from launcher vehicle to target.
- Red NO LOCK message when no valid target is inside the launcher cone.

Settings are in `Config.LockOn`.

## Safe deploy / no damage

This system uses visual-only object movement and server-side GPS state. It does **not** create explosions, does **not** fire bullets, and does **not** apply vehicle damage.

Relevant settings:

```lua
Config.Fire.projectileModel = `prop_ld_keypad_01`
Config.Fire.safeVisualOnly = true
Config.Fire.forceNoCollision = true
Config.Fire.damageProofFx = true
Config.Fire.launchScreenShake = false
```

The visual projectile and attached tracker are set collisionless/invincible/non-damaging client-side.

## Low-profile tracker prop

The default tracker is now:

```lua
Config.Tracker.model = `prop_ld_keypad_01`
Config.Tracker.attachBonePreference = 'bumper_r'
Config.Tracker.attachOffset = { x = 0.0, y = -0.055, z = 0.025 }
Config.Tracker.attachRotation = { x = 90.0, y = 0.0, z = 0.0 }
```

If a specific vehicle model still needs adjustment, tune `attachOffset` in small increments. Large Y values will make the device stick out from the vehicle.

## Optional QBCore items

Add these to `qb-core/shared/items.lua` if you want remote/ammo inventory requirements:

```lua
starchase_remote = {
    name = 'starchase_remote',
    label = 'DPN StarChase Remote',
    weight = 750,
    type = 'item',
    image = 'starchase_remote.png',
    unique = true,
    useable = true,
    shouldClose = true,
    combinable = nil,
    description = 'Secure DPN StarChase law enforcement remote.'
},

starchase_round = {
    name = 'starchase_round',
    label = 'StarChase GPS Tracker Round',
    weight = 250,
    type = 'item',
    image = 'starchase_round.png',
    unique = false,
    useable = false,
    shouldClose = true,
    combinable = nil,
    description = 'A deployable GPS tracker round for the DPN StarChase launcher.'
},
```

Then set:

```lua
Config.Items.useRemoteItem = true
Config.Items.requireAmmo = true
```

## Commands

- `/starchase` opens the remote UI.
- `/starchasefire` quick-deploys a tracker.
- `/starchaselockhud` toggles the lock-on HUD.
- `/removestarchase` physically removes the nearest active tracker as law enforcement.
- `/starchaseclear` clears all trackers. Requires ACE `command.dpnstarchase.admin` unless used from console.

## ACE permission

For admin bypass / force clear:

```cfg
add_ace group.admin command.dpnstarchase.admin allow
```

## Exports

Client:

```lua
exports['dpn-starchase']:LaunchTracker()
local trackers = exports['dpn-starchase']:GetActiveTrackers()
```

## Vehicle fitting

By default the script works with GTA emergency class vehicles only. For strict fitting, add model hashes to `Config.VehicleRules.allowedModels`:

```lua
Config.VehicleRules.allowedModels = {
    [`police`] = true,
    [`police2`] = true,
    [`sheriff`] = true,
}
```

## Notes

- This system uses GPS blips and entity updates from nearby authorized officers. With OneSync enabled, tracking is much more reliable.
- Physical tracker props are visual only; GPS state is controlled server-side.
- You can change the prop model in `Config.Tracker.model` if your server has a custom StarChase device model.

## v1.1.1 Patch

- Changed the default Lock-On HUD toggle key from `F8` to `F3`.
- Reworked the NUI sizing so the remote uses viewport-based height, scroll-safe panels, smaller responsive spacing, and no longer clips off-screen on lower resolutions.
- Existing players who already have `/starchaselockhud` bound may need to clear/rebind it under FiveM key bindings because FiveM stores player-side bindings.
