Config = {}

Config.Debug = false
Config.Framework = 'qb' -- This package is designed for qb-core and does not require qb-policejob.
Config.Command = 'dpnle'
Config.OpenKey = 'F6'
Config.RequireOnDuty = true
Config.UseAcePerms = true
Config.AdminAce = 'dpn.le.admin'
Config.CommandAce = 'dpn.le.open'
Config.BypassDutyAce = 'dpn.le.bypassduty'

Config.DispatchResource = 'dpn-digital-dispatch'
Config.CorrectionsResource = 'dpn-corrections-system'
Config.Inventory = 'auto' -- auto, qb-inventory, ox_inventory, playerdata

Config.OperationsResource = 'dpn-le-operations'
Config.MdtResource = 'dpn-mdt'
Config.JusticeResource = 'dpn-justice-system'
Config.EvidenceResource = 'dpn-evidence-ai'

Config.Capabilities = {
    patrol = { minimumGrade = 0, label = 'Patrol Operations' },
    traffic = { minimumGrade = 0, label = 'Traffic Enforcement' },
    arrest = { minimumGrade = 0, label = 'Arrest and Booking' },
    warrants = { minimumGrade = 1, label = 'Warrant Requests' },
    pursuit = { minimumGrade = 1, label = 'Pursuit Operations' },
    evidence = { minimumGrade = 1, label = 'Evidence Handling' },
    supervisor = { minimumGrade = 4, label = 'Field Supervision' },
    command = { minimumGrade = 5, label = 'Incident Command' }
}

Config.AllowedJobs = {
    police = { type = 'law', label = 'Police Department', defaultUnitPrefix = 'PD' },
    sheriff = { type = 'law', label = 'Sheriff Office', defaultUnitPrefix = 'SO' },
    state = { type = 'law', label = 'State Police', defaultUnitPrefix = 'SP' },
    trooper = { type = 'law', label = 'State Police', defaultUnitPrefix = 'SP' },
    ranger = { type = 'law', label = 'Park Rangers', defaultUnitPrefix = 'PR' },
    corrections = { type = 'law', label = 'Corrections', defaultUnitPrefix = 'DOC' },
    ambulance = { type = 'medical', label = 'EMS', defaultUnitPrefix = 'MED' },
    ems = { type = 'medical', label = 'EMS', defaultUnitPrefix = 'MED' },
    fire = { type = 'fire', label = 'Fire Department', defaultUnitPrefix = 'FD' },
    dispatch = { type = 'dispatch', label = 'Emergency Communications', defaultUnitPrefix = 'DISP' }
}

Config.SupervisorGrades = {
    police = 4, sheriff = 4, state = 4, trooper = 4, ranger = 4,
    corrections = 4, ambulance = 4, ems = 4, fire = 4, dispatch = 2
}

Config.Statuses = {
    ['10-8'] = { label = 'Available / In Service', color = 'green' },
    ['10-6'] = { label = 'Busy', color = 'yellow' },
    ['10-7'] = { label = 'Out of Service', color = 'gray' },
    ['10-11'] = { label = 'Traffic Stop', color = 'orange' },
    ['10-15'] = { label = 'Transporting', color = 'purple' },
    ['10-23'] = { label = 'On Scene', color = 'blue' },
    ['10-97'] = { label = 'En Route', color = 'cyan' },
    ['10-99'] = { label = 'Emergency / Panic', color = 'red' }
}
Config.DefaultStatus = '10-8'

Config.Interactions = {
    Enabled = true,
    MaxDistance = 3.0,
    VehicleDistance = 5.0,
    RequireLawJob = true,
    AllowSoftCuff = true,
    SearchShowsMoney = true,
    SearchShowsInventory = true,
    SearchMaxItems = 80,
    ActionCooldownMs = 700,
    CuffItem = '', -- Optional item requirement, e.g. 'handcuffs'. Leave blank for no item requirement.
    AutoUncuffOnDeath = true
}

Config.Citations = {
    Enabled = true,
    Minimum = 1,
    Maximum = 100000,
    AutoDebit = false,
    DebitAccount = 'bank'
}

Config.Booking = {
    Enabled = true,
    MaxSentenceMinutes = 720,
    MaxFine = 250000,
    SendToCorrections = true
}

Config.Dispatch = {
    RetainMinutes = 120,
    MaxActiveCalls = 100,
    AutoExpire = true,
    AllowCivilianCalls = true,
    BlipTimeSeconds = 300
}

Config.Security = {
    MaxStringLength = 500,
    MaxUnitLength = 16,
    RateWindowSeconds = 10,
    MaxActionsPerWindow = 20
}

Config.UI = {
    Title = 'DPN Law Enforcement Network',
    Theme = 'dpn-blue',
    ShowWatermark = true
}

Config.Webhooks = {
    Enabled = false,
    Dispatch = '',
    OfficerStatus = '',
    EnforcementActions = '',
    Errors = ''
}
