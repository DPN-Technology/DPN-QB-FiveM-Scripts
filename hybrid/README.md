# DPN Hybrid FiveM Resources

Hybrid resources are designed to support more than one runtime mode, such as **QBCore** and **Standalone**.

Published by **DPN Technology** and created under the direction of **Diesel, CEO of DPN Technology**.

Preferred hybrid architecture isolates framework-specific logic behind a bridge layer instead of scattering framework checks throughout the codebase.

Example:

```text
dpn-resource/
├── bridge/
│   ├── qb.lua
│   └── standalone.lua
├── client/
├── server/
├── shared/
├── config.lua
└── fxmanifest.lua
```

Each hybrid resource must document exactly which modes are tested and supported.
