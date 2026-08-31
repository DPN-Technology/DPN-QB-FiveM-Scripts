local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local uiOpen = false
local calls = {}
local units = {}
local callBlips = {}
local lastShot = 0
local lastCrash = 0
local currentStatus = '10-8'
local unitNumber = nil
local supervisor = false

local function refreshPlayerData()
    PlayerData = QBCore.Functions.GetPlayerData() or {}
end

local function jobDefinition()
    refreshPlayerData()
    local job = PlayerData.job or {}
    return Config.AllowedJobs[job.name], job
end

local function isOnDuty()
    local definition, job = jobDefinition()
    return definition ~= nil and (not Config.RequireDuty or job.onduty == true)
end

local function notify(message, kind)
    QBCore.Functions.Notify(message, kind or 'primary')
end
RegisterNetEvent('dpn_dispatch:client:notify', notify)

local function coordsTable()
    local coords = GetEntityCoords(PlayerPedId())
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function streetName(coords)
    local primary, crossing = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(primary)
    local cross = crossing ~= 0 and GetStreetNameFromHashKey(crossing) or ''
    return cross ~= '' and (street .. ' / ' .. cross) or street
end

local function sendNui()
    SendNUIMessage({ action = 'sync', calls = calls, units = units, statuses = Config.UnitStatuses, callStatuses = Config.CallStatuses, status = currentStatus, unit = unitNumber, supervisor = supervisor })
end

local function openUi()
    if uiOpen then return end
    if not isOnDuty() then return notify('You must be on duty to access digital dispatch.', 'error') end
    uiOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent('dpn_dispatch:server:requestSync')
    SendNUIMessage({ action = 'open' })
end

local function closeUi()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterCommand(Config.Command, openUi, false)
RegisterKeyMapping(Config.Command, 'Open DPN Digital Dispatch', 'keyboard', Config.OpenKey)
RegisterCommand('+dpn_panic', function()
    if not isOnDuty() then return end
    TriggerServerEvent('dpn_dispatch:server:createCall', {
        type = 'panic', title = 'OFFICER PANIC BUTTON', description = 'Emergency panic button activated.',
        coords = coordsTable(), priority = 1, staffOnly = true
    })
end, false)
RegisterCommand('-dpn_panic', function() end, false)
if Config.PanicKey and Config.PanicKey ~= '' then RegisterKeyMapping('+dpn_panic', 'DPN Panic Button', 'keyboard', Config.PanicKey) end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', refreshPlayerData)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
    if uiOpen and not isOnDuty() then closeUi() end
end)
RegisterNetEvent('QBCore:Player:SetPlayerData', function(data) PlayerData = data or PlayerData end)

RegisterNUICallback('close', function(_, cb) closeUi(); cb({ ok = true }) end)
RegisterNUICallback('assignSelf', function(data, cb) TriggerServerEvent('dpn_dispatch:server:assignSelf', data.callId); cb({ ok = true }) end)
RegisterNUICallback('closeCall', function(data, cb) TriggerServerEvent('dpn_dispatch:server:closeCall', data.callId, data.disposition, data.notes); cb({ ok = true }) end)
RegisterNUICallback('addNote', function(data, cb) TriggerServerEvent('dpn_dispatch:server:addNote', data.callId, data.note); cb({ ok = true }) end)
RegisterNUICallback('setCallStatus', function(data, cb) TriggerServerEvent('dpn_dispatch:server:setCallStatus', data.callId, data.status); cb({ ok = true }) end)
RegisterNUICallback('setCallPriority', function(data, cb) TriggerServerEvent('dpn_dispatch:server:setCallPriority', data.callId, data.priority, data.reason); cb({ ok = true }) end)
RegisterNUICallback('setStatus', function(data, cb)
    currentStatus = Config.UnitStatuses[data.status] and data.status or '10-8'
    TriggerServerEvent('dpn_dispatch:server:updateUnit', { status = currentStatus, unit = unitNumber, coords = coordsTable() })
    TriggerServerEvent('dpn-le-core:server:setStatus', currentStatus)
    cb({ ok = true })
end)
RegisterNUICallback('setUnit', function(data, cb)
    unitNumber = tostring(data.unit or ''):sub(1, Config.Security.MaxUnitLength):upper()
    TriggerServerEvent('dpn_dispatch:server:updateUnit', { status = currentStatus, unit = unitNumber, coords = coordsTable() })
    TriggerServerEvent('dpn-le-core:server:setUnit', unitNumber)
    cb({ ok = true })
end)
RegisterNUICallback('createCall', function(data, cb)
    local coords = coordsTable()
    data.coords = coords
    data.description = (data.description or '') .. '\nLocation: ' .. streetName(coords)
    data.staffOnly = true
    TriggerServerEvent('dpn_dispatch:server:createCall', data)
    cb({ ok = true })
end)
RegisterNUICallback('waypoint', function(data, cb)
    local call = calls[data.callId] or calls[tostring(data.callId)]
    if call and call.coords then SetNewWaypoint(call.coords.x + 0.0, call.coords.y + 0.0); notify('Waypoint set.', 'success') end
    cb({ ok = true })
end)

