# DPN-MDT Install Checklist

1. Import `sql/dpn_mdt.sql`.
2. Confirm these tables exist:
   - `dpn_mdt_dispatch_calls`
   - `dpn_mdt_reports`
   - `dpn_mdt_cases`
   - `dpn_mdt_bolos`
   - `dpn_mdt_warrants`
   - `dpn_mdt_evidence`
   - `dpn_mdt_court_cases`
   - `dpn_mdt_medical_records`
   - `dpn_mdt_fire_records`
   - `dpn_mdt_fire_preplans`
   - `dpn_mdt_audit_logs`
3. Confirm `qb-core` starts before `dpn-mdt`.
4. Confirm `oxmysql` starts before `dpn-mdt`.
5. Confirm your job names match `config.lua`.
6. Add `ensure dpn-mdt` after all dependencies.
7. Go on duty and press F11.

## Common Fixes

### MDT says unauthorized
- Your job name is not in `Config.Departments`.
- You are off duty and `Config.OnlyShowOnDuty = true`.
- Your MIB/admin permissions do not have the configured ACE.

### Citizen search does not return names
- Your `players.charinfo` format may differ. Adjust `SearchCitizens` in `server/main.lua`.

### Vehicle search fails
- Your vehicle table may not be named `player_vehicles`. Change the SQL in `SearchVehicles`.

### Dispatch calls are not showing
- Make sure `dpn-dispatch` calls `exports['dpn-mdt']:CreateDispatchCall(data)` or triggers `dpn-mdt:server:ReceiveDispatchCall`.


## Department UI colors

The MDT now applies the theme from `Config.Departments.<department>.theme`:

- Law enforcement: `leo` dark blue
- EMS: `ems` orange
- Fire: `fire` red
- Courts/justice: `courts` grey
- MIB/admin: `mib` black
- Corrections: `corrections` brown

If the wrong color opens, check that the player job is listed under the correct department in `config.lua` and that the department has the correct `theme` value.

## UI cut-off fixes

This build uses a responsive NUI shell, fixed min-height containers, scrollable navigation, scrollable content, wrapped action buttons, and horizontally scrollable tables. This prevents the dispatch board, roster, reports, and smaller 720p/900p displays from cutting off.
