# DPN FiveM Security Review Standard

This document provides a defensive review standard for DPN Technology FiveM resources.

**Project:** DPN QB FiveM Scripts  
**Created under the direction of Diesel, CEO of DPN Technology**

## Server Authority

Before release, confirm that protected game state is controlled by trusted server-side logic.

Review:

- Player identity checks
- Job and grade checks
- Administrative permission checks
- Item ownership checks
- Money and reward validation
- Location and distance validation where relevant
- Cooldown enforcement where relevant
- Entity existence and ownership checks
- Allowed value ranges
- Database state validation

## Client Input

Treat all client and NUI input as untrusted.

Confirm that sensitive server operations do not rely only on values supplied by:

- Client events
- NUI callbacks
- Local player state
- Hidden menu options
- Client-side job checks

## Database Safety

Confirm:

- Parameterized database operations are used
- User-controlled values are not directly concatenated into queries
- Destructive operations require appropriate authorization
- Schema changes are documented
- Database migrations include backup guidance

## Credential Safety

Before every public release, verify that the repository contains no real:

- Passwords
- API keys
- Discord bot tokens
- Private webhook URLs
- Database credentials
- Server license keys
- SSH/private keys
- Private service credentials

## Permission Review

Confirm:

- Administrative commands validate permission server-side
- QBCore job/grade restrictions are checked server-side when protecting privileged actions
- ACE permissions are documented where applicable
- UI visibility is never treated as the sole permission boundary

## NUI Review

Confirm:

- NUI callbacks validate expected data types
- Privileged actions are revalidated by the server
- NUI focus can be released correctly
- The UI recovers cleanly after a resource restart

## Release Gate

A DPN resource should not be marked Stable while a known high-impact authorization, reward, data-integrity, or privilege issue remains unresolved.

For private vulnerability reporting guidance, see `SECURITY.md`.

---

**DPN Technology**  
**Created by Diesel, CEO of DPN Technology**
