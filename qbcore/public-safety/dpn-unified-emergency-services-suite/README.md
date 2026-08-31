# DPN Unified Emergency Services Suite

## Official DPN Technology Integrated Public-Safety Platform

**Created by Diesel — CEO of DPN Technology**

This folder intentionally keeps the uploaded bracketed resource packs together. They are **not independent random scripts**: the law-enforcement and medical stacks, MDT, dispatch, unified emergency network, incident command, and cross-agency integrations are designed to operate as one coordinated DPN public-safety ecosystem.

## Suite Layout

```text
dpn-unified-emergency-services-suite/
├── core/
│   ├── dpn-unified-emergency-network/
│   ├── dpn-dispatch/
│   └── dpn-mdt/
├── [dpn-lawenforcement]/
│   ├── dpn-le-core/
│   ├── dpn-digital-dispatch/
│   ├── dpn-emergency-network/
│   ├── dpn-incident-command/
│   ├── dpn-crime-intelligence/
│   ├── dpn-evidence-ai/
│   ├── dpn-officer-safety/
│   ├── dpn-drone-command/
│   ├── dpn-smart-city/
│   ├── dpn-training-academy/
│   ├── dpn-vehicle-computer/
│   └── dpn-le-operations/
└── [dpn-medical]/
    ├── dpn-medical-core/
    ├── dpn-medical-ems/
    ├── dpn-medical-dispatch/
    ├── dpn-medical-hospital/
    ├── dpn-medical-records/
    ├── dpn-medical-lifepak/
    ├── dpn-medical-ambulance/
    ├── dpn-medical-radiology/
    ├── dpn-medical-surgery/
    ├── dpn-medical-icu/
    ├── dpn-medical-pharmacy/
    ├── dpn-medical-disease/
    ├── dpn-medical-rehab/
    ├── dpn-medical-coroner/
    ├── dpn-medical-insurance/
    ├── dpn-medical-inventory/
    ├── dpn-medical-billing-plus/
    ├── dpn-medical-training/
    ├── dpn-medical-ai/
    └── dpn-medical-admin-tools/
```

## Cross-System Design

The suite provides a shared operational model for:

- Law enforcement
- EMS / medical
- Fire and rescue routing
- Unified 911/CAD dispatch
- MDT/RMS access
- Incident command
- Multi-agency mutual aid
- BOLO and intelligence workflows
- Evidence and case workflows
- Medical records, triage, transport, hospital and clinical operations
- Unit status, GPS and responder safety
- Emergency network event routing
- Administrative/audit workflows

Do not move individual bracketed modules to unrelated folders unless you also update every dependency, export, event, SQL migration, and documented start-order dependency that references them.

## Start Order

Use [START_ORDER.cfg](START_ORDER.cfg) as the baseline and then adapt optional integrations to your server.

## Database

Review [DATABASE_INSTALL.md](docs/DATABASE_INSTALL.md) before importing SQL into production. Back up your database first.

## Department Entry Points

- **[Law Enforcement Suite]([dpn-lawenforcement]/README.md)** — coordinated 12-resource law-enforcement stack.
- **[Medical / EMS Suite]([dpn-medical]/README.md)** — coordinated 20-resource medical stack.
- **[Fire & Rescue Integration](departments/fire-rescue/README.md)** — current fire/rescue role across the shared platform.
- **[Dispatch / MDT Core](departments/dispatch-mdt/README.md)** — cross-agency dispatch, MDT and emergency-network backbone.

## Deployment & Architecture

Before production deployment, read these in order:

1. **[Pre-Install Checklist](docs/PRE_INSTALL_CHECKLIST.md)**
2. **[FiveM Deployment Topology](docs/DEPLOYMENT.md)**
3. **[Database Installation Inventory](docs/DATABASE_INSTALL.md)**
4. **[Architecture](docs/ARCHITECTURE.md)**
5. **[Resource Matrix](docs/RESOURCE_MATRIX.md)**
6. **[START_ORDER.cfg](START_ORDER.cfg)**

The repository folder is a source-management container for many actual FiveM resources. It is not itself a single `fxmanifest.lua` resource; follow the deployment topology when copying the suite to a server.

## License

DPN-owned portions are governed by the repository DPN Technology Community Source License (DPN-CSL). Third-party material, if any, remains subject to its own license.
