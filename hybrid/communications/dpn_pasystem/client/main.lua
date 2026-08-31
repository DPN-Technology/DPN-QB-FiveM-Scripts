local State = {
    uiOpen = false,
    pttHeld = false,
    active = false,
    pending = false,
    latched = false,
    session = nil,
    startedAt = 0,
    selectedRange = Config.DefaultRange,
    auth = { authorized = false, reason = 'loading' },
    settings = {},
    incoming = {},
    pmaApplied = false,
}

local function debugPrint(...)
    if Config.Debug then
        print('[dpn_pasystem:client]', ...)
    end
end

local function tableCopy(src)
    local out = {}
    if type(src) == 'table' then
        for k, v in pairs(src) do out[k] = v end
    end
    return out
end

local function notify(message, msgType)
    msgType = msgType or 'primary'
    if GetResourceState('qb-core') == 'started' then
        local ok = pcall(function()
            exports['qb-core']:GetCoreObject().Functions.Notify(message, msgType)
        end)
        if ok then return end
    end

    if GetResourceState('ox_lib') == 'started' then
        local ok = pcall(function()
            exports.ox_lib:notify({ description = message, type = msgType })
        end)
        if ok then return end
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function kvpKey()
    -- Client KVP is already local to the player installation. Do not include
    -- server ID here because that changes between sessions and makes UI
    -- settings such as panel/HUD position appear like they are not saving.
    return 'dpn_pa_settings'
end

local function legacyKvpKey()
    return ('dpn_pa_settings_%s'):format(GetPlayerServerId(PlayerId()))
end

local function saveSettings()
    SetResourceKvp(kvpKey(), json.encode(State.settings))
end

local function loadSettings()
    State.settings = tableCopy(Config.DefaultSettings)

    local raw = GetResourceKvpString(kvpKey())

    -- Backwards compatibility for players who already saved settings on the
    -- old per-server-ID key before this fix.
    if not raw or raw == '' then
        raw = GetResourceKvpString(legacyKvpKey())
    end

    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            for k, v in pairs(decoded) do
                State.settings[k] = v
            end
        end
    end

    State.selectedRange = Config.ClampRange(State.settings.selectedRange or Config.DefaultRange)
    State.latched = State.settings.latchMode == true
end

