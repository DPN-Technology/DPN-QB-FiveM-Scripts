# Changelog

## 1.1.0

### Fixed

- Corrected the Lua parser error caused by using the reserved keyword `or` as a bare table key.
- Fixed recovery controls being applied only once per second instead of every game frame.
- Fixed duplicate active admissions creating ghost occupied beds after restart.
- Fixed unrestricted client-triggered bed release.
- Fixed resource restart behavior for active admissions and occupied beds.
- Fixed payment race conditions and added automatic refunds on failed bill updates.
- Fixed optional command arguments being treated as mandatory.
- Fixed NUI text rendering so admission reasons cannot inject HTML.

### Added

- Ward and hospital-state validation helpers.
- Valid hospital state-transition rules.
- Persistent admission restoration.
- Secure staff and admin authorization checks.
- Server-side distance validation for admission and self check-in.
- Admission event cooldowns and duplicate-processing locks.
- Severity-based billing.
- Configurable triage routing.
- Secure patient transfers and bed handoff.
- Public bed data filtering.
- qb-target fallback marker.
- Responsive patient portal with progress, billing, and bed census.
- New staff commands and server exports.
- Database failure safeguards for recovery, discharge, transfer, and billing.
