# DPN Technology Release Checklist

Use this checklist before publishing or tagging a DPN FiveM resource release.

## Identity

- [ ] Resource uses a clear DPN name
- [ ] README identifies DPN Technology
- [ ] README identifies Diesel as CEO of DPN Technology and original creator where applicable
- [ ] DPN-CSL licensing notice is included
- [ ] Third-party attribution is preserved

## Code

- [ ] Dead code removed
- [ ] Debug spam disabled
- [ ] No temporary test commands
- [ ] No hard-coded development paths
- [ ] No credentials
- [ ] No secrets
- [ ] No private webhooks
- [ ] No server keys
- [ ] No hidden dependencies

## FiveM

- [ ] fxmanifest.lua validated
- [ ] Resource starts
- [ ] Resource stops
- [ ] Resource restarts cleanly
- [ ] Player reconnect tested
- [ ] Server restart tested
- [ ] OneSync behavior considered where relevant

## QBCore

- [ ] Current intended QBCore version tested
- [ ] Player loading tested
- [ ] Player unloading tested
- [ ] Job changes tested
- [ ] Duty changes tested where relevant
- [ ] Shared items documented
- [ ] Required jobs documented

## Standalone

- [ ] Framework-disabled path tested
- [ ] ACE permissions tested where used
- [ ] No accidental QBCore dependency remains

## Security

- [ ] Sensitive client inputs validated server-side
- [ ] Reward amounts validated
- [ ] Item operations validated
- [ ] Money operations validated
- [ ] Job/permission operations validated
- [ ] Distance/location checks added where appropriate
- [ ] Cooldowns/rate limits considered
- [ ] Entity ownership checked where relevant
- [ ] SQL uses safe parameters
- [ ] NUI does not directly authorize privileged actions

## Performance

- [ ] Resource monitor checked
- [ ] Idle loops reviewed
- [ ] Unnecessary 0ms loops removed
- [ ] Repeated database queries reviewed
- [ ] Network-event frequency reviewed
- [ ] Entity cleanup tested

## Data

- [ ] Database backup warning documented
- [ ] SQL migration included if needed
- [ ] Migration tested
- [ ] Upgrade path documented
- [ ] Destructive schema changes clearly identified

## UX

- [ ] Menus close correctly
- [ ] NUI focus releases correctly
- [ ] Errors are understandable
- [ ] Config names are clear
- [ ] Defaults are safe

## Documentation

- [ ] Installation complete
- [ ] Dependencies complete
- [ ] Configuration complete
- [ ] Permissions complete
- [ ] Commands documented
- [ ] Public exports documented
- [ ] Public integration events documented
- [ ] Troubleshooting included
- [ ] Changelog updated
- [ ] Version updated

## Release

- [ ] Clean test server passed
- [ ] Modified development config removed
- [ ] Final diff reviewed
- [ ] Release notes prepared
- [ ] Breaking changes highlighted
- [ ] DPN ownership and license verified
