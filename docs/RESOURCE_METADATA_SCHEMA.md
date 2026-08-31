# DPN Resource Metadata Standard

Each actual DPN FiveM resource should include a `resource.json` file at the resource root.

This metadata powers automated repository indexing and future DPN tooling.

## Required Fields

```json
{
  "name": "dpn-example-resource",
  "display_name": "DPN Example Resource",
  "version": "1.0.0",
  "framework": "qbcore",
  "category": "law-enforcement",
  "status": "stable",
  "description": "Short description.",
  "creator": "Diesel",
  "creator_title": "CEO of DPN Technology",
  "organization": "DPN Technology",
  "license": "DPN-CSL-1.0"
}
```

## Framework Values

- `qbcore`
- `standalone`
- `hybrid`

## Recommended Status Values

- `experimental`
- `alpha`
- `beta`
- `release-candidate`
- `stable`
- `legacy`
- `archived`

## Automation

The DPN Script Index workflow reads these files and rebuilds `SCRIPT_INDEX.md` when resources are added or changed.

**DPN Technology — Created by Diesel, CEO of DPN Technology**
