# DPN Medical Phase 3A — Registry, Version, and Heartbeat Hardening

Created by DPN Technology.

## Goal

Phase 3A removes medical-suite runtime identity drift without changing gameplay behavior. The medical resource manifests remain the authoritative version source.

## Core rules

1. Runtime resource versions are derived with `GetResourceMetadata(resource, 'version', 0)`.
2. `dpn-medical-core` maintains the authoritative module registry.
3. Repeated registrations merge capabilities instead of overwriting prior capabilities.
4. Legacy loose-string `RegisterModule` capability calls remain temporarily compatible and are normalized into a deduplicated capability array.
5. Heartbeats update the same authoritative registry used for registration and health reporting.
6. Health states are `healthy`, `degraded`, `stale`, and `offline`.
7. Historical modules may continue reporting old hard-coded versions during migration, but Medical Core resolves a started resource to its manifest version and logs the mismatch.
8. Feature modules must eventually stop independently registering and heartbeating the same physical resource. One registration owner and one heartbeat owner per resource is the Phase 3A end state.

## Current health thresholds

- Healthy: heartbeat/registration age <= 90 seconds.
- Degraded: age 91–180 seconds.
- Stale: age > 180 seconds while the resource is started.
- Offline: resource is not started.

## Migration sequence

- Harden Medical Core registry and health authority.
- Convert malformed advanced registrations to capability tables.
- Replace hard-coded runtime resource versions with manifest-derived versions.
- Consolidate duplicate heartbeat producers into one owner per medical resource.
- Add CI validation preventing new malformed registrations or resource-version drift.

This file documents the migration contract only; it does not mark the medical suite stable.