# dpn-medical-hospital v1.1.0

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Advanced hospital admissions, secure bed management, triage routing, persistent recovery, billing, transfers, and discharge workflows for QBCore and `dpn-medical-core`.

## Important Fix in 1.1.0

The original `shared/states.lua` used this invalid Lua table key:

```lua
or = 'Operating Room'
```

`or` is a reserved Lua keyword. It is now correctly defined through bracket notation:

```lua
['or'] = 'Operating Room'
```

The state file now also includes ward validation, state labels, legal state transitions, and normalization helpers.

## Installation

1. Replace the old `dpn-medical-hospital` folder with this folder.
2. Import `sql/dpn_medical_hospital.sql` for a new installation.
3. Keep the resource name exactly `dpn-medical-hospital`.
4. Use this load order:

```cfg
ensure qb-core
ensure oxmysql
ensure dpn-medical-core
ensure dpn-medical-ems
ensure dpn-medical-hospital
```

5. Restart the server and confirm the console reports restored active admissions.

## Requirements

- QBCore
- oxmysql
- dpn-medical-core
- qb-target is optional; a marker and E-key fallback is included.

## Player Controls

- `/hospitalstatus` or F7: open the patient portal.
- Hospital check-in is available through qb-target or the fallback marker.
- Patients can pay outstanding bills and request discharge after recovery reaches zero.

## Medical Staff Commands

- `/admit [id] [er|icu|or|recovery] [minutes] [reason]`
- `/dischargepatient [id] [reason]`
- `/transferpatient [id] [er|icu|or|recovery] [hospital]`
- `/hospitalbeds`

Staff actions require an allowed job and, by default, on-duty status. Admin and god permissions bypass staff-job restrictions.

## Major Improvements

- Fixed the Lua parser failure caused by the reserved `or` keyword.
- Persistent active admissions restored from the database after resource restart.
- Protected manual bed-release event.
- Duplicate active admission prevention.
- Server-side hospital and ward validation.
- Server-side distance validation for self check-in and staff admissions.
- Event cooldowns to reduce spam and abuse.
- Atomic-style bed reservation with rollback on database failure.
- Ward fallback when the requested ward is full.
- Configurable triage recommendations and severity-based billing.
- Secure payment locking and automatic refund if a payment race occurs.
- Patient transfer workflow with bed handoff.
- Legal hospital state-transition checks.
- Public bed sync no longer exposes patient citizen IDs or server IDs.
- Recovery controls now run every game frame, as required by FiveM.
- Combat, sprinting, jumping, and vehicle controls can be restricted while bed-bound.
- Responsive NUI with recovery progress, bill status, bed census, and Escape-to-close.
- NUI text is escaped before rendering to prevent HTML injection.
- Check-in fallback works when qb-target is disabled or unavailable.

## Configuration

Edit `shared/config.lua` to configure:

- Staff and surgeon jobs.
- On-duty requirements.
- Hospital costs and severity surcharge.
- Recovery timing limits.
- Self-discharge and bill requirements.
- Server-side interaction distances.
- Hospital locations and beds.
- Triage condition routing.
- Recovery effects and control restrictions.

## Wards

- `er`: Emergency Room
- `icu`: Intensive Care Unit
- `or`: Operating Room
- `recovery`: Recovery Ward

## Database

The resource uses:

- `dpn_hospital_admissions`
- `dpn_hospital_bed_log`

The current code remains compatible with the original table columns.


## Version 5 Advanced Integration
Capacity reporting, risk-based routing, admission plans and automated deterioration escalation.


## v6 Clinical-Operations Layer
This resource includes its v6 operational workflow in `server/v6.lua` and integrates with the DPN Medical digital twin, orders, observations, safety alerts and structured handoffs.


## Version 9 adaptive network
This resource includes a `server/v9.lua` operational layer registered with DPN Medical Core v9. Use `V9_API.md` in the suite root for the supported exports.
