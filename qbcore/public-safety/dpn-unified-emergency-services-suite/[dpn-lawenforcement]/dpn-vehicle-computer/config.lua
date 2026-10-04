Config = {}

Config.Framework = 'qbcore' -- QBCore-only release
Config.Locale = 'en'
Config.Debug = false

Config.OpenKey = 'F5'
Config.AllowPassengerUse = true
Config.RequireVehicle = true
Config.RequireEmergencyVehicle = false
Config.AllowedJobs = {
    police = true,
    sheriff = true,
    state = true,
    trooper = true,
    ranger = true,
    corrections = true,
    ambulance = true,
    ems = true,
    fire = true
}

Config.Command = 'vcomputer'
Config.PanicCommand = 'vpanic'
Config.StatusCommand = 'vstatus'
Config.PlateCommand = 'vplate'

-- Per-player server event throttles. Values are milliseconds.
Config.RateLimits = {
    OpenMs = 500,
    StatusMs = 300,
    CreateCallMs = 1500,
    PanicMs = 3000,
    PlateCheckMs = 500,
    HotlistMs = 750,
    SaveNoteMs = 750
}

Config.Statuses = {
    ['10-8'] = 'Available',
    ['10-6'] = 'Busy',
    ['10-7'] = 'Out of Service',
    ['10-11'] = 'Traffic Stop',
    ['10-15'] = 'Transporting',
    ['10-97'] = 'On Scene'
}

Config.Radar = {
    Enabled = true,
    RefreshMs = 500,
    MaxDistance = 95.0,
    UseMph = true
}

Config.ALPR = {
    Enabled = true,
    ScanIntervalMs = 1200,
    MaxDistance = 42.0,
    HotlistAlert = true
}

Config.Modules = {
    Dispatch = true,
    ALPR = true,
    Radar = true,
    StarChase = true,
    BodyCam = true,
    Doorbell = true,
    OfficerSafety = true,
    Operations = true,
    PursuitCommand = true,
    Warrants = true
}

Config.OperationsCommand = 'leops'
Config.PursuitCommand = 'leops'

Config.IntegrationEvents = {
    DispatchCreateCall = 'dpn_dispatch:server:createCall',
    DispatchGetCalls = 'dpn-dispatch:server:getCalls',
    CoreSetStatus = 'dpn-le-core:server:setStatus',
    StarChaseOpen = 'dpn-starchase:client:openRemote',
    BodyCamToggle = 'dpn-bodycam:client:toggleRecording',
    DoorbellCall = 'dpn-police-doorbell:server:ring'
}

Config.Webhooks = {
    Enabled = false,
    VehicleComputer = ''
}
