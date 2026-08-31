# DPN Technology FiveM Installation Standard

This document defines the preferred installation documentation format for all DPN FiveM resources.

## Every Resource Must Identify

- Resource name
- Version
- Framework
- Dependencies
- Required start order
- SQL requirements
- Config files
- Items/jobs that must be added
- Permissions
- Upgrade steps

## Standard Install Flow

1. Back up the server.
2. Back up the database when SQL changes are involved.
3. Install dependencies.
4. Copy the DPN resource into the correct resources directory.
5. Import SQL if required.
6. Configure the resource.
7. Add the resource to `server.cfg`.
8. Confirm dependency start order.
9. Start a test server.
10. Review server console.
11. Review F8/client console.
12. Test permissions and privileged actions.
13. Test resource restart.
14. Test player reconnect.
15. Move to production only after validation.

## Example

```cfg
ensure qb-core
ensure oxmysql
ensure dpn-example-resource
```

The example is not universal. Resource-specific documentation controls.

## Upgrade Standard

Every breaking update should document:

- Changed configuration keys
- Database migrations
- Removed exports/events
- Renamed commands
- Dependency changes
- Required manual steps

---

**DPN Technology**  
Created by Diesel, CEO of DPN Technology
