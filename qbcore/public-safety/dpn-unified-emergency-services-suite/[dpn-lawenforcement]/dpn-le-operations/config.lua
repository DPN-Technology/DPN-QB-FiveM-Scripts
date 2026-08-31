Config = {}

Config.Debug = false
Config.Command = 'leops'
Config.OpenKey = 'F1'
Config.RequireDuty = true
Config.CoreResource = 'dpn-le-core'
Config.DispatchResource = 'dpn-digital-dispatch'
Config.IncidentResource = 'dpn-incident-command'
Config.EvidenceResource = 'dpn-evidence-ai'
Config.IntelligenceResource = 'dpn-crime-intelligence'
Config.TrainingResource = 'dpn-training-academy'
Config.JusticeResource = 'dpn-justice-system'
Config.CorrectionsResource = 'dpn-corrections-system'
Config.MdtResource = 'dpn-mdt'

Config.AllowedJobs = {
    police = { department='law', label='Police Department' },
    sheriff = { department='law', label='Sheriff Office' },
    state = { department='law', label='State Police' },
    trooper = { department='law', label='State Police' },
    ranger = { department='law', label='Park Rangers' },
    corrections = { department='law', label='Corrections' },
    dispatch = { department='dispatch', label='Emergency Communications' }
}

Config.JusticeJobs = { judge=true, doj=true, attorney=true, justice=true }
Config.SupervisorGrades = { police=4, sheriff=4, state=4, trooper=4, ranger=4, corrections=4, dispatch=2 }
Config.JudgeGrades = { judge=0, doj=3, justice=2 }
Config.AdminAce = 'dpn.le.admin'
Config.SupervisorAce = 'dpn.le.supervisor'
Config.JudgeAce = 'dpn.justice.warrants'

Config.MaxUnitMembers = 4

Config.UnitRoles = {
    patrol='Patrol', primary='Primary Unit', secondary='Secondary Unit', supervisor='Field Supervisor',
    traffic='Traffic Enforcement', detective='Detective', k9='K-9 Unit', air='Air Unit',
    transport='Prisoner Transport', swat='Tactical Unit', marine='Marine Unit', ranger='Ranger Unit'
}

Config.Warrants = {
    MaxProbableCauseLength = 6000,
    MaxChargesLength = 2500,
    DefaultExpiryDays = 14,
    MaximumExpiryDays = 90,
    HighRiskDispatch = true,
    RequireJudicialApproval = true,
    Types = {
        arrest='Arrest Warrant', search_person='Search Warrant — Person', search_property='Search Warrant — Property',
        search_vehicle='Search Warrant — Vehicle', bench='Bench Warrant', seizure='Seizure Order'
    },
    RiskLevels = { low='Low', standard='Standard', high='High', critical='Critical' }
}

Config.Pursuits = {
    MaxActive = 20,
    AcquisitionDistance = 140.0,
    UpdateMinimumMs = 1000,
    AutoDispatch = true,
    AutoIncident = true,
    SupervisorRequiredForPit = true,
    SupervisorRequiredForRoadblock = true,
    Stages = { observation='Observation', active='Active Pursuit', high_risk='High Risk', containment='Containment', terminated='Terminated' },
    Tactics = { pit='PIT Maneuver', spikes='Spike Strips', roadblock='Roadblock', air='Air Support', starchase='StarChase', k9='K-9 Response' },
    ReviewFindings = { within_policy='Within Policy', training='Training Referral', corrective='Corrective Action', investigation='Administrative Investigation' }
}

Config.Force = {
    AutoDraftOnWeaponDischarge = true,
    DischargeCooldownSeconds = 120,
    NarrativeMaxLength = 6000,
    Levels = {
        presence='Officer Presence', verbal='Verbal Direction', restraint='Physical Restraint',
        control='Physical Control', less_lethal='Less-Lethal Force', lethal='Lethal Force'
    },
    ReviewFindings = {
        pending='Pending Review', within_policy='Within Policy', training='Training Referral',
        corrective='Corrective Action', investigation='Administrative Investigation', criminal='Criminal Referral'
    }
}

Config.Fleet = {
    CheckoutDistance = 12.0,
    MaxActivePerOfficer = 1,
    RequireEmergencyClass = false,
    AllowedVehicleClasses = { [18]=true },
    DamageReportThreshold = 100.0
}

