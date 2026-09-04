# Phase 3F — Responder Runtime Lifecycle Guard

This slice wires the live `dpn-medical-dispatch:server:respond` handler through the Phase 3F responder lifecycle authority.

## Runtime contract

- `server/main.lua` remains the sole responder-state owner.
- The live responder event validates every requested transition through `DPNMedicalResponderAuthority.ValidateTransition` before mutating responder or call state.
- Invalid or unknown transitions fail closed and notify the responder instead of silently coercing the request to `accepted`.
- Idempotent transitions remain accepted through the responder authority policy.
- Successful transitions continue to update existing call state, persistence, external bridge updates, responder notifications, and compatibility events.
- The previous permissive fallback that converted unknown states into `accepted` is removed.

## Compatibility

No event, export, command, database table, historical `vN.lua` layer, or external compatibility surface is removed in this slice.

## Verification

`tools/check_medical_responder_runtime_guard.py` enforces that the live handler calls the lifecycle authority, fails closed, and does not retain the legacy permissive fallback. The check is included in DPN Quality Gate.
