# Officer Safety Duplicate Panic Route

Status: Confirmed audit finding — no runtime behavior changed

## Finding

The current Officer Safety panic path can create more than one Digital Dispatch call for a single physical panic activation.

## Current flow

`dpn-officer-safety` creates an alert through `createAlertFor`. The `/panic`-equivalent server event sets both:

- `dispatch = true`
- `incident = true`

`broadcastAlert` then performs both actions:

1. `createDispatchCall(alert)` calls `exports[Config.Integrations.Dispatch]:CreateDispatchCall(...)`.
2. `createIncident(alert)` triggers `dpn-incident-command:server:autoIncident`.

Incident Command has its own `notifyDispatch` helper that calls:

`exports['dpn-digital-dispatch']:CreateDispatchCall(...)`

Its normal manual incident creation path calls `notifyDispatch` immediately after creating the incident. The automatic-incident path therefore needs explicit correlation review to ensure it cannot create a second dispatch record for the same Officer Safety panic.

## Why Phase 3B correlation is required

The Officer Safety alert currently has its own generated alert ID, but there is no immutable shared root `eventId` linking:

- the Officer Safety alert;
- the first dispatch call;
- the Incident Command incident;
- any subsequent dispatch representation;
- any MDT case or medical response.

Without a root identity, each subsystem can reasonably believe it is creating the first durable record.

## Target behavior

One panic activation should result in:

- one `eventId`;
- one Officer Safety alert ID;
- one canonical `dispatchCallId`;
- at most one Incident Command `incidentId` for that event;
- one MDT case when configured;
- multiple notifications/views are allowed, but no duplicate durable emergency records.

## Migration-safe fix sequence

1. Generate or resolve `eventId` in the trusted Officer Safety server path.
2. Pass that root ID into the canonical dispatch call.
3. Attach the returned `dispatchCallId` to correlation.
4. Pass the same `eventId` and `dispatchCallId` into `autoIncident`.
5. Incident Command creates/returns `incidentId` and attaches it to the same event.
6. Incident Command must not create another canonical dispatch call when `dispatchCallId` is already present.
7. If the Incident Command incident originated independently, it may create a dispatch call using the same root `eventId`.
8. Add an integration self-test asserting exactly one canonical dispatch call exists after a panic+auto-incident flow.

## Compatibility

Do not remove Officer Safety dispatching or automatic Incident Command creation. The migration should preserve both features and change only durable record identity/ownership so they cooperate instead of duplicating the same emergency.
