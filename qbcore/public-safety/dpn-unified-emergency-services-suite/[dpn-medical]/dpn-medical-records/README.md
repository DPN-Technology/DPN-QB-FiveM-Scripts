# dpn-medical-records 2.0.1

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Central longitudinal patient records and the cross-module clinical timeline.

## 2.0.1 schema compatibility

- Automatically inspects `dpn_medical_records` on startup.
- Adds missing v5 canonical columns.
- Backfills values from common legacy column names.
- Preserves all existing rows and legacy fields.
- Supplies values for required legacy columns during new inserts.
- Exposes `GetSchemaStatus` for diagnostics.
- Adds the `/medrecordschema` administrator command.

For manual database repair, import:

```text
sql/dpn-medical-records.sql
```


## v6 Clinical-Operations Layer
This resource includes its v6 operational workflow in `server/v6.lua` and integrates with the DPN Medical digital twin, orders, observations, safety alerts and structured handoffs.


## Version 9 adaptive network
This resource includes a `server/v9.lua` operational layer registered with DPN Medical Core v9. Use `V9_API.md` in the suite root for the supported exports.
