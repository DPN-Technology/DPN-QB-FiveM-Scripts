# DPN-MDT

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


DPN-MDT is a QBCore Mobile Data Terminal designed for the DPN Unified Emergency Service Network. It connects law enforcement, EMS, fire/rescue, courts/DOJ, MIB/admin, dispatch, evidence, warrants, BOLOs, reports, fire preplans, medical records, and audit logging into one NUI tablet.

This resource is built as an original DPN implementation with ps-mdt-style workflows. Project-Sloth ps-mdt is licensed under CC BY-NC-SA 4.0. If you directly merge or adapt code from ps-mdt, keep attribution, non-commercial use, and share-alike licensing intact.

## Main Features

- Law enforcement MDT access for LSPD, BCSO, SAHP, FIB, SASP, police jobs.
- EMS access for patient care reports, triage, treatments, hospital transport records.
- Fire/rescue access for fire incident records, building preplans, hydrants, hazards, utility shutoff notes, search-and-rescue notes.
- Courts/DOJ access for dockets, criminal/civil cases, hearings, charges, sentencing workflow placeholders.
- Corrections access for custody records, inmate status, housing, movement logs, and disciplinary notes.
- MIB/admin access for emergency overrides, admin audit trail, neuralizer/portal logging hooks.
- Dispatch board connected by events and exports to `dpn-dispatch`.
- Unified emergency network hooks for `dpn-unified-emergency-network`.
- QBCore citizen search and player vehicle search.
- Reports, cases, evidence, warrants, BOLOs, charges, and audit trail database tables.
- Permission-aware module list based on job/department and grade.
- F11 keybind and `/mdt` command.
- Browser-previewable NUI for fast layout testing.
- Department auto-themes: law enforcement dark blue, EMS orange, fire red, justice grey, MIB/admin black, and corrections brown.
- Responsive NUI fixes for cut-off panels, wide dispatch tables, smaller screens, and long department/module names.


## Latest Update: Opaque UI + Advanced Penal Codes

This build fixes transparent/see-through MDT sections and expands the Penal Code module into a larger RP charging system. The seeded SQL now includes 121 penal codes across law enforcement, traffic, violent/property crimes, narcotics, weapons, courts, corrections, emergency services, fire/rescue, EMS/medical, and MIB/admin categories.

The Penal Code page now has category/class filters, automatic result loading, selected-charge summaries, and a supervisor penal-code builder guarded by `Config.Permissions.manageCharges`.

See `docs/UI_OPAQUE_AND_ADVANCED_CHARGES.md` for details.

## Dependencies

Required:

- `qb-core`
- `oxmysql`

Recommended / optional:

- `dpn-dispatch`
- `dpn-unified-emergency-network`
- `screenshot-basic`
- `dpn-neuralizer`
- `dpn-pg-7x`

## Installation

1. Drop the `dpn-mdt` folder into your resources folder.
2. Import `sql/dpn_mdt.sql` into your FiveM database.
3. Edit `config.lua` and match your exact job names.
4. Add this to `server.cfg` after dependencies:

```cfg
ensure qb-core
ensure oxmysql
ensure dpn-dispatch
ensure dpn-unified-emergency-network
ensure dpn-mdt
```

5. Restart your server.
6. Go on duty as an authorized job and press F11 or run `/mdt`.

## QBCore Job Examples

Add job names to `Config.Departments` in `config.lua`. Example:

```lua
Config.Departments.leo.jobs = { 'police', 'lspd', 'bcso', 'sahp', 'fib', 'sasp' }
Config.Departments.ems.jobs = { 'ambulance', 'ems', 'doctor' }
Config.Departments.fire.jobs = { 'fire', 'fd', 'firefighter' }
Config.Departments.courts.jobs = { 'judge', 'lawyer', 'doj' }
Config.Departments.corrections.jobs = { 'corrections', 'doc', 'prison', 'jail', 'jailer' }
Config.Departments.mib.jobs = { 'mib', 'admin' }
```


## Department Themes

The UI automatically changes color from the authorized department context returned by the server:

- `leo` = dark blue law enforcement MDT
- `ems` = orange EMS MDT
- `fire` = red fire/rescue MDT
- `courts` = grey justice/court MDT
- `mib` = black MIB/admin MDT
- `corrections` = brown corrections MDT

Set each department theme in `config.lua` with the `theme` field. Example:

```lua
Config.Departments.leo.theme = 'leo'
Config.Departments.ems.theme = 'ems'
Config.Departments.fire.theme = 'fire'
Config.Departments.courts.theme = 'courts'
Config.Departments.corrections.theme = 'corrections'
Config.Departments.mib.theme = 'mib'
```

## Dispatch Integration

From another server resource:

```lua
exports['dpn-mdt']:CreateDispatchCall({
    code = '10-80',
    title = 'Vehicle Pursuit',
    description = 'Black Sultan fleeing from officers.',
    priority = 'high',
    department = 'leo',
    caller = 'Dispatch',
    location = 'Alta St',
    coords = { x = 215.0, y = -810.0, z = 30.0 },
    metadata = { source = 'dpn-dispatch' }
})
```

Or with an event:

```lua
TriggerEvent('dpn-mdt:server:ReceiveDispatchCall', {
    code = 'FIRE-1',
    title = 'Structure Fire',
    description = 'Smoke showing from second floor.',
    priority = 'critical',
    department = 'fire',
    location = 'South Rockford Dr'
})
```

## Exports

Server exports:

- `exports['dpn-mdt']:IsAuthorized(source)`
- `exports['dpn-mdt']:CreateDispatchCall(callData)`
- `exports['dpn-mdt']:RegisterEvidence(data)`
- `exports['dpn-mdt']:RegisterWeapon(citizenid, weaponName, serial, info)`
- `exports['dpn-mdt']:GetActiveWarrants(citizenid)`

Client exports:

- `exports['dpn-mdt']:OpenMDT()`
- `exports['dpn-mdt']:CloseMDT()`
- `exports['dpn-mdt']:IsMDTOpen()`
- `exports['dpn-mdt']:GetMDTContext()`

## Security Notes

The server checks access before returning data or mutating records. Do not trust client-side UI permissions alone. Keep MIB/admin features behind job grade and ACE permissions.

Recommended ACE example:

```cfg
add_ace group.admin admin allow
add_ace group.god god allow
```

## Next Upgrade Targets

- Add exact penal code editor UI.
- Add mugshot upload bridge.
- Add charge sentencing calculator.
- Add bodycam and dashcam viewer hooks.
- Add real GIS hydrant map overlay.
- Add fire spread prediction feed from `dpn-fire-system`.
- Add court calendar sync with your court system.
- Add advanced IA/PPR personnel files.


## Advanced QBCore Data Pulls

This build adds real SQL-backed citizen and vehicle profiles. See `docs/DATA_PULLS.md` for the full list of pulled player, vehicle, license, money, warrant, report, medical, corrections, weapon, BOLO, note, and vehicle-flag data.


## Charging & Penal Code Upgrade

This build includes a full penal-code charging system. Officers, courts, MIB/admin, and corrections can search penal codes, add multiple charges, calculate fines/jail/points, file citizen charges, link charges to reports/cases/warrants, and view charge history inside citizen profiles. See `docs/CHARGING.md`.
