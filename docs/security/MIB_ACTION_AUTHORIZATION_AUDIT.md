# DPN MIB Action Authorization Hardening

Status: remediation implemented

Baseline refreshed from `main` at `efb9eef0055c823775e04282815c66a5c7780ffa`.

## Resolution

The MIB runtime now separates **MIB access** from **administrative authority** and enforces server-owned action policy before privileged effects.

- `Config.AcePermissions` grants normal MIB access only.
- `Config.AdminAcePermissions` is a separate admin trust domain; the default explicit ACE is `dpn.mib.admin`.
- QBCore `admin` / `god` compatibility remains authoritative when `Config.UseAdminPermission` is enabled.
- Director authority is derived from the server-side MIB job and the existing `director` grade.
- `Config.MIBActionPolicy` maps sensitive tool actions to `mib`, `director`, or `admin` tiers.
- Scene wipes, medical override, lockdown, remote movement/observation, and threat controls require Director by default.
- Player kicks and routing-bucket changes require Admin by default.
- Standard Alpha/Beta neuralizer modes remain normal MIB operations; Gamma/Omega and Advanced Area modes require Director.
- Unknown policy names fail closed at the Admin tier.
- Denied escalations generate bounded `ACTION_AUTHORIZATION_DENIED` audit evidence.
- Routing buckets must be integers inside the server-owned configured range before `SetPlayerRoutingBucket` can run.

Reasons remain audit controls and do not grant authority.

## Compatibility and migration

Servers that previously used `dpn.mib` as an implicit full-admin ACE should explicitly grant `dpn.mib.admin` to principals that are intended to retain administrative actions. Normal MIB ACE users keep baseline MIB functions without inheriting kick/routing-bucket authority.

Existing QBCore `admin` and `god` users retain administrative compatibility. Existing MIB Director job-grade behavior is preserved and extended to action policy.

## Regression coverage

`tools/check_mib_action_policy.py` is wired into DPN Quality Gate. It verifies the ACE trust-domain split, centralized policy gate, required sensitive-action mappings, neuralizer policy, denial logging, routing-bucket bounds, and ordering before side effects.
