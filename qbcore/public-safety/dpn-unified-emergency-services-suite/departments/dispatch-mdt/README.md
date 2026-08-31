# Dispatch / MDT / Emergency Network Core

## Shared Cross-Agency Backbone

**Created by Diesel — CEO of DPN Technology**

The `core/` directory contains the cross-service backbone used to connect Law Enforcement, EMS/Medical, Fire/Rescue, incident command, and administrative/public-safety workflows.

## Core Resources

### dpn-unified-emergency-network

Cross-agency operational coordination and shared emergency-network foundation.

### dpn-dispatch

Unified CAD/RMS dispatch surface supporting law enforcement, EMS, fire/rescue and other configured services.

### dpn-mdt

Cross-department MDT/RMS interface tying records, dispatch, evidence, warrants/BOLOs, medical/public-safety data and audit workflows together.

## Design Rule

These resources are intentionally stored at the suite core rather than inside the Law or Medical brackets because they are shared by multiple departments.

## Recommended Baseline

Start the parent suite using `START_ORDER.cfg`. Do not install a duplicate copy of these core resources inside another bracketed pack.

**This shared core is what makes the DPN public-safety stack one integrated platform rather than several isolated script packs.**
