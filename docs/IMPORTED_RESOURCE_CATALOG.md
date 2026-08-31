# DPN FiveM Imported Resource Catalog

## Initial DPN Technology Public Release Collection

**Created by Diesel — CEO of DPN Technology**

The initial uploaded collection contains **45 actual FiveM resources** organized by function while preserving tightly coupled bracketed suites.

## Unified Emergency Services Platform — 35 Resources

Location:

`qbcore/public-safety/dpn-unified-emergency-services-suite/`

### Shared Cross-Agency Core — 3

- `dpn-unified-emergency-network`
- `dpn-dispatch`
- `dpn-mdt`

### [dpn-lawenforcement] — 12

- `dpn-crime-intelligence`
- `dpn-digital-dispatch`
- `dpn-drone-command`
- `dpn-emergency-network`
- `dpn-evidence-ai`
- `dpn-incident-command`
- `dpn-le-core`
- `dpn-le-operations`
- `dpn-officer-safety`
- `dpn-smart-city`
- `dpn-training-academy`
- `dpn-vehicle-computer`

### [dpn-medical] — 20

- `dpn-medical-admin-tools`
- `dpn-medical-ai`
- `dpn-medical-ambulance`
- `dpn-medical-billing-plus`
- `dpn-medical-core`
- `dpn-medical-coroner`
- `dpn-medical-disease`
- `dpn-medical-dispatch`
- `dpn-medical-ems`
- `dpn-medical-hospital`
- `dpn-medical-icu`
- `dpn-medical-insurance`
- `dpn-medical-inventory`
- `dpn-medical-lifepak`
- `dpn-medical-pharmacy`
- `dpn-medical-radiology`
- `dpn-medical-records`
- `dpn-medical-rehab`
- `dpn-medical-surgery`
- `dpn-medical-training`

## Additional QBCore Resources — 6

### Law Enforcement

- `qbcore/law-enforcement/dpn-starchase`
- `qbcore/law-enforcement/dpn_mobilespikes`
- `qbcore/law-enforcement/dpn_police_qbdoorbell`

### Administration

- `qbcore/admin/dpn-mib-system`

### Civilian

- `qbcore/civilian/dpn_sitanywhere`

### World / Traffic

- `qbcore/world/dpn-real-traffic`

## Hybrid Resources — 3

### Administration

- `hybrid/admin/dpn-pg-7x`
- `hybrid/admin/dpn_neuralizer`

### Communications

- `hybrid/communications/dpn_pasystem`

## Standalone Resources — 1

### Administration / Server Operations

- `standalone/admin/dpn-queue`

## Naming Compatibility

Some uploaded resources use legacy `dpn_` names. Those names are preserved intentionally because changing a FiveM resource directory can break `ensure` entries, exports, dependency declarations, resource-state checks and cross-resource integrations.

New DPN resources should use the `dpn-` convention.

## Integration Principle

The Law Enforcement and Medical bracketed packs are **not split into unrelated standalone projects**. They remain inside the DPN Unified Emergency Services Suite, with Dispatch, MDT and the unified emergency network stored at the shared core because those services connect multiple departments.

For deployment details see the suite README, architecture, resource matrix, database inventory, start order and pre-install checklist.
