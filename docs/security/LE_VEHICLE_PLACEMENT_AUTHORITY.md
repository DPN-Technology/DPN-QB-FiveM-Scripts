# Law-Enforcement Vehicle Placement Authority Hardening

Baseline refreshed from `main` at `222192644208077bef43085cc0b6baf153719a0a`.

## Resolution

`dpn-le-core:server:putInVehicle` now treats the client-selected vehicle network ID as untrusted input and re-establishes authority on the server before any placement mutation.

- Existing law-enforcement action authorization and rate limiting remain in force.
- The target must be valid, restrained by server-owned state, and within the configured officer interaction distance.
- The submitted network ID is normalized and resolved server-side with `NetworkGetEntityFromNetworkId`.
- The resolved entity must exist and must be a vehicle.
- The server resolves both player peds and compares their server-observed coordinates to the vehicle.
- Both officer and restrained target must remain within the bounded vehicle interaction distance.
- Escort state is not cleared and the client placement event is not emitted until all validation succeeds.
- The success audit records the observed placement distance.

The runtime hardening was merged in PR #100.

## Regression coverage

`tools/check_le_vehicle_placement_authority.py` is wired into DPN Quality Gate and verifies the server-resolution, entity-type, proximity, ordering, mutation, and audit-evidence contract.

Existing event names, argument shapes, restraint rules, and normal nearby-vehicle placement remain compatible.
