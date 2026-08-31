Config = {}

Config.Debug = false
Config.HealthIntervalSeconds = 20
Config.RecentEventLimit = 100
Config.MaxPayloadBytes = 12000
Config.MaxStringLength = 1800
Config.RateWindowSeconds = 10
Config.MaxPlayerPublishesPerWindow = 8
Config.RequireDutyForPlayerPublish = true
Config.AdminAce = 'dpn.emergency.admin'
Config.SupervisorAce = 'dpn.emergency.supervisor'

Config.AllowedJobs = {
    police='law', sheriff='law', state='law', trooper='law', ranger='law', corrections='corrections',
    ambulance='medical', ems='medical', doctor='medical', fire='fire', firefighter='fire',
    dispatch='dispatch', judge='justice', doj='justice', justice='justice', attorney='justice',
    mib='mib', admin='mib'
}

Config.SupervisorGrades = {
    police=4, sheriff=4, state=4, trooper=4, ranger=4, corrections=4,
    ambulance=4, ems=4, fire=4, firefighter=4, dispatch=2, judge=0, doj=3, justice=2, mib=0
}

-- Logical systems may have multiple historical/current resource names. The first started alias wins.
Config.Systems = {
    emergency_network={ label='Unified Emergency Network', category='core', critical=true, aliases={'dpn-unified-emergency-network','dpn-emergency-service-network','dpn-emergency-network'} },
    law_core={ label='Law Enforcement Core', category='law', critical=true, aliases={'dpn-le-core'} },
    law_operations={ label='Law Enforcement Operations', category='law', critical=true, aliases={'dpn-le-operations'} },
    dispatch={ label='Digital Dispatch', category='dispatch', critical=true, aliases={'dpn-digital-dispatch','dpn-dispatch-system','dpn-dispatch'} },
    mdt={ label='DPN MDT', category='records', critical=true, aliases={'dpn-mdt'} },
    medical={ label='Medical System', category='medical', critical=false, aliases={'dpn-medical-system','dpn-medical'} },
    fire={ label='Fire System', category='fire', critical=false, aliases={'dpn-fire-system','dpn-fire'} },
    corrections={ label='Corrections System', category='corrections', critical=false, aliases={'dpn-corrections-system','dpn-corrections'} },
    justice={ label='Justice System', category='justice', critical=false, aliases={'dpn-justice-system','dpn-justice'} },
    mib={ label='MIB Administration', category='administration', critical=false, aliases={'dpn-mib-system'} },
    evidence={ label='Evidence AI', category='records', critical=false, aliases={'dpn-evidence-ai'} },
    incident_command={ label='Incident Command', category='command', critical=false, aliases={'dpn-incident-command'} },
    officer_safety={ label='Officer Safety', category='law', critical=false, aliases={'dpn-officer-safety'} },
    intelligence={ label='Crime Intelligence', category='law', critical=false, aliases={'dpn-crime-intelligence'} },
    smart_city={ label='Smart City', category='infrastructure', critical=false, aliases={'dpn-smart-city'} },
    drone={ label='Drone Command', category='aviation', critical=false, aliases={'dpn-drone-command'} },
    training={ label='Training Academy', category='training', critical=false, aliases={'dpn-training-academy'} },
    vehicle_computer={ label='Vehicle Computer', category='law', critical=false, aliases={'dpn-vehicle-computer'} },
    starchase={ label='StarChase', category='law', critical=false, aliases={'dpn-starchase'} },
    bodycam={ label='Bodycam / Dashcam', category='evidence', critical=false, aliases={'dpn-bodycam','dpn-bodycam-system','dpn-dash-bodycam'} },
    police_doorbell={ label='Police Reception Doorbell', category='public', critical=false, aliases={'dpn-police-doorbell'} },
    traffic={ label='Real Traffic', category='infrastructure', critical=false, aliases={'dpn-real-traffic'} },
    mechanic={ label='Advanced Mechanic', category='support', critical=false, aliases={'dpn-advancedmechanic','dpn-advanced-mechanic','dpn-mechanic-system'} },
    queue={ label='Server Queue', category='infrastructure', critical=false, aliases={'dpn-queue'} },
    portal={ label='PG-7X Portal System', category='administration', critical=false, aliases={'dpn-pg-7x'} },
    neuralizer={ label='Neuralizer', category='administration', critical=false, aliases={'dpn-neuralizer'} },
    pa={ label='Emergency PA System', category='communications', critical=false, aliases={'dpn-pa-system','dpn-pasystem'} },
    doors={ label='Door Access', category='infrastructure', critical=false, aliases={'dpn-doors','doors_creator'} },
    housing={ label='Housing', category='civilian', critical=false, aliases={'dpn-housing','housing'} },
    mechanic_fleet={ label='Fleet Maintenance', category='support', critical=false, aliases={'jim-mechanic','qb-mechanicjob'} }
}

