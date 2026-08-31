# DPN Unified Emergency Services — Pre-Install Checklist

Use this before deploying the imported public-safety suite to a production FiveM server.

## 1. Backups

- [ ] Full server resource backup
- [ ] Database backup
- [ ] Current `server.cfg` backup
- [ ] Current job/item/shared-data configuration backup

## 2. Framework

- [ ] Compatible QBCore installation available
- [ ] `oxmysql` installed and starts before DPN resources
- [ ] Required optional libraries from each resource README reviewed
- [ ] Existing third-party resources checked for overlapping functionality

## 3. Conflict Review

Pay special attention to systems that may already own the same state:

- [ ] Death / last stand / revive
- [ ] Injury / health state
- [ ] Hospital respawn
- [ ] Dispatch / CAD
- [ ] MDT / RMS
- [ ] Evidence
- [ ] Vehicle computers
- [ ] Emergency network / responder state
- [ ] Incident command
- [ ] Billing / medical billing
- [ ] Inventory integrations

## 4. Jobs and Permissions

- [ ] Police/sheriff/state/corrections job names mapped
- [ ] EMS/ambulance/medical job names mapped
- [ ] Fire/rescue job names mapped
- [ ] Dispatch job/permission mapping reviewed
- [ ] Admin/MIB permissions reviewed
- [ ] ACE permissions reviewed where applicable

## 5. Database

- [ ] Read `docs/DATABASE_INSTALL.md`
- [ ] Determine fresh install vs upgrade for every SQL component
- [ ] Do not apply install and upgrade SQL blindly together
- [ ] Check table/index naming conflicts
- [ ] Apply core schemas before dependent schemas
- [ ] Keep a rollback backup

## 6. Configuration

- [ ] Coordinates/locations reviewed
- [ ] Department/job names reviewed
- [ ] Item names reviewed
- [ ] Inventory integration reviewed
- [ ] Notification/target/menu integrations reviewed
- [ ] Dispatch/MDT URLs or integration settings reviewed
- [ ] Debug/development modes disabled where appropriate
- [ ] Webhooks/tokens kept outside public source

## 7. Startup

- [ ] Copy all required resources without renaming them
- [ ] Use `START_ORDER.cfg` as the dependency baseline
- [ ] Check server console for missing exports/dependencies
- [ ] Check client F8 console
- [ ] Verify database queries/migrations

## 8. Cross-Agency Test

Test a controlled development incident involving:

- [ ] Dispatch call creation
- [ ] Law-enforcement unit assignment
- [ ] EMS assignment
- [ ] Fire/rescue assignment/configuration
- [ ] Incident command
- [ ] MDT visibility
- [ ] Unit status/GPS where supported
- [ ] Medical transport/hospital workflow
- [ ] Records/audit persistence

## 9. Production Gate

Do not mark the suite production-ready until your specific QBCore build, job setup, dependencies, database and integrations have been tested.

The GitHub repository quality checks validate repository structure and hygiene; they do **not** replace live FiveM runtime testing.
