# Update Instructions

## Existing Installation

1. Stop `dpn-medical-hospital` or stop the FiveM server.
2. Back up the existing `dpn-medical-hospital` folder.
3. Replace the entire old folder with the new `dpn-medical-hospital` folder.
4. Keep the folder name exactly `dpn-medical-hospital`.
5. Existing installations do not require a database migration because v1.1.0 uses the original table columns.
6. Verify the resource order in `server.cfg`:

```cfg
ensure qb-core
ensure oxmysql
ensure dpn-medical-core
ensure dpn-medical-ems
ensure dpn-medical-hospital
```

7. Start the server.
8. Confirm the console no longer reports an error in `shared/states.lua` and shows:

```text
[dpn-medical-hospital] Restored 0 active admission(s).
```

The number may be greater than zero when patients already have active admissions.

## New Installation

Import `sql/dpn_medical_hospital.sql`, then follow the resource order above.

## Basic Test

1. Join the server.
2. Walk to the Pillbox check-in point.
3. Check in through qb-target or the E-key fallback marker.
4. Press F7 or run `/hospitalstatus`.
5. As an on-duty medical employee, test `/hospitalbeds`.
6. Test `/admit [id] er 5 Test admission` with a nearby player.
7. Wait for recovery or use an authorized staff discharge.

## Important Configuration

Review `shared/config.lua` before going live, especially:

- `Config.JobAccess`
- `Config.RequireOnDutyForStaffActions`
- `Config.CheckInCost`
- `Config.StaffAdmissionDistance`
- `Config.Hospitals`
- `Config.RequiredAdmissionByCondition`
