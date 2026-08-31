local QBCore = exports['qb-core']:GetCoreObject()

local PlayerData = {}
local State = {
    debug = Config.Debug,
    yielded = {},
    stuck = {},
    priority = {},
    tsWarned = false
}

local function now()
    return GetGameTimer()
end

local function log(message)
    if State.debug then
        print(('^3[dpn-real-traffic]^7 %s'):format(message))
    end
end

local function notify(message, nType)
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, nType or 'primary')
    else
        TriggerEvent('chat:addMessage', { args = { 'dpn-real-traffic', message } })
    end
end

local function loadPlayerData()
    local ok, data = pcall(function()
        return QBCore.Functions.GetPlayerData()
    end)

    if ok and data then
        PlayerData = data
    end
end

CreateThread(function()
    Wait(1000)
    loadPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    loadPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
end)

local function clampHeading(heading)
    heading = heading % 360.0
    if heading < 0.0 then heading = heading + 360.0 end
    return heading
end

local function headingDiff(a, b)
    local diff = math.abs(clampHeading(a) - clampHeading(b))
    if diff > 180.0 then diff = 360.0 - diff end
    return diff
end

local function headingInRange(target, heading, tolerance)
    return headingDiff(target, heading) <= tolerance
end

local function getHeadingVectors(heading)
    local rad = math.rad(heading)
    local forward = vector3(-math.sin(rad), math.cos(rad), 0.0)
    local right = vector3(math.cos(rad), math.sin(rad), 0.0)
    return forward, right
end

local function dot(a, b)
    return (a.x * b.x) + (a.y * b.y) + (a.z * b.z)
end

local function vec3From(value)
    if not value then return nil end
    return vector3(value.x or value[1] or 0.0, value.y or value[2] or 0.0, value.z or value[3] or 0.0)
end

local function isTSStarted()
    return Config.TrafficLights.Enabled and GetResourceState(Config.TrafficLights.ResourceName) == 'started'
end

local function requestControl(entity, timeout)
    if not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end

    NetworkRequestControlOfEntity(entity)
    local expire = now() + (timeout or 250)
    while not NetworkHasControlOfEntity(entity) and now() < expire do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end

    return NetworkHasControlOfEntity(entity)
end

local function isPlayerVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end

    local maxSeats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) or 2
    for seat = -1, maxSeats - 2 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then
            return true
        end
    end

    return false
end

