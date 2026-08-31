Config = {}

-- Framework: 'auto', 'qb', 'qbx', 'esx', or 'standalone'.
Config.Framework = 'auto'
Config.Debug = false

-- Permission mode:
-- 'job'      = only configured emergency jobs
-- 'ace'      = only ACE permission
-- 'either'   = emergency job OR ACE permission
-- 'both'     = emergency job AND ACE permission
Config.PermissionMode = 'either'
Config.AcePermission = 'dpn.pa.use'
Config.RequireOnDuty = true

-- Jobs allowed to use the PA. Grade can be a number or a QB grade table.
Config.AllowedJobs = {
    police    = { label = 'Police', minGrade = 0 },
    sheriff   = { label = 'Sheriff', minGrade = 0 },
    state     = { label = 'State Police', minGrade = 0 },
    ambulance = { label = 'EMS', minGrade = 0 },
    ems       = { label = 'EMS', minGrade = 0 },
    fire      = { label = 'Fire Department', minGrade = 0 },
}

-- Optional inventory requirement. Set to false to disable.
-- Examples: 'pa_microphone', 'megaphone', 'radio'
Config.RequiredItem = false

-- Vehicle checks.
Config.RequireVehicle = true
Config.RequireEmergencyVehicle = true
Config.AllowedVehicleClasses = {
    [18] = true, -- Emergency
}

-- Optional extra models allowed even if not class 18.
-- Use lower-case spawn names.
Config.AllowedVehicleModels = {
    v18charger = true,
    police2 = true,
    police3 = true,
    police4 = true,
    sheriff = true,
    sheriff2 = true,
    ambulance = true,
    firetruk = true,
    fbi = true,
    fbi2 = true,
}

-- Optional blocked vehicle models.
Config.BlacklistedVehicleModels = {}

-- Seats allowed to transmit. -1 driver, 0 passenger, 1 rear left, 2 rear right.
Config.AllowedSeats = {
    [-1] = true,
    [0] = true,
}

-- pma-voice integration.
Config.PmaVoiceResource = 'pma-voice'
Config.PmaMethod = 'overrideProximityRange' -- currently safest public-style export for a PA/megaphone effect.
Config.ForceGamePushToTalkWhilePA = true -- makes the PA key also press GTA/FiveM voice PTT control.
Config.PushToTalkControl = 249 -- INPUT_PUSH_TO_TALK. Do not change unless you know the FiveM control index.

-- Distance settings. pma-voice distance is in GTA units/meters.
Config.DefaultRange = 160.0
Config.MaxRange = 260.0
Config.MinRange = 40.0
Config.RangePresets = {
    { id = 'street',   label = 'Street PA',   range = 90.0,  description = 'Traffic stop / nearby crowd' },
    { id = 'block',    label = 'Block PA',    range = 160.0, description = 'Default patrol PA range' },
    { id = 'incident', label = 'Incident PA', range = 230.0, description = 'Large scene / evacuation' },
}

-- Abuse protection / cleanup.
Config.StartCooldownMs = 900
Config.HeartbeatMs = 1250
Config.StopIfVehicleStopsExisting = true
Config.StopIfPlayerDead = true
Config.StopIfPlayerExitsVehicle = true
Config.MaxTransmissionSeconds = 180 -- safety cap for latch mode; set false to disable.

-- Incoming HUD for nearby listeners. Disabled so players do not see any listener-side PA overlay.
Config.ShowIncomingHud = false
Config.IncomingHudExtraDistance = 35.0
Config.IncomingHudExpireMs = 3000

-- Commands and keybinds. Players can change mapped keys in: Settings > Key Bindings > FiveM.
Config.Commands = {
    menu = 'pamenu',
    stop = 'pacancel',
    status = 'pastatus',
}

Config.Keybinds = {
    menu = {
        command = 'dpnpa_menu',
        label = 'DPN PA: Open control panel',
        default = 'F7'
    },
    ptt = {
        command = '+dpnpa_ptt',
        label = 'DPN PA: Push to talk',
        default = 'H'
    },
    latch = {
        command = 'dpnpa_latch',
        label = 'DPN PA: Toggle latch transmission',
        default = 'F8'
    },
}

-- UI defaults stored per player with resource KVP.
Config.DefaultSettings = {
    selectedRange = Config.DefaultRange,
    selectedPreset = 'block',
    hudEnabled = false,
    clickSounds = true,
    latchMode = false,
    uiScale = 1.0,
    uiPosition = 'right',
}

Config.Messages = {
    no_permission = 'You are not authorized to use the emergency PA system.',
    not_on_duty = 'You must be on duty to use the PA system.',
    no_item = 'You need the configured PA item to use this.',
    pma_missing = 'pma-voice is not started or does not expose the required PA range function.',
    no_vehicle = 'You must be inside an authorized emergency vehicle.',
    wrong_seat = 'You must be in an allowed PA seat.',
    too_fast = 'PA system is cooling down. Try again in a moment.',
    started = 'PA microphone live.',
    stopped = 'PA microphone off.',
    invalid = 'PA cancelled: vehicle, permission, or voice state is no longer valid.',
}

function Config.ClampRange(range)
    range = tonumber(range) or Config.DefaultRange
    if range < Config.MinRange then return Config.MinRange end
    if range > Config.MaxRange then return Config.MaxRange end
    return range + 0.0
end
