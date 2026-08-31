# Contributing to DPN QB FiveM Scripts

Thank you for helping improve a **DPN Technology** community project.

**Project:** DPN QB FiveM Scripts  
**Original Creator:** Diesel, CEO of DPN Technology  
**Publisher:** DPN Technology

All contributions should strengthen the project's goals: free, editable, well-documented FiveM resources with responsible engineering and no unauthorized commercial resale.

## Before You Contribute

By submitting code or documentation, you represent that you have the right to submit it. Do not submit leaked, stolen, purchased, escrow-protected, or otherwise non-redistributable code.

Read:

- \`README.md\`
- \`LICENSE\`
- \`SECURITY.md\`
- \`DPN_DEVELOPMENT_STANDARD.md\`

## Contribution Priorities

DPN Technology especially welcomes:

- Bug fixes
- QBCore compatibility fixes
- Standalone compatibility
- Security hardening
- Server-side validation
- Performance optimization
- Reduced idle resource usage
- New configuration options
- Improved documentation
- Accessibility improvements
- Database reliability
- Framework bridges
- Inventory and target integrations
- Localization
- Testing improvements

## Branch Naming

Use focused branch names:

\`\`\`text
fix/resource-name-issue
feature/new-integration
security/event-validation
perf/reduce-loop-time
docs/install-guide
refactor/framework-bridge
\`\`\`

## Commit Style

Preferred examples:

\`\`\`text
fix: validate server reward event
feat: add standalone permission bridge
perf: reduce idle client polling
docs: expand installation guide
security: reject invalid entity ownership
\`\`\`

## Pull Request Requirements

A pull request should explain:

1. What problem it solves.
2. Which resource is affected.
3. QBCore, standalone, or hybrid impact.
4. Dependencies added or removed.
5. Configuration changes.
6. SQL/database changes.
7. Security impact.
8. Performance impact.
9. How it was tested.
10. Whether documentation was updated.

## Code Requirements

Do not knowingly submit code that:

- Trusts the client for protected rewards.
- Gives items or money without appropriate server validation.
- Contains plaintext secrets.
- Contains hidden backdoors.
- Spams network events.
- Creates unnecessary 0ms loops.
- Breaks normal resource restart behavior.
- Silently changes database schemas without documentation.
- Depends on undocumented paid resources.

## DPN Naming

New DPN-created resources should normally use a clear \`dpn-\` resource prefix unless there is a reason not to.

Recommended event format:

\`\`\`text
dpn-resource:client:eventName
dpn-resource:server:eventName
\`\`\`

## Testing

Test both expected and invalid flows.

For sensitive server events, test:

- Missing player
- Wrong job
- Wrong grade
- Missing item
- Invalid amount
- Excessive amount
- Invalid entity
- Out-of-range coordinates
- Repeated trigger attempts
- Resource restart
- Player reconnect

## Licensing

Contributing does not give contributors a right to commercially resell DPN Technology-owned code.

DPN-derived code remains subject to the repository license.

## Review Authority

DPN Technology maintains final editorial and technical authority over the official repository. Acceptance of a contribution does not guarantee permanent inclusion.

Final project direction is maintained by **Diesel, CEO of DPN Technology**, and authorized DPN Technology maintainers.