local function sendUI(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

local function getVehicleInfo()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return nil end

    local seat = nil
    for i = -1, 6 do
        if GetPedInVehicleSeat(veh, i) == ped then
            seat = i
            break
        end
    end

    local modelHash = GetEntityModel(veh)
    local modelName = string.lower(GetDisplayNameFromVehicleModel(modelHash) or 'unknown')
    local plate = GetVehicleNumberPlateText(veh) or 'UNKNOWN'
    local class = GetVehicleClass(veh)
    local coords = GetEntityCoords(veh)

    return {
        entity = veh,
        netId = VehToNet(veh),
        modelHash = modelHash,
        model = modelName,
        plate = plate,
        class = class,
        seat = seat,
        coords = coords,
        engineHealth = GetVehicleEngineHealth(veh),
        bodyHealth = GetVehicleBodyHealth(veh),
    }
end

local function isAllowedVehicleLocal(info)
    if not Config.RequireVehicle then return true end
    if not info then return false, Config.Messages.no_vehicle end

    if not Config.AllowedSeats[info.seat] then
        return false, Config.Messages.wrong_seat
    end

    if Config.BlacklistedVehicleModels[info.model] then
        return false, Config.Messages.no_vehicle
    end

    if not Config.RequireEmergencyVehicle then return true end

    if Config.AllowedVehicleClasses[info.class] then return true end
    if Config.AllowedVehicleModels[info.model] then return true end

    return false, Config.Messages.no_vehicle
end

local function buildStatus()
    local info = getVehicleInfo()
    local vehOk, vehMsg = isAllowedVehicleLocal(info)
    local pmaState = GetResourceState(Config.PmaVoiceResource)

    return {
        active = State.active,
        pending = State.pending,
        latched = State.latched,
        selectedRange = State.selectedRange,
        maxRange = Config.MaxRange,
        minRange = Config.MinRange,
        presets = Config.RangePresets,
        settings = State.settings,
        auth = State.auth,
        vehicle = info and {
            plate = info.plate,
            model = info.model,
            class = info.class,
            seat = info.seat,
            valid = vehOk,
            message = vehMsg,
        } or nil,
        vehicleValid = vehOk,
        vehicleMessage = vehMsg,
        pmaVoice = {
            resource = Config.PmaVoiceResource,
            state = pmaState,
            ready = pmaState == 'started',
        },
        keybinds = Config.Keybinds,
        commands = Config.Commands,
    }
end

local function refreshUI()
    sendUI('status', buildStatus())
end

local function openUI()
    if State.uiOpen then return end
    State.uiOpen = true
    SetNuiFocus(true, true)
    sendUI('open', buildStatus())
end

local function closeUI()
    State.uiOpen = false
    SetNuiFocus(false, false)
    sendUI('close')
end

local function clearPmaRange()
    if not State.pmaApplied then return end
    State.pmaApplied = false

    if GetResourceState(Config.PmaVoiceResource) == 'started' then
        pcall(function()
            exports[Config.PmaVoiceResource]:clearProximityOverride()
        end)
        pcall(function()
            exports[Config.PmaVoiceResource]:resetProximityCheck()
        end)
    end
end

local function applyPmaRange(range)
    if GetResourceState(Config.PmaVoiceResource) ~= 'started' then
        notify(Config.Messages.pma_missing, 'error')
        return false
    end

    range = Config.ClampRange(range)

    local ok = pcall(function()
        exports[Config.PmaVoiceResource]:overrideProximityRange(range, true)
    end)

    if ok then
        State.pmaApplied = true
        return true
    end

    -- Compatibility fallback for pma-voice builds that expose proximity checks but not range override.
    -- This still uses pma-voice exports rather than touching Mumble proximity natives directly.
    ok = pcall(function()
        exports[Config.PmaVoiceResource]:overrideProximityCheck(function(player)
            local targetPed = GetPlayerPed(player)
            if targetPed == 0 then return false end
            local myCoords = GetEntityCoords(PlayerPedId())
            return #(myCoords - GetEntityCoords(targetPed)) <= range
        end)
    end)

    if ok then
        State.pmaApplied = true
        return true
    end

    notify(Config.Messages.pma_missing, 'error')
    return false
end

local function getStartPayload()
    local info = getVehicleInfo()
    if not info then return nil end
    local coords = info.coords

    return {
        vehicleNetId = info.netId,
        plate = info.plate,
        model = info.model,
        class = info.class,
        seat = info.seat,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        range = State.selectedRange,
    }
end

local function heartbeatPayload()
    local payload = getStartPayload()
    if not payload then return nil end
    payload.session = State.session
    return payload
end

local function playClick(on)
    if not State.settings.clickSounds then return end
    if on then
        PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    else
        PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
end

local function startPTTControlLoop()
    if not Config.ForceGamePushToTalkWhilePA then return end
    CreateThread(function()
        while State.active and (State.pttHeld or State.latched) do
            SetControlNormal(0, Config.PushToTalkControl, 1.0)
            SetControlNormal(1, Config.PushToTalkControl, 1.0)
            SetControlNormal(2, Config.PushToTalkControl, 1.0)
            Wait(0)
        end
    end)
end

local function stopPA(reason, silent)
    if not State.active and not State.pending then return end

    State.active = false
    State.pending = false
    State.session = nil
    State.startedAt = 0
    clearPmaRange()
    playClick(false)

    TriggerServerEvent('dpn_pa:server:stopPA', reason or 'client_stop')
    sendUI('paState', { active = false, reason = reason or 'stopped' })
    refreshUI()

    if not silent then
        notify(Config.Messages.stopped, 'primary')
    end
end

local function localCanStart()
    if State.active or State.pending then return false, nil end

    if Config.StopIfPlayerDead and IsEntityDead(PlayerPedId()) then
        return false, Config.Messages.invalid
    end

    local info = getVehicleInfo()
    local vehicleOk, vehicleMessage = isAllowedVehicleLocal(info)
    if not vehicleOk then
        return false, vehicleMessage or Config.Messages.no_vehicle
    end

    if GetResourceState(Config.PmaVoiceResource) ~= 'started' then
        return false, Config.Messages.pma_missing
    end

    return true, nil
end

local function requestStart(latched)
    local canStart, reason = localCanStart()
    if not canStart then
        if reason then notify(reason, 'error') end
        return
    end

    State.latched = latched == true
    State.pending = true
    State.selectedRange = Config.ClampRange(State.selectedRange)
    TriggerServerEvent('dpn_pa:server:startPA', getStartPayload())
    refreshUI()
end

local function startHeartbeatLoop()
    CreateThread(function()
        while State.active do
            local info = getVehicleInfo()
            local vehOk = isAllowedVehicleLocal(info)

            if Config.StopIfPlayerDead and IsEntityDead(PlayerPedId()) then
                stopPA('dead')
                break
            end

            if Config.StopIfPlayerExitsVehicle and not info then
                stopPA('vehicle_exit')
                break
            end

            if not vehOk then
                stopPA('invalid_vehicle')
                break
            end

            if Config.StopIfVehicleStopsExisting and info and (info.engineHealth <= 0.0 or info.bodyHealth <= 0.0) then
                stopPA('vehicle_destroyed')
                break
            end

            TriggerServerEvent('dpn_pa:server:heartbeat', heartbeatPayload())
            refreshUI()
            Wait(Config.HeartbeatMs)
        end
    end)
end

local function handleApproved(data)
    State.pending = false

    if not State.pttHeld and not State.latched then
        TriggerServerEvent('dpn_pa:server:stopPA', 'released_before_start')
        refreshUI()
        return
    end

    local range = Config.ClampRange(data and data.range or State.selectedRange)
    if not applyPmaRange(range) then
        TriggerServerEvent('dpn_pa:server:stopPA', 'pma_missing')
        refreshUI()
        return
    end

    State.active = true
    State.session = data and data.session or tostring(GetGameTimer())
    State.startedAt = GetGameTimer()
    State.selectedRange = range

    playClick(true)
    notify(Config.Messages.started, 'success')
    sendUI('paState', { active = true, range = range, session = State.session })
    refreshUI()
    startPTTControlLoop()
    startHeartbeatLoop()
end

local function updateIncoming(payload)
    if not Config.ShowIncomingHud or type(payload) ~= 'table' then return end
    if payload.source == GetPlayerServerId(PlayerId()) then return end
    if not payload.coords then return end

    local ped = PlayerPedId()
    local myCoords = GetEntityCoords(ped)
    local coords = vector3(payload.coords.x or 0.0, payload.coords.y or 0.0, payload.coords.z or 0.0)
    local distance = #(myCoords - coords)
    local range = tonumber(payload.range or Config.DefaultRange) or Config.DefaultRange

    if distance <= (range + Config.IncomingHudExtraDistance) then
        payload.distance = math.floor(distance)
        payload.expires = GetGameTimer() + Config.IncomingHudExpireMs
        State.incoming[payload.source] = payload
    else
        State.incoming[payload.source] = nil
    end
end

local function incomingLoop()
    if not Config.ShowIncomingHud then return end

    CreateThread(function()
        while true do
            local now = GetGameTimer()
            local nearest = nil

            for src, data in pairs(State.incoming) do
                if data.expires <= now then
                    State.incoming[src] = nil
                else
                    if not nearest or (data.distance or 999999) < (nearest.distance or 999999) then
                        nearest = data
                    end
                end
            end

            if nearest then
                sendUI('incoming', nearest)
            else
                sendUI('incoming', false)
            end

            Wait(500)
        end
    end)
end

RegisterNetEvent('dpn_pa:client:notify', function(message, msgType)
    notify(message, msgType)
end)

RegisterNetEvent('dpn_pa:client:setAuth', function(data)
    State.auth = data or { authorized = false, reason = 'unknown' }
    refreshUI()
end)

RegisterNetEvent('dpn_pa:client:startApproved', function(data)
    handleApproved(data)
end)

RegisterNetEvent('dpn_pa:client:startDenied', function(reason)
    State.pending = false
    State.active = false
    State.session = nil
    clearPmaRange()
    sendUI('paState', { active = false, reason = reason or 'denied' })
    refreshUI()
end)

RegisterNetEvent('dpn_pa:client:forceStop', function(reason)
    State.active = false
    State.pending = false
    State.session = nil
    State.startedAt = 0
    clearPmaRange()
    playClick(false)
    sendUI('paState', { active = false, reason = reason or 'stopped' })
    refreshUI()

    local warnReasons = {
        permission = true,
        vehicle = true,
        timeout = true,
        resource_stop = true,
        vehicle_destroyed = true,
    }

    if reason and warnReasons[reason] then
        notify(Config.Messages.invalid, 'error')
    end
end)

RegisterNetEvent('dpn_pa:client:incomingPA', function(payload)
    updateIncoming(payload)
end)

RegisterNetEvent('dpn_pa:client:incomingStop', function(src)
    State.incoming[src] = nil
end)

RegisterNetEvent('dpn_pa:client:statusReport', function(data)
    local auth = data and data.authorized and 'AUTHORIZED' or 'NOT AUTHORIZED'
    local active = data and data.active and 'PA LIVE' or 'PA IDLE'
    notify(('PA Status: %s / %s'):format(auth, active), data and data.authorized and 'success' or 'error')
end)

RegisterCommand(Config.Keybinds.menu.command, function()
    openUI()
    TriggerServerEvent('dpn_pa:server:requestAuth')
end, false)

RegisterCommand(Config.Commands.menu, function()
    openUI()
    TriggerServerEvent('dpn_pa:server:requestAuth')
end, false)

RegisterCommand(Config.Commands.stop, function()
    stopPA('command')
end, false)

RegisterCommand('+dpnpa_ptt', function()
    State.pttHeld = true
    requestStart(false)
end, false)

RegisterCommand('-dpnpa_ptt', function()
    State.pttHeld = false
    if State.active and not State.latched then
        stopPA('ptt_release')
    elseif State.pending and not State.latched then
        State.pending = false
        TriggerServerEvent('dpn_pa:server:stopPA', 'ptt_release_pending')
        refreshUI()
    end
end, false)

RegisterCommand(Config.Keybinds.latch.command, function()
    if State.active and State.latched then
        stopPA('latch_toggle')
        return
    end

    State.pttHeld = true
    requestStart(true)
end, false)

RegisterKeyMapping(Config.Keybinds.menu.command, Config.Keybinds.menu.label, 'keyboard', Config.Keybinds.menu.default)
RegisterKeyMapping(Config.Keybinds.ptt.command, Config.Keybinds.ptt.label, 'keyboard', Config.Keybinds.ptt.default)
RegisterKeyMapping(Config.Keybinds.latch.command, Config.Keybinds.latch.label, 'keyboard', Config.Keybinds.latch.default)

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('dpn_pa:server:requestAuth')
    cb({ ok = true, status = buildStatus() })
end)

