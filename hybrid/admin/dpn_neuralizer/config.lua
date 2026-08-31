Config = {}

-- DPN Neuralizer Advanced
-- Drop this resource in your resources folder, then add: ensure dpn_neuralizer_advanced

Config.Debug = false

-- Framework support: 'auto', 'qb', 'esx', or 'standalone'
Config.Framework = 'auto'
Config.UseAsItem = true
Config.ItemName = 'neuralizer'

Config.UseCommand = true
Config.CommandName = 'neuralizer'
Config.Keybind = {
    enabled = false,
    description = 'Use DPN Neuralizer',
    defaultKey = '' -- Example: 'G'. Leave blank/disabled unless you want a default keybind.
}

Config.Targeting = {
    maxDistance = 8.0,
    coneDegrees = 28.0,
    raycastFirst = true,
    requireLineOfSight = true,
    allowSelfTarget = false
}

Config.Security = {
    -- Main requirement from you: admins cannot be affected by the neuralizer.
    adminImmunity = true,

    -- Set true if only people with ACE permission can use it.
    requireAceToUse = false,
    useAce = 'dpn.neuralizer.use',

    -- Any player with this ACE is immune.
    adminAce = 'dpn.neuralizer.admin',

    -- QBCore/ESX admin groups that are immune.
    qbAdminGroups = { 'god', 'admin', 'mod' },
    esxAdminGroups = { 'superadmin', 'admin', 'mod' },

    -- Add exact identifiers here for hard-coded immunity.
    -- Examples: 'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'discord:123456789012345678'
    adminIdentifiers = {},

    -- Server-side validation. Keep this on if your server has OneSync.
    enforceServerDistance = true,
    maxServerDistance = 10.0,

    cooldownSeconds = 10,
    targetCooldownSeconds = 5,
    eventRateLimitMs = 900,

    notifyImmuneAdminsOnAttempt = false
}

Config.Prop = {
    -- Default is a built-in GTA prop so the resource works immediately.
    -- A custom OBJ/MTL model source is included in model_source/ for conversion to .ydr.
    useCustomModel = false,
    customModel = 'dpn_neuralizer_prop',
    model = 'prop_cs_police_torch',
    fallbackModel = 'prop_cs_police_torch',
    bone = 57005,
    offset = { x = 0.105, y = 0.035, z = -0.025 },
    rotation = { x = -78.0, y = 12.0, z = 8.0 }
}

Config.Animation = {
    dict = 'anim@heists@humane_labs@emp@hack_door',
    name = 'hack_loop',
    flag = 49
}

Config.Effects = {
    useNui = true,
    chargeMs = 450,
    flashMs = 850,
    nearbyFlashMs = 280,
    sourceFlashNearby = true,
    sourceFlashRadius = 18.0,

    -- Target is fully blacked out after the white neuralizer flash.
    blackoutMs = 15000,
    blackoutFadeMs = 350,

    -- Overall scramble/disorientation duration. The script automatically keeps this
    -- long enough to cover the blackout, so you can tune either value safely.
    targetDurationMs = 8500,
    ragdollMs = 1400,
    controlLockMs = 2600,
    screenShake = 0.85,
    drunkenWalkMs = 5000,

    timecycle = 'spectator5',
    postfx = 'DrugsMichaelAliensFight',
    clearWaypoint = true,
    wipeChatMessage = true
}

Config.Safety = {
    -- Prevents the item/effects/ragdoll from draining health or armor.
    -- It does not resurrect dead players.
    preventHealthDrain = true,
    restoreArmor = true,

    -- How long the user of the neuralizer is protected during charge/fire cleanup.
    sourceGuardMs = 4500,

    -- Extra guard time after the target effect ends.
    targetGuardExtraMs = 1000
}

Config.Notifications = {
    system = 'auto', -- auto, qb, esx, ox, chat, none
    prefix = 'DPN Neuralizer'
}

Config.Logging = {
    enableConsole = true,
    discordWebhook = '',
    webhookName = 'DPN Neuralizer Logs'
}