local function removeCallBlip(callId)
    if callBlips[callId] and DoesBlipExist(callBlips[callId]) then RemoveBlip(callBlips[callId]) end
    callBlips[callId] = nil
end

local function addCallBlip(call)
    if not Config.EnableGPSBlips or not call.coords then return end
    removeCallBlip(call.callId)
    local blip = AddBlipForCoord(call.coords.x + 0.0, call.coords.y + 0.0, (call.coords.z or 0.0) + 0.0)
    SetBlipSprite(blip, 161)
    SetBlipScale(blip, call.priority == 1 and 1.25 or 0.9)
    SetBlipColour(blip, (Config.CallTypes[call.type] and Config.CallTypes[call.type].color) or 1)
    SetBlipFlashes(blip, call.priority == 1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('%s • %s'):format(call.callId, call.title or 'Dispatch Call'))
    EndTextCommandSetBlipName(blip)
    callBlips[call.callId] = blip
    SetTimeout(Config.CallBlipDurationSeconds * 1000, function() removeCallBlip(call.callId) end)
end

RegisterNetEvent('dpn_dispatch:client:sync', function(data)
    calls = data.calls or {}
    units = data.units or {}
    supervisor = data.supervisor == true
    sendNui()
end)
RegisterNetEvent('dpn_dispatch:client:callCreated', function(call)
    calls[call.callId] = call
    addCallBlip(call)
    notify(('New dispatch: %s'):format(call.title), call.priority == 1 and 'error' or 'primary')
    sendNui()
end)
RegisterNetEvent('dpn_dispatch:client:callUpdated', function(call) calls[call.callId] = call; sendNui() end)
RegisterNetEvent('dpn_dispatch:client:callClosed', function(callId)
    calls[callId] = nil
    removeCallBlip(callId)
    sendNui()
end)
RegisterNetEvent('dpn_dispatch:client:unitsUpdated', function(data) units = data or {}; sendNui() end)

CreateThread(function()
    refreshPlayerData()
    while true do
        Wait((Config.BlipUpdateSeconds or 5) * 1000)
        if isOnDuty() then
            TriggerServerEvent('dpn_dispatch:server:updateUnit', { status = currentStatus, unit = unitNumber, coords = coordsTable() })
        end
    end
end)

CreateThread(function()
    while true do
        Wait(250)
        if isOnDuty() then
            local ped = PlayerPedId()
            local definition = jobDefinition()
            if Config.EnableAutoShotsFired and definition and definition.department == 'law' and IsPedShooting(ped) then
                local current = GetGameTimer()
                if current - lastShot > Config.ShotsCooldownSeconds * 1000 then
                    lastShot = current
                    local coords = coordsTable()
                    TriggerServerEvent('dpn_dispatch:server:createCall', { type = 'shots', title = 'Officer Weapon Discharge', description = 'Weapon discharge detected near ' .. streetName(coords), coords = coords, priority = 2, staffOnly = true })
                end
            end
            if Config.EnableAutoVehicleCrash and IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                local speed = GetEntitySpeed(vehicle) * 2.236936
                if GetVehicleClass(vehicle) == 18 and HasEntityCollidedWithAnything(vehicle) and speed > Config.CrashSpeedMPH then
                    local current = GetGameTimer()
                    if current - lastCrash > 60000 then
                        lastCrash = current
                        local coords = coordsTable()
                        TriggerServerEvent('dpn_dispatch:server:createCall', { type = 'backup', title = 'Emergency Unit Crash', description = 'High-speed emergency vehicle crash near ' .. streetName(coords), coords = coords, priority = 1, staffOnly = true })
                    end
                end
            end
        else
            Wait(750)
        end
    end
end)
