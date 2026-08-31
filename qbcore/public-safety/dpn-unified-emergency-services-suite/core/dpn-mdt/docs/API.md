# DPN-MDT API

## Server Events

### `dpn-mdt:server:ReceiveDispatchCall`
Receives a call from dispatch or any emergency script.

```lua
TriggerEvent('dpn-mdt:server:ReceiveDispatchCall', {
    code = '10-50',
    title = 'Motor Vehicle Accident',
    description = 'Two vehicle crash with possible injuries.',
    priority = 'high',
    department = 'shared',
    caller = '911 Caller',
    location = 'Great Ocean Hwy',
    coords = { x = -2500.0, y = 3300.0, z = 32.0 },
    metadata = { vehicles = 2, injuries = true }
})
```

### `dpn-mdt:server:SetUnitStatus`
Sets the current unit status and forwards to the Unified Emergency Network.

```lua
TriggerServerEvent('dpn-mdt:server:SetUnitStatus', 'enroute', 'CALL-0705-1001')
```

## Client Events

### `dpn-mdt:client:OpenMDT`
Opens the MDT for authorized users.

```lua
TriggerEvent('dpn-mdt:client:OpenMDT')
```

### `dpn-mdt:client:DispatchUpdated`
Pushes a dispatch refresh into the UI.

## Server Exports

### `CreateDispatchCall(callData)`
Creates a dispatch record in the MDT.

### `RegisterEvidence(data)`
Creates an evidence record and returns `id, evidenceNo`.

### `RegisterWeapon(citizenid, weaponName, serial, info)`
Adds a weapon to the registry.

### `GetActiveWarrants(citizenid)`
Returns active warrants for a citizen.


## NUI/serverAction callbacks

The NUI calls these through `serverAction` and the server validates job/module access before writing anything:

- `CreateReport`
- `CreateCase`
- `CreateEvidence`
- `CreateCourtCase`
- `CreateMedicalRecord`
- `CreateFireRecord`
- `CreateCorrectionsRecord`
- `MIBAction`

### `CreateCorrectionsRecord`
Creates a corrections/custody record for DOC jobs.

```lua
-- Called from the MDT UI through serverAction
{
    citizenid = 'ABC12345',
    inmate_name = 'John Doe',
    status = 'active',
    housing = 'Block A / Cell 12',
    notes = 'Booked and processed for transport.',
    movement_log = {},
    disciplinary = {},
    medical_flags = {}
}
```
