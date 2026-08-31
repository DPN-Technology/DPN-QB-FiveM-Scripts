Config = Config or {}

Config.Version = '4.0.0'
Config.Debug = true
Config.Jobs = { ambulance=true, ems=true, paramedic=true, fire=true, dispatch=true }
Config.DispatcherJobs = { dispatch=true, ambulance=true, ems=true, paramedic=true, fire=true }
Config.CallExpiryMinutes = 30
Config.DistressCooldownSeconds = 60
Config.RequireIncapacitatedForDistress = true
Config.AllowDeadDistress = true
Config.AutoRoutePriorityOne = false
Config.NotifyOffDuty = false

Config.Blip = {
    sprite = 153,
    colour = 1,
    scale = 0.95,
    durationMs = 300000,
    flash = true,
    radius = 55.0
}

Config.Audio = {
    enabled = true,
    soundName = 'TIMER_STOP',
    soundSet = 'HUD_MINI_GAME_SOUNDSET'
}

-- Optional integration with the separate DPN CAD/dispatch resource. The bridge
-- fails safely when no external dispatch resource is installed.
Config.ExternalDispatch = {
    enabled = true,
    mode = 'first_success',
    emitEventsAfterExport = false, -- prevents duplicate CAD calls when an export already accepted the incident
    resources = { 'dpn-dispatch-system', 'dpn-dispatch' },
    exports = { 'CreateCall', 'CreateDispatchCall', 'CreateIncident', 'CreateCADCall', 'AddCall' },
    events = {
        'dpn-dispatch-system:server:createCall',
        'dpn-dispatch:server:createExternalCall',
        'dpn-dispatch:server:medicalCall',
        'dpn:dispatch:server:createCall'
    },
    updateEvents = {
        'dpn-dispatch-system:server:updateCall',
        'dpn-dispatch:server:updateExternalCall',
        'dpn:dispatch:server:updateCall'
    }
}
