local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local DispatchOpen = false
local LatestState = nil
local CurrentAssignedCall = nil
local LastStreet = 'Unknown Location'

local function GetStreetName()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = streetHash and GetStreetNameFromHashKey(streetHash) or 'Unknown Road'
    local crossing = crossingHash and crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or nil
    if crossing and crossing ~= '' then return street .. ' / ' .. crossing end
    return street
end

local function GetCoordsTable()
    local coords = GetEntityCoords(PlayerPedId())
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function HasDispatchJob()
    if not PlayerData or not PlayerData.job then return false end
    local jobName = PlayerData.job.name
    if Config.DispatchCenterJobs[jobName] then return true end
    return #DPNDispatch.GetDepartmentByJob(jobName) > 0
end

local function OpenDispatch(tab)
    QBCore.Functions.TriggerCallback('dpn-dispatch:server:canOpen', function(canOpen)
        if not canOpen then
            QBCore.Functions.Notify('You are not authorized to use dispatch.', 'error')
            return
        end

        DispatchOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', tab = tab })
        QBCore.Functions.TriggerCallback('dpn-dispatch:server:getState', function(state)
            LatestState = state
            SendNUIMessage({ action = 'syncState', state = state })
            if tab then SendNUIMessage({ action = 'setTab', tab = tab }) end
        end)
    end)
end

local function CloseDispatch()
    DispatchOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterCommand(Config.Commands.dispatch, function()
    if DispatchOpen then CloseDispatch() else OpenDispatch() end
end, false)

RegisterCommand(Config.Commands.report, function()
    OpenDispatch('reports')
end, false)

RegisterKeyMapping(Config.Commands.dispatch, 'Open DPN Dispatch Center', 'keyboard', Config.OpenKey)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    if HasDispatchJob() then TriggerServerEvent('dpn-dispatch:server:registerUnit', { coords = GetCoordsTable(), status = 'available' }) end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    CloseDispatch()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
    if HasDispatchJob() then
        TriggerServerEvent('dpn-dispatch:server:registerUnit', { coords = GetCoordsTable(), status = 'available' })
    else
        CloseDispatch()
    end
end)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(500) end
    PlayerData = QBCore.Functions.GetPlayerData()
    Wait(1000)
    if HasDispatchJob() then TriggerServerEvent('dpn-dispatch:server:registerUnit', { coords = GetCoordsTable(), status = 'available' }) end
end)

CreateThread(function()
    while true do
        Wait(Config.UnitPositionUpdateMs)
        if HasDispatchJob() then
            LastStreet = GetStreetName()
            TriggerServerEvent('dpn-dispatch:server:updateUnitPosition', GetCoordsTable())
        end
    end
end)

RegisterNetEvent('dpn-dispatch:client:open', function() OpenDispatch() end)
RegisterNetEvent('dpn-dispatch:client:openReport', function() OpenDispatch('reports') end)

RegisterNetEvent('dpn-dispatch:client:closedNui', function()
    DispatchOpen = false
    SetNuiFocus(false, false)
end)

RegisterNetEvent('dpn-dispatch:client:syncState', function(state)
    LatestState = state
    SendNUIMessage({ action = 'syncState', state = state })
    if DPNDispatchBlips and DPNDispatchBlips.Refresh then DPNDispatchBlips.Refresh(state, CurrentAssignedCall) end
end)

RegisterNetEvent('dpn-dispatch:client:newCall', function(call)
    SendNUIMessage({ action = 'newCall', call = call })
    if call.priority == 1 then
        PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
        QBCore.Functions.Notify(('Priority dispatch: %s'):format(call.title or call.code), 'error', 7500)
    else
        PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
        QBCore.Functions.Notify(('New dispatch call: %s'):format(call.title or call.code), 'primary', 5000)
    end
end)

RegisterNetEvent('dpn-dispatch:client:assignedToCall', function(call)
    CurrentAssignedCall = call.id
    QBCore.Functions.Notify(('Assigned to call #%s - %s'):format(call.id, call.title), 'success', 7000)
    if call.coords and Config.Blips.routeOnAssigned then SetNewWaypoint(call.coords.x + 0.0, call.coords.y + 0.0) end
end)

RegisterNetEvent('dpn-dispatch:client:unassignedFromCall', function(callId)
    if CurrentAssignedCall == callId then CurrentAssignedCall = nil end
    QBCore.Functions.Notify(('Unassigned from call #%s'):format(callId), 'primary')
end)

RegisterNetEvent('dpn-dispatch:client:createCall', function(data)
    data = data or {}
    data.location = data.location or GetStreetName()
    data.coords = data.coords or GetCoordsTable()
    TriggerServerEvent('dpn-dispatch:server:createCall', data)
end)

exports('CreateClientCall', function(data)
    data = data or {}
    data.location = data.location or GetStreetName()
    data.coords = data.coords or GetCoordsTable()
    TriggerServerEvent('dpn-dispatch:server:createCall', data)
end)

exports('CreateClientReport', function(data)
    data = data or {}
    data.location = data.location or GetStreetName()
    data.coords = data.coords or GetCoordsTable()
    TriggerServerEvent('dpn-dispatch:server:createReport', data)
end)

exports('OpenDispatch', function() OpenDispatch() end)
exports('OpenReports', function() OpenDispatch('reports') end)
exports('CloseDispatch', CloseDispatch)
exports('GetLatestState', function() return LatestState end)
