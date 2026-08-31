# DPN Advanced Law Enforcement Operations

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


The v3 operations center adds agency workflow that is normally spread across police job, MDT, fleet, training, court, evidence, and dispatch resources.

## Included workflows

- Shift clock, activity statistics, paired units, unit roles, partners, and dispatch callsigns
- Person and vehicle warrants with probable cause, judicial/supervisor review, expiry, service, and audit history
- Network-verified pursuit acquisition, primary/support units, stages, tactics, supervisor authorization, dispatch and incident escalation
- Automatic weapon-discharge force drafts, complete use-of-force reports, evidence records, and supervisor findings
- Fleet vehicle checkout/return with plate, health, fuel, damage, and review tasks
- Certification-aware armory issue/return with serial tracking
- Supervisor queues for warrant, pursuit, tactic, force, fleet, and administrative reviews
- Hooks for `dpn-mdt`, `dpn-justice-system`, `dpn-corrections-system`, evidence, intelligence, incident command, and digital dispatch

## Command

`/leops` — default key F1, fully remappable in FiveM key bindings.

## Important configuration

Review `config.lua` before use. `Config.Armory.TrackOnly` defaults to `true`, which records issue/return activity without adding or removing inventory items. Set it to `false` only after confirming your QBCore item names and inventory behavior.
