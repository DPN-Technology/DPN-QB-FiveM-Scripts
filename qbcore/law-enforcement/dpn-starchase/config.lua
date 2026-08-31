Config = {}

Config.Debug = false
Config.CoreName = 'qb-core'
Config.ResourceName = 'dpn-starchase'

-- Jobs allowed to open/fire/use the law-enforcement tracker controls.
-- Value = minimum grade level. Add/remove jobs to match your server.
Config.AllowedJobs = {
    police = 0,
    sheriff = 0,
    state = 0,
    trooper = 0,
    ranger = 0,
}
Config.RequireOnDuty = true
Config.AllowAdminBypass = true -- ACE: command.dpnstarchase.admin

Config.Commands = {
    remote = 'starchase',
    fire = 'starchasefire',
    toggleLockHud = 'starchaselockhud',
    removeNearest = 'removestarchase',
    forceClear = 'starchaseclear'
}

-- All keybinds are registered through FiveM key mapping.
-- Players can change them in ESC > Settings > Key Bindings > FiveM.
-- Change defaultKey here before the player first binds it, or tell players to reset/change it in FiveM settings.
Config.Controls = {
    openRemote = {
        enabled = true,
        command = 'starchase',
        description = 'Open DPN StarChase Remote',
        defaultKey = 'F10'
    },
    quickDeploy = {
        enabled = true,
        command = 'starchasefire',
        description = 'DPN StarChase Quick Deploy Tracker',
        defaultKey = 'F11'
    },
    removeNearest = {
        enabled = true,
        command = 'removestarchase',
        description = 'Remove Nearest DPN StarChase Tracker',
        defaultKey = 'F9'
    },
    toggleLockHud = {
        enabled = true,
        command = 'starchaselockhud',
        description = 'Toggle DPN StarChase Lock-On HUD',
        defaultKey = 'F3'
    }
}

-- Backward compatibility for older config references.
Config.Keybind = Config.Controls.openRemote

Config.Items = {
    useRemoteItem = false,       -- if true, players need the remote item to open the UI
    remoteItem = 'starchase_remote',
    requireAmmo = false,         -- if true, firing consumes ammoItem
    ammoItem = 'starchase_round',
    removeAmmoOnFire = true
}

Config.VehicleRules = {
    requireVehicle = true,
    driverOnly = false,          -- false = passenger officer can operate the launcher
    requireEmergencyClass = true,
    allowedClasses = { [18] = true }, -- GTA class 18 = emergency
    allowedModels = {            -- optional model allow-list. Leave empty to allow all emergency vehicles.
        -- [`police`] = true,
        -- [`police2`] = true,
    },
    blockedModels = {}
}

Config.Fire = {
    cooldownSeconds = 8,
    maxDistance = 62.0,
    coneDegrees = 15.0,
    capsuleRadius = 4.4,
    minLauncherSpeed = 0.0,
    maxLauncherSpeed = 145.0,
    maxTargetSpeed = 180.0,
    rejectIfTargetStopped = false,
    launchOffset = { x = 0.0, y = 2.85, z = 0.58 },
    targetOffset = { x = 0.0, y = -2.25, z = 0.34 },
    projectileModel = `prop_ld_keypad_01`, -- small visual device, not a bomb
    launchSound = true,
    launchScreenShake = false, -- kept off so it does not feel explosive
    requireLineOfSight = true,
    preventSameVehicle = true,
    safeVisualOnly = true,      -- no explosion, no bullet, no collision damage, no vehicle health changes
    forceNoCollision = true,
    damageProofFx = true
}

Config.LockOn = {
    enabled = true,
    showWhileDriving = true,
    drawLine = true,
    drawTargetMarker = true,
    drawTargetBox = true,
    requireAllowedVehicle = true,
    refreshMs = 120,
    maxNoTargetDrawDistance = 24.0,
    textScale = 0.34,
    validColor = { r = 35, g = 255, b = 85, a = 220 },
    noTargetColor = { r = 255, g = 65, b = 65, a = 180 },
    lineColor = { r = 35, g = 255, b = 85, a = 190 },
    showPlate = true,
    showDistance = true,
    showSpeed = true
}

Config.Tracker = {
    model = `prop_ld_keypad_01`, -- compact low-profile tracker instead of a bomb model
    attachBonePreference = 'bumper_r',
    -- Bone-relative offsets: keep these small. Large Y values make the prop stick way out.
    attachOffset = { x = 0.0, y = -0.055, z = 0.025 },
    attachRotation = { x = 90.0, y = 0.0, z = 0.0 },
    fallbackVehicleOffset = { x = 0.0, y = -2.45, z = 0.34 },
    fallbackRotation = { x = 90.0, y = 0.0, z = 0.0 },
    lifetimeSeconds = 900, -- 15 minutes
    heartbeatSeconds = 1.5,
    staleAfterSeconds = 12,
    maxActivePerOfficer = 4,
    maxActiveGlobal = 80,
    broadcastUpdateDistance = 650.0,
    physicalRemovalDistance = 2.2,
    officerRemovalSeconds = 3500,
    civilianRemoval = true,
    civilianRemovalSeconds = 9000,
    civilianRemovalKey = 38, -- E
    removalAlertToPolice = true,
    deletePropOnRemove = true,
    autoRemoveWhenVehicleDestroyed = true,
    markerHeight = 0.18
}

Config.Blip = {
    sprite = 225,
    color = 1,
    staleColor = 47,
    scale = 0.86,
    shortRange = false,
    namePrefix = 'DPN StarChase',
    flashWhenStale = true,
    routeColor = 1,
    forceCleanupOnRemove = true,
    resyncAfterRemoval = true
}

Config.UI = {
    title = 'DPN StarChase',
    unitLabel = 'LAW GPS TRACKER SYSTEM',
    theme = 'dpn-red',
    showPlate = true,
    showOfficer = true,
    showDistance = true,
    showKeybinds = true,
    showLockOnHelp = true
}

Config.Alerts = {
    notifyAllLawOnLaunch = true,
    notifyAllLawOnRemove = true,
    notifyLauncherOnlyOnFail = true
}

Config.Database = {
    enabled = true,
    autoCreate = true,
    resource = 'oxmysql',
    tableName = 'dpn_starchase_logs'
}

Config.Dispatch = {
    enabled = false,
    -- Optional hook. Return true if handled.
    customAlert = function(action, data)
        -- Example:
        -- exports['ps-dispatch']:CustomAlert({ coords = data.coords, message = 'StarChase tracker active', dispatchCode = '10-80T' })
        return false
    end
}

Config.Messages = {
    noAccess = 'You are not authorized to use DPN StarChase.',
    offDuty = 'You must be on duty to use DPN StarChase.',
    noVehicle = 'You must be inside a police/emergency vehicle.',
    badVehicle = 'This vehicle is not fitted with a StarChase launcher.',
    noTarget = 'No valid vehicle target in the launcher cone.',
    cooldown = 'Launcher cooling down.',
    ammoMissing = 'Missing StarChase tracker round.',
    maxTrackers = 'Maximum active StarChase trackers reached.',
    launched = 'StarChase tracker deployed and GPS lock established.',
    removed = 'StarChase tracker removed.',
    expired = 'StarChase tracker expired.',
    nearestMissing = 'No StarChase tracker nearby.',
    lockHudOn = 'StarChase lock-on HUD enabled.',
    lockHudOff = 'StarChase lock-on HUD disabled.'
}
