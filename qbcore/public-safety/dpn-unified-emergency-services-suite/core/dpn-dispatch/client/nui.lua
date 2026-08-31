local QBCore = exports['qb-core']:GetCoreObject()

local function GetCoordsTable()
    local coords = GetEntityCoords(PlayerPedId())
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function GetStreetName()
    local coords = GetEntityCoords(PlayerPedId())
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = streetHash and GetStreetNameFromHashKey(streetHash) or 'Unknown Road'
    local crossing = crossingHash and crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or nil
    if crossing and crossing ~= '' then return street .. ' / ' .. crossing end
    return street
end

local function Reply(cb, payload)
    cb(payload or { ok = true })
end

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerEvent('dpn-dispatch:client:closedNui')
    Reply(cb)
end)

RegisterNUICallback('requestState', function(_, cb)
    QBCore.Functions.TriggerCallback('dpn-dispatch:server:getState', function(state)
        Reply(cb, state or {})
    end)
end)

RegisterNUICallback('createCall', function(data, cb)
    data = data or {}
    data.fromDispatch = true
    data.location = data.location ~= '' and data.location or GetStreetName()
    data.coords = data.useCurrentLocation and GetCoordsTable() or data.coords
    TriggerServerEvent('dpn-dispatch:server:createCall', data)
    Reply(cb)
end)

RegisterNUICallback('assignSelf', function(data, cb)
    TriggerServerEvent('dpn-dispatch:server:assignSelf', data and data.callId)
    Reply(cb)
end)

RegisterNUICallback('assignUnit', function(data, cb)
    TriggerServerEvent('dpn-dispatch:server:assignUnit', data and data.callId, data and data.unitSrc)
    Reply(cb)
end)

RegisterNUICallback('unassignUnit', function(data, cb)
    TriggerServerEvent('dpn-dispatch:server:unassignUnit', data and data.callId, data and data.unitSrc)
    Reply(cb)
end)

RegisterNUICallback('setCallStatus', function(data, cb)
    TriggerServerEvent('dpn-dispatch:server:updateCall', data and data.callId, { status = data and data.status })
    Reply(cb)
end)

RegisterNUICallback('setCallPriority', function(data, cb)
    TriggerServerEvent('dpn-dispatch:server:updateCall', data and data.callId, { priority = data and data.priority })
    Reply(cb)
end)

RegisterNUICallback('addNote', function(data, cb)
    TriggerServerEvent('dpn-dispatch:server:updateCall', data and data.callId, { note = data and data.note })
    Reply(cb)
end)

RegisterNUICallback('setUnitStatus', function(data, cb)
    TriggerServerEvent('dpn-dispatch:server:setUnitStatus', data and data.status, data and data.radio)
    Reply(cb)
end)

RegisterNUICallback('panic', function(data, cb)
    TriggerServerEvent('dpn-dispatch:server:panic', data and data.message)
    Reply(cb)
end)


RegisterNUICallback('forceMdtSync', function(_, cb)
    TriggerServerEvent('dpn-dispatch:server:forceMdtSync')
    Reply(cb)
end)

RegisterNUICallback('createReport', function(data, cb)
    data = data or {}
    data.location = data.location ~= '' and data.location or GetStreetName()
    if data.useCurrentLocation then data.coords = GetCoordsTable() end
    TriggerServerEvent('dpn-dispatch:server:createReport', data)
    Reply(cb)
end)

RegisterNUICallback('updateReport', function(data, cb)
    data = data or {}
    local changes = data.changes or data
    if changes.location ~= nil then changes.location = changes.location ~= '' and changes.location or GetStreetName() end
    if changes.useCurrentLocation then changes.coords = GetCoordsTable() end
    changes.useCurrentLocation = nil
    TriggerServerEvent('dpn-dispatch:server:updateReport', data.reportId, changes)
    Reply(cb)
end)

RegisterNUICallback('setGps', function(data, cb)
    if data and data.coords and data.coords.x and data.coords.y then
        SetNewWaypoint(data.coords.x + 0.0, data.coords.y + 0.0)
        QBCore.Functions.Notify('GPS waypoint set.', 'success')
    end
    Reply(cb)
end)

RegisterNUICallback('copyLocation', function(data, cb)
    if data and data.coords then
        local coords = data.coords
        QBCore.Functions.Notify(('Coords: %.2f, %.2f, %.2f'):format(coords.x or 0.0, coords.y or 0.0, coords.z or 0.0), 'primary', 7500)
    end
    Reply(cb)
end)

RegisterNUICallback('escape', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerEvent('dpn-dispatch:client:closedNui')
    Reply(cb)
end)
