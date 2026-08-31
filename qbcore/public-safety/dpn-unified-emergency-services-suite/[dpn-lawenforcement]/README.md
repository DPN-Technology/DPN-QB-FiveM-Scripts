# [dpn-lawenforcement] — DPN Law Enforcement Suite

## Integrated Component of the DPN Unified Emergency Services Suite

**Created by Diesel — CEO of DPN Technology**

This bracketed folder is intentionally preserved as **one coordinated law-enforcement package**. The resources inside it are modules of the same DPN public-safety ecosystem and should not be treated as unrelated downloads.

## Included Modules

| Resource | Role |
|---|---|
| `dpn-le-core` | Law-enforcement domain foundation |
| `dpn-digital-dispatch` | Law-enforcement dispatch integration |
| `dpn-emergency-network` | Emergency inter-resource event/network layer |
| `dpn-incident-command` | Multi-agency incident command |
| `dpn-crime-intelligence` | Intelligence and investigative workflows |
| `dpn-evidence-ai` | Evidence/intelligence processing |
| `dpn-officer-safety` | Officer-safety and responder-awareness systems |
| `dpn-drone-command` | Drone/airborne command support |
| `dpn-smart-city` | Smart-city/public-safety integrations |
| `dpn-training-academy` | Training/academy operations |
| `dpn-vehicle-computer` | In-vehicle law-enforcement computing |
| `dpn-le-operations` | High-level law-enforcement operations center |

## Shared Core Dependencies

This law-enforcement package is designed to work with the suite-level:

- `dpn-unified-emergency-network`
- `dpn-dispatch`
- `dpn-mdt`

It also interoperates with the DPN Medical/EMS stack and Fire/Rescue workflows through the shared emergency network, dispatch, MDT, and incident-command layers.

## Installation

Do **not** start these modules in arbitrary alphabetical order.

Use the parent suite's [START_ORDER.cfg](../START_ORDER.cfg), database inventory, and architecture documentation.

## Important

Changing an event name, export, SQL contract, or resource name in one module can affect other modules in this folder and the wider emergency-services suite. Search the entire suite before making breaking changes.

**DPN Technology — DPN-CSL applies to DPN-owned portions.**
