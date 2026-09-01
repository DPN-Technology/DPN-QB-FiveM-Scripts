# Changelog

All notable repository-level changes to DPN QB FiveM Scripts should be documented here.

This project follows semantic-versioning principles for formal releases where practical. Individual resources may also maintain resource-specific version history in their own documentation and metadata.

## Unreleased

### Added

- DPN Technology repository governance standard under `docs/`.
- Repository-wide contribution guidelines.
- Repository-wide support policy.
- FiveM manifest integrity validation covering legacy manifests, globally duplicate resource names, required manifest declarations, missing referenced files, and private runtime configuration.
- Strengthened DPN repository quality validation including secret-pattern checks, workflow permission restrictions, immutable GitHub Action pinning, resource metadata validation, and DPN resource standards.

### Security

- Public repository CI enforces least-privilege workflow permissions and rejects unapproved write access patterns.
- External GitHub Actions are required to use immutable full commit SHAs by the DPN quality gate.
- Obvious credentials, private-key containers, production configuration, and likely hard-coded secrets are blocked or surfaced by repository validation.

## Release history

GitHub Releases and resource-specific `resource.json`, `fxmanifest.lua`, and README version information remain the authoritative source for previously published resource versions until older release notes are normalized into this changelog.

© DPN Technology.