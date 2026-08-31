# DPN-MDT Advanced Data Pulls

This build reads real QBCore data directly from your database and live player cache.

## Core tables used

- `players`
- `player_vehicles`
- `dpn_mdt_reports`
- `dpn_mdt_cases`
- `dpn_mdt_warrants`
- `dpn_mdt_bolos`
- `dpn_mdt_medical_records`
- `dpn_mdt_corrections_records`
- `dpn_mdt_weapons`
- `dpn_mdt_citizen_notes`
- `dpn_mdt_vehicle_flags`

## What citizen profiles pull

- Citizen ID, name, DOB, gender, nationality, phone
- Job, grade, duty status, gang
- Cash/bank/crypto from QBCore money JSON
- Licenses from QBCore metadata JSON
- Fingerprint, blood type, callsign, live source ID, ping, live coords when online
- Registered vehicles
- Warrants, reports, cases, BOLOs, medical, corrections, weapons, and MDT notes

## What vehicle profiles pull

- Plate, fake plate, model, hash, owner, garage, state
- Fuel, engine, body, mileage, depot/finance fields when your `player_vehicles` table has them
- Owner citizen profile summary
- Linked reports, active BOLOs, and MDT vehicle flags

## Compatibility

The server checks `information_schema` before selecting optional QBCore columns. If your database lacks a column like `fakeplate`, `financetime`, or `drivingdistance`, the MDT skips it instead of throwing a callback error.

If your server renamed the QBCore tables, edit `Config.Database` in `config.lua`.
