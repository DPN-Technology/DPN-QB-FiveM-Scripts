Config = {}

Config.Debug = false
Config.Framework = 'qb-core'

-- Density tuning. Lower values improve performance and reduce GTA's chaotic traffic.
Config.Density = {
    Enabled = true,
    Vehicle = 0.42,
    RandomVehicle = 0.30,
    ParkedVehicle = 0.22,
    Ped = 0.55,
    ScenarioPed = 0.50,
    VehicleBudget = 65,
    PedBudget = 55
}

-- General NPC driver realism tuning.
Config.Driver = {
    Enabled = true,
    ScanInterval = 1500,
    ScanRadius = 125.0,
    NormalCruiseSpeed = 18.0,
    CautiousCruiseSpeed = 13.0,
    Aggressiveness = 0.12,
    Ability = 0.75,
    DrivingStyle = 786603, -- careful / obey road laws / avoid vehicles
    AvoidPlayerBumpDistance = 10.0,
    AntiGridlockInterval = 3500,
    StuckSpeedThreshold = 1.0,
    StuckTime = 9000
}

-- Emergency vehicle yielding behavior.
Config.Emergency = {
    Enabled = true,

    -- Class 18 is GTA emergency vehicles. Keep this true unless you use custom non-class-18 emergency cars.
    RequireEmergencyVehicleClass = true,

    -- When true, police/ems/fire jobs are allowed. When false, any class-18 vehicle with lights/siren works.
    UseQBCoreJobCheck = false,
    AllowedJobs = {
        police = true,
        ambulance = true,
        fire = true,
        sheriff = true,
        state = true,
        leo = true
    },

    ScanInterval = 450,
    ScanRadius = 115.0,
    AheadDistance = 135.0,
    BehindDistance = 18.0,
    LaneWidth = 32.0,
    MinEmergencySpeed = 1.5,

    PullOverCooldown = 26000,
    PullOverHoldTime = 15000,
    PullOverSpeed = 7.5,
    PullOverStopRange = 3.5,
    ShoulderOffset = 8.0,
    ForwardOffset = 32.0,
    UseRoadNode = true,
    UseHazardsAfterPullOver = true,

    -- This keeps NPCs from repeatedly yielding to the same siren every frame.
    PerVehicleMemoryTime = 30000
}

-- ts_Trafficlights support.
Config.TrafficLights = {
    Enabled = true,
    ResourceName = 'ts_Trafficlights',

    -- Uses ts_Trafficlights exported SwitchLightStates for emergency priority when available.
    EmergencyPriorityGreen = true,
    PriorityScanInterval = 900,
    PriorityCooldown = 11000,
    PriorityDistance = 58.0,
    PriorityRadius = 34.0,
    PriorityDuration = 8000,

    -- Smooth AI when ts_Trafficlights sync events fire. This does not replace ts_Trafficlights; it assists it.
    AssistTSSyncAI = true,
    AssistRadiusFallback = 36.0,
    GreenHeadingTolerance = 38.0,
    RedBrakeTime = 1250,
    GreenDriveDistance = 34.0,
    GreenDriveSpeed = 13.5
}

-- Commands for admins/devs.
Config.Commands = {
    ToggleDebug = 'dpntrafficdebug',
    Status = 'dpntrafficstatus'
}

-- ACE permission used by commands:
-- add_ace group.admin dpnrealtraffic.admin allow
Config.AdminAce = 'dpnrealtraffic.admin'
