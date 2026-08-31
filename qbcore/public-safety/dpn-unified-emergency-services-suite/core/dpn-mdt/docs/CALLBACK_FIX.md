# DPN-MDT CanOpen Callback Fix

This build fixes the common `callback CanOpen failed` / `callback error: CanOpen` issue.

## What changed

- `CanOpen` no longer hard-fails if the audit log SQL table is missing.
- Added safe database wrappers around oxmysql calls so missing MDT tables print a server-console error instead of crashing the open callback.
- Added a client callback timeout so `/mdt` will return a clear error instead of freezing forever.
- Added `/mdtdebug` to test the open permission/callback result in-game.
- Improved the authorization error message for jobs not listed in `Config.Departments` or players who are off duty.

## If it still does not open

1. Make sure your server.cfg order is:

```cfg
ensure qb-core
ensure oxmysql
ensure dpn-dispatch
ensure dpn-unified-emergency-network
ensure dpn-mdt
```

2. Import `sql/dpn_mdt.sql` into your database.
3. Make sure your player job is listed in `config.lua` under `Config.Departments`.
4. If `Config.OnlyShowOnDuty = true`, go on duty before opening `/mdt`.
5. Run `/mdtdebug` in-game and check F8/server console output.
