# DPN StarChase SQL Identifier Hardening

Status: implementation candidate

Baseline refreshed from `main` at `9233cae414f5325f40d6a88f44a299f7f78ac0dd`.

## Finding

StarChase row values were already parameterized, but the configurable database table name was interpolated into `CREATE TABLE` and `INSERT INTO` statements because SQL identifiers cannot be supplied through normal value placeholders.

The configured table name is server-owned rather than client-provided, so this was a hardening/review signal rather than evidence of a client SQL-injection path. The identifier boundary is now explicit and fail-closed.

## Remediation contract

- `server/database.lua` resolves the configured table name through `ident(value, fallback)`.
- Identifiers must match `^[%w_]+$`.
- Identifiers longer than 64 characters are rejected.
- Empty or invalid identifiers fall back to `dpn_starchase_logs`.
- Invalid configured values produce a bounded warning.
- Both dynamic SQL statements consume only the validated resolver output.
- Row values remain parameterized with `?` placeholders.
- `tools/check_starchase_sql_identifier.py` prevents a future direct interpolation regression.
- DPN Quality Gate executes the regression check on every PR and push to `main`.

## Maturity

After the exact candidate head passes the repository gates, StarChase may be recorded as `hardened` rather than `imported` because the dynamic SQL review has an explicit defensive contract and CI evidence.
