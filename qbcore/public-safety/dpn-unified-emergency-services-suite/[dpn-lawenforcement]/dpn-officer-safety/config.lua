
Config = {}

Config.Framework = 'qbcore' -- QBCore-only release
Config.Debug = false

Config.Jobs = {
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

Config.Command = 'safety'
Config.OpenKey = 'F8'
Config.PanicKey = 'F10'
Config.PanicHoldMs = 900

Config.EnableNUI = true
Config.EnableGpsBlips = true
Config.EnableServerLogs = true
Config.Webhook = ''

Config.Integrations = {
    Core = 'dpn-le-core',
    Dispatch = 'dpn-digital-dispatch',
    VehicleComputer = 'dpn-vehicle-computer',
    IncidentCommand = 'dpn-incident-command'
}

Config.AlertCooldowns = {
    panic = 8,
    officerDown = 30,
    crash = 25,
    shotsFired = 20,
    welfare = 60,
    pursuit = 30,
    weaponDrawn = 45,
    footPursuit = 35
}

Config.OfficerDown = {
    Enabled = true,
    HealthThreshold = 105,
    CheckMs = 1000,
    RequireInjury = false,
    AutoCreateDispatchCall = true,
    AutoCreateIncident = true
}

Config.Crash = {
    Enabled = true,
    MinSpeedMph = 38.0,
    DeltaSpeedMph = 24.0,
    HeavyDeltaSpeedMph = 42.0,
    AutoCreateDispatchCall = true
}

Config.ShotsFired = {
    Enabled = true,
    AutoCreateDispatchCall = true,
    IgnoreSilenced = false
}

Config.WeaponDrawn = {
    Enabled = true,
    SecondsBeforeAlert = 90,
    AutoCreateDispatchCall = false
}

Config.Welfare = {
    Enabled = true,
    SecondsWithoutMovement = 420,
    SecondsInHighRisk = 180,
    AutoCreateDispatchCall = true
}

Config.Pursuit = {
    Enabled = true,
    MinVehicleSpeedMph = 65.0,
    SecondsBeforeAlert = 30,
    FootPursuitSprintSeconds = 18,
    AutoCreateDispatchCall = true
}

Config.Stress = {
    Enabled = true,
    BaseHeartRate = 78,
    MaxHeartRate = 185,
    DecayPerTick = 1,
    TickMs = 2500
}

Config.Notification = function(message, nType)
    if GetResourceState('qb-core') == 'started' then
        TriggerEvent('QBCore:Notify', message, nType or 'primary')
        return
    end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end