Config.Armory = {
    TrackOnly = true, -- Set false to add/remove configured QBCore items during issue and return.
    MaximumQuantity = 10,
    RequireValidCertification = true,
    Catalog = {
        radio = { label='Encrypted Radio', item='radio', cert=nil },
        bodycam = { label='Body-Worn Camera', item='bodycam', cert=nil },
        handgun = { label='Duty Handgun', item='weapon_pistol', cert='firearms_basic' },
        rifle = { label='Patrol Rifle', item='weapon_carbinerifle', cert='firearms_advanced' },
        lesslethal = { label='Less-Lethal Launcher', item='weapon_stungun', cert='firearms_basic' },
        shield = { label='Ballistic Shield', item='policeshield', cert='firearms_advanced' },
        spikes = { label='Spike Strip Kit', item='spikestrip', cert='evoc_pursuit' },
        drone = { label='Public Safety Drone Kit', item='policedrone', cert='drone_operator' }
    }
}

Config.Security = {
    MaxString = 6000,
    MaxShortString = 160,
    RateWindowSeconds = 10,
    MaxActionsPerWindow = 25
}

Config.Webhook = ''

-- v4 unified DPN emergency-network integration.
Config.NetworkResource = 'dpn-emergency-network'
Config.NetworkRefreshSeconds = 15
Config.CommandCenterTitle = 'DPN Public Safety Command Center'
Config.CommandCenterSubtitle = 'Law enforcement, emergency services, justice, corrections, intelligence, and infrastructure'

-- Modules appear in the Command Center launcher. Commands are used when a resource does not expose an open-UI export.
Config.ModuleLauncher = {
    dispatch={ label='Digital Dispatch', icon='radio', command='dispatch', resource='dpn-digital-dispatch', department='all' },
    mdt={ label='DPN MDT', icon='database', command='mdt', resource='dpn-mdt', department='law' },
    core={ label='Field Actions', icon='shield', command='dpnle', resource='dpn-le-core', department='law' },
    vehicle={ label='Vehicle Computer', icon='car', command='vcomputer', resource='dpn-vehicle-computer', department='law' },
    evidence={ label='Evidence AI', icon='fingerprint', command='evidenceai', resource='dpn-evidence-ai', department='law' },
    intelligence={ label='Crime Intelligence', icon='network', command='crimeintel', resource='dpn-crime-intelligence', department='law' },
    incident={ label='Incident Command', icon='command', command='ics', resource='dpn-incident-command', department='all' },
    safety={ label='Officer Safety', icon='heart', command='safety', resource='dpn-officer-safety', department='law' },
    smartcity={ label='Smart City', icon='city', command='smartcity', resource='dpn-smart-city', department='law' },
    drone={ label='Drone Command', icon='drone', command='drone', resource='dpn-drone-command', department='law' },
    academy={ label='Training Academy', icon='academy', command='academy', resource='dpn-training-academy', department='law' },
    medical={ label='Medical System', icon='medical', command='medical', resource='dpn-medical-core', department='all' },
    fire={ label='Fire System', icon='fire', command='fire', resource='dpn-fire-system', department='all' },
    corrections={ label='Corrections System', icon='corrections', command='corrections', resource='dpn-corrections-system', department='law' },
    justice={ label='Justice System', icon='justice', command='justice', resource='dpn-justice-system', department='all' },
    mib={ label='MIB Administration', icon='admin', command='mib', resource='dpn-mib-system', department='all' },
    starchase={ label='StarChase', icon='tracker', command='starchase', resource='dpn-starchase', department='law' },
    bodycam={ label='Bodycam Evidence', icon='camera', command='bodycam', resource='dpn-bodycam', department='law' }
}

Config.NetworkQuickSignals = {
    backup={ label='Request Backup', eventType='officer_panic', severity=1 },
    medical={ label='Request EMS', eventType='patient_critical', severity=2 },
    fire={ label='Request Fire', eventType='fire_incident', severity=2 },
    transport={ label='Request Prisoner Transport', eventType='corrections_transport', severity=3 },
    supervisor={ label='Request Supervisor', eventType='generic', severity=3 }
}
