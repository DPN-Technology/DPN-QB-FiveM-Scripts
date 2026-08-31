# DPN FiveM Development Standard

**DPN Technology Engineering Standard for Community FiveM Resources**  
Created under the direction of **Diesel, CEO of DPN Technology**

This document defines the preferred engineering baseline for resources released through DPN QB FiveM Scripts.

## 1. Resource Identity

Preferred resource naming:

\`\`\`text
dpn-resource-name
\`\`\`

Preferred event namespace:

\`\`\`text
dpn-resource:client:eventName
dpn-resource:server:eventName
\`\`\`

Each resource should identify:

- Name
- Purpose
- Creator
- DPN Technology
- Version
- Framework
- Dependencies
- Installation steps
- Configuration
- Known limitations
- License

## 2. fxmanifest.lua

Use a modern \`fxmanifest.lua\`.

Document required dependencies explicitly when practical.

Do not declare dependencies that are not actually used.

## 3. Framework Isolation

When supporting multiple frameworks, prefer a bridge layer rather than scattering framework checks throughout the entire codebase.

Suggested structure:

\`\`\`text
shared/
client/
server/
bridge/
  qb.lua
  standalone.lua
config.lua
fxmanifest.lua
\`\`\`

## 4. Configuration

Server owners should not have to edit core logic for normal configuration.

Expose safe settings for:

- Framework
- Debug mode
- Commands
- Permissions
- Jobs
- Locations
- Distances
- Cooldowns
- Features
- Integrations
- Notifications
- Logging

## 5. Server Authority

Protected state belongs on the server.

Never rely only on client input for protected actions.

Validate all relevant parameters before:

- Giving money
- Removing money
- Giving items
- Removing items
- Completing paid objectives
- Changing jobs
- Changing permissions
- Granting access
- Writing protected database state

## 6. Network Events

Every sensitive network event should answer:

- Who can call this?
- What can they submit?
- What ranges are valid?
- Does location matter?
- Is a cooldown needed?
- Can it be replayed?
- Does the server independently verify state?

## 7. Performance

Avoid permanent high-frequency polling when events, zones, state bags, or longer sleep intervals can solve the same problem.

Prefer adaptive waits.

Clean up:

- Entities
- Blips
- Zones
- Threads where practical
- NUI focus
- Temporary state

## 8. Database

Use parameterized queries.

Do not concatenate untrusted client data into SQL.

Document schema changes.

For substantial migrations, provide:

- Migration file
- Backup warning
- Upgrade instructions
- Rollback notes when practical

## 9. Logging

Logs should be useful, not noisy.

Debug logging should normally be configurable.

Never log:

- Passwords
- Tokens
- Private keys
- Full secrets
- Sensitive personal information unless strictly required and lawfully handled

## 10. Error Handling

Failures should be understandable.

Prefer clear errors such as:

\`\`\`text
[DPN Resource] Missing dependency: ox_lib
\`\`\`

instead of silent failure.

## 11. Resource Restart Safety

Where practical, resources should tolerate:

- Manual restart
- Player reconnect
- Framework reload
- Entity cleanup
- Database reconnect

## 12. UI/NUI

NUI must not be treated as trusted authority.

Validate privileged actions server-side.

Ensure focus can be released and the UI can recover after resource restart.

## 13. Compatibility

Document exact integrations when they matter.

Avoid claiming support for systems that have not been tested.

## 14. Documentation

Each substantive script should explain:

- Installation
- Dependencies
- Configuration
- Commands
- Permissions
- Exports
- Events intended for public integration
- SQL
- Troubleshooting
- Upgrade notes

## 15. Release Checklist

Before a stable DPN release:

- [ ] Starts without errors
- [ ] Stops/restarts cleanly
- [ ] No committed secrets
- [ ] Sensitive events validated server-side
- [ ] Dependencies documented
- [ ] SQL documented
- [ ] Config documented
- [ ] Performance reviewed
- [ ] Debug logging disabled by default where appropriate
- [ ] README present
- [ ] License/attribution present
- [ ] Basic exploit paths considered
- [ ] Upgrade notes included when breaking changes exist

## 16. Ownership Header

New DPN-authored source files may use:

\`\`\`lua
--[[
    DPN Technology
    DPN QB FiveM Scripts

    Created by Diesel, CEO of DPN Technology
    Licensed under the DPN Technology Community Source License (DPN-CSL).
    Free to use and modify under the license.
    Commercial resale requires explicit DPN Technology authorization.
]]
\`\`\`

## 17. DPN Standard

The target is not merely "works on my server."

The target is code that is understandable, configurable, secure by design, efficient enough for real servers, and documented well enough that another developer can maintain it.
