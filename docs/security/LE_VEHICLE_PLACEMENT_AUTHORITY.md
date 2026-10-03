# Law-Enforcement Vehicle Placement Authority Hardening

Baseline: `main` at `6bea5b82dd09764584e9e6ea9664c23a15b580e4`.

## Current finding

`dpn-le-core:server:putInVehicle` currently:

- checks law-enforcement action authority;
- normalizes the target and client-supplied vehicle network ID;
- checks officer-to-target distance;
- requires server-owned restraint state;
- then forwards the network ID to the target client and records a successful placement action.

It still does not resolve the supplied network ID server-side, prove the entity exists, prove it is a vehicle, or prove that the vehicle is near the officer and restrained target.

## Required server-authority contract

Before `dpn-le-core:client:putInVehicle` is emitted:

1. Require existing officer authorization and rate limiting.
2. Require a valid restrained target within the configured interaction distance.
3. Require a positive numeric network ID.
4. Resolve the network ID server-side to an existing entity.
5. Verify the entity type is a vehicle.
6. Verify the vehicle is within `Config.Interactions.VehicleDistance` of the relevant participants using server-observed coordinates.
7. Fail closed before clearing escort state, moving the target, or writing a success audit record.
8. Add an additive regression guard to the DPN Quality Gate.

Existing event names, argument shapes, normal nearby-vehicle placement, restraint rules, and gameplay behavior must remain compatible.
