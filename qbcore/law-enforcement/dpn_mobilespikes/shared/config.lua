Config = {}

-- QBCore Settings
Config.UseTarget = GetConvar('UseTarget', 'false') == 'true' -- Use qb-target for interactions

-- Authorized vehicle models that can use the spike system
Config.AuthorizedVehicles = {
    [`police`] = true,
    [`police2`] = true,
    [`police3`] = true,
    [`police4`] = true,
    [`policeb`] = true,
    [`policet`] = true,
    [`sheriff`] = true,
    [`sheriff2`] = true,
    [`fbi`] = true,
    [`fbi2`] = true,
    [`riot`] = true,
    [`pbus`] = true,
    [`pranger`] = true,
    [`predator`] = true
}

-- Job restrictions
Config.AuthorizedJobs = {
    ['police'] = {grades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}},
    ['bcso'] = {grades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}},
    ['sahp'] = {grades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}},
    ['fbi'] = {grades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}},
}

-- Controls
Config.Controls = {
    deploy = {
        key = 38, -- E key
        label = 'E'
    },
    toggle = {
        key = 74, -- H key  
        label = 'H'
    }
}

-- Spike strip settings
Config.SpikeSettings = {
    model = `p_ld_stinger_s`, -- Spike strip prop model
    offset = vector3(0.0, -4.5, -0.8), -- Offset from vehicle rear
    rotation = vector3(0.0, 0.0, 0.0), -- Rotation offset
    attachBone = 'boot', -- Vehicle bone to attach to
    maxDistance = 100.0, -- Max distance from vehicle to maintain spikes
}

-- Damage settings
Config.DamageSettings = {
    tireDamageChance = 95, -- Percentage chance to pop tire
    engineDamageChance = 30, -- Percentage chance for engine damage
    maxDamageSpeed = 80.0, -- Maximum speed to take damage (km/h)
    minDamageSpeed = 10.0, -- Minimum speed to take damage (km/h)
    damageRadius = 3.5, -- Radius around spike strip
    damageAmount = {
        engine = 150.0, -- Engine damage amount
        body = 100.0 -- Body damage amount
    },
    immuneVehicles = { -- Vehicles immune to spike damage
        [`riot`] = true,
        [`insurgent`] = true,
        [`insurgent2`] = true,
        [`technical`] = true,
        [`halftrack`] = true
    }
}

-- Visual settings
Config.Visual = {
    drawMarker = true,
    marker = {
        type = 1,
        size = vector3(6.0, 2.0, 0.5),
        color = {r = 255, g = 50, b = 50, a = 120},
        rotation = vector3(0.0, 0.0, 0.0),
        bobUpAndDown = false,
        faceCamera = false,
        rotate = false
    },
    drawText3D = true,
    text3DDistance = 10.0,
    blip = {
        sprite = 161,
        color = 1,
        scale = 0.8,
        label = 'Spike Strip'
    }
}

-- Animation settings
Config.Animation = {
    deploy = {
        dict = 'amb@world_human_welding@male@base',
        anim = 'base',
        flags = 16,
        duration = 3000
    },
    retract = {
        dict = 'amb@world_human_welding@male@base', 
        anim = 'base',
        flags = 16,
        duration = 2000
    }
}

-- Sound settings
Config.Sounds = {
    deploy = {
        name = 'CHECKPOINT_PERFECT',
        set = 'HUD_MINI_GAME_SOUNDSET'
    },
    retract = {
        name = 'CHECKPOINT_MISSED',
        set = 'HUD_MINI_GAME_SOUNDSET'
    },
    damage = {
        name = 'CARS_PLANES_LARGE_CAR_CRASH_METAL',
        set = 'GTAO_FM_EVENTS_SOUNDSET'
    }
}

-- Notification messages
Config.Notifications = {
    deployed = 'Spike strips deployed successfully!',
    retracted = 'Spike strips retracted successfully!',
    alreadyDeployed = 'Spike strips are already deployed on this vehicle!',
    notDeployed = 'No spike strips are currently deployed!',
    notAuthorized = 'You are not authorized to use the spike system!',
    noVehicle = 'You must be in an authorized vehicle!',
    wrongSeat = 'You must be in the driver seat to deploy spikes!',
    vehicleMoving = 'Vehicle must be stationary to deploy spikes!',
    tooClose = 'Another spike strip is too close to this location!',
    maxReached = 'Maximum number of spike strips reached!',
    cooldown = 'You must wait before deploying another spike strip!',
    damaged = 'Your vehicle has been damaged by spike strips!'
}

-- System limits
Config.Limits = {
    maxSpikesPerPlayer = 2,
    maxSpikesGlobal = 20,
    deploymentCooldown = 5000, -- 5 seconds
    minDistanceBetweenSpikes = 15.0, -- Meters
    autoRetractTime = 1800000, -- 30 minutes in ms
}