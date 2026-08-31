# dpn-evidence-ai

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Advanced FiveM law-enforcement evidence and case management resource for the DPN ecosystem.

## Features
- Case creation and case status workflow
- Evidence intake with types, notes, and metadata
- Automatic evidence events from other DPN scripts
- Chain of custody transfer logs
- Court-ready report generator
- NUI evidence dashboard
- Supervisor-only case status control
- QBCore, ESX, or standalone bridge
- Webhook logging support
- Exports for DPN Dispatch, Officer Safety, Bodycam, Vehicle Computer, and Incident Command

## Install
1. Place `dpn-evidence-ai` in your resources folder.
2. Import `sql/install.sql` into your database.
3. Make sure `oxmysql` starts before this resource.
4. Add to `server.cfg`:

```cfg
ensure oxmysql
ensure dpn-le-core
ensure dpn-digital-dispatch
ensure dpn-vehicle-computer
ensure dpn-incident-command
ensure dpn-officer-safety
ensure dpn-evidence-ai
```

## Commands
- `/evidenceai` opens the evidence dashboard.
- Default keybind: `F7`

## Exports
```lua
local caseId = exports['dpn-evidence-ai']:CreateCase('Armed Robbery', 'Store robbery investigation', 'SYSTEM')
local evId = exports['dpn-evidence-ai']:AddEvidence(caseId, 'photo', 'Scene Photo', 'Front counter photo', { url = 'https://example.com/image.png' })
```

## Auto Evidence Event
```lua
TriggerServerEvent('dpn-evidence-ai:server:autoEvidence', {
  type = 'bodycam',
  title = 'Bodycam Bookmark',
  case_id = 'CASE-123',
  notes = 'Critical moment captured.',
  meta = { clip = 'clip_001.mp4' }
})
```

## Notes
This resource is built to be expanded. The current package includes strong foundations for cases, evidence, custody, reports, and ecosystem hooks.
