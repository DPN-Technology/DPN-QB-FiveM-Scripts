local incidents, units, markers = {}, {}, {}
local uiOpen = false
local activeBlips = {}

local function playerCoords()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function notify(msg, nType)
    DPN_IC_Bridge.Notify(nil, msg, nType)
end

RegisterNetEvent('dpn-incident-command:client:notify', function(msg, nType) notify(msg, nType) end)

local function clearBlips()
    for _, b in pairs(activeBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    activeBlips = {}
end

local function makeBlip(id, coords, label, cfg)
    if not coords or not coords.x then return end
    local blip = AddBlipForCoord(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    SetBlipSprite(blip, cfg.sprite)
    SetBlipColour(blip, cfg.color)
    SetBlipScale(blip, cfg.scale)
    SetBlipAsShortRange(blip, cfg.shortRange == true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
    activeBlips[id] = blip
end

local function rebuildBlips()
    clearBlips()
    for id, inc in pairs(incidents) do
        makeBlip(id, inc.coords, 'ICS: ' .. (inc.title or 'Incident'), DPN_IC_Config.DefaultBlip)
    end
    for incId, list in pairs(markers) do
        for _, m in ipairs(list) do
            local cfg = DPN_IC_Config.StagingBlip
            if m.marker_type == 'roadblock' then cfg = DPN_IC_Config.RoadblockBlip end
            if m.marker_type == 'search_grid' then cfg = DPN_IC_Config.SearchGridBlip end
            makeBlip(m.marker_uid, m.coords, 'ICS: ' .. m.label, cfg)
        end
    end
end

RegisterNetEvent('dpn-incident-command:client:sync', function(i, u, m)
    incidents, units, markers = i or {}, u or {}, m or {}
    rebuildBlips()
    if uiOpen then
        SendNUIMessage({ action = 'sync', incidents = incidents, units = units, markers = markers })
    end
end)

local function openUI()
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', incidents = incidents, units = units, markers = markers })
    TriggerServerEvent('dpn-incident-command:server:requestSync')
end

local function closeUI()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterCommand(DPN_IC_Config.Command, function() openUI() end, false)
RegisterKeyMapping(DPN_IC_Config.Command, 'Open DPN Incident Command', 'keyboard', DPN_IC_Config.OpenKey)

RegisterNUICallback('close', function(_, cb) closeUI(); cb(true) end)
RegisterNUICallback('createIncident', function(data, cb)
    data.coords = playerCoords()
    TriggerServerEvent('dpn-incident-command:server:createIncident', data)
    cb(true)
end)
RegisterNUICallback('updateIncident', function(data, cb)
    TriggerServerEvent('dpn-incident-command:server:updateIncident', data.id, data.patch)
    cb(true)
end)
RegisterNUICallback('archiveIncident', function(data, cb)
    TriggerServerEvent('dpn-incident-command:server:archiveIncident', data.id)
    cb(true)
end)
RegisterNUICallback('addSelf', function(data, cb)
    TriggerServerEvent('dpn-incident-command:server:addUnit', data.id, { source_id = GetPlayerServerId(PlayerId()), role = data.role, division = data.division })
    cb(true)
end)
RegisterNUICallback('addMarker', function(data, cb)
    data.coords = playerCoords()
    TriggerServerEvent('dpn-incident-command:server:addMarker', data.id, data)
    cb(true)
end)

exports('OpenIncidentCommand', openUI)
exports('GetIncidents', function() return incidents end)
