# dpn_pasystem v2.0.2

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Advanced in-vehicle PA system for FiveM emergency personnel. This is a clean rebuild designed for QBCore/QBX/ESX/standalone permission setups and `pma-voice`.

## What it does

- In-vehicle public address microphone for police, sheriff, state police, fire, EMS, or ACE-authorized staff.
- Uses `pma-voice` proximity override so the officer/medic/firefighter voice carries farther like a real PA.
- UI control panel with authorization status, pma-voice status, vehicle validation, range presets, local settings, panel position control, and keybind information.
- FiveM key mapping support so users can change keys in **Settings → Key Bindings → FiveM**.
- Configurable PA range presets and max range.
- Emergency vehicle-only lock with class/model whitelist and seat checks.
- Anti-abuse cooldown, server-side authorization, heartbeat cleanup, dead/vehicle-exit auto-stop, and transmission timeout.
- Listener-side PA broadcast overlay is disabled/removed by default.
- Local settings saved per player with KVP, including panel position. The KVP key no longer uses changing server IDs, so settings persist correctly after reconnecting.

## Install

1. Drop the folder into your resources directory as:

   ```text
   resources/[dpn]/dpn_pasystem
   ```

2. Ensure `pma-voice` starts before this resource:

   ```cfg
   ensure pma-voice
   ensure dpn_pasystem
   ```

3. Configure `shared/config.lua` for your jobs, vehicles, ranges, ACE permission, item requirement, and key defaults.

4. Restart the server or run:

   ```text
   refresh
   ensure dpn_pasystem
   ```

## Commands

- `/pamenu` — open PA UI.
- `/pacancel` — force stop your PA transmission.
- `/pastatus` — check authorization and live status.

## Default keybinds

- `F7` — open PA panel.
- `H` — hold to transmit PA.
- `F8` — latch/toggle PA transmission.

Players can change these through **Settings → Key Bindings → FiveM** and searching for `DPN PA`.


## Panel position settings

Open `/pamenu`, go to **Settings**, and change **Panel Position**. The panel moves immediately and saves automatically. Supported positions are right, left, center, top-right, top-left, bottom-right, and bottom-left.

## ACE permission example

If `Config.PermissionMode = 'ace'`, `'either'`, or `'both'`, add this to `server.cfg` for your admin/group:

```cfg
add_ace group.admin dpn.pa.use allow
```

## QBCore job example

`shared/config.lua` already includes common defaults:

```lua
Config.AllowedJobs = {
    police = { label = 'Police', minGrade = 0 },
    sheriff = { label = 'Sheriff', minGrade = 0 },
    ambulance = { label = 'EMS', minGrade = 0 },
    fire = { label = 'Fire Department', minGrade = 0 },
}
```

Set `Config.RequireOnDuty = true` if only on-duty emergency personnel should use it.

## Optional item requirement

Set this if you want officers to need an item:

```lua
Config.RequiredItem = 'pa_microphone'
```

Set it back to `false` to disable item checking.

## Notes

- This resource expects `pma-voice` to expose `overrideProximityRange` and `clearProximityOverride`. If your `pma-voice` build is very old, update it.
- Do not run multiple voice systems at the same time.
- Do not add another script that directly overrides Mumble/FiveM proximity natives while using pma-voice.

## Exports

Client:

```lua
exports['dpn_pasystem']:IsPAActive()
exports['dpn_pasystem']:StopPA('reason')
```

Server:

```lua
exports['dpn_pasystem']:IsPAActive(source)
exports['dpn_pasystem']:StopPA(source, 'reason')
```
