local uiOpen = false
local officers = {}
local calls = {}
local extraState = {}
local restrained = false
local cuffType = 'hard'
local escorted = false
local escortOfficer = 0
local lastAction = 0
local PlayerData = {}

local function refreshPlayerData()
    PlayerData = DPNBridge.GetPlayerData() or {}
end

local function jobAllowed()
    refreshPlayerData()
    local job = PlayerData.job and PlayerData.job.name
    return job and Config.AllowedJobs[job] ~= nil
end

local function isLawJob()
    refreshPlayerData()
    local job = PlayerData.job and PlayerData.job.name
    return job and Config.AllowedJobs[job] and Config.AllowedJobs[job].type == 'law'
end

local function notify(message, kind, duration)
    DPNBridge.Notify(nil, message, kind, duration)
end

local function myOfficer()
    local serverId = GetPlayerServerId(PlayerId())
    return officers[serverId] or officers[tostring(serverId)]
end

local function sendState()
    SendNUIMessage({
        action = 'state',
        officers = officers,
        calls = calls,
        self = myOfficer(),
        extra = extraState,
        config = {
            title = Config.UI.Title,
            statuses = Config.Statuses,
            citations = Config.Citations,
            booking = Config.Booking
        }
    })
end

local function setUi(state)
    if state and not jobAllowed() then
        return notify('Your current job is not authorized for the DPN Emergency Network.', 'error')
    end
    uiOpen = state
    SetNuiFocus(state, state)
    SendNUIMessage({ action = 'toggle', show = state })
    if state then
        TriggerServerEvent('dpn-le-core:server:requestState')
        sendState()
    end
end

local function closestPlayer(maxDistance)
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local closest, closestDistance = -1, maxDistance or Config.Interactions.MaxDistance
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local ped = GetPlayerPed(player)
            local distance = #(GetEntityCoords(ped) - myCoords)
            if distance < closestDistance then
                closest = player
                closestDistance = distance
            end
        end
    end
    if closest == -1 then return nil, nil end
    return GetPlayerServerId(closest), closestDistance
end

local function closestVehicle(maxDistance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, maxDistance or Config.Interactions.VehicleDistance, 0, 70)
    if vehicle == 0 then return nil end
    return vehicle
end

local function actionReady()
    local current = GetGameTimer()
    if current - lastAction < Config.Interactions.ActionCooldownMs then return false end
    lastAction = current
    return true
end

RegisterCommand(Config.Command, function()
    setUi(not uiOpen)
end, false)
RegisterKeyMapping(Config.Command, 'Open DPN Law Enforcement Network', 'keyboard', Config.OpenKey)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshPlayerData()
    TriggerServerEvent('dpn-le-core:server:requestState')
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
    if uiOpen and not jobAllowed() then setUi(false) end
    TriggerServerEvent('dpn-le-core:server:requestState')
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    PlayerData = data or PlayerData
end)

RegisterNetEvent('dpn-le-core:client:syncState', function(officerData, callData, metadata)
    officers = officerData or {}
    calls = callData or {}
    extraState = metadata or {}
    sendState()
end)

RegisterNetEvent('dpn-le-core:client:newCall', function(call)
    if not jobAllowed() then return end
    local callId = call.callId or call.id
    calls[callId] = call
    notify(('New dispatch: %s'):format(call.title or 'Call'), call.priority == 1 and 'error' or 'primary')
    SendNUIMessage({ action = 'newCall', call = call })

    if call.coords and call.coords.x and call.coords.y then
        local blip = AddBlipForCoord(call.coords.x + 0.0, call.coords.y + 0.0, (call.coords.z or 0.0) + 0.0)
        SetBlipSprite(blip, 161)
        SetBlipScale(blip, call.priority == 1 and 1.15 or 0.9)
        SetBlipColour(blip, call.priority == 1 and 1 or 5)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('DPN Dispatch %s'):format(callId))
        EndTextCommandSetBlipName(blip)
        SetTimeout((Config.Dispatch.BlipTimeSeconds or 300) * 1000, function()
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end)
    end
