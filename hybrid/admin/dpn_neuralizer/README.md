# DPN Neuralizer Advanced for FiveM

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


A Men-in-Black-style RP neuralizer resource for FiveM with:

- Admin immunity that is enforced on the server
- QBCore, ESX, and standalone support
- Usable inventory item support for QBCore/ESX
- Optional `/neuralizer` command
- Camera raycast + cone fallback targeting
- Server-side distance validation
- Cooldowns and event rate limiting
- NUI flash/charge effects with audio tone
- Target disorientation, waypoint clear, movement blur, ragdoll, control lock, and post FX
- Discord webhook logging support
- Custom model source files included for conversion to `.ydr`

## Install

1. Put `dpn_neuralizer_advanced` in your server `resources` folder.
2. Add this to `server.cfg`:

```cfg
ensure dpn_neuralizer_advanced
```

3. Add admin ACE immunity in `server.cfg`:

```cfg
add_ace group.admin dpn.neuralizer.admin allow
add_ace group.god dpn.neuralizer.admin allow
```

You can also add direct identifier immunity:

```cfg
add_ace identifier.license:YOUR_LICENSE_HERE dpn.neuralizer.admin allow
```

4. Configure `config.lua`.

## QBCore Item

Add the item from `items/qb_items.lua` into `qb-core/shared/items.lua`.
Copy `items/neuralizer.png` into your inventory image folder, usually:

```text
qb-inventory/html/images/
```

The resource automatically registers the usable item when QBCore is running.

## ESX Item

Create the item in your ESX items database/inventory and wire the image into your inventory system. The resource automatically registers the usable item with `ESX.RegisterUsableItem` when ESX is running.

## Standalone Usage

Use:

```text
/neuralizer
```

Aim at a player within range before using it.

## Admin Immunity

The target cannot be affected if any of these are true:

- They have ACE `dpn.neuralizer.admin`
- They are in a configured QBCore permission group such as `god`, `admin`, or `mod`
- They are in a configured ESX group such as `superadmin`, `admin`, or `mod`
- Their identifier is listed in `Config.Security.adminIdentifiers`

The server checks immunity before it sends the effect to the target.

## Optional Permission to Use

If you want only selected staff/jobs to use it, set this in `config.lua`:

```lua
Config.Security.requireAceToUse = true
```

Then add this to `server.cfg`:

```cfg
add_ace group.admin dpn.neuralizer.use allow
```

## Custom Model

A source model is included:

```text
model_source/dpn_neuralizer_prop.obj
model_source/dpn_neuralizer_prop.mtl
model_source/create_blender_model.py
```

FiveM streams GTA drawable files such as `.ydr`, so the OBJ is included as the model source. Convert it in Blender with Sollumz or CodeWalker, export it as:

```text
stream/dpn_neuralizer_prop.ydr
```

Then set:

```lua
Config.Prop.useCustomModel = true
```

Until the `.ydr` is created, the script uses the built-in `prop_cs_police_torch` model so the neuralizer works immediately.

## Notes

This is an RP effect. It does not and cannot erase a real player's memory. It creates an in-game flash, disorientation, and roleplay memory-wipe experience.


## Update Notes
- Added a 15-second target blackout after the neuralizer flash.
- Added health/armor preservation so using or receiving the neuralizer does not drain life.
- Admin immunity remains server-side protected.
