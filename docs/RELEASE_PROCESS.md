# DPN Technology Release Process

This document defines the preferred path from development to an official DPN FiveM release.

## 1. Development

Develop the resource using the DPN FiveM Development Standard.

The resource should have:

- Clear DPN identity
- Resource README
- Configuration documentation
- Dependency documentation
- Appropriate source headers
- License reference
- Version number

## 2. Internal Review

Review:

- Functional behavior
- Server authority
- Permissions
- Database changes
- Resource restart behavior
- Player reconnect behavior
- Performance
- Documentation

## 3. Release Classification

Choose one:

- Experimental
- Alpha
- Beta
- Release Candidate
- Stable
- Legacy

Do not label a resource Stable merely because it starts successfully.

## 4. Versioning

Preferred version format:

```text
MAJOR.MINOR.PATCH
```

Examples:

- 1.0.0 — initial stable release
- 1.1.0 — backward-compatible feature release
- 1.1.1 — bug-fix release
- 2.0.0 — breaking release

## 5. Changelog

Document:

- Added
- Changed
- Fixed
- Security
- Performance
- Breaking changes
- Migration requirements

## 6. Release Notes

Use `.github/RELEASE_TEMPLATE.md` as the baseline.

## 7. Production Readiness

Before Stable release:

- Clean installation tested
- Upgrade path tested when applicable
- Dependencies documented
- SQL documented
- Permissions documented
- Console errors reviewed
- Restart behavior tested
- Security review completed
- Performance reviewed
- License and DPN attribution verified

## 8. Publishing

Official releases should come from the DPN Technology repository or an explicitly authorized DPN Technology distribution channel.

## 9. Post-Release

After release:

- Monitor bug reports
- Review compatibility reports
- Address security issues
- Update documentation
- Record important changes in CHANGELOG.md
- Deprecate older versions clearly when necessary

---

**DPN Technology — Develop Pioneer Navigate**  
Created under the direction of **Diesel, CEO of DPN Technology**.
