# DPN Repository Automation

**DPN Technology**  
**Created by Diesel, CEO of DPN Technology**

This repository contains automation designed to keep DPN FiveM releases organized, reproducible, and easier to maintain.

## DPN Quality Gate

**Workflow:** `.github/workflows/dpn-quality-gate.yml`

Runs on pull requests and pushes to `main`.

Checks the DPN resource structure and metadata standard.

## DPN Automatic Script Index

**Workflow:** `.github/workflows/dpn-auto-script-index.yml`

Automatically rebuilds `SCRIPT_INDEX.md` from production resource `resource.json` files.

## DPN Pull Request Resource Summary

**Workflow:** `.github/workflows/dpn-pr-resource-summary.yml`

Creates an Actions summary showing which DPN framework/category areas a pull request changes.

## DPN Build & Release Resource

**Workflow:** `.github/workflows/dpn-build-release.yml`

Manually packages one validated resource.

Input example:

```text
qbcore/law-enforcement/dpn-example-resource
```

The workflow:

1. Checks out the official repository.
2. Runs the DPN Quality Gate.
3. Validates the requested resource path.
4. Reads `resource.json`.
5. Creates a versioned ZIP.
6. Uploads the ZIP as a workflow artifact.
7. Optionally creates a GitHub Release.

Release tags use:

```text
dpn-resource-name-v1.0.0
```

## DPN Weekly Repository Check

**Workflow:** `.github/workflows/dpn-weekly-repo-check.yml`

Runs each Monday and verifies:

- DPN Python tooling compiles.
- Repository validation passes.
- The generated Script Index is current.

This GitHub-side check complements the separate DPN repository health audit notification.

## Dependabot

**Configuration:** `.github/dependabot.yml`

Checks GitHub Actions dependencies weekly and can open update pull requests.

## Resource Packaging

**Tool:** `tools/package_resource.py`

The packager refuses unsafe paths and only packages resources inside:

- `qbcore/`
- `standalone/`
- `hybrid/`

A package must have:

- `fxmanifest.lua`
- `README.md`
- `resource.json`

The metadata name, folder name, and framework path must agree before a ZIP is created.

## Branch Protection

GitHub branch protection should be configured in repository settings so important merges require the DPN Quality Gate.

The connected GitHub controls available to ChatGPT currently do not expose a branch-protection write operation, so that account-level setting is not changed automatically by these repository files.

---

**DPN Technology — Develop Pioneer Navigate**

*We Develop what doesn't exist. We Pioneer what comes next. We Navigate the future.*