end)

RegisterNetEvent('dpn-le-core:client:setCuffed', function(state, style)
    restrained = state == true
    cuffType = style == 'soft' and 'soft' or 'hard'
    escorted = false
    escortOfficer = 0
    DetachEntity(PlayerPedId(), true, false)
    local ped = PlayerPedId()

    if restrained then
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        SetEnableHandcuffs(ped, true)
        SetPedCanPlayGestureAnims(ped, false)
        local dict = cuffType == 'soft' and 'anim@move_m@prisoner_cuffed' or 'mp_arresting'
        local anim = cuffType == 'soft' and 'idle' or 'idle'
        RequestAnimDict(dict)
        local timeout = GetGameTimer() + 3000
        while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end
        if HasAnimDictLoaded(dict) then TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 49, 0.0, false, false, false) end
    else
        SetEnableHandcuffs(ped, false)
        SetPedCanPlayGestureAnims(ped, true)
        ClearPedTasks(ped)
    end
end)

RegisterNetEvent('dpn-le-core:client:setEscorted', function(state, officerServerId)
    escorted = state == true
    escortOfficer = tonumber(officerServerId) or 0
    if not escorted then DetachEntity(PlayerPedId(), true, false) end
end)

RegisterNetEvent('dpn-le-core:client:putInVehicle', function(vehicleNetId)
    local vehicle = NetToVeh(tonumber(vehicleNetId) or 0)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    DetachEntity(PlayerPedId(), true, false)
    escorted = false
    escortOfficer = 0
    local maxPassengers = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = maxPassengers - 1, 0, -1 do
        if IsVehicleSeatFree(vehicle, seat) then
            TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, seat)
            return
        end
    end
    notify('No open passenger seat was found.', 'error')
end)

RegisterNetEvent('dpn-le-core:client:removeFromVehicle', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
    end
end)

RegisterNetEvent('dpn-le-core:client:searchResult', function(data)
    SendNUIMessage({ action = 'searchResult', result = data or {} })
    if not uiOpen then setUi(true) end
end)

RegisterNUICallback('close', function(_, cb)
    setUi(false)
    cb({ ok = true })
end)

RegisterNUICallback('toggleDuty', function(_, cb)
    TriggerServerEvent('dpn-le-core:server:toggleDuty')
    cb({ ok = true })
end)

RegisterNUICallback('setStatus', function(data, cb)
    TriggerServerEvent('dpn-le-core:server:setStatus', data.status)
    cb({ ok = true })
end)

RegisterNUICallback('setUnit', function(data, cb)
    TriggerServerEvent('dpn-le-core:server:setUnit', data.unit)
    cb({ ok = true })
end)

RegisterNUICallback('assignSelf', function(data, cb)
    TriggerServerEvent('dpn-le-core:server:assignSelf', data.callId)
    cb({ ok = true })
end)

RegisterNUICallback('closeCall', function(data, cb)
    TriggerServerEvent('dpn-le-core:server:closeCall', data.callId, data.disposition, data.notes)
    cb({ ok = true })
end)

RegisterNUICallback('waypoint', function(data, cb)
    local call = calls[data.callId] or calls[tostring(data.callId)]
    if call and call.coords then
        SetNewWaypoint(call.coords.x + 0.0, call.coords.y + 0.0)
        notify('Dispatch waypoint set.', 'success')
    end
    cb({ ok = true })
end)

