# DPN FiveM Release Process

This repository releases **individual FiveM resources**, not a single monolithic repository version.

## Release authority

A GitHub Release is considered an official DPN resource release only when it is produced from the repository's **DPN Build & Release Resource** workflow with `publish_release=true`.

Published releases must originate from `main`.

## Release identity

The release identity is derived from the selected resource's `resource.json`:

```text
<tag>   <resource-name>-v<version>
<title> <display-name> v<version>
```

Example:

```text
dpn-starchase-v1.1.1
```

The workflow refuses to publish when the version in `resource.json` does not match the quoted `version` declaration in `fxmanifest.lua`.

## Pipeline

```text
main
  |
  v
Repository quality validation
  |
  v
Resource metadata + manifest version verification
  |
  v
Safe resource packaging
  |
  v
ZIP integrity test
  |
  v
SHA-256 generation + verification
  |
  v
Release evidence JSON
  |
  +--> GitHub Actions artifact
  |
  +--> optional GitHub Release
```

## Release assets

Each packaged run produces:

- `<resource>-v<version>.zip`
- `<resource>-v<version>.zip.sha256`
- `<resource>-v<version>.release-evidence.json`

The evidence file records the repository, source SHA/ref, workflow run, resource identity, declared versions, framework/category/status, artifact filename, size, and SHA-256.

## Pre-release checklist

Before publishing:

1. Confirm the target resource is intended for public distribution.
2. Confirm `resource.json` accurately describes the current resource.
3. Confirm `resource.json.version` and `fxmanifest.lua` version match.
4. Confirm the repository quality/security workflows are green on `main`.
5. Review resource-specific setup, SQL, configuration, and compatibility documentation.
6. Run the release workflow once with `publish_release=false` when practical and inspect its artifact/evidence.
7. Publish from `main` with `publish_release=true`.

## Verification

A downloaded resource can be verified with:

```bash
sha256sum -c <resource>-v<version>.zip.sha256
```

The checksum proves artifact integrity against the published checksum. The attached release-evidence JSON links the artifact to the source commit and workflow context used to package it.

## Rollback

GitHub Releases are distribution records, not a substitute for source control.

If a release is defective:

- do not silently replace an existing version;
- fix the source;
- increment the resource version;
- rerun validation;
- publish a new release;
- document the change in release notes or resource documentation.

## Security boundary

The packager rejects unsafe resource paths, path traversal, symbolic links, private-key/config file types, generated build/cache directories, and other excluded payloads. Repository-wide security validation runs before packaging.

Do not put credentials, server secrets, private configuration, customer data, or production logs inside a public FiveM resource.
