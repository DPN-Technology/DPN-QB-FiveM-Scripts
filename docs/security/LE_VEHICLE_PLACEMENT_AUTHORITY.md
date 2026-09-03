# Law-Enforcement Vehicle Placement Authority Hardening

## Scope

This document records the server-authority contract required for `dpn-le-core:server:putInVehicle` before runtime hardening is merged.

The current server path already requires an authorized on-duty law-enforcement actor, validates officer-to-target distance, and requires the target to be restrained. However, the vehicle network ID is supplied by the client and is forwarded to the target without a server-side proof that the network ID resolves to an existing vehicle near the officer and restrained target.

This preparation is documentation-only. It does not remove or alter gameplay behavior.

## Security objective

The server must remain authoritative over which vehicle can be used for a forced placement action. A client-provided network ID is an untrusted selector, not proof that the referenced entity is a valid nearby vehicle.

Before `dpn-le-core:client:putInVehicle` is emitted, the server implementation should prove all of the following:

1. The actor passes the existing `actionAllowed(src, true)` authorization and rate-limit path.
2. The target is a valid connected player, is not the actor, and remains within the configured interaction distance.
3. The target is currently restrained according to server-owned restraint state.
4. `vehicleNetId` is numeric, positive, and resolves server-side to an existing entity.
5. The resolved entity is a vehicle.
6. The vehicle is within `Config.Interactions.VehicleDistance` of the actor and the target.
7. Validation happens immediately before the client event is emitted so a stale or swapped network ID cannot bypass the checks.
8. A rejected request does not clear escort state, move the target, or produce a successful placement audit record.

## Compatibility requirements

The runtime fix must preserve:

- the existing `dpn-le-core:server:putInVehicle` event name and argument shape;
- the existing `dpn-le-core:client:putInVehicle` event;
- the configured `Config.Interactions.VehicleDistance` behavior;
- existing restraint requirements;
- existing law-enforcement authorization and rate limiting;
- normal placement into a legitimate nearby networked vehicle;
- action logging for successful placements.

No compatibility alias or unique gameplay functionality should be deleted as part of this hardening.

## Recommended server-side validation shape

The implementation should use the FiveM server entity APIs to resolve the supplied network ID and obtain the entity coordinates. Validation should fail closed when the entity cannot be resolved or no longer exists. The server should avoid trusting coordinates supplied by the requesting client for this decision.

A small helper should encapsulate the check so future vehicle-related actions can reuse the same policy rather than duplicating validation logic.

Conceptually, the helper should:

- convert the network ID with `tonumber`;
- reject non-positive IDs;
- resolve the entity from the network ID;
- reject missing/nonexistent entities;
- verify the entity type is a vehicle;
- compare server-observed entity coordinates with server-observed actor and target coordinates;
- return the validated entity or a false/nil result.

## Required regression coverage

A focused CI guard should fail if the privileged placement path regresses to forwarding a raw client-supplied network ID without server entity validation.

At minimum, the guard should assert that the server file contains:

- a server-side network-ID-to-entity resolution step;
- an entity existence check;
- a vehicle-type check;
- a server-side distance check between the resolved vehicle and the participants;
- the validation before `TriggerClientEvent('dpn-le-core:client:putInVehicle', ...)`;
- no successful `PLACE_IN_VEHICLE` audit path before validation completes.

The existing repository validator, manifest integrity check, medical registry ownership guard, MIB authorization guard, PD doorbell authority guard, and Lua syntax validation must remain enabled. The new guard is additive only.

## Negative test cases

Runtime validation should reject without moving the target when:

- the network ID is nil, a string that cannot be converted, zero, or negative;
- the network ID does not resolve to an entity;
- the entity was deleted between selection and server processing;
- the network ID points to a non-vehicle entity;
- the vehicle is remote from the officer;
- the vehicle is remote from the restrained target;
- the target is no longer restrained;
- the officer is no longer authorized/on duty;
- the actor or target disconnects before validation completes.

## Positive test cases

Runtime validation should continue to allow placement when:

- an authorized on-duty officer is near a restrained target;
- the supplied network ID resolves to an existing vehicle;
- both participants are within the configured vehicle interaction distance;
- all existing rate-limit and authorization requirements pass.

## Follow-on implementation boundary

The runtime implementation should be delivered as a separate focused hardening change from a fresh current `main`, with an additive regression checker and Quality Gate integration. It should not be mixed into Phase 3B-3G emergency ownership work, and it should not rewrite or rebase those phase branches.
