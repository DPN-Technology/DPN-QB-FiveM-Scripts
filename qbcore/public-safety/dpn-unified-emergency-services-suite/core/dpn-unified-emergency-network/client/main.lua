local QBCore = exports['qb-core']:GetCoreObject()
local open = false
local lastCoords = nil

local function getVehicleData()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then
        return { plate = GetVehicleNumberPlateText(veh), model = GetDisplayNameFromVehicleModel(GetEntityModel(veh)), speed = math.floor(GetEntitySpeed(veh) * 2.236936), netId = NetworkGetNetworkIdFromEntity(veh) }
    end
    return nil
end

local function sendCurrentGps(reason)
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        local c = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        local coords = { x = c.x, y = c.y, z = c.z }
        lastCoords = coords
        TriggerServerEvent('dpn-unes:server:unitLocation', { coords = coords, heading = heading, vehicle = getVehicleData(), reason = reason or 'manual' })
        return true
    end
    return false
end

RegisterNetEvent('dpn-unes:client:open', function(payload)
    open = true
    sendCurrentGps('open_ui')
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', payload = payload })
    SetTimeout(300, function() TriggerServerEvent('dpn-unes:server:requestSnapshot') end)
end)

RegisterNUICallback('close', function(_, cb) open = false; SetNuiFocus(false, false); cb(true) end)
RegisterNUICallback('assignSelf', function(data, cb) TriggerServerEvent('dpn-unes:server:assignSelf', data.incidentId); cb(true) end)
RegisterNUICallback('unassignSelf', function(data, cb) TriggerServerEvent('dpn-unes:server:unassignSelf', data.incidentId); cb(true) end)
RegisterNUICallback('setStatus', function(data, cb) TriggerServerEvent('dpn-unes:server:updateIncidentStatus', data.incidentId, data.status); cb(true) end)
RegisterNUICallback('requestSupport', function(data, cb) TriggerServerEvent('dpn-unes:server:requestAgencySupport', data); cb(true) end)
RegisterNUICallback('setUnitStatus', function(data, cb) TriggerServerEvent('dpn-unes:server:setUnitStatus', data.status); cb(true) end)
RegisterNUICallback('setSceneCommander', function(data, cb) TriggerServerEvent('dpn-unes:server:setSceneCommander', data); cb(true) end)
RegisterNUICallback('addIncidentNote', function(data, cb) TriggerServerEvent('dpn-unes:server:addIncidentNote', data); cb(true) end)
RegisterNUICallback('addObjective', function(data, cb) TriggerServerEvent('dpn-unes:server:addObjective', data); cb(true) end)
RegisterNUICallback('toggleObjective', function(data, cb) TriggerServerEvent('dpn-unes:server:toggleObjective', data); cb(true) end)
RegisterNUICallback('updateTriage', function(data, cb) TriggerServerEvent('dpn-unes:server:updateTriage', data); cb(true) end)
RegisterNUICallback('createBolo', function(data, cb) TriggerServerEvent('dpn-unes:server:createBolo', data); cb(true) end)
RegisterNUICallback('archiveBolo', function(data, cb) TriggerServerEvent('dpn-unes:server:archiveBolo', data.boloId); cb(true) end)
RegisterNUICallback('createIncident', function(data, cb) TriggerServerEvent('dpn-unes:server:createIncident', data); cb(true) end)

RegisterNUICallback('waypoint', function(data, cb)
    if data and data.x and data.y then SetNewWaypoint(data.x + 0.0, data.y + 0.0); QBCore.Functions.Notify('Waypoint set.', 'success') end
    cb(true)
end)

CreateThread(function()
    while true do
        Wait(DPN_UNES.Config.ClientLocationRefreshMs or 3500)
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            local c = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local coords = { x = c.x, y = c.y, z = c.z }
            if open or not lastCoords or #(vector3(c.x,c.y,c.z) - vector3(lastCoords.x,lastCoords.y,lastCoords.z)) > 2.0 then
                lastCoords = coords
                TriggerServerEvent('dpn-unes:server:unitLocation', { coords = coords, heading = heading, vehicle = getVehicleData(), reason = open and 'ui_live_heartbeat' or 'movement' })
            end
        end
    end
end)

RegisterNetEvent('dpn-unes:client:unitUpdated', function(unit) SendNUIMessage({ action = 'unitUpdated', unit = unit }) end)
RegisterNetEvent('dpn-unes:client:unitRemoved', function(unitKey) SendNUIMessage({ action = 'unitRemoved', unitKey = unitKey }) end)
RegisterNetEvent('dpn-unes:client:boloUpdated', function(bolo) SendNUIMessage({ action = 'boloUpdated', bolo = bolo }) end)

function DPNCreateIncident(data) TriggerServerEvent('dpn-unes:server:createIncident', data) end
exports('CreateIncident', DPNCreateIncident)

-- v4 live-map repair: on-demand full snapshot so the NUI map can recover if it opens before GPS sync arrives.
RegisterNUICallback('refreshSnapshot', function(_, cb)
    sendCurrentGps('nui_refresh')
    TriggerServerEvent('dpn-unes:server:requestSnapshot')
    cb(true)
end)

RegisterNetEvent('dpn-unes:client:snapshot', function(payload)
    SendNUIMessage({ action = 'snapshot', payload = payload })
end)


RegisterNUICallback('mapDebug', function(_, cb)
    sendCurrentGps('nui_map_debug')
    TriggerServerEvent('dpn-unes:server:mapDebug')
    cb(true)
end)
