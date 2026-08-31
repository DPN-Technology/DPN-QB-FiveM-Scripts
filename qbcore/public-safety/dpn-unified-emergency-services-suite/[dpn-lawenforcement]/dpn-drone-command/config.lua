Config = {}

Config.Framework = 'qb' -- QBCore-only release
Config.Debug = false

Config.Command = 'drone'
Config.AdminCommand = 'dronectl'
Config.OpenKey = 'F4'

Config.AllowedJobs = {
    police = true,
    sheriff = true,
    state = true,
    trooper = true,
    ranger = true,
    corrections = true,
    ambulance = true,
    ems = true,
    fire = true
}

Config.RequireOnDuty = true

Config.ServerUpdateMinimumMs = 1000
Config.ServerMaximumSpeedMetersPerSecond = 75.0
Config.ServerRangeTolerance = 40.0
Config.ServerAltitudeTolerance = 15.0
Config.RequireVehicleDeploy = false
Config.AllowedDeployVehicles = {
    police = true,
    police2 = true,
    police3 = true,
    sheriff = true,
    fbi = true,
    riot = true
}

Config.Drone = {
    Model = 'ch_prop_casino_drone_02a',
    SpawnDistance = 2.5,
    MaxRange = 550.0,
    MaxAltitude = 130.0,
    MinAltitude = 1.5,
    Speed = 0.85,
    SprintSpeed = 1.65,
    TurnSpeed = 2.5,
    BatteryMinutes = 12,
    LowBatteryPercent = 20,
    CriticalBatteryPercent = 8,
    AutoReturnOnLowBattery = true,
    AutoDeleteDistance = 850.0,
    Invincible = true,
    Collision = true
}

Config.Camera = {
    Fov = 55.0,
    MinFov = 18.0,
    MaxFov = 80.0,
    ZoomSpeed = 2.5,
    NightVision = true,
    ThermalVision = true,
    Spotlight = true,
    ScanRadius = 70.0,
    LockRange = 180.0
}

Config.Controls = {
    Forward = 32, Back = 33, Left = 34, Right = 35,
    Up = 44, Down = 38, Sprint = 21,
    Exit = 177, ToggleUI = 168, Scan = 47,
    NightVision = 74, Thermal = 47, Spotlight = 73,
    ReturnHome = 246, LockTarget = 24
}

Config.DispatchIntegration = true
Config.VehicleComputerIntegration = true
Config.IncidentCommandIntegration = true
Config.EvidenceIntegration = true

Config.Webhook = ''
Config.LogEvents = true

Config.Blips = {
    Drone = { sprite = 627, color = 3, scale = 0.75, name = 'Police Drone' },
    Target = { sprite = 225, color = 1, scale = 0.9, name = 'Drone Target' }
}
