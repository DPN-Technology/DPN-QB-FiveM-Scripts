# DPN Emergency Network

> [!IMPORTANT]
> **Official DPN Technology Release** — Created by **Diesel, CEO of DPN Technology**. This resource is part of the DPN FiveM community release library and is governed by the repository DPN Technology Community Source License (DPN-CSL). Use and modification are permitted under the license; commercial resale requires explicit DPN Technology authorization.


Canonical interoperability and health-monitoring layer for the DPN emergency ecosystem. External resources should publish through the server export:

```lua
exports['dpn-emergency-network']:PublishEvent('medical', 'patient_critical', {
    title = 'Critical Patient',
    message = 'Trauma patient requires police-secured transport.',
    coords = { x = 0.0, y = 0.0, z = 0.0 },
    patientCid = 'ABC123'
}, source)
```

The resource correlates the event with dispatch, incident command, evidence, intelligence, and the v4 Law Enforcement Command Center according to `Config.Routes`.
