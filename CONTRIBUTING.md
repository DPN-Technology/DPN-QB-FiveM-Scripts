# Contributing to DPN QB FiveM Scripts

Thank you for helping improve DPN Technology's public FiveM resources.

## Before contributing

- Read `README.md`, `LICENSE`, `NOTICE.md`, `SECURITY.md`, and `COMMERCIAL_PERMISSION.md`.
- Do not submit secrets, private server configuration, credentials, API keys, webhooks, private keys, or third-party content you are not authorized to redistribute.
- New resources must follow the repository's `qbcore/`, `standalone/`, or `hybrid/` catalog structure.
- New DPN resources should use the `dpn-` naming convention and include `fxmanifest.lua`, `README.md`, and required resource metadata.

## Development workflow

1. Create a focused branch for the change.
2. Keep commits scoped and descriptive.
3. Run the repository validators before opening a pull request:
   - `python3 tools/dpn_repo_validator.py`
   - `python3 tools/check_fivem_manifest_integrity.py`
   - `python3 tools/check_medical_registry_ownership.py` when applicable
   - `python3 tools/check_fivem_lua_syntax.py`
4. Open a pull request using the repository template.
5. Resolve CI, security, manifest, syntax, metadata, and review findings before merge.

## Resource standards

- Use `fxmanifest.lua`; legacy `__resource.lua` is not accepted.
- Manifest-referenced files must exist.
- Resource folder names must be globally unique.
- Keep dependencies explicit and documented.
- Preserve compatibility notes for QBCore or standalone use.
- Do not weaken security checks, secret scanning, workflow permission limits, or immutable Action pinning without documented justification.

## Licensing and commercial use

Contributions are accepted under the repository's existing licensing and usage terms. Selling, relicensing, or commercially redistributing DPN Technology scripts is governed by `LICENSE` and `COMMERCIAL_PERMISSION.md` and may require explicit permission.

## Security reports

Do not disclose sensitive vulnerabilities in a public issue. Follow `SECURITY.md` for responsible reporting.

© DPN Technology.