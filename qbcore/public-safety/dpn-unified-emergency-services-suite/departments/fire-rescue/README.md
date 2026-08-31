# Fire & Rescue Integration

## DPN Unified Emergency Services Suite

**Created by Diesel — CEO of DPN Technology**

Fire/Rescue is a first-class operational domain in the DPN public-safety platform even though the uploaded collection does not contain a separate bracketed `[dpn-fire]` runtime pack.

Fire and rescue workflows are currently delivered through the suite's shared cross-agency systems:

- `dpn-dispatch` — fire/rescue call intake, CAD and unit coordination
- `dpn-mdt` — cross-department terminal/records access
- `dpn-unified-emergency-network` — shared responder/network coordination
- `dpn-emergency-network` — event routing and emergency-service health/correlation
- `dpn-incident-command` — multi-agency incident command
- `dpn-medical-dispatch` — medical/rescue dispatch integration where applicable
- `dpn-medical-ems` — patient care/EMS side of rescue incidents

## Fire Department Expansion Standard

Future dedicated DPN fire resources should be added as a coordinated bracketed pack such as:

```text
[dpn-fire]/
├── dpn-fire-core/
├── dpn-fire-dispatch/
├── dpn-fire-apparatus/
├── dpn-fire-operations/
└── ...
```

They should integrate through the existing shared dispatch, MDT, network and incident-command APIs rather than creating a second isolated emergency-services stack.

## Deployment

Fire jobs/unit types must be configured consistently across the relevant dispatch, MDT, incident-command, emergency-network and medical integrations.

Do not assume default job names match your server.

**This document is an integration map, not an additional runtime resource.**