Config.Routes = {
    officer_panic={ severity=1, dispatch=true, incident=true, evidence=true, departments={'law','dispatch','medical'}, code='10-99', title='Officer Emergency' },
    officer_down={ severity=1, dispatch=true, incident=true, evidence=true, departments={'law','dispatch','medical','fire'}, code='10-13', title='Officer Down' },
    shots_fired={ severity=1, dispatch=true, incident=false, evidence=true, departments={'law','dispatch'}, code='10-71', title='Shots Fired' },
    patient_critical={ severity=1, dispatch=true, incident=true, evidence=true, departments={'medical','fire','law','dispatch'}, code='MED-1', title='Critical Patient' },
    hospital_security={ severity=1, dispatch=true, incident=true, evidence=true, departments={'medical','law','dispatch'}, code='MED-SEC', title='Hospital Security Emergency' },
    mass_casualty={ severity=1, dispatch=true, incident=true, evidence=true, departments={'medical','fire','law','dispatch'}, code='MCI', title='Mass-Casualty Incident' },
    fire_incident={ severity=2, dispatch=true, incident=true, evidence=false, departments={'fire','medical','law','dispatch'}, code='FIRE', title='Structure / Wildland Fire' },
    hazmat={ severity=1, dispatch=true, incident=true, evidence=true, departments={'fire','medical','law','dispatch'}, code='HAZMAT', title='Hazardous Materials Incident' },
    rescue={ severity=2, dispatch=true, incident=true, evidence=false, departments={'fire','medical','law','dispatch'}, code='RESCUE', title='Technical Rescue' },
    corrections_escape={ severity=1, dispatch=true, incident=true, evidence=true, intelligence=true, departments={'corrections','law','dispatch'}, code='ESCAPE', title='Inmate Escape' },
    corrections_transport={ severity=3, dispatch=true, incident=false, evidence=false, departments={'corrections','law','dispatch'}, code='TRANSPORT', title='Prisoner Transport Request' },
    facility_lockdown={ severity=1, dispatch=true, incident=true, evidence=true, departments={'corrections','law','fire','medical','dispatch'}, code='LOCKDOWN', title='Facility Lockdown' },
    warrant_approved={ severity=3, dispatch=false, incident=false, evidence=true, intelligence=true, departments={'law','justice'}, code='WARRANT', title='Warrant Approved' },
    court_order={ severity=3, dispatch=false, incident=false, evidence=true, intelligence=false, departments={'justice','law','corrections'}, code='COURT', title='Court Order Issued' },
    bolo={ severity=2, dispatch=true, incident=false, evidence=true, intelligence=true, departments={'law','dispatch'}, code='BOLO', title='Be On the Lookout' },
    pursuit={ severity=1, dispatch=true, incident=true, evidence=true, intelligence=true, departments={'law','dispatch','medical'}, code='PURSUIT', title='Vehicle Pursuit' },
    starchase_deployed={ severity=2, dispatch=true, incident=false, evidence=true, intelligence=true, departments={'law','dispatch'}, code='TRACKER', title='StarChase Tracker Deployed' },
    starchase_lost={ severity=1, dispatch=true, incident=false, evidence=true, intelligence=true, departments={'law','dispatch'}, code='TRACKER-LOST', title='StarChase Signal Lost' },
    bodycam_uploaded={ severity=4, dispatch=false, incident=false, evidence=true, departments={'law'}, code='BODYCAM', title='Bodycam Evidence Uploaded' },
    reception_request={ severity=4, dispatch=true, incident=false, evidence=false, departments={'law','dispatch'}, code='RECEPTION', title='Police Reception Request' },
    traffic_collision={ severity=2, dispatch=true, incident=true, evidence=false, departments={'law','medical','fire','dispatch'}, code='MVC', title='Serious Traffic Collision' },
    road_hazard={ severity=3, dispatch=true, incident=false, evidence=false, departments={'law','fire','dispatch'}, code='HAZARD', title='Roadway Hazard' },
    emergency_vehicle_oos={ severity=4, dispatch=false, incident=false, evidence=true, departments={'law','fire','medical'}, code='FLEET', title='Emergency Vehicle Out of Service' },
    infrastructure_failure={ severity=2, dispatch=true, incident=true, evidence=false, departments={'law','fire','medical','dispatch'}, code='INFRA', title='Infrastructure Failure' },
    admin_intervention={ severity=2, dispatch=false, incident=false, evidence=true, departments={'mib'}, code='ADMIN', title='Administrative Intervention' },
    generic={ severity=3, dispatch=false, incident=false, evidence=true, departments={'law','dispatch'}, code='DPN', title='DPN Network Event' }
}

Config.SystemEventAliases = {
    ['dpn-medical-system:server:publishNetworkEvent']='medical',
    ['dpn-fire-system:server:publishNetworkEvent']='fire',
    ['dpn-corrections-system:server:publishNetworkEvent']='corrections',
    ['dpn-justice-system:server:publishNetworkEvent']='justice',
    ['dpn-mdt:server:publishNetworkEvent']='mdt',
    ['dpn-mib-system:server:publishNetworkEvent']='mib',
    ['dpn-starchase:server:publishNetworkEvent']='starchase',
    ['dpn-bodycam:server:publishNetworkEvent']='bodycam',
    ['dpn-police-doorbell:server:publishNetworkEvent']='police_doorbell',
    ['dpn-real-traffic:server:publishNetworkEvent']='traffic',
    ['dpn-advancedmechanic:server:publishNetworkEvent']='mechanic',
    ['dpn-queue:server:publishNetworkEvent']='queue',
    ['dpn-unified-emergency-network:server:publishNetworkEvent']='emergency_network'
}
