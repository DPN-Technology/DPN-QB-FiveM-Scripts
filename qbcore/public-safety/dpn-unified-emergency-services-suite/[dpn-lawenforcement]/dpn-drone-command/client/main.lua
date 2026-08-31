local drone, droneCam, controlling, battery, homeCoords, droneData = nil, nil, false, 100, nil, nil
local night, thermal, spotlight, lockedTarget = false, false, false, nil
local synced = {}

local function notify(msg, typ) DPNDrone.Notify(msg, typ) end
local function ped() return PlayerPedId() end
local function vecToTable(v) return { x = v.x, y = v.y, z = v.z } end

local function isAllowedVehicle()
    if not Config.RequireVehicleDeploy then return true end
    local veh = GetVehiclePedIsIn(ped(), false)
    if veh == 0 then return false end
    local model = GetEntityModel(veh)
    local name = string.lower(GetDisplayNameFromVehicleModel(model))
    return Config.AllowedDeployVehicles[name] == true
end

local function setNui(show)
    SetNuiFocus(show, show)
    SendNUIMessage({ type = show and 'open' or 'close', battery = battery, controlling = controlling, data = droneData })
end

local function destroyDrone(reason)
    if droneCam then RenderScriptCams(false, false, 0, true, true); DestroyCam(droneCam); droneCam = nil end
    SetNightvision(false); SetSeethrough(false)
    if drone and DoesEntityExist(drone) then DeleteEntity(drone) end
    drone, controlling, droneData, lockedTarget = nil, false, nil, nil
    TriggerServerEvent('dpn-drone:server:recall', reason or 'manual')
    setNui(false)
end

