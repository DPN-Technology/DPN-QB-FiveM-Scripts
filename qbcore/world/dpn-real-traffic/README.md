# dpn-real-traffic

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Advanced QBCore AI traffic realism resource for FiveM.

## Features

- Realistic NPC driving behavior tuning.
- Emergency vehicle yielding for active emergency lights/sirens.
- NPCs pull to the shoulder using road-node targeting instead of hard freezing.
- Brake lights, turn signals, and hazard behavior during yield/pull-over.
- AI traffic density tuning for smoother city performance.
- Gentle anti-gridlock helper for stuck NPC traffic.
- Optional `ts_Trafficlights` integration.
- Uses `ts_Trafficlights` `SwitchLightStates` export for emergency-priority greens when available.
- Listens to `ts_Trafficlights` AI sync events and assists AI around synced intersections.

## Install

1. Put the folder in your resources directory:

   `resources/[dpn]/dpn-real-traffic`

2. Add this to `server.cfg` after `qb-core` and after `ts_Trafficlights` if you use it:

   ```cfg
   ensure qb-core
   ensure ts_Trafficlights
   ensure dpn-real-traffic
   ```

   If you do not use `ts_Trafficlights`, leave it out. The script still works, but emergency traffic-light priority will be disabled.

3. Optional admin command permission:

   ```cfg
   add_ace group.admin dpnrealtraffic.admin allow
   ```

## Commands

- `/dpntrafficdebug` toggles local debug logging for admins.
- `/dpntrafficstatus` shows resource status and `ts_Trafficlights` state.


## Security & resilience

- The server-side status request is read-only and returns only DPN traffic configuration/state information.
- Status requests are throttled per player with `Config.StatusRequestCooldownMs` (default: 1000 ms) to prevent event spam.
- The throttle state is cleared when a player disconnects.
- Admin debug control remains protected by the configured ACE/QBCore admin permission checks.

## Configuration

Edit `shared/config.lua`.

Important settings:

- `Config.Density` controls GTA traffic/ped density.
- `Config.Emergency` controls emergency yielding radius, shoulder offset, cooldowns, and job checks.
- `Config.TrafficLights` controls `ts_Trafficlights` integration.

## Notes

- For custom emergency vehicles that are not GTA class 18, set:

  ```lua
  Config.Emergency.RequireEmergencyVehicleClass = false
  ```

- For job-only yielding, set:

  ```lua
  Config.Emergency.UseQBCoreJobCheck = true
  ```

  Then update `Config.Emergency.AllowedJobs` with your QBCore job names.

- If NPCs pull too far right or not far enough, adjust:

  ```lua
  Config.Emergency.ShoulderOffset = 8.0
  Config.Emergency.ForwardOffset = 32.0
  ```

## Server.cfg example

```cfg
ensure qb-core
ensure ts_Trafficlights
ensure dpn-real-traffic
add_ace group.admin dpnrealtraffic.admin allow
```
