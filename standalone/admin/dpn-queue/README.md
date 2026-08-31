# dpn-queue

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Advanced FiveM queue resource for DPN Technology.

## Features

- Configurable reserved admin slots, default `13`.
- Public slot protection: regular players only fill public slots.
- Admins can use the reserved pool when public slots are full.
- ACE permission admin detection.
- Optional identifier-based admin fallback.
- Priority queue system.
- Reconnect grace priority.
- Duplicate queued connection replacement.
- Anti-spam protection.
- Queue status command.
- Standalone resource; does not require QBCore, ESX, or ox_lib.

## Install

1. Drop the `dpn-queue` folder into your FiveM `resources` folder.
2. Add this near the top of your `server.cfg`:

```cfg
ensure dpn-queue
```

Recommended: start this before heavy framework resources so it controls connection flow early.

## Example server.cfg permissions

```cfg
# Queue admin slot permission
add_ace group.admin dpn.queue.admin allow

# Queue management command permission for /dpnqueue
add_ace group.admin dpn.queue.manage allow

# Add your license to the admin group
add_principal identifier.license:PUT_YOUR_LICENSE_HERE group.admin
```

## Slots example

If your server has:

```cfg
sv_maxclients 48
```

And `config.lua` has:

```lua
Config.ReservedAdminSlots = 13
```

Then the queue will treat the server like this:

- 35 public slots
- 13 admin-reserved slots
- Regular players stop entering once 35 used slots are reached
- Admins can keep entering until the full 48 slots are used

## Command

```txt
/dpnqueue
```

Shows queue count, used slots, public slots, reserved slots, and queued player priority.

Use from server console or in game with `dpn.queue.manage` ACE permission.

## Configuring admins

Best method is ACE:

```cfg
add_ace group.admin dpn.queue.admin allow
add_principal identifier.license:YOUR_LICENSE group.admin
```

You can also add direct fallback identifiers in `config.lua`:

```lua
Config.Admin.Identifiers = {
    'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    'discord:123456789012345678'
}
```

## Priority boosts

Example:

```lua
Config.Priority.IdentifierBoosts = {
    ['license:OWNER_LICENSE'] = { points = 5000, label = 'Owner' },
    ['discord:123456789012345678'] = { points = 2500, label = 'VIP' }
}
```

Higher points move a player closer to the front.
