# DPN FiveM Resource Library — Release Profile

## Baseline

**Repository release line:** `1.0.4`

This repository is the official DPN Technology FiveM resource library for QBCore, hybrid, and standalone resources.

## Release gate

A repository baseline is release-ready only when the default branch has a passing:

- DPN Quality Gate
- DPN Security Baseline
- DPN Security & Supply Chain check
- Automatic Script Index validation
- FiveM manifest integrity validation
- FiveM Lua syntax validation

The resource catalog is generated from repository metadata and must remain synchronized with `SCRIPT_INDEX.md`.

## Quality-control rules

Every distributable resource is expected to contain:

- `fxmanifest.lua`
- `README.md`
- `resource.json`
- DPN Technology ownership and identity metadata
- a declared version
- documented dependencies and installation requirements

Security-sensitive material, tracked environment secrets, private keys, floating GitHub Action references, and unsafe release contents are blocked by repository validation.

## Compatibility model

Resources are organized under:

- `qbcore/` — QBCore-native resources
- `hybrid/` — framework-bridging resources
- `standalone/` — framework-independent resources

The Unified Emergency Services Suite is treated as an integrated system. Its components should be evaluated with their documented dependency and startup order rather than as unrelated resources.

## Release identity

Repository releases represent tested library baselines. Individual resources retain their own semantic versions in `resource.json` and `fxmanifest.lua`.

**DPN Technology — Develop • Pioneer • Navigate**
