# DPN-MDT Charging & Penal Code System

## What this adds

The MDT now includes a real penal-code and citizen charging workflow:

- Searchable penal-code database from `dpn_mdt_charges`
- Charge picker with quantity/multiplier support
- Automatic fine, jail-time, and driver-point totals
- Citizen charging records stored in `dpn_mdt_citizen_charges`
- Charge history shown on citizen profiles
- Optional report/case/warrant/court links
- Audit logs for every filed charge
- Unified Emergency Network record-link event support
- Optional fine/jail/court bridge events configured in `Config.Charging`

## Required SQL

Re-import `sql/dpn_mdt.sql` after updating. New installs will create everything automatically. Existing installs should make sure these tables exist:

- `dpn_mdt_charges`
- `dpn_mdt_citizen_charges`

The schema also includes an expanded default RP penal code list. You can edit the charges directly in SQL or use the `CreatePenalCode` server callback from an admin UI.

## NUI usage

Open `/mdt`, go to **Penal Code**, search for a code, click **Add**, fill the citizen ID/name, choose Arrest/Citation/Warrant Request/Court Referral, add notes, then press **File Charges**.

## Bridge events

Set these in `config.lua` if you want external resources to apply fines or jail automatically:

```lua
Config.Charging.triggerFineEvent = true
Config.Charging.fineEvent = 'dpn-mdt:server:FineIssued'
Config.Charging.triggerJailEvent = true
Config.Charging.jailEvent = 'dpn-mdt:server:JailSentenceIssued'
```

The MDT intentionally does not force money removal or jail time by default, so you can connect it to your preferred billing, jail, or court resource safely.
