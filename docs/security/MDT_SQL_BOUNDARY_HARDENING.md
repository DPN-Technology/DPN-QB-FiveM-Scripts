# DPN MDT — Dynamic SQL Boundary Hardening

**Resource:** `dpn-mdt`  
**Target release:** `1.1.1-charges`  
**Status:** Candidate pending CI validation

## Objective

Strengthen the MDT's advanced QBCore compatibility layer where SQL identifiers must be constructed dynamically to support installations with renamed core tables or differing schemas.

## Controls

- Configured table names are validated once at startup.
- Table identifiers are restricted to `[A-Za-z0-9_]` and a maximum of 64 characters.
- Malformed configured table names fall back to known-safe QBCore defaults.
- Invalid configured values are logged with bounded output.
- Column identifiers continue to pass through the same strict quoting boundary.
- Dynamic WHERE suffix composition no longer accepts arbitrary SQL fragments.
- Optional count filters are selected by a server-owned key from `COUNT_FILTERS`.
- Search/profile values remain parameterized.

## Regression enforcement

`tools/check_mdt_sql_boundary.py` fails the DPN Quality Gate if the identifier bound, fallback map, filter allowlist, parameterized count queries, hardened metadata, or documentation disappear.

## Scope

This change does not alter the public MDT callback names, exports, commands, department permissions, QBCore data model, or database schema.