local function deployDrone(data)
    droneData = data
    battery = 100
    homeCoords = GetEntityCoords(ped())
    local model = joaat(Config.Drone.Model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    local spawn = GetOffsetFromEntityInWorldCoords(ped(), 0.0, Config.Drone.SpawnDistance, 1.0)
    drone = CreateObject(model, spawn.x, spawn.y, spawn.z, true, true, false)
    SetEntityHeading(drone, GetEntityHeading(ped()))
    SetEntityInvincible(drone, Config.Drone.Invincible)
    SetEntityCollision(drone, Config.Drone.Collision, Config.Drone.Collision)
    FreezeEntityPosition(drone, true)
    droneCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    AttachCamToEntity(droneCam, drone, 0.0, 0.0, 0.25, true)
    SetCamFov(droneCam, Config.Camera.Fov)
    RenderScriptCams(true, false, 0, true, true)
    controlling = true
    setNui(true)
    notify('Drone deployed. Use WASD/Q/E, Shift boost, Backspace recall.', 'success')
end

local function findTarget()
    if not drone or not DoesEntityExist(drone) then return nil end
    local pos = GetEntityCoords(drone)
    local best, bestDist = nil, Config.Camera.LockRange
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local dist = #(GetEntityCoords(veh) - pos)
        if dist < bestDist and HasEntityClearLosToEntity(drone, veh, 17) then best, bestDist = veh, dist end
    end
    return best, bestDist
end

local function scanArea()
    if not drone then return end
    local pos = GetEntityCoords(drone)
    local vehicles, peds = 0, 0
    for _, veh in ipairs(GetGamePool('CVehicle')) do if #(GetEntityCoords(veh) - pos) < Config.Camera.ScanRadius then vehicles = vehicles + 1 end end
    for _, p in ipairs(GetGamePool('CPed')) do if not IsPedAPlayer(p) and #(GetEntityCoords(p) - pos) < Config.Camera.ScanRadius then peds = peds + 1 end end
    TriggerServerEvent('dpn-drone:server:createAlert', {
        title = 'Drone Area Scan', code = 'DRN-SCAN', priority = 3,
        coords = vecToTable(pos), description = ('Scan found %s vehicles and %s pedestrians nearby.'):format(vehicles, peds)
    })
    SendNUIMessage({ type = 'scan', vehicles = vehicles, peds = peds })
end

RegisterCommand(Config.Command, function()
    if controlling then destroyDrone('manual') return end
    if not isAllowedVehicle() then notify('Drone must be deployed from an approved emergency vehicle.', 'error') return end
    local c = GetEntityCoords(ped())
    TriggerServerEvent('dpn-drone:server:requestDeploy', vecToTable(c))
end)

RegisterKeyMapping(Config.Command, 'DPN Drone Command', 'keyboard', Config.OpenKey)

RegisterNetEvent('dpn-drone:client:deployApproved', deployDrone)
RegisterNetEvent('dpn-drone:client:deployDenied', function(msg) notify(msg, 'error') end)
RegisterNetEvent('dpn-drone:client:alert', function(alert) notify((alert.title or 'Drone alert') .. ' received.', 'primary') end)
RegisterNetEvent('dpn-drone:client:syncDrone', function(owner, data) synced[owner] = data end)
RegisterNetEvent('dpn-drone:client:removeDrone', function(owner) synced[owner] = nil end)

CreateThread(function()
    while true do
        Wait(controlling and 0 or 500)
        if controlling and drone and DoesEntityExist(drone) then
            local pos = GetEntityCoords(drone)
            local heading = GetEntityHeading(drone)
            local speed = IsControlPressed(0, Config.Controls.Sprint) and Config.Drone.SprintSpeed or Config.Drone.Speed
            local forward = GetEntityForwardVector(drone)
            local right = vector3(forward.y, -forward.x, 0.0)
            local next = pos
            if IsControlPressed(0, Config.Controls.Forward) then next = next + forward * speed end
            if IsControlPressed(0, Config.Controls.Back) then next = next - forward * speed end
            if IsControlPressed(0, Config.Controls.Left) then next = next + right * speed end
            if IsControlPressed(0, Config.Controls.Right) then next = next - right * speed end
            if IsControlPressed(0, Config.Controls.Up) then next = next + vector3(0,0,speed*0.7) end
            if IsControlPressed(0, Config.Controls.Down) then next = next - vector3(0,0,speed*0.7) end
            if IsDisabledControlPressed(0, 14) then SetCamFov(droneCam, math.min(Config.Camera.MaxFov, GetCamFov(droneCam) + Config.Camera.ZoomSpeed)) end
            if IsDisabledControlPressed(0, 15) then SetCamFov(droneCam, math.max(Config.Camera.MinFov, GetCamFov(droneCam) - Config.Camera.ZoomSpeed)) end
            if IsControlPressed(0, Config.Controls.Left) then heading = heading + Config.Drone.TurnSpeed end
            if IsControlPressed(0, Config.Controls.Right) then heading = heading - Config.Drone.TurnSpeed end
            if homeCoords and #(next - homeCoords) <= Config.Drone.MaxRange and next.z <= homeCoords.z + Config.Drone.MaxAltitude and next.z >= homeCoords.z + Config.Drone.MinAltitude then
                SetEntityCoordsNoOffset(drone, next.x, next.y, next.z, true, true, true)
            end
            SetEntityHeading(drone, heading)
            if spotlight then DrawSpotLight(pos.x, pos.y, pos.z, forward.x, forward.y, -0.35, 255,255,255, 90.0, 10.0, 0.0, 20.0, 1.0) end
            if IsControlJustPressed(0, Config.Controls.Exit) then destroyDrone('manual') end
            if IsControlJustPressed(0, Config.Controls.NightVision) then night = not night; SetNightvision(night) end
            if IsControlJustPressed(0, Config.Controls.Thermal) then thermal = not thermal; SetSeethrough(thermal) end
            if IsControlJustPressed(0, Config.Controls.Spotlight) then spotlight = not spotlight end
            if IsControlJustPressed(0, Config.Controls.Scan) then scanArea() end
            if IsControlJustPressed(0, Config.Controls.LockTarget) then lockedTarget = findTarget(); notify(lockedTarget and 'Target locked.' or 'No target found.', lockedTarget and 'success' or 'error') end
            SendNUIMessage({ type='telemetry', battery=battery, coords=vecToTable(pos), night=night, thermal=thermal, spotlight=spotlight, locked=lockedTarget and DoesEntityExist(lockedTarget) })
        end
    end
end)

CreateThread(function()
    while true do
        Wait(10000)
        if controlling and drone then
            battery = math.max(0, battery - (100 / (Config.Drone.BatteryMinutes * 6)))
            local pos = GetEntityCoords(drone)
            TriggerServerEvent('dpn-drone:server:updateDrone', { coords = vecToTable(pos), battery = math.floor(battery), mode = thermal and 'thermal' or night and 'night' or 'normal' })
            if battery <= Config.Drone.CriticalBatteryPercent then
                notify('Drone battery critical. Recalling drone.', 'error')
                destroyDrone('critical_battery')
            elseif battery <= Config.Drone.LowBatteryPercent and Config.Drone.AutoReturnOnLowBattery then
                notify('Drone battery low.', 'error')
            end
        end
    end
end)

RegisterNUICallback('close', function(_, cb) setNui(false); cb({ ok = true }) end)
RegisterNUICallback('recall', function(_, cb) destroyDrone('nui'); cb({ ok = true }) end)
RegisterNUICallback('scan', function(_, cb) scanArea(); cb({ ok = true }) end)
RegisterNUICallback('alert', function(data, cb)
    if drone then TriggerServerEvent('dpn-drone:server:createAlert', { title = data.title or 'Drone Alert', code='DRN', priority=2, coords=vecToTable(GetEntityCoords(drone)), description=data.description or 'Manual drone alert' }) end
    cb({ ok = true })
end)

exports('IsDroneActive', function() return controlling end)
exports('GetDroneEntity', function() return drone end)
exports('RecallDrone', function(reason) destroyDrone(reason or 'export') end)
