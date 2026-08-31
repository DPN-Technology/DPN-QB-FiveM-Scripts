# dpn-medical-hospital Exports

## Admit a patient

```lua
local ok, admission = exports['dpn-medical-hospital']:AdmitPatient(
    targetSource,
    'pillbox',
    doctorCitizenId,
    'icu',
    25,
    'Critical trauma monitoring'
)
```

## Discharge a patient

```lua
local ok, admission = exports['dpn-medical-hospital']:DischargePatient(
    patientCitizenId,
    doctorCitizenId,
    false,
    'Cleared by attending physician'
)
```

Set the third argument to `true` only for a trusted forced discharge.

## Transfer a patient

```lua
local ok, admission = exports['dpn-medical-hospital']:TransferPatient(
    patientCitizenId,
    'pillbox',
    'or',
    doctorCitizenId
)
```

## Update a hospital state

```lua
local ok, admission = exports['dpn-medical-hospital']:UpdateAdmissionState(
    patientCitizenId,
    HospitalStates.IN_SURGERY,
    surgeonCitizenId
)
```

State transitions are validated against `HospitalStateTransitions`.

## Read admission or bed data

```lua
local admission = exports['dpn-medical-hospital']:GetAdmissionByCitizenId(citizenId)
local internalBeds = exports['dpn-medical-hospital']:GetBeds(false)
local publicBeds = exports['dpn-medical-hospital']:GetBeds(true)
local bed = exports['dpn-medical-hospital']:GetAvailableBed('pillbox', 'icu', true)
```

## Release a bed from a trusted server resource

```lua
local ok, errorMessage = exports['dpn-medical-hospital']:ReleaseBed('PB-ER-01', 'Transferred to another facility')
```
