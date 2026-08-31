# DPN PG-7X Portal Gun for FiveM

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


## v1.3.1 Return Portal + Advanced Swirl Fix

This build fixes the issue where the destination-side portal could be visible but would not send players back. The return side now sends the client-resolved visible portal center to the server, and the server validates it against the raw postal/destination area. This fixes nearest-postal portals when the destination portal is moved to a safe road/ground point instead of the original raw postal X/Y/Z=0.

Visuals were also upgraded again: the portal is a taller vertical oval with layered green glow, ragged animated edge particles, brighter lime inner spiral arms, pulsing light, and sparks/orbs around the rim. It is still built with native FiveM markers and lights, so no custom YDR/YTD is required.

## v1.3.0 Vertical Paired Two-Way Portals

This build changes PG-7X portals from a one-way doorway into a paired two-way portal system. Firing the PG-7X now opens a vertical green sci-fi portal at the point you shoot and a matching vertical portal at the destination/postal. Players can walk into either side and travel back and forth until the admin closes the portal or it expires.

New visual behavior:

- Vertical oval doorway instead of a flat ground marker.
- Animated glowing green ring, inner swirl, light pulse, and sparks.
- No custom copyrighted assets, YDR, or YTD required; it uses native FiveM markers/lights.
- Postal destination portals resolve safe ground/road Z on the client before drawing/teleporting.

## v1.2.2 True Legacy CEF UI Fix

This build fixes older FiveM CEF display problems where `/pgui` could show only the mouse or trigger a failed-display warning. The UI has been rebuilt with true legacy-safe HTML, CSS, and JavaScript: no CSS variables, no CSS grid/flex dependency, no modern selectors, no fetch API, no arrow functions, and no template strings. It also acknowledges the NUI open event immediately before rendering so the client does not falsely release focus on slow/older CEF clients.

Emergency reset commands remain available:

```text
/pguifix
/pguireset
```

## v1.2.1 UI Hard Fix

This build fixes the issue where `/pgui` only shows the mouse and traps the player. The NUI JavaScript was rebuilt to be compatible with older FiveM CEF clients, avoiding modern JavaScript features that can fail silently. It also adds repeated focus-release protection, ESC/Backspace/F8 hard-close support, and a `/pguifix` emergency command.

If the UI ever gets stuck again, press **F8** or run:

```text
/pguifix
```

`dpn-pg-7x` is an admin-only FiveM portal gun resource. Admins can save destinations, select saved destinations, select postal destinations from the nearest-postal database, aim at a surface, and create a glowing green walk-in portal.

## New in v1.2.0

- Fixed postal teleport falling through the map by adding client-side ground-Z detection, collision loading, freeze protection, and a safe fallback Z.
- Fixed UI access flow so `/pgui`/F7 asks the server for admin authorization before opening instead of depending on stale client auth.
- Added `/pg7xui` as a backup UI command alias.

## Added in v1.1.0

- Added NUI control panel with destination list, postal selection, current postal display, and portal controls.
- Added nearest-postal integration for postal-code destinations.
- Added temporary postal destinations: select a postal and immediately open a portal to it without saving it first.
- Added saved postal destinations: save a postal as a normal PG-7X destination.
- Added `/pgpostal` command.
- Added `/pgui` command and default F7 keybind.

## Features

- Admin-only access with ACE permission, optional identifier whitelist, and optional QBCore admin/god fallback.
- Saved portal destinations stored in `destinations.json`.
- Postal destinations loaded from supported postal JSON files.
- Vertical green animated portal visuals with layered glow, ragged oval ring, pulsing light, sparks, and multi-arm inner swirl.
- Paired two-way portals: the entry and destination portals both stay open until closed/expired.
- Walk-in teleporting for players from either portal side, with optional admin-only portal entry.
- Server-side validation for portal creation and teleport entry.
- Cooldowns to prevent spam.
- Optional QBCore usable item support.
- One active portal per admin by default.
- Vehicle teleport support.

## Install

1. Drop the folder into your FiveM resources folder:

```text
resources/[dpn]/dpn-pg-7x
```

2. Make sure `nearest-postal` starts before `dpn-pg-7x` if you want postal destinations:

```cfg
ensure nearest-postal
ensure dpn-pg-7x
```

3. Give admins permission:

```cfg
add_ace group.admin dpn.pg7x.use allow
```

Example principal assignment:

```cfg
add_principal identifier.license:YOUR_LICENSE_HERE group.admin
```

Restart the server or run:

```cfg
refresh
ensure dpn-pg-7x
```

## Nearest Postal Setup

This resource auto-detects common postal resource names and reads the postal JSON from the postal resource. It checks the `postal_file` fxmanifest metadata first, then falls back to:

```text
new-postals.json
ocrp-postals.json
old-postals.json
postals.json
postal.json
data/postals.json
config/postals.json
```

If your postal resource has a custom name or custom file path, edit `Config.Postal.AutoDetectResources` and `Config.Postal.PostalFiles` in `config.lua`.

