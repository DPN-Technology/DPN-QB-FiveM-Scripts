# DPN Technology Repository Standard

This repository follows the DPN Technology engineering governance baseline.

## Required controls

- `main` is the production/default branch and should be protected with pull-request review and required successful CI/security checks.
- CI must fail on syntax, test, security, repository-health, or release-integrity failures.
- GitHub Actions must use least-privilege `GITHUB_TOKEN` permissions and third-party actions should be pinned to immutable commit SHAs.
- Secrets, private keys, production `.env` files, credentials, tokens, and private runtime configuration must never be committed.
- Dependency automation and security review must remain enabled where supported.
- Releases should use semantic versions, release notes, reproducible build artifacts, SHA-256 checksums, and an SBOM where practical.
- Root-directory documentation should remain limited to canonical project documents; historical/version-specific engineering notes belong under `docs/`.
- Changes should be made through pull requests when collaboration or production risk warrants review.

## Canonical documentation

Projects should maintain `README.md`, `CHANGELOG.md`, `SECURITY.md`, `CONTRIBUTING.md`, release documentation, and ownership/governance information appropriate to the repository.

## Repository health

Automated health checks should cover CI status, dependency state, secrets, workflow permissions, release readiness, stale documentation, and application-specific validation.

© DPN Technology. Public repositories remain subject to their existing license, commercial-permission, and contribution terms.
