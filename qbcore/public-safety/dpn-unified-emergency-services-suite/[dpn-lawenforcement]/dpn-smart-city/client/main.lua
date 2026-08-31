local nuiOpen = false
local bolos = {}
local lastWeaponShot = 0
local cameraBlips, sensorBlips = {}, {}
local trafficOverrides = {}

local function IsAllowedVehicleClass(vehicle)
    local class = GetVehicleClass(vehicle)
    return class ~= 13 and class ~= 14 and class ~= 15 and class ~= 16 and class ~= 21
end

local function Notify(msg, typ)
    if GetResourceState('qb-core') == 'started' then
        TriggerEvent('QBCore:Notify', msg, typ or 'primary')
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

local function SetNui(state)
    nuiOpen = state
    SetNuiFocus(state, state)
    SendNUIMessage({ action='setVisible', visible=state })
    if state then
        TriggerServerEvent('dpn-smartcity:server:requestData')
        TriggerServerEvent('dpn-smartcity:server:getRecentEvents')
    end
end

RegisterCommand(Config.Command, function() SetNui(not nuiOpen) end)
RegisterKeyMapping(Config.Command, 'Open DPN Smart City', 'keyboard', Config.OpenKey)

RegisterNUICallback('close', function(_, cb) SetNui(false) cb(true) end)
RegisterNUICallback('addBolo', function(data, cb) TriggerServerEvent('dpn-smartcity:server:addBolo', data) cb(true) end)
RegisterNUICallback('clearBolo', function(data, cb) TriggerServerEvent('dpn-smartcity:server:clearBolo', data.id) cb(true) end)
RegisterNUICallback('trafficOverride', function(data, cb) TriggerServerEvent('dpn-smartcity:server:trafficOverride', data.nodeId, data.mode) cb(true) end)
RegisterNUICallback('refreshEvents', function(_, cb) TriggerServerEvent('dpn-smartcity:server:getRecentEvents') cb(true) end)

RegisterNetEvent('dpn-smartcity:client:syncBolos', function(data)
    bolos = data or {}
    SendNUIMessage({ action='bolos', bolos=bolos })
end)

RegisterNetEvent('dpn-smartcity:client:syncConfig', function(data)
    SendNUIMessage({ action='config', config=data })
end)

RegisterNetEvent('dpn-smartcity:client:recentEvents', function(rows)
    SendNUIMessage({ action='events', events=rows or {} })
end)

RegisterNetEvent('dpn-smartcity:client:smartAlert', function(payload)
    Notify((payload.title or 'Smart City') .. ': ' .. (payload.description or payload.message or ''), tonumber(payload.priority) == 1 and 'error' or 'primary')
end)

RegisterNetEvent('dpn-smartcity:client:trafficOverride', function(nodeId, mode, seconds)
    trafficOverrides[nodeId] = { mode=mode, expires=GetGameTimer() + ((seconds or 180) * 1000) }
    Notify(('Traffic node %s set to %s mode.'):format(nodeId, mode), 'success')
end)

local function InZone(coords, zone)
    return #(coords - zone.coords) <= zone.radius
end

local function ClosestCamera(coords)
    local best, dist = nil, 999999.0
    for _, cam in ipairs(Config.Cameras) do
        local d = #(coords - cam.coords)
        if d < dist and d <= (cam.range or 100.0) then best, dist = cam, d end
    end
    return best, dist
end

local function PlateMatchesBolo(plate)
    plate = DPN.PlateTrim(plate)
    for _, bolo in ipairs(bolos) do
        local target = DPN.PlateTrim(bolo.plate)
        if Config.Bolo.ExactPlate then
            if plate == target then return bolo end
        else
            if plate:find(target, 1, true) or target:find(plate, 1, true) then return bolo end
        end
    end
    return nil
end

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('dpn-smartcity:server:requestData')
    if Config.MapBlips.Cameras then
        for _, cam in ipairs(Config.Cameras) do
            local blip = AddBlipForCoord(cam.coords.x, cam.coords.y, cam.coords.z)
            SetBlipSprite(blip, 184)
            SetBlipScale(blip, 0.55)
            SetBlipColour(blip, 3)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(cam.name)
            EndTextCommandSetBlipName(blip)
            cameraBlips[#cameraBlips+1] = blip
        end
    end
    if Config.MapBlips.Sensors then
        for _, zone in ipairs(Config.GunshotZones) do
            local blip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
            SetBlipColour(blip, 1)
            SetBlipAlpha(blip, 45)
            sensorBlips[#sensorBlips+1] = blip
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.SensorScanIntervalMs)
        local ped = PlayerPedId()
        if IsPedShooting(ped) and GetGameTimer() - lastWeaponShot > 2500 then
            lastWeaponShot = GetGameTimer()
            local coords = GetEntityCoords(ped)
            for _, zone in ipairs(Config.GunshotZones) do
                if InZone(coords, zone) then
                    TriggerServerEvent('dpn-smartcity:server:gunshot', {
                        zoneId=zone.id, zoneName=zone.name,
                        coords={ x=coords.x, y=coords.y, z=coords.z },
                        weapon=GetSelectedPedWeapon(ped)
                    })
                    break
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.CameraScanIntervalMs)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and IsAllowedVehicleClass(veh) then
            local coords = GetEntityCoords(veh)
            local cam = ClosestCamera(coords)
            if cam then
                -- The server derives plate, speed, vehicle and coordinates from the driver's entity.
                TriggerServerEvent('dpn-smartcity:server:cameraPass', cam.id)
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        for nodeId, data in pairs(trafficOverrides) do
            if data.expires < GetGameTimer() then trafficOverrides[nodeId] = nil end
        end
    end
end)

exports('OpenSmartCity', function() SetNui(true) end)
exports('GetActiveBolos', function() return bolos end)
exports('IsPlateBolo', function(plate) return PlateMatchesBolo(plate) ~= nil end)
