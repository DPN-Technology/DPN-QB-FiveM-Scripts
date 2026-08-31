# Database Installation Inventory

**Back up your database before importing or upgrading any schema.**

The imported suite contains the following SQL files. Review each file and resource README before applying it. Do not blindly execute both an install and upgrade script against an unknown schema version.

- `[dpn-lawenforcement]/dpn-crime-intelligence/sql/install.sql`
- `[dpn-lawenforcement]/dpn-digital-dispatch/sql/install.sql`
- `[dpn-lawenforcement]/dpn-digital-dispatch/sql/upgrade_v1_to_v2.sql`
- `[dpn-lawenforcement]/dpn-drone-command/sql/install.sql`
- `[dpn-lawenforcement]/dpn-emergency-network/sql/install.sql`
- `[dpn-lawenforcement]/dpn-evidence-ai/sql/install.sql`
- `[dpn-lawenforcement]/dpn-incident-command/sql/install.sql`
- `[dpn-lawenforcement]/dpn-le-core/sql/install.sql`
- `[dpn-lawenforcement]/dpn-le-core/sql/upgrade_v1_to_v2.sql`
- `[dpn-lawenforcement]/dpn-le-operations/sql/install.sql`
- `[dpn-lawenforcement]/dpn-officer-safety/sql/install.sql`
- `[dpn-lawenforcement]/dpn-smart-city/sql/install.sql`
- `[dpn-lawenforcement]/dpn-training-academy/sql/install.sql`
- `[dpn-lawenforcement]/dpn-vehicle-computer/sql/install.sql`
- `[dpn-medical]/dpn-medical-admin-tools/sql/dpn-medical-admin-tools.sql`
- `[dpn-medical]/dpn-medical-ai/sql/dpn-medical-ai.sql`
- `[dpn-medical]/dpn-medical-ambulance/sql/dpn-medical-ambulance.sql`
- `[dpn-medical]/dpn-medical-billing-plus/sql/dpn-medical-billing-plus.sql`
- `[dpn-medical]/dpn-medical-core/sql/dpn_medical_core.sql`
- `[dpn-medical]/dpn-medical-coroner/sql/dpn-medical-coroner.sql`
- `[dpn-medical]/dpn-medical-disease/sql/dpn-medical-disease.sql`
- `[dpn-medical]/dpn-medical-dispatch/sql/dpn-medical-dispatch.sql`
- `[dpn-medical]/dpn-medical-ems/sql/dpn-medical-ems.sql`
- `[dpn-medical]/dpn-medical-hospital/sql/dpn_medical_hospital.sql`
- `[dpn-medical]/dpn-medical-icu/sql/dpn-medical-icu.sql`
- `[dpn-medical]/dpn-medical-insurance/sql/dpn-medical-insurance.sql`
- `[dpn-medical]/dpn-medical-inventory/sql/dpn-medical-inventory.sql`
- `[dpn-medical]/dpn-medical-lifepak/sql/dpn-medical-lifepak.sql`
- `[dpn-medical]/dpn-medical-pharmacy/sql/dpn-medical-pharmacy.sql`
- `[dpn-medical]/dpn-medical-radiology/sql/dpn-medical-radiology.sql`
- `[dpn-medical]/dpn-medical-records/sql/dpn-medical-records.sql`
- `[dpn-medical]/dpn-medical-rehab/sql/dpn-medical-rehab.sql`
- `[dpn-medical]/dpn-medical-surgery/sql/dpn-medical-surgery.sql`
- `[dpn-medical]/dpn-medical-training/sql/dpn-medical-training.sql`
- `core/dpn-dispatch/docs/install.sql`
- `core/dpn-mdt/sql/dpn_mdt.sql`
- `core/dpn-unified-emergency-network/sql/install.sql`

## Recommended process

1. Stop the affected resources.
2. Back up the database.
3. Confirm whether the target is a fresh install or an upgrade.
4. Review the SQL for table/index conflicts.
5. Apply core schemas before dependent modules.
6. Start the resources in `START_ORDER.cfg` order.
7. Check server console for migration/query errors.
8. Test on a development server before production.
