Config = {}

Config.Framework = 'qbcore' -- QBCore-only release
Config.Debug = false

Config.Command = 'smartcity'
Config.OpenKey = 'F3'
Config.RequireJob = true
Config.RequireDuty = true
Config.AllowedJobs = {
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

Config.AcePermission = 'dpn.smartcity'
Config.AdminAcePermission = 'dpn.smartcity.admin'

Config.DispatchResource = 'dpn-digital-dispatch'
Config.CoreResource = 'dpn-le-core'
Config.VehicleComputerResource = 'dpn-vehicle-computer'
Config.IncidentCommandResource = 'dpn-incident-command'
Config.EvidenceResource = 'dpn-evidence-ai'

Config.Alerts = {
    gunshots = true,
    boloHits = true,
    speeding = true,
    recklessDriving = true,
    trafficCameraHits = true,
    panicZones = true
}

Config.ServerValidationTolerance = 15.0 -- meters added to configured sensor/camera range for network variance
Config.SensorScanIntervalMs = 2500
Config.CameraScanIntervalMs = 3500
Config.BoloScanIntervalMs = 3000
Config.BlipRefreshMs = 5000

Config.Gunshot = {
    Radius = 155.0,
    CooldownSeconds = 45,
    MinimumShots = 1,
    CreateEvidence = true,
    CreateDispatchCall = true
}

Config.SpeedCamera = {
    Enabled = true,
    Unit = 'mph',
    DefaultLimit = 55,
    AlertOverBy = 20,
    CooldownSeconds = 35,
    CreateDispatchCall = true
}

Config.Bolo = {
    ExactPlate = false,
    CooldownSeconds = 45,
    AutoBlipSeconds = 90,
    CreateDispatchCall = true
}

Config.TrafficControl = {
    Enabled = true,
    EmergencyLightOverride = true,
    EmergencyRadius = 80.0,
    SceneModeSeconds = 180
}

Config.MapBlips = {
    Cameras = true,
    Sensors = true,
    TrafficNodes = false
}

Config.Webhook = ''

Config.Cameras = {
    { id='cam_mrpd_1', name='MRPD Front Camera', type='traffic', coords=vector3(428.61, -984.45, 30.71), heading=90.0, range=85.0, speedLimit=35 },
    { id='cam_legion_1', name='Legion Square Camera', type='traffic', coords=vector3(215.76, -810.12, 30.73), heading=160.0, range=105.0, speedLimit=35 },
    { id='cam_sandy_1', name='Sandy Shores Main Camera', type='traffic', coords=vector3(1859.52, 3678.43, 33.68), heading=30.0, range=120.0, speedLimit=45 },
    { id='cam_paleto_1', name='Paleto Boulevard Camera', type='traffic', coords=vector3(-442.19, 6023.66, 31.49), heading=45.0, range=110.0, speedLimit=35 }
}

Config.GunshotZones = {
    { id='zone_legion', name='Legion Square Acoustic Grid', coords=vector3(205.6, -920.3, 30.7), radius=350.0 },
    { id='zone_mrpd', name='MRPD Downtown Acoustic Grid', coords=vector3(436.2, -982.1, 30.7), radius=420.0 },
    { id='zone_sandy', name='Sandy Shores Acoustic Grid', coords=vector3(1846.8, 3671.2, 33.8), radius=450.0 },
    { id='zone_paleto', name='Paleto Acoustic Grid', coords=vector3(-448.8, 6012.4, 31.7), radius=450.0 }
}

Config.TrafficNodes = {
    { id='node_legion', name='Legion Priority Light Node', coords=vector3(218.0, -805.0, 30.7), radius=95.0 },
    { id='node_mrpd', name='MRPD Priority Light Node', coords=vector3(420.0, -1000.0, 30.7), radius=95.0 },
    { id='node_sandy', name='Sandy Priority Light Node', coords=vector3(1850.0, 3680.0, 33.7), radius=110.0 }
}
