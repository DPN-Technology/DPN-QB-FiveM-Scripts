# DPN Vehicle Computer — Rate Control & Trust-Boundary Hardening

**Resource:** `dpn-vehicle-computer`  
**Target release:** `4.0.1`  
**Classification:** Repository security evidence  
**Status:** Candidate pending CI validation

## Objective

Reduce abuse potential across the vehicle computer's exposed server events without changing the existing DPN law-enforcement authorization model or public integration contracts.

## Controls added

### Per-event rate enforcement

Each exposed server event now passes through a per-player, per-action fixed-window limiter before expensive authorization, database, dispatch, or broadcast work is performed.

Protected actions:

- `open`
- `setStatus`
- `createCall`
- `panic`
- `plateCheck`
- `addHotlist`
- `saveNote`

Limits are centralized in `Config.Security.EventLimits`, with a shared bounded window. Rate-limit audit messages have their own cooldown so an abusive client cannot convert the defense into a log-flooding primitive.

Per-source state is removed on `playerDropped`.

### Dispatch payload ownership

The previous `createCall` path mutated and forwarded the client-provided Lua table. Version 4.0.1 instead builds a new server-owned call object.

The server now owns:

- officer identity
- verified coordinates
- staff-only classification
- departments
- source metadata
- bounded priority

Client-provided values are restricted to bounded call type, title, description, and priority inputs.

### Existing controls preserved

- ACE and DPN LE authorization
- on-duty job authorization
- server-verified vehicle state
- server-verified player position
- parameterized SQL
- authorized-recipient panic fan-out
- bounded text input

## Regression enforcement

`tools/check_vehicle_computer_security.py` fails CI if:

- an exposed event loses rate enforcement,
- rate-policy configuration disappears,
- disconnect cleanup disappears,
- server-owned dispatch reconstruction disappears,
- legacy mutation of the client call table returns,
- the resource loses hardened status or version alignment.

The DPN Quality Gate runs this checker on pull requests and `main`.

## Expected audit effect

The prior hardening audit flagged the resource for exposed handlers without an observable cooldown/rate-limit signal. This change addresses that finding while also tightening the dispatch trust boundary beyond the audit's minimum signal.
