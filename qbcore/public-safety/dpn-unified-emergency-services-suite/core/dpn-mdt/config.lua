Config = Config or {}

Config.Debug = false
Config.Command = 'mdt'
Config.Keybind = 'F11'
Config.CallbackTimeout = 8000 -- milliseconds before the client reports a missing/stuck server callback
Config.OnlyShowOnDuty = true
Config.DefaultTheme = 'leo'
Config.Locale = 'en'

Config.Framework = {
    name = 'qb-core',
    resource = 'qb-core'
}


Config.Database = {
    -- Standard QBCore table names. Change these if your server renamed core tables.
    players = 'players',
    vehicles = 'player_vehicles',
    apartments = 'apartments',
    houses = 'player_houses',
    phoneVehicles = 'phone_vehicles'
}

Config.DataPulls = {
    searchLimit = 50,
    profileVehicleLimit = 150,
    includeLivePlayerData = true,
    includeMoney = true,
    includeLicenses = true,
    includeMetadata = true
}

Config.Departments = {
    leo = {
        label = 'Law Enforcement',
        theme = 'leo',
        jobs = { 'police', 'lspd', 'bcso', 'sahp', 'fib', 'sasp' },
        modules = { 'dashboard', 'dispatch', 'citizens', 'vehicles', 'reports', 'cases', 'warrants', 'bolos', 'evidence', 'weapons', 'roster', 'charges', 'courts', 'audit' }
    },
    ems = {
        label = 'Emergency Medical Services',
        theme = 'ems',
        jobs = { 'ambulance', 'ems', 'doctor' },
        modules = { 'dashboard', 'dispatch', 'citizens', 'vehicles', 'reports', 'cases', 'evidence', 'roster', 'ems', 'audit' }
    },
    fire = {
        label = 'Fire / Rescue',
        theme = 'fire',
        jobs = { 'fire', 'fd', 'firefighter', 'firedept' },
        modules = { 'dashboard', 'dispatch', 'citizens', 'vehicles', 'reports', 'cases', 'evidence', 'roster', 'fire', 'audit' }
    },
    courts = {
        label = 'Courts / DOJ',
        theme = 'courts',
        jobs = { 'judge', 'lawyer', 'doj', 'districtattorney', 'publicdefender' },
        modules = { 'dashboard', 'citizens', 'vehicles', 'reports', 'cases', 'warrants', 'evidence', 'charges', 'courts', 'audit' }
    },
    corrections = {
        label = 'Corrections / Department of Corrections',
        theme = 'corrections',
        jobs = { 'corrections', 'doc', 'prison', 'jail', 'jailer', 'correctionsofficer', 'correctional' },
        modules = { 'dashboard', 'dispatch', 'citizens', 'vehicles', 'reports', 'cases', 'warrants', 'bolos', 'evidence', 'weapons', 'roster', 'charges', 'courts', 'corrections', 'audit' }
    },
    mib = {
        label = 'MIB / Server Administration',
        theme = 'mib',
        jobs = { 'mib', 'admin' },
        ace = { 'admin', 'god' },
        modules = { 'dashboard', 'dispatch', 'citizens', 'vehicles', 'reports', 'cases', 'warrants', 'bolos', 'evidence', 'weapons', 'roster', 'charges', 'courts', 'ems', 'fire', 'mib', 'audit' }
    }
}

Config.Permissions = {
    -- minimum grade per module action. 0 means any authorized employee.
    createReport = 0,
    editReport = 1,
    deleteReport = 4,
    createWarrant = 2,
    clearWarrant = 2,
    createCourtCase = 1,
    sentenceCitizen = 2,
    manageCharges = 4,
    mibTools = 4,
    auditView = 3
}

Config.Dispatch = {
    resource = 'dpn-dispatch',
    enabled = true,
    receiveEvent = 'dpn-mdt:server:ReceiveDispatchCall',
    updateEvent = 'dpn-dispatch:server:UpdateCall',
    assignEvent = 'dpn-dispatch:server:AssignUnit',
    statusEvent = 'dpn-dispatch:server:SetUnitStatus'
}

Config.UnifiedNetwork = {
    enabled = true,
    resource = 'dpn-unified-emergency-network',
    incidentEvent = 'dpn-unes:server:mdtIncidentUpdated',
    unitStatusEvent = 'dpn-unes:server:mdtUnitStatusChanged',
    recordEvent = 'dpn-unes:server:mdtRecordLinked'
}

Config.MIB = {
    enabled = true,
    allowedAce = { 'admin', 'god' },
    neuralizerResource = 'dpn_neuralizer',
    portalResource = 'dpn-pg-7x',
    allowPlayerLookup = true,
    allowAuditExport = true,
    allowEmergencyOverride = true
}

Config.Mugshots = {
    enabled = true,
    screenshotResource = 'screenshot-basic',
    uploadWebhook = '' -- optional Discord/FiveManage URL handled by your own bridge
}

Config.Fines = {
    maxAmount = 100000,
    defaultAccount = 'bank'
}


Config.Charging = {
    -- Charging records are stored in dpn_mdt_citizen_charges and displayed on citizen profiles.
    defaultType = 'arrest', -- arrest, citation, warrant_request, court_referral
    defaultStatus = 'filed', -- filed, pending_court, convicted, dismissed, expunged
    maxFine = 250000,
    maxJail = 999,
    maxPoints = 99,
    allowCustomMultiplier = true,
    requireCitizenId = true,
    requireAtLeastOneCharge = true,
    -- Optional hooks for your economy/court/jail resources. The MDT only triggers these events; your bridge decides what happens.
    fineAccount = Config.Fines.defaultAccount or 'bank',
    triggerFineEvent = false,
    fineEvent = 'dpn-mdt:server:FineIssued',
    triggerJailEvent = false,
    jailEvent = 'dpn-mdt:server:JailSentenceIssued',
    triggerCourtEvent = true,
    courtEvent = 'dpn-mdt:server:CourtReferralCreated'
}

Config.Callsigns = {
    autoCreate = true,
    defaultPrefix = 'DPN'
}
