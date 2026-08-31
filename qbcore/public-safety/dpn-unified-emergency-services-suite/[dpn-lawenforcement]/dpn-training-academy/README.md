# dpn-training-academy

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Advanced FiveM law enforcement training academy for DPN Technology.

## Features

- QBCore / ESX / standalone bridge
- Academy command UI: `/academy` or F7
- Firearms, EVOC, drone, evidence, field training, and incident command certifications
- Instructor scenario staging and grading
- Training records and expiring certifications
- SQL-backed audit logs
- DPN ecosystem hooks for dispatch, evidence, drone, smart city, and incident command
- NUI dashboard for courses, records, certs, scenarios, and instructor tools

## Installation

1. Drop `dpn-training-academy` into your resources folder.
2. Import `sql/install.sql` into your database.
3. Add this after the DPN core resources in `server.cfg`:

```cfg
ensure oxmysql
ensure dpn-le-core
ensure dpn-digital-dispatch
ensure dpn-evidence-ai
ensure dpn-training-academy
```

4. Optional ACE permissions:

```cfg
add_ace group.admin dpn.academy.admin allow
add_ace group.admin dpn.academy.instructor allow
```

## Commands

- `/academy` opens the academy UI.
- `/finishacademy` completes and scores the active course.

## Exports

### Client

```lua
exports['dpn-training-academy']:IsInAcademyCourse()
exports['dpn-training-academy']:AddTrainingHit(points)
exports['dpn-training-academy']:AddTrainingMistake(reason)
```

### Server

```lua
exports['dpn-training-academy']:GetAcademyProfile(source, function(profile) end)
exports['dpn-training-academy']:HasCertification(source, 'drone_operator', function(hasCert) end)
local scenarioId = exports['dpn-training-academy']:CreateScenario(data)
```

## Notes

This is built as a strong resource foundation. For real firearms target scoring, connect your range target script to the `AddTrainingHit` client export. For advanced EVOC scoring, add checkpoint markers and call `AddTrainingMistake` when cones/props are struck.
