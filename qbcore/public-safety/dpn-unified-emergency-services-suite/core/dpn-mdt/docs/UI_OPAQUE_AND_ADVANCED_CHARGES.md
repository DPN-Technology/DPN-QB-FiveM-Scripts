# DPN-MDT Opaque UI + Advanced Penal Code Update

## Opaque UI Fix

This build removes the see-through look from MDT sections. The NUI still keeps the outside of the tablet transparent, but the tablet itself, sidebar, topbar, content area, cards, tables, inputs, selected-charge boxes, alerts, and action buttons are now solid department-colored panels.

Affected file:

```text
html/style.css
```

The update adds a `DPN opaque UI hotfix` block at the bottom of the stylesheet. If your server uses an older cached NUI, restart the resource and clear your FiveM cache if needed.

## Advanced Penal Code System

The default SQL seed now includes 121 RP penal codes covering:

- Public order / government operations
- Traffic and vehicle offenses
- Violent crimes
- Property crimes
- Narcotics
- Weapons
- Financial crimes
- Courts / DOJ
- Corrections
- Emergency services
- Fire / rescue
- EMS / medical
- MIB / admin disciplinary codes

Affected files:

```text
sql/dpn_mdt.sql
server/main.lua
html/app.js
html/style.css
```

## New Penal Code UI Features

The Penal Code module now includes:

- Search by code, title, category, class, or description
- Category filter
- Class filter
- Auto-loading search results when the Penal Code page opens
- Larger 250-result limit
- Selected-charge count summary
- Improved selected-charge totals
- Supervisor Penal Code Builder UI
- Permission-gated server callback for creating new penal codes

## SQL Upgrade Note

If you already imported an older SQL file, import this updated `sql/dpn_mdt.sql` again. It uses `CREATE TABLE IF NOT EXISTS` and `INSERT IGNORE`, so it will add missing seeded codes without duplicating existing ones.

If your database engine does not support `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, add the listed columns manually or ignore duplicate-column warnings if the columns already exist.

## Recommended Test

1. Restart `dpn-mdt`.
2. Run `/mdt`.
3. Open the Penal Code section.
4. Filter category `traffic` and class `felony`.
5. Add multiple charges to the charging sheet.
6. File charges against a real citizen ID.
7. Open the citizen profile and verify the charge history appears.
