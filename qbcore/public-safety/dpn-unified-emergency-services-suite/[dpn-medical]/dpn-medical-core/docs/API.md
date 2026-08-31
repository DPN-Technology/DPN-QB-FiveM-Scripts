# DPN Medical Core API

Server exports: `GetPatientState`, `GetPatientStateByCitizenId`, `GetPatientSummary`, `ApplyInjury`, `TreatPatient`, `SetLifeState`, `RevivePatient`, `ResetPatient`, `AddCondition`, `RemoveCondition`, `AddMedication`, `SetDiagnostic`, `SetFlag`, `RegisterModule`, `GetModules`, `IsMedicalJob`, and `EmitIntegration`.

Server events emitted:
- `dpn-medical:server:stateChanged`
- `dpn-medical:server:lifeStateChanged`
- `dpn-medical:server:integration`