The UI also attempts to read the current nearest postal from client exports such as:

```lua
exports['nearest-postal']:getPostal()
exports['nearest-postal']:npostal()
```

If your postal resource does not provide a current-postal export, manually type the postal code in the UI or use `/pgpostal postal_code`.

## Commands

### Open UI

```text
/pgui
```

Default keybind: `F7`. Players can rebind it in FiveM keybind settings.

### Toggle portal gun

```text
/pg7x
```

Arms or disarms the DPN PG-7X. While armed:

- Aim at a surface.
- Press `E` to open a paired two-way portal.
- Press `G` to close both ends of your active portal pair.
- Press `Backspace` to disarm.
- Press `F7` or use `/pgui` to manage destinations.

### Select a postal destination

```text
/pgpostal 401
/pgpostal current
```

`/pgpostal current` requires your postal script to expose a current-postal client export.

### Save your current location as a destination

```text
/pgdest save name_here
```

Examples:

```text
/pgdest save legion_square
/pgdest save sandy_airfield
/pgdest save mrpd_roof
```

### Select a saved destination

```text
/pgdest select name_here
```

### Select a postal destination through the destination command

```text
/pgdest postal 401
```

### List destinations

```text
/pgdest list
```

### Delete a destination

```text
/pgdest delete name_here
```

### Reload destinations and postal data

```text
/pg7xreload
```

This can be run from server console or by an admin in-game.

### Close your portal pair

```text
/pgclose
```

This closes both ends of your active two-way PG-7X portal.

## Optional QBCore Item

If you use QBCore, add this item to `qb-core/shared/items.lua`:

```lua
['dpn_pg_7x'] = {
    name = 'dpn_pg_7x',
    label = 'DPN PG-7X Portal Gun',
    weight = 1000,
    type = 'item',
    image = 'dpn_pg_7x.png',
    unique = true,
    useable = true,
    shouldClose = true,
    combinable = nil,
    description = 'Admin-grade DPN portal device for opening green walk-in portals.'
},
```

The item is still admin-only. Non-admin players cannot use it even if they somehow receive it.

## Config Highlights

Open `config.lua` to adjust:

```lua
Config.RequireAdminToEnterPortal = false
```

Set this to `true` if only admins should be allowed to walk through portals.

```lua
Config.Postal.PrimaryResource = 'nearest-postal'
Config.Postal.PostalFiles = { 'new-postals.json', 'ocrp-postals.json', 'old-postals.json' }
```

Use these if your postal resource has a custom name or custom file.

```lua
Config.PortalDuration = 120
Config.MaxCreateDistance = 80.0
Config.CreateCooldown = 3
Config.TeleportCooldown = 4
Config.TwoWayPortals = true
Config.PortalWidth = 1.45
Config.PortalHeight = 2.45
Config.PortalCenterZOffset = 1.05
```

These control lifetime, shot distance, and cooldowns.

```lua
Config.Teleport = {
    ResolveGroundWhenBelowZ = 10.0,
    GroundOffset = 0.95,
    FallbackZ = 75.0,
    CollisionTimeoutMs = 6500
}
```

This is what prevents postal destinations from dropping players under the map when the postal file only has X/Y coordinates.

## Important Notes

- This resource uses an existing GTA prop for the handheld device, so no custom model/YDR is required.
- This script does not include copyrighted show assets. It creates a green, animated, sci-fi-style portal effect using native FiveM markers/lights.
- All important actions are checked server-side so non-admins cannot create portals by triggering client events.
- Postal destinations require a postal JSON file from a postal resource such as `nearest-postal`.

## Troubleshooting

### I get access denied even as admin

Make sure your `server.cfg` contains:

```cfg
add_ace group.admin dpn.pg7x.use allow
add_principal identifier.license:YOUR_LICENSE_HERE group.admin
```

Then restart the server.

### UI does not open

Use either command:

```text
/pgui
/pg7xui
```

Make sure you have the ACE permission. The UI now requests server-side authorization each time it opens, so a restart or stale client auth should not block it. If the command still says access denied, your ACE/principal setup is the issue.

### The UI opens but postal database says Not Ready

Make sure your postal resource starts before this resource:

```cfg
ensure nearest-postal
ensure dpn-pg-7x
```

Then run:

```text
/pg7xreload
```

If your postal resource folder has a different name, add it to `Config.Postal.AutoDetectResources`.

### Postal portal makes me fall through the map

This v1.2.0 build fixes that by resolving the ground Z on the client before moving the player. Postal JSON files often store only `x` and `y`, leaving `z` as `0.0`.

After installing this version, restart the resource and re-select the postal. Existing saved postal destinations with `z = 0.0` should also be handled safely.

### Current Postal says N/A

Your postal resource may not expose a current-postal export. You can still type the postal manually in the PG-7X UI or use:

```text
/pgpostal 401
```

### The QBCore item does nothing

Make sure `Config.EnableQBCoreItem = true`, the item exists in `qb-core/shared/items.lua`, and `qb-core` starts before this resource.
