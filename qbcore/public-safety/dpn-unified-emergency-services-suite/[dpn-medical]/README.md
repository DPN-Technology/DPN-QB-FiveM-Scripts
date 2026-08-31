# [dpn-medical] — DPN Medical / EMS Suite

## Integrated Component of the DPN Unified Emergency Services Suite

**Created by Diesel — CEO of DPN Technology**

This bracketed folder is intentionally preserved as **one coordinated medical and EMS platform**. Its modules share an authoritative medical core and are designed to work together with DPN Dispatch, MDT, Law Enforcement, Fire/Rescue, and Incident Command.

## Included Modules

| Resource | Role |
|---|---|
| `dpn-medical-core` | Authoritative medical/injury state |
| `dpn-medical-ems` | EMS field operations |
| `dpn-medical-dispatch` | Medical dispatch integration |
| `dpn-medical-ambulance` | Ambulance/transport workflows |
| `dpn-medical-hospital` | Hospital operations |
| `dpn-medical-records` | Medical records |
| `dpn-medical-lifepak` | Monitor/LifePak-style workflows |
| `dpn-medical-inventory` | Medical inventory/supplies |
| `dpn-medical-pharmacy` | Pharmacy/medication systems |
| `dpn-medical-radiology` | Radiology/imaging workflows |
| `dpn-medical-surgery` | Surgery workflows |
| `dpn-medical-icu` | ICU workflows |
| `dpn-medical-disease` | Disease/condition systems |
| `dpn-medical-rehab` | Rehabilitation workflows |
| `dpn-medical-coroner` | Coroner/death-management workflows |
| `dpn-medical-insurance` | Insurance workflows |
| `dpn-medical-billing-plus` | Medical billing |
| `dpn-medical-training` | Medical training |
| `dpn-medical-ai` | Medical AI/support workflows |
| `dpn-medical-admin-tools` | Medical administration and diagnostics |

## Shared Core Dependencies

The medical stack integrates with:

- `dpn-unified-emergency-network`
- `dpn-dispatch`
- `dpn-mdt`
- `dpn-incident-command`

## Critical Medical-Core Rule

`dpn-medical-core` is intended to own authoritative injury/death/medical state for this stack. Do not run another conflicting death, last-stand, injury, revive, or hospital-respawn authority without carefully reviewing the integration.

## Installation

Use the parent suite's [START_ORDER.cfg](../START_ORDER.cfg) and [DATABASE_INSTALL.md](../docs/DATABASE_INSTALL.md). Back up the database before applying medical schemas or upgrades.

**DPN Technology — DPN-CSL applies to DPN-owned portions.**
