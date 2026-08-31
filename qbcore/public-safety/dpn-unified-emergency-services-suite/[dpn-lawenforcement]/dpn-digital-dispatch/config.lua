Config = {}

Config.Debug = false
Config.CoreResource = 'dpn-le-core'
Config.Framework = 'qbcore'
Config.RequireDuty = true

Config.Command = 'digitaldispatch'
Config.PanicCommand = 'digitalpanic'
Config.Civilian911Command = 'd911'
Config.OpenKey = 'F9'
Config.PanicKey = '' -- Officer Safety owns the default F10 panic key; /panic still works.

Config.AllowedJobs = {
    police = { department = 'law' },
    sheriff = { department = 'law' },
    state = { department = 'law' },
    trooper = { department = 'law' },
    ranger = { department = 'law' },
    corrections = { department = 'law' },
    fire = { department = 'fire' },
    ambulance = { department = 'medical' },
    ems = { department = 'medical' },
    dispatch = { department = 'dispatch' }
}

Config.SupervisorGrades = {
    police = 4, sheriff = 4, state = 4, trooper = 4, ranger = 4,
    corrections = 4, fire = 4, ambulance = 4, ems = 4, dispatch = 2
}

Config.CallTypes = {
    ['911'] = { label = '911 Emergency', priority = 2, color = 1, timeout = 900, departments = { 'law', 'fire', 'medical', 'dispatch' } },
    ['panic'] = { label = 'Officer Panic', priority = 1, color = 1, timeout = 1200, departments = { 'law', 'dispatch' } },
    ['shots'] = { label = 'Shots Fired', priority = 1, color = 1, timeout = 900, departments = { 'law', 'medical', 'dispatch' } },
    ['traffic'] = { label = 'Traffic Stop', priority = 3, color = 5, timeout = 900, departments = { 'law', 'dispatch' } },
    ['backup'] = { label = 'Backup Request', priority = 2, color = 47, timeout = 900, departments = { 'law', 'dispatch' } },
    ['medical'] = { label = 'Medical Emergency', priority = 2, color = 6, timeout = 900, departments = { 'medical', 'fire', 'dispatch' } },
    ['fire'] = { label = 'Fire Emergency', priority = 2, color = 17, timeout = 1200, departments = { 'fire', 'medical', 'dispatch' } },
    ['bolo'] = { label = 'BOLO / Intelligence Hit', priority = 2, color = 47, timeout = 1800, departments = { 'law', 'dispatch' } },
    ['training'] = { label = 'Training Scenario', priority = 4, color = 3, timeout = 1800, departments = { 'law', 'fire', 'medical', 'dispatch' } },
    ['incident'] = { label = 'Major Incident', priority = 1, color = 1, timeout = 3600, departments = { 'law', 'fire', 'medical', 'dispatch' } },
    ['pursuit'] = { label = 'Vehicle Pursuit', priority = 2, color = 1, timeout = 2400, departments = { 'law', 'dispatch' } },
    ['warrant'] = { label = 'Warrant Service', priority = 2, color = 47, timeout = 2400, departments = { 'law', 'dispatch' } },
    ['use_of_force'] = { label = 'Use-of-Force Review', priority = 2, color = 1, timeout = 1800, departments = { 'law', 'dispatch' } },
    ['transport'] = { label = 'Prisoner Transport', priority = 3, color = 7, timeout = 1800, departments = { 'law', 'dispatch' } },
    ['roadblock'] = { label = 'Roadblock / Traffic Control', priority = 2, color = 5, timeout = 1800, departments = { 'law', 'dispatch' } }
}

Config.UnitStatuses = {
    ['10-8'] = 'Available', ['10-6'] = 'Busy', ['10-7'] = 'Out of Service',
    ['10-23'] = 'On Scene', ['10-97'] = 'En Route', ['10-15'] = 'Transporting',
    ['10-11'] = 'Traffic Stop', ['10-99'] = 'Emergency'
}


Config.CallStatuses = {
    active = 'Active', assigned = 'Assigned', enroute = 'Units En Route', on_scene = 'Units On Scene',
    holding = 'Holding / Staging', cleared = 'Cleared', closed = 'Closed', expired = 'Expired'
}
Config.RequireDispositionOnClose = true
Config.MaxCallNotes = 100
Config.MaxNoteLength = 1200

Config.EnableCivilian911 = true
Config.EnableAutoShotsFired = false -- Use dpn-smart-city for realistic acoustic detection.
Config.ShotsCooldownSeconds = 45
Config.EnableAutoVehicleCrash = true
Config.CrashSpeedMPH = 55
Config.EnableGPSBlips = true
Config.BlipUpdateSeconds = 5
Config.CallBlipDurationSeconds = 300
Config.CallRetentionSeconds = 7200
Config.MaxActiveCalls = 150

Config.Security = {
    MaxTitleLength = 128,
    MaxDescriptionLength = 1000,
    MaxCallsPerMinute = 8,
    MaxUnitLength = 20
}

Config.DiscordWebhook = ''
Config.LogEvents = true