RegisterNUICallback('saveSettings', function(data, cb)
    data = data or {}
    if type(data.settings) == 'table' then
        for k, v in pairs(data.settings) do
            State.settings[k] = v
        end
        State.settings.selectedRange = Config.ClampRange(State.settings.selectedRange or State.selectedRange)
        State.selectedRange = State.settings.selectedRange
        State.latched = State.settings.latchMode == true
        saveSettings()
    end

    refreshUI()
    cb({ ok = true, status = buildStatus() })
end)

RegisterNUICallback('setRange', function(data, cb)
    local range = Config.ClampRange(data and data.range or State.selectedRange)
    State.selectedRange = range
    State.settings.selectedRange = range
    State.settings.selectedPreset = data and data.preset or State.settings.selectedPreset
    saveSettings()

    if State.active then
        clearPmaRange()
        applyPmaRange(range)
    end

    refreshUI()
    cb({ ok = true, range = range })
end)

RegisterNUICallback('startPA', function(data, cb)
    if data and data.range then
        State.selectedRange = Config.ClampRange(data.range)
        State.settings.selectedRange = State.selectedRange
        saveSettings()
    end
    State.pttHeld = true
    requestStart(data and data.latched == true)
    cb({ ok = true })
end)

RegisterNUICallback('stopPA', function(_, cb)
    State.pttHeld = false
    stopPA('nui')
    cb({ ok = true })
end)

CreateThread(function()
    loadSettings()
    if Config.ShowIncomingHud then
        incomingLoop()
    end

    Wait(1500)
    TriggerServerEvent('dpn_pa:server:requestAuth')

    while true do
        if State.uiOpen then
            refreshUI()
            Wait(1000)
        else
            Wait(2500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearPmaRange()
    SetNuiFocus(false, false)
end)

exports('IsPAActive', function()
    return State.active
end)

exports('StopPA', function(reason)
    stopPA(reason or 'export')
end)
