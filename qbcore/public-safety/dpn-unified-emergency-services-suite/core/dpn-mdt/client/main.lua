local QBCore = exports[Config.Framework.resource]:GetCoreObject()
local isOpen = false
local playerContext = nil

local function notify(message, type)
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, type or 'primary')
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandThefeedPostTicker(false, false)
    end
end

local function serverCallback(name, payload, cb)
    local finished = false
    local eventName = 'dpn-mdt:server:' .. name
    local timeout = Config.CallbackTimeout or 8000

    SetTimeout(timeout, function()
        if finished then return end
        finished = true
        if cb then
            cb({ ok = false, error = ('MDT callback timed out: %s. Make sure dpn-mdt is started after qb-core and oxmysql, then import sql/dpn_mdt.sql.'):format(name) })
        end
    end)

    QBCore.Functions.TriggerCallback(eventName, function(result)
        if finished then return end
        finished = true
        if cb then cb(result or { ok = false, error = 'No response from MDT server callback: ' .. name }) end
    end, payload or {})
end

local function setNui(open)
    isOpen = open
    SetNuiFocus(open, open)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = open and 'open' or 'close' })
end

local function openMDT()
    if isOpen then return end
    serverCallback('CanOpen', {}, function(result)
        if not result or not result.ok then
            notify(result and result.error or 'Unable to open MDT.', 'error')
            return
        end
        playerContext = result.context
        setNui(true)
        SendNUIMessage({ action = 'context', context = result.context })
    end)
end

local function closeMDT()
    if not isOpen then return end
    setNui(false)
end

RegisterCommand(Config.Command, function()
    openMDT()
end, false)

RegisterCommand('mdtdebug', function()
    serverCallback('CanOpen', {}, function(result)
        print(('^3[dpn-mdt]^7 CanOpen result: %s'):format(json.encode(result or {})))
        notify(result and (result.ok and 'MDT debug passed. CanOpen returned OK.' or result.error) or 'No debug response', result and result.ok and 'success' or 'error')
    end)
end, false)

RegisterKeyMapping(Config.Command, 'Open DPN MDT', 'keyboard', Config.Keybind)

RegisterNUICallback('close', function(_, cb)
    closeMDT()
    cb({ ok = true })
end)

RegisterNUICallback('getInitialData', function(data, cb)
    serverCallback('GetInitialData', data, cb)
end)

RegisterNUICallback('serverAction', function(data, cb)
    local name = data and data.name
    local payload = data and data.payload or {}
    if not name then
        cb({ ok = false, error = 'Missing action name' })
        return
    end
    serverCallback(name, payload, cb)
end)

RegisterNUICallback('setUnitStatus', function(data, cb)
    TriggerServerEvent('dpn-mdt:server:SetUnitStatus', data.status, data.call_id)
    cb({ ok = true })
end)

RegisterNetEvent('dpn-mdt:client:OpenMDT', function()
    openMDT()
end)

RegisterNetEvent('dpn-mdt:client:CloseMDT', function()
    closeMDT()
end)

RegisterNetEvent('dpn-mdt:client:DispatchUpdated', function(call)
    SendNUIMessage({ action = 'dispatchUpdated', call = call })
end)

RegisterNetEvent('dpn-mdt:client:BoloUpdated', function(bolo)
    SendNUIMessage({ action = 'boloUpdated', bolo = bolo })
    notify(('New MDT BOLO: %s'):format(bolo.title or 'BOLO'), 'police')
end)

RegisterNetEvent('dpn-dispatch:client:SendCallToMDT', function(call)
    SendNUIMessage({ action = 'dispatchUpdated', call = call })
end)

RegisterNetEvent('dpn-unes:client:incidentUpdated', function(incident)
    SendNUIMessage({ action = 'unifiedIncidentUpdated', incident = incident })
end)

exports('OpenMDT', openMDT)
exports('CloseMDT', closeMDT)
exports('IsMDTOpen', function() return isOpen end)
exports('GetMDTContext', function() return playerContext end)

CreateThread(function()
    while true do
        if isOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
        end
        Wait(isOpen and 0 or 750)
    end
end)