local function isUsableAIVehicle(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if isPlayerVehicle(vehicle) then return false end
    if IsEntityDead(vehicle) then return false end
    if IsVehicleSeatFree(vehicle, -1) then return false end

    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver == 0 or IsPedAPlayer(driver) or IsEntityDead(driver) then return false end
    if GetVehicleClass(vehicle) == 13 or GetVehicleClass(vehicle) == 14 or GetVehicleClass(vehicle) == 15 or GetVehicleClass(vehicle) == 16 or GetVehicleClass(vehicle) == 21 then return false end

    return true, driver
end

local function playerJobAllowed()
    if not Config.Emergency.UseQBCoreJobCheck then return true end
    local jobName = PlayerData and PlayerData.job and PlayerData.job.name
    return jobName and Config.Emergency.AllowedJobs[jobName] == true
end

local function isEmergencyVehicleActive(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if Config.Emergency.RequireEmergencyVehicleClass and GetVehicleClass(vehicle) ~= 18 then return false end
    if not playerJobAllowed() then return false end

    -- IsVehicleSirenOn normally becomes true when emergency lights are enabled.
    -- IsVehicleSirenAudioOn catches vehicles with audible sirens enabled.
    if not IsVehicleSirenOn(vehicle) and not IsVehicleSirenAudioOn(vehicle) then
        return false
    end

    return true
end

local function getActiveEmergencyVehicles()
    local vehicles = {}

    for _, playerId in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(playerId)
        if ped ~= 0 and DoesEntityExist(ped) and IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(vehicle, -1) == ped and isEmergencyVehicleActive(vehicle) then
                local coords = GetEntityCoords(vehicle)
                local heading = GetEntityHeading(vehicle)
                local forward, right = getHeadingVectors(heading)
                vehicles[#vehicles + 1] = {
                    player = playerId,
                    vehicle = vehicle,
                    coords = coords,
                    heading = heading,
                    forward = forward,
                    right = right,
                    speed = GetEntitySpeed(vehicle)
                }
            end
        end
    end

    return vehicles
end

local function findPullOverTarget(vehicle, emergency)
    local coords = GetEntityCoords(vehicle)
    local vehHeading = GetEntityHeading(vehicle)
    local vehForward, vehRight = getHeadingVectors(vehHeading)

    -- Prefer the vehicle's own right side so NPCs don't cut across lanes.
    local rough = coords + (vehRight * Config.Emergency.ShoulderOffset) + (vehForward * Config.Emergency.ForwardOffset)

    if Config.Emergency.UseRoadNode then
        local ok, found, nodeCoords, nodeHeading = pcall(function()
            return GetClosestVehicleNodeWithHeading(rough.x, rough.y, rough.z, 1, 3.0, 0)
        end)

        if ok and found and nodeCoords then
            return nodeCoords, nodeHeading or vehHeading
        end
    end

    return rough, vehHeading
end

local function setRightIndicator(vehicle, enabled)
    -- GTA uses indexed blinkers. Right/left can vary by wrapper, so this keeps right signal plus safe fallback blink.
    SetVehicleIndicatorLights(vehicle, 0, enabled)
end

local function setHazards(vehicle, enabled)
    SetVehicleIndicatorLights(vehicle, 0, enabled)
    SetVehicleIndicatorLights(vehicle, 1, enabled)
end

local function resumeAIDriving(vehicle, driver)
    if not DoesEntityExist(vehicle) or not DoesEntityExist(driver) then return end
    if isPlayerVehicle(vehicle) then return end

    requestControl(vehicle, 200)
    setHazards(vehicle, false)
    SetVehicleBrakeLights(vehicle, false)
    SetDriverAggressiveness(driver, Config.Driver.Aggressiveness)
    SetDriverAbility(driver, Config.Driver.Ability)
    SetDriveTaskDrivingStyle(driver, Config.Driver.DrivingStyle)
    TaskVehicleDriveWander(driver, vehicle, Config.Driver.NormalCruiseSpeed, Config.Driver.DrivingStyle)
end

local function pullOverVehicle(vehicle, driver, emergency)
    if State.yielded[vehicle] and State.yielded[vehicle] > now() then return end
    if not requestControl(vehicle, 350) then return end

    local targetCoords, targetHeading = findPullOverTarget(vehicle, emergency)
    State.yielded[vehicle] = now() + Config.Emergency.PerVehicleMemoryTime

    SetDriverAggressiveness(driver, 0.0)
    SetDriverAbility(driver, 0.85)
    SetDriveTaskDrivingStyle(driver, Config.Driver.DrivingStyle)
    SetVehicleBrakeLights(vehicle, false)
    setRightIndicator(vehicle, true)

    TaskVehicleDriveToCoordLongrange(
        driver,
        vehicle,
        targetCoords.x,
        targetCoords.y,
        targetCoords.z,
        Config.Emergency.PullOverSpeed,
        Config.Driver.DrivingStyle,
        Config.Emergency.PullOverStopRange
    )

    SetTimeout(3500, function()
        if not DoesEntityExist(vehicle) then return end
        setRightIndicator(vehicle, false)
        if Config.Emergency.UseHazardsAfterPullOver then
            setHazards(vehicle, true)
        end
        SetVehicleBrakeLights(vehicle, true)
    end)

    SetTimeout(Config.Emergency.PullOverHoldTime, function()
        if DoesEntityExist(vehicle) and DoesEntityExist(driver) then
            resumeAIDriving(vehicle, driver)
        end
    end)

    log(('NPC yielding to emergency vehicle at %.1f %.1f %.1f'):format(targetCoords.x, targetCoords.y, targetCoords.z))
end

local function shouldYieldToEmergency(aiVehicle, emergency)
    local aiCoords = GetEntityCoords(aiVehicle)
    local rel = aiCoords - emergency.coords
    local ahead = dot(rel, emergency.forward)
    local side = math.abs(dot(rel, emergency.right))

    if #(aiCoords - emergency.coords) > Config.Emergency.ScanRadius then return false end
    if side > Config.Emergency.LaneWidth then return false end
    if ahead < -Config.Emergency.BehindDistance or ahead > Config.Emergency.AheadDistance then return false end

    -- Ignore vehicles moving in the opposite direction unless they are very close to the emergency vehicle.
    local aiHeading = GetEntityHeading(aiVehicle)
    local sameFlow = headingInRange(emergency.heading, aiHeading, 80.0)
    if not sameFlow and ahead > 28.0 then return false end

    return true
end

local function tuneAIDriver(vehicle, driver)
    if not requestControl(vehicle, 70) then return end
    SetDriverAggressiveness(driver, Config.Driver.Aggressiveness)
    SetDriverAbility(driver, Config.Driver.Ability)
    SetDriveTaskDrivingStyle(driver, Config.Driver.DrivingStyle)
end

local function gentlyUnstick(vehicle, driver)
    if State.yielded[vehicle] and State.yielded[vehicle] > now() then return end
    if not requestControl(vehicle, 120) then return end

    local coords = GetEntityCoords(vehicle)
    local heading = GetEntityHeading(vehicle)
    local forward = getHeadingVectors(heading)
    local target = coords + (forward * 18.0)

    TaskVehicleDriveToCoordLongrange(driver, vehicle, target.x, target.y, target.z, Config.Driver.CautiousCruiseSpeed, Config.Driver.DrivingStyle, 6.0)
    log('Applied gentle anti-gridlock drive task.')
end

local function cleanupMemory()
    local t = now()
    for veh, expires in pairs(State.yielded) do
        if expires < t or not DoesEntityExist(veh) then
            State.yielded[veh] = nil
        end
    end
    for veh, data in pairs(State.stuck) do
        if not DoesEntityExist(veh) or (data.expires and data.expires < t) then
            State.stuck[veh] = nil
        end
    end
    for veh, expires in pairs(State.priority) do
        if expires < t or not DoesEntityExist(veh) then
            State.priority[veh] = nil
        end
    end
end

local function assistTrafficlightAI(intersectionCenter, radius, heading, duration)
    if not Config.TrafficLights.AssistTSSyncAI then return end

    local center = vec3From(intersectionCenter)
    if not center then return end

    radius = radius or Config.TrafficLights.AssistRadiusFallback
    duration = duration or Config.TrafficLights.PriorityDuration

    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        local ok, driver = isUsableAIVehicle(vehicle)
        if ok then
            local coords = GetEntityCoords(vehicle)
            if #(coords - center) <= radius then
                requestControl(vehicle, 100)
                local aiHeading = GetEntityHeading(vehicle)
                local shouldDrive = headingInRange(heading, aiHeading, Config.TrafficLights.GreenHeadingTolerance)
                    or headingInRange(heading + 180.0, aiHeading, Config.TrafficLights.GreenHeadingTolerance)

                if shouldDrive then
                    local forward = getHeadingVectors(aiHeading)
                    local target = coords + (forward * Config.TrafficLights.GreenDriveDistance)
                    SetVehicleBrakeLights(vehicle, false)
                    TaskVehicleDriveToCoordLongrange(driver, vehicle, target.x, target.y, target.z, Config.TrafficLights.GreenDriveSpeed, Config.Driver.DrivingStyle, 5.0)
                else
                    SetVehicleBrakeLights(vehicle, true)
                    TaskVehicleTempAction(driver, vehicle, 1, Config.TrafficLights.RedBrakeTime)
                    SetTimeout(math.min(duration, 7000), function()
                        if DoesEntityExist(vehicle) then
                            SetVehicleBrakeLights(vehicle, false)
                        end
                    end)
                end
            end
        end
    end
end

local function requestTrafficlightPriority(emergency)
    if not Config.TrafficLights.Enabled or not Config.TrafficLights.EmergencyPriorityGreen then return end
    if not isTSStarted() then
        if not State.tsWarned then
            State.tsWarned = true
            log(('ts_Trafficlights not started. Priority light control disabled. Resource state: %s'):format(GetResourceState(Config.TrafficLights.ResourceName)))
        end
        return
    end

    if emergency.speed < Config.Emergency.MinEmergencySpeed then return end
    if State.priority[emergency.vehicle] and State.priority[emergency.vehicle] > now() then return end

    local center = emergency.coords + (emergency.forward * Config.TrafficLights.PriorityDistance)
    local center4 = vector4(center.x, center.y, center.z, emergency.heading)

    local ok, err = pcall(function()
        exports[Config.TrafficLights.ResourceName]:SwitchLightStates(
            center4,
            Config.TrafficLights.PriorityRadius,
            emergency.heading,
            Config.TrafficLights.PriorityDuration
        )
    end)

    if ok then
        State.priority[emergency.vehicle] = now() + Config.TrafficLights.PriorityCooldown
        log('Requested ts_Trafficlights emergency priority green.')
    else
        log(('ts_Trafficlights priority call failed: %s'):format(err or 'unknown error'))
        State.priority[emergency.vehicle] = now() + Config.TrafficLights.PriorityCooldown
    end
end

-- ts_Trafficlights API sync event support.
RegisterNetEvent('Trusted:Trafficlight:API:SyncAI', function(intersectionCenter, radius, heading, duration)
    assistTrafficlightAI(intersectionCenter, radius, heading, duration)
end)

-- Older/current public ts_Trafficlights event support.
RegisterNetEvent('Trusted:Trafficlights:HandleAI', function(coords, heading, otherLights, targetLight, intersectionCenter)
    assistTrafficlightAI(intersectionCenter or coords, Config.TrafficLights.AssistRadiusFallback, heading, Config.TrafficLights.PriorityDuration)
end)

RegisterNetEvent('dpn-real-traffic:client:toggleDebug', function()
    State.debug = not State.debug
    notify(('DPN real traffic debug: %s'):format(State.debug and 'ON' or 'OFF'), 'primary')
end)

RegisterNetEvent('dpn-real-traffic:client:requestStatus', function()
    TriggerServerEvent('dpn-real-traffic:server:requestStatus')
end)

RegisterNetEvent('dpn-real-traffic:client:status', function(data)
    notify(('DPN Traffic | Emergency: %s | Density: %s | TS: %s (%s)'):format(
        tostring(data.emergency),
        tostring(data.density),
        data.tsResource or 'none',
        data.tsState or 'unknown'
    ), 'primary')
end)

-- Density loop: must be applied every frame by GTA/FiveM.
CreateThread(function()
    while true do
        if Config.Density.Enabled then
            SetVehicleDensityMultiplierThisFrame(Config.Density.Vehicle)
            SetRandomVehicleDensityMultiplierThisFrame(Config.Density.RandomVehicle)
            SetParkedVehicleDensityMultiplierThisFrame(Config.Density.ParkedVehicle)
            SetPedDensityMultiplierThisFrame(Config.Density.Ped)
            SetScenarioPedDensityMultiplierThisFrame(Config.Density.ScenarioPed, Config.Density.ScenarioPed)
            SetVehiclePopulationBudget(Config.Density.VehicleBudget)
            SetPedPopulationBudget(Config.Density.PedBudget)
        end
        Wait(0)
    end
end)

-- General NPC tuning / anti-gridlock.
CreateThread(function()
    while true do
        if Config.Driver.Enabled then
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local vehicles = GetGamePool('CVehicle')

            for _, vehicle in ipairs(vehicles) do
                local ok, driver = isUsableAIVehicle(vehicle)
                if ok and #(GetEntityCoords(vehicle) - playerCoords) <= Config.Driver.ScanRadius then
                    tuneAIDriver(vehicle, driver)

                    local speed = GetEntitySpeed(vehicle)
                    if speed <= Config.Driver.StuckSpeedThreshold and not IsVehicleStoppedAtTrafficLights(vehicle) then
                        local data = State.stuck[vehicle]
                        if not data then
                            State.stuck[vehicle] = { since = now(), expires = now() + 18000 }
                        elseif now() - data.since >= Config.Driver.StuckTime then
                            gentlyUnstick(vehicle, driver)
                            State.stuck[vehicle] = { since = now(), expires = now() + 18000 }
                        end
                    else
                        State.stuck[vehicle] = nil
                    end
                end
            end
        end

        cleanupMemory()
        Wait(Config.Driver.ScanInterval)
    end
end)

-- Emergency yielding loop.
CreateThread(function()
    while true do
        if Config.Emergency.Enabled then
            local emergencies = getActiveEmergencyVehicles()
            if #emergencies > 0 then
                local vehicles = GetGamePool('CVehicle')
                for _, emergency in ipairs(emergencies) do
                    requestTrafficlightPriority(emergency)

                    for _, vehicle in ipairs(vehicles) do
                        local ok, driver = isUsableAIVehicle(vehicle)
                        if ok and shouldYieldToEmergency(vehicle, emergency) then
                            pullOverVehicle(vehicle, driver, emergency)
                        end
                    end
                end
            end
        end

        Wait(Config.Emergency.ScanInterval)
    end
end)