RegisterNUICallback('targetAction', function(data, cb)
    if not actionReady() or not isLawJob() then cb({ ok = false }); return end
    local target = tonumber(data.target)
    if not target then target = select(1, closestPlayer(Config.Interactions.VehicleDistance + 2.0)) end
    if not target then notify('No nearby player found.', 'error'); cb({ ok = false }); return end

    local action = data.action
    if action == 'cuff' or action == 'softcuff' then
        TriggerServerEvent('dpn-le-core:server:toggleCuff', target, action == 'softcuff' and 'soft' or 'hard')
    elseif action == 'escort' then
        TriggerServerEvent('dpn-le-core:server:toggleEscort', target)
    elseif action == 'search' then
        TriggerServerEvent('dpn-le-core:server:searchPlayer', target)
    elseif action == 'putvehicle' then
        local vehicle = closestVehicle(Config.Interactions.VehicleDistance)
        if not vehicle then notify('No nearby vehicle found.', 'error'); cb({ ok = false }); return end
        TriggerServerEvent('dpn-le-core:server:putInVehicle', target, VehToNet(vehicle))
    elseif action == 'removevehicle' then
        TriggerServerEvent('dpn-le-core:server:removeFromVehicle', target)
    end
    cb({ ok = true, target = target })
end)

RegisterNUICallback('issueCitation', function(data, cb)
    if not isLawJob() then cb({ ok = false }); return end
    local target = tonumber(data.target)
    if not target then target = select(1, closestPlayer(Config.Interactions.MaxDistance)) end
    if not target then notify('No nearby player found.', 'error'); cb({ ok = false }); return end
    data.target = target
    TriggerServerEvent('dpn-le-core:server:issueCitation', data)
    cb({ ok = true, target = target })
end)

RegisterNUICallback('bookSuspect', function(data, cb)
    if not isLawJob() then cb({ ok = false }); return end
    local target = tonumber(data.target)
    if not target then target = select(1, closestPlayer(Config.Interactions.MaxDistance + 2.0)) end
    if not target then notify('No nearby player found.', 'error'); cb({ ok = false }); return end
    data.target = target
    TriggerServerEvent('dpn-le-core:server:bookSuspect', data)
    cb({ ok = true, target = target })
end)

RegisterNUICallback('createTestCall', function(_, cb)
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('dpn-le-core:server:createCall', {
        type = 'test',
        title = 'Officer Generated Test Call',
        description = 'DPN Emergency Network integration test.',
        priority = 3,
        staffOnly = true,
        coords = { x = coords.x, y = coords.y, z = coords.z }
    })
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if restrained then
            local ped = PlayerPedId()
            if not IsEntityPlayingAnim(ped, cuffType == 'soft' and 'anim@move_m@prisoner_cuffed' or 'mp_arresting', 'idle', 3) and not IsPedInAnyVehicle(ped, false) then
                local dict = cuffType == 'soft' and 'anim@move_m@prisoner_cuffed' or 'mp_arresting'
                RequestAnimDict(dict)
                if HasAnimDictLoaded(dict) then TaskPlayAnim(ped, dict, 'idle', 8.0, -8.0, -1, 49, 0.0, false, false, false) end
            end
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 45, true)
            DisableControlAction(0, 75, true)
            DisablePlayerFiring(PlayerId(), true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if escorted and escortOfficer > 0 then
            local officerPlayer = GetPlayerFromServerId(escortOfficer)
            if officerPlayer ~= -1 then
                local officerPed = GetPlayerPed(officerPlayer)
                if officerPed > 0 and not IsEntityAttachedToEntity(PlayerPedId(), officerPed) then
                    AttachEntityToEntity(PlayerPedId(), officerPed, 11816, 0.35, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                end
            else
                escorted = false
                escortOfficer = 0
                DetachEntity(PlayerPedId(), true, false)
            end
            Wait(250)
        else
            Wait(750)
        end
    end
end)

CreateThread(function()
    Wait(2000)
    refreshPlayerData()
    TriggerServerEvent('dpn-le-core:server:requestState')
    while true do
        Wait(5000)
        if jobAllowed() then
            local coords = GetEntityCoords(PlayerPedId())
            TriggerServerEvent('dpn-le-core:server:updatePosition', { x = coords.x, y = coords.y, z = coords.z })
        end
    end
end)

exports('OpenCore', function() setUi(true) end)
exports('CloseCore', function() setUi(false) end)
exports('CreateLocalDispatchCall', function(data) TriggerServerEvent('dpn-le-core:server:createCall', data) end)
exports('IsRestrained', function() return restrained end)
