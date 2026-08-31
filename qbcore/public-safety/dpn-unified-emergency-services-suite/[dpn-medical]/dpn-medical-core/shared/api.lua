DPN_MED = DPN_MED or {}
DPN_MED.Events = {
    RequestState = 'dpn-medical-core:server:requestState',
    SyncState = 'dpn-medical-core:client:syncState',
    ReportDamage = 'dpn-medical-core:server:reportDamage',
    TreatPart = 'dpn-medical-core:server:treatPart',
    EnterIncapacitated = 'dpn-medical-core:server:enterIncapacitated',
    RequestDeath = 'dpn-medical-core:server:requestDeath',
    RequestRespawn = 'dpn-medical-core:server:requestRespawn',
    ReviveClient = 'dpn-medical-core:client:revive',
    RespawnClient = 'dpn-medical-core:client:respawn',
    StateChanged = 'dpn-medical:server:stateChanged',
    LifeStateChanged = 'dpn-medical:server:lifeStateChanged',
    Integration = 'dpn-medical:server:integration'
}

DPN_MED.Events.ClinicalEvent = 'dpn-medical:server:clinicalEvent'
DPN_MED.Events.CriticalAlert = 'dpn-medical:server:criticalAlert'
DPN_MED.Events.CarePlanChanged = 'dpn-medical:server:carePlanChanged'
DPN_MED.Events.EpisodeChanged = 'dpn-medical:server:episodeChanged'
DPN_MED.Events.ModuleHeartbeat = 'dpn-medical-core:server:moduleHeartbeat'
