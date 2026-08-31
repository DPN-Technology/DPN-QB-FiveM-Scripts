# DPN Technology Security Policy

**DPN QB FiveM Scripts**  
Created by **Diesel, CEO of DPN Technology**

DPN Technology takes exploit resistance, server authority, credential safety, and responsible disclosure seriously.

## Supported Security Reports

Please report vulnerabilities involving:

- Unauthorized money or item creation
- Privilege escalation
- Admin permission bypass
- Job/grade bypass
- Arbitrary server event abuse
- Insecure callbacks
- SQL injection
- Unsafe dynamic queries
- Authentication or authorization bypass
- Entity ownership abuse
- Server-side trust of unvalidated client values
- Remote code execution
- Credential exposure
- Sensitive webhook/token exposure
- NUI privilege bypass
- Unsafe file operations
- Resource-to-resource trust issues

## Do Not Publish Live Exploit Details First

If a vulnerability could materially compromise active FiveM servers, avoid publishing a weaponized proof of concept before maintainers have had a reasonable opportunity to assess and fix it.

Open a GitHub issue only when public disclosure is safe. For sensitive reports, contact DPN Technology through an official private channel associated with the project.

Do not include real:

- Database passwords
- API keys
- Discord bot tokens
- Private webhooks
- Server license keys
- SSH credentials
- Player private information

## DPN Security Standard

Sensitive actions should follow a server-authoritative design.

The server should validate, where relevant:

- Player source
- Character identity
- Job
- Grade
- Permission
- Location
- Distance
- Item ownership
- Money amount
- Reward amount
- Cooldown
- State
- Entity existence
- Entity ownership
- Database state
- Allowed value ranges

## Client Trust Rule

The client may request an action.

The server decides whether the action is valid.

A client should not have unilateral authority to:

- Create currency
- Create protected items
- Change permissions
- Set privileged jobs
- Mark protected objectives complete
- Grant rewards
- Modify another player's protected state

## Security Review Status

A script being publicly released does not mean it has been formally penetration tested.

Server owners must test resources in a non-production environment and review integrations before deployment.

## Responsible Disclosure Credit

DPN Technology may credit researchers who responsibly disclose valid security issues unless the reporter asks to remain anonymous or disclosure would create additional risk.
