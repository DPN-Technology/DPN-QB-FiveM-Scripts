Config = {}

Config.Framework = 'qb' -- QBCore-only release
Config.Debug = false
Config.Command = 'evidenceai'
Config.OpenKey = 'F9'
Config.AllowCivReports = true

Config.Jobs = {
    police = true,
    sheriff = true,
    state = true,
    trooper = true,
    ranger = true,
    corrections = true,
    ambulance = true,
    ems = true,
    fire = true,
    dispatch = true
}

Config.SupervisorGrades = { 4, 5, 6, 7, 8, 9, 10 }
Config.AdminAce = 'dpn.evidence.admin'

Config.Webhooks = {
    enabled = false,
    evidence = '',
    custody = '',
    cases = '',
    court = ''
}

Config.Integrations = {
    leCore = true,
    dispatch = true,
    officerSafety = true,
    vehicleComputer = true,
    bodycam = true
}

Config.EvidenceTypes = {
    'photo', 'video', 'audio', 'weapon', 'casings', 'blood', 'dna', 'fingerprint',
    'vehicle', 'drug', 'property', 'document', 'bodycam', 'dashcam', 'starchase', 'other'
}

Config.CaseStatuses = {
    open = 'Open',
    pending = 'Pending Review',
    warrant = 'Warrant Requested',
    submitted = 'Submitted To Court',
    closed = 'Closed',
    archived = 'Archived'
}

Config.AutoEvidence = {
    GunshotCasings = true,
    OfficerPanic = true,
    OfficerDown = true,
    VehicleCrash = true,
    DispatchCallCreated = true,
    BodycamBookmark = true
}

Config.AutoEvidenceCooldownMs = 10000
Config.ServerRateLimitMs = 2500
Config.MaxMetadataLength = 12000

Config.RetentionDays = 180
Config.MaxEvidencePerCase = 250
Config.MaxNoteLength = 2500
