# DPN Crime Intelligence

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.

DPN Crime Intelligence is the law-enforcement intelligence layer in the DPN Unified Emergency Services Suite. It provides authenticated intelligence searches, risk summaries, reports, watchlists, entity links, dispatch alerts, and audit evidence.

## Current capabilities

- Search QBCore citizens by citizen ID and character information.
- Search player vehicles by plate or vehicle model.
- Calculate risk summaries from bookings, citations, intelligence links, watchlists, and active warrants.
- Create intelligence reports with bounded titles, narratives, classifications, and metadata.
- Create and clear person/vehicle watchlists.
- Link reports to people, vehicles, and other intelligence entities.
- Generate intelligence alerts through the configured DPN digital-dispatch integration.
- Maintain an audit trail for searches and write operations.
- Apply separate officer and supervisor authorization paths.

## Authorization model

Player-originated actions are checked on the server. Access may be granted by:

- configured law-enforcement/corrections jobs;
- on-duty status when `Config.RequireDuty` is enabled;
- supervisor grade for privileged watchlist operations;
- `dpn.intel` / `dpn.intel.supervisor` ACE permissions.

Client UI state is never treated as authority.

## Abuse resistance

`Config.RateLimits` defines independent server-side cooldowns for:

- opening the interface;
- intelligence searches;
- report/watchlist/link mutations;
- player-originated intelligence alerts.

The rate state is scoped per player and cleared on disconnect. Server-side integrations using source `0` are not throttled.

Search text, report text, identifiers, classifications, relationship labels, and watchlist data are length-bounded before persistence. Watchlist priority is clamped, and clear operations require a positive numeric record ID.

## Data safety

Database calls use parameter binding for player-controlled values. Do not replace bound parameters with string-built SQL.

Crime-intelligence data may contain sensitive roleplay records. Only authorized departments should have access, and external integrations should receive the minimum data necessary for their function.

## Configuration

Edit `shared/config.lua` to configure:

- allowed jobs and supervisor grades;
- duty requirements;
- search/report size limits;
- risk weights and risk levels;
- dispatch integration;
- server-side rate limits.

## Dependencies

This resource expects the DPN Unified Emergency Services Suite database schema and its configured QBCore / oxmysql environment. The dispatch integration is optional and only runs when the configured dispatch resource is started.

## Operational note

The resource metadata currently retains its imported lifecycle marker. Passing the repository static gates does not by itself certify a specific FiveM server deployment; production operators should validate job mappings, database schema, ACE permissions, and expected dispatch integrations in their own environment.
