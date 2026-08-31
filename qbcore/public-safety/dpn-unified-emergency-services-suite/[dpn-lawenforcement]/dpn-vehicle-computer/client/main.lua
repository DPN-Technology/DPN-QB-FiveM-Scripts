local uiOpen = false
local radarEnabled = false
local alprEnabled = false
local lastPlate = nil

local function notify(msg, typ)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, false)
end

local function isEmergencyVehicle(veh)
    if veh == 0 then return false end
    local class = GetVehicleClass(veh)
    return class == 18 or not Config.RequireEmergencyVehicle
end

local function getVehicleInfo()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return nil end
    return {
        netId = VehToNet(veh),
        plate = GetVehicleNumberPlateText(veh),
        model = GetDisplayNameFromVehicleModel(GetEntityModel(veh)),
        speed = math.floor(GetEntitySpeed(veh) * 2.236936),
        seat = GetPedInVehicleSeat(veh, -1) == ped and 'Driver' or 'Passenger'
    }
end

local function openComputer()
    if uiOpen then return end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if Config.RequireVehicle and veh == 0 then notify('You must be inside a vehicle.') return end
    if Config.RequireEmergencyVehicle and not isEmergencyVehicle(veh) then notify('This vehicle does not have a DPN computer.') return end
    if veh ~= 0 and not Config.AllowPassengerUse and GetPedInVehicleSeat(veh, -1) ~= ped then notify('Only the driver can use this computer.') return end
    TriggerServerEvent('dpn-vehicle-computer:server:open')
end

RegisterCommand(Config.Command, openComputer)
RegisterKeyMapping(Config.Command, 'Open DPN Vehicle Computer', 'keyboard', Config.OpenKey)

RegisterCommand(Config.PanicCommand, function()
    TriggerServerEvent('dpn-vehicle-computer:server:panic')
end)

RegisterCommand(Config.StatusCommand, function(_, args)
    TriggerServerEvent('dpn-vehicle-computer:server:setStatus', args[1] or '10-8')
end)

RegisterCommand(Config.PlateCommand, function(_, args)
    TriggerServerEvent('dpn-vehicle-computer:server:plateCheck', table.concat(args, ' '))
end)

RegisterNetEvent('dpn-vehicle-computer:client:openUI', function(payload)
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', payload = payload })
end)

RegisterNetEvent('dpn-vehicle-computer:client:notify', notify)
RegisterNetEvent('dpn-vehicle-computer:client:plateResult', function(result)
    SendNUIMessage({ action = 'plateResult', payload = result })
    if result.flagged then notify(('ALERT: %s - %s'):format(result.plate, result.reason), 'error') end
end)

RegisterNetEvent('dpn-vehicle-computer:client:panicAlert', function(name, coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipScale(blip, 1.3)
    SetBlipColour(blip, 1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Officer Panic: ' .. name)
    EndTextCommandSetBlipName(blip)
    notify('OFFICER PANIC: ' .. name)
    SetTimeout(180000, function() RemoveBlip(blip) end)
end)

RegisterNUICallback('close', function(_, cb)
    uiOpen = false
    SetNuiFocus(false, false)
    cb(true)
end)

RegisterNUICallback('status', function(data, cb)
    TriggerServerEvent('dpn-vehicle-computer:server:setStatus', data.status)
    cb(true)
end)

RegisterNUICallback('panic', function(_, cb)
    TriggerServerEvent('dpn-vehicle-computer:server:panic')
    cb(true)
end)

RegisterNUICallback('plateCheck', function(data, cb)
    TriggerServerEvent('dpn-vehicle-computer:server:plateCheck', data.plate)
    cb(true)
end)

RegisterNUICallback('hotlist', function(data, cb)
    TriggerServerEvent('dpn-vehicle-computer:server:addHotlist', data.plate, data.reason)
    cb(true)
end)

RegisterNUICallback('createCall', function(data, cb)
    TriggerServerEvent('dpn-vehicle-computer:server:createCall', data)
    cb(true)
end)

RegisterNUICallback('saveNote', function(data, cb)
    TriggerServerEvent('dpn-vehicle-computer:server:saveNote', data.text)
    cb(true)
end)

RegisterNUICallback('toggleRadar', function(_, cb)
    radarEnabled = not radarEnabled
    cb(radarEnabled)
end)

RegisterNUICallback('toggleALPR', function(_, cb)
    alprEnabled = not alprEnabled
    cb(alprEnabled)
end)

RegisterNUICallback('module', function(data, cb)
    if data.module == 'starchase' then TriggerEvent(Config.IntegrationEvents.StarChaseOpen) end
    if data.module == 'bodycam' then TriggerEvent(Config.IntegrationEvents.BodyCamToggle) end
    if data.module == 'operations' or data.module == 'pursuit' or data.module == 'warrants' then
        uiOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        ExecuteCommand(Config.OperationsCommand or 'leops')
    end
    cb(true)
end)

CreateThread(function()
    while true do
        Wait(Config.Radar.RefreshMs)
        if radarEnabled and uiOpen then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            local speed = veh ~= 0 and math.floor(GetEntitySpeed(veh) * 2.236936) or 0
            SendNUIMessage({ action = 'radar', payload = { speed = speed, front = speed, rear = 0 } })
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.ALPR.ScanIntervalMs)
        if alprEnabled then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local vehs = GetGamePool('CVehicle')
            local closest, dist = nil, Config.ALPR.MaxDistance
            for _, v in ipairs(vehs) do
                if v ~= GetVehiclePedIsIn(ped, false) then
                    local d = #(coords - GetEntityCoords(v))
                    if d < dist then closest, dist = v, d end
                end
            end
            if closest then
                local plate = GetVehicleNumberPlateText(closest)
                if plate and plate ~= lastPlate then
                    lastPlate = plate
                    TriggerServerEvent('dpn-vehicle-computer:server:plateCheck', plate)
                    SendNUIMessage({ action = 'alprScan', payload = { plate = plate, distance = math.floor(dist) } })
                end
            end
        end
    end
end)
