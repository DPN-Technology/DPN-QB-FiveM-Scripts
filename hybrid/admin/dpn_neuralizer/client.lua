local QBCore = nil
local ESX = nil
local handProp = nil
local busy = false
local neuralized = false
local lastLocalUse = 0

local function debugPrint(...)
    if Config.Debug then
        print('[DPN Neuralizer:CLIENT]', ...)
    end
end

CreateThread(function()
    Wait(500)

    if (Config.Framework == 'auto' or Config.Framework == 'qb') and GetResourceState('qb-core') == 'started' then
        local ok, obj = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok and obj then
            QBCore = obj
            debugPrint('QBCore detected')
        end
    end

    if not QBCore and (Config.Framework == 'auto' or Config.Framework == 'esx') and GetResourceState('es_extended') == 'started' then
        local ok, obj = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and obj then
            ESX = obj
            debugPrint('ESX detected')
        end
    end
end)

local function notify(message, msgType)
    msgType = msgType or 'primary'

    if Config.Notifications.system == 'none' then return end

    if (Config.Notifications.system == 'ox' or Config.Notifications.system == 'auto') and GetResourceState('ox_lib') == 'started' and lib then
        lib.notify({
            title = Config.Notifications.prefix,
            description = message,
            type = msgType == 'error' and 'error' or msgType == 'success' and 'success' or 'inform'
        })
        return
    end

    if (Config.Notifications.system == 'qb' or Config.Notifications.system == 'auto') and QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, msgType)
        return
    end

    if (Config.Notifications.system == 'esx' or Config.Notifications.system == 'auto') and ESX and ESX.ShowNotification then
        ESX.ShowNotification(message)
        return
    end

    TriggerEvent('chat:addMessage', {
        color = { 0, 210, 255 },
        multiline = true,
        args = { Config.Notifications.prefix, message }
    })
end

local function sendNui(action, payload)
    payload = payload or {}
    payload.action = action
    SendNUIMessage(payload)
end

local function rotationToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function requestModel(modelName)
    local hash = type(modelName) == 'number' and modelName or GetHashKey(modelName)

    if not IsModelInCdimage(hash) then
        return nil
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(10)
    end

    if not HasModelLoaded(hash) then
        return nil
    end

    return hash
end

local function requestAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 4000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function requestAnimSet(set)
    RequestAnimSet(set)
    local timeout = GetGameTimer() + 4000
    while not HasAnimSetLoaded(set) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasAnimSetLoaded(set)
end

local function deleteHandProp()
    if handProp and DoesEntityExist(handProp) then
        DetachEntity(handProp, true, true)
        DeleteEntity(handProp)
    end
    handProp = nil
end

local function createHandProp()
    deleteHandProp()

    local ped = PlayerPedId()
    local model = Config.Prop.model

    if Config.Prop.useCustomModel and Config.Prop.customModel and Config.Prop.customModel ~= '' then
        model = Config.Prop.customModel
    end

    local hash = requestModel(model)
    if not hash and Config.Prop.fallbackModel then
        hash = requestModel(Config.Prop.fallbackModel)
    end

    if not hash then
        debugPrint('No valid prop model found')
        return nil
    end

    local coords = GetEntityCoords(ped)
    handProp = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, false)

    if not DoesEntityExist(handProp) then
        return nil
    end

    SetEntityCollision(handProp, false, false)
    AttachEntityToEntity(
        handProp,
        ped,
        GetPedBoneIndex(ped, Config.Prop.bone),
        Config.Prop.offset.x, Config.Prop.offset.y, Config.Prop.offset.z,
        Config.Prop.rotation.x, Config.Prop.rotation.y, Config.Prop.rotation.z,
        true, true, false, true, 1, true
    )

    SetModelAsNoLongerNeeded(hash)
    return handProp
end

local function playUseAnimation(targetPed)
    local ped = PlayerPedId()

    if targetPed and DoesEntityExist(targetPed) then
        TaskTurnPedToFaceEntity(ped, targetPed, 500)
        Wait(150)
    end

    if requestAnimDict(Config.Animation.dict) then
        TaskPlayAnim(
            ped,
            Config.Animation.dict,
            Config.Animation.name,
            8.0,
            -8.0,
            Config.Effects.chargeMs + Config.Effects.flashMs + 1000,
            Config.Animation.flag,
            0.0,
            false,
            false,
            false
        )
    end
end

local function hasLineOfSight(sourcePed, targetPed)
    if not Config.Targeting.requireLineOfSight then
        return true
    end
    return HasEntityClearLosToEntity(sourcePed, targetPed, 17)
end

local function getPlayerFromPed(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    if GetEntityType(ped) ~= 1 or not IsPedAPlayer(ped) then return nil end

    local playerIndex = NetworkGetPlayerIndexFromPed(ped)
    if not playerIndex or playerIndex == -1 then return nil end

    return GetPlayerServerId(playerIndex), playerIndex
end

local function getTargetFromRaycast()
    local ped = PlayerPedId()
    local camCoord = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = rotationToDirection(camRot)
    local destination = camCoord + (direction * Config.Targeting.maxDistance)

    local ray = StartShapeTestRay(
        camCoord.x,
        camCoord.y,
        camCoord.z,
        destination.x,
        destination.y,
        destination.z,
        -1,
        ped,
        0
    )

    local result, hit, _, _, entityHit = nil, 0, nil, nil, 0
    local timeout = GetGameTimer() + 150
    repeat
        result, hit, _, _, entityHit = GetShapeTestResult(ray)
        if result == 1 then Wait(0) end
    until result ~= 1 or GetGameTimer() > timeout

    if hit == 1 and entityHit and entityHit ~= 0 and DoesEntityExist(entityHit) then
        local serverId, playerIndex = getPlayerFromPed(entityHit)
        if serverId and playerIndex then
            local targetPed = GetPlayerPed(playerIndex)
            if not Config.Targeting.allowSelfTarget and playerIndex == PlayerId() then
                return nil
            end
            if hasLineOfSight(ped, targetPed) then
                return serverId, targetPed
            end
        end
    end

    return nil
end

local function getTargetFromCone()
    local sourcePed = PlayerPedId()
    local sourceCoords = GetEntityCoords(sourcePed)
    local camCoord = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = rotationToDirection(camRot)
    local minDot = math.cos(math.rad(Config.Targeting.coneDegrees))

    local bestServerId = nil
    local bestPed = nil
    local bestScore = -999999.0

    for _, playerIndex in ipairs(GetActivePlayers()) do
        if Config.Targeting.allowSelfTarget or playerIndex ~= PlayerId() then
            local targetPed = GetPlayerPed(playerIndex)

            if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) and not IsEntityDead(targetPed) then
                local targetCoords = GetPedBoneCoords(targetPed, 31086, 0.0, 0.0, 0.0)
                local distanceFromSource = #(targetCoords - sourceCoords)

                if distanceFromSource <= Config.Targeting.maxDistance and hasLineOfSight(sourcePed, targetPed) then
                    local toTarget = targetCoords - camCoord
                    local length = #(toTarget)
                    if length > 0.01 then
                        local normal = vector3(toTarget.x / length, toTarget.y / length, toTarget.z / length)
                        local dot = (direction.x * normal.x) + (direction.y * normal.y) + (direction.z * normal.z)

                        if dot >= minDot then
                            local score = (dot * 100.0) - distanceFromSource
                            if score > bestScore then
                                bestScore = score
                                bestServerId = GetPlayerServerId(playerIndex)
                                bestPed = targetPed
                            end
                        end
                    end
                end
            end
        end
    end

    return bestServerId, bestPed
end

local function getTargetPlayer()
    if Config.Targeting.raycastFirst then
        local rayId, rayPed = getTargetFromRaycast()
        if rayId then
            return rayId, rayPed
        end
    end

    return getTargetFromCone()
end

local function fallbackWhiteFlash(duration)
    CreateThread(function()
        local started = GetGameTimer()
        while GetGameTimer() - started < duration do
            local elapsed = GetGameTimer() - started
            local alpha = math.floor(255 * (1.0 - (elapsed / duration)))
            DrawRect(0.5, 0.5, 1.0, 1.0, 255, 255, 255, alpha)
            Wait(0)
        end
    end)
end

local function fallbackBlackout(duration)
    CreateThread(function()
        local started = GetGameTimer()
        while GetGameTimer() - started < duration do
            DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, 255)
            Wait(0)
        end
    end)
end

local function captureVitals(ped)
    if not Config.Safety or not Config.Safety.preventHealthDrain then return nil end
    if not ped or not DoesEntityExist(ped) then return nil end

    return {
        health = GetEntityHealth(ped),
        armour = GetPedArmour(ped)
    }
end

local function restoreVitals(ped, vitals)
    if not Config.Safety or not Config.Safety.preventHealthDrain then return end
    if not ped or not DoesEntityExist(ped) or not vitals then return end

    local currentHealth = GetEntityHealth(ped)
    if vitals.health and currentHealth > 0 and currentHealth < vitals.health then
        SetEntityHealth(ped, vitals.health)
    end

    if Config.Safety.restoreArmor and vitals.armour then
        local currentArmour = GetPedArmour(ped)
        if currentArmour < vitals.armour then
            SetPedArmour(ped, vitals.armour)
        end
    end
end

local function startVitalsGuard(duration)
    if not Config.Safety or not Config.Safety.preventHealthDrain then return end

    local ped = PlayerPedId()
    local vitals = captureVitals(ped)
    if not vitals then return end

    duration = duration or 3000

    CreateThread(function()
        local expires = GetGameTimer() + duration
        while GetGameTimer() < expires do
            restoreVitals(PlayerPedId(), vitals)
            Wait(250)
        end
        restoreVitals(PlayerPedId(), vitals)
    end)
end

local function flashScreen(duration, mode)
    duration = duration or Config.Effects.flashMs

    if Config.Effects.useNui then
        sendNui('flash', {
            duration = duration,
            mode = mode or 'full'
        })
    else
        fallbackWhiteFlash(duration)
    end
end

local function blackoutScreen(duration)
    duration = duration or Config.Effects.blackoutMs or 15000

    if duration <= 0 then return end

    if Config.Effects.useNui then
        sendNui('blackout', {
            duration = duration,
            fadeMs = Config.Effects.blackoutFadeMs or 350
        })
    else
        fallbackBlackout(duration)
    end
end

local function runNeuralizedEffect(sourceServerId)
    if neuralized then return end
    neuralized = true

    local ped = PlayerPedId()
    local flashMs = Config.Effects.flashMs or 850
    local blackoutMs = Config.Effects.blackoutMs or 15000
    local duration = math.max(Config.Effects.targetDurationMs or 0, flashMs + blackoutMs)

    startVitalsGuard(duration + (Config.Safety and Config.Safety.targetGuardExtraMs or 1000))
    flashScreen(flashMs, 'target')

    if blackoutMs > 0 then
        SetTimeout(flashMs, function()
            blackoutScreen(blackoutMs)
        end)
    end

    if Config.Effects.clearWaypoint then
        SetWaypointOff()
    end

    if Config.Effects.wipeChatMessage then
        notify('Everything goes white. Your memory feels scrambled for a moment.', 'error')
    end

    ClearPedTasksImmediately(ped)

    if not IsPedInAnyVehicle(ped, false) and Config.Effects.ragdollMs > 0 then
        SetPedToRagdoll(ped, Config.Effects.ragdollMs, Config.Effects.ragdollMs, 0, false, false, false)
    end

    if Config.Effects.screenShake and Config.Effects.screenShake > 0 then
        ShakeGameplayCam('DRUNK_SHAKE', Config.Effects.screenShake)
    end

    SetPedMotionBlur(ped, true)

    if Config.Effects.timecycle and Config.Effects.timecycle ~= '' then
        SetTimecycleModifier(Config.Effects.timecycle)
        SetTimecycleModifierStrength(0.85)
    end

    if Config.Effects.postfx and Config.Effects.postfx ~= '' then
        AnimpostfxPlay(Config.Effects.postfx, duration, false)
    end

    local movementSet = 'move_m@drunk@moderatedrunk'
    if Config.Effects.drunkenWalkMs > 0 and requestAnimSet(movementSet) then
        SetPedMovementClipset(ped, movementSet, 0.35)
        SetPedStrafeClipset(ped, movementSet)
    end

    local lockUntil = GetGameTimer() + Config.Effects.controlLockMs
    CreateThread(function()
        while GetGameTimer() < lockUntil do
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true) -- look left/right
            EnableControlAction(0, 2, true) -- look up/down
            EnableControlAction(0, 245, true) -- chat
            Wait(0)
        end
    end)

    Wait(duration)

    if Config.Effects.postfx and Config.Effects.postfx ~= '' then
        AnimpostfxStop(Config.Effects.postfx)
    end

    ClearTimecycleModifier()
    StopGameplayCamShaking(true)
    ResetPedMovementClipset(ped, 0.35)
    ResetPedStrafeClipset(ped)
    SetPedMotionBlur(ped, false)
    neuralized = false
end

local function useNeuralizer()
    if busy then
        notify('Neuralizer is already charging.', 'error')
        return
    end

    local now = GetGameTimer()
    if now - lastLocalUse < 1000 then
        return
    end
    lastLocalUse = now

    local targetServerId, targetPed = getTargetPlayer()
    if not targetServerId then
        notify('No valid player target in range. Aim at a player and try again.', 'error')
        return
    end

    busy = true
    startVitalsGuard(Config.Safety and Config.Safety.sourceGuardMs or 4500)
    createHandProp()
    playUseAnimation(targetPed)

    if Config.Effects.useNui then
        sendNui('charge', { duration = Config.Effects.chargeMs })
    end

    Wait(Config.Effects.chargeMs)
    TriggerServerEvent('dpn_neuralizer:server:attempt', targetServerId)

    SetTimeout(Config.Effects.chargeMs + Config.Effects.flashMs + 1800, function()
        deleteHandProp()
        busy = false
    end)
end

RegisterNetEvent('dpn_neuralizer:client:use', function()
    useNeuralizer()
end)

RegisterNetEvent('dpn_neuralizer:client:sourceConfirmed', function(targetName)
    flashScreen(Config.Effects.flashMs, 'source')
    notify(('Neuralizer fired at %s.'):format(targetName or 'target'), 'success')
end)

RegisterNetEvent('dpn_neuralizer:client:denied', function(message)
    notify(message or 'Neuralizer denied.', 'error')
    deleteHandProp()
    busy = false
end)

RegisterNetEvent('dpn_neuralizer:client:notify', function(message, msgType)
    notify(message, msgType)
end)

RegisterNetEvent('dpn_neuralizer:client:receive', function(sourceServerId)
    runNeuralizedEffect(sourceServerId)
end)

RegisterNetEvent('dpn_neuralizer:client:nearbyFlash', function(sourceServerId, targetServerId, sourceCoords)
    if not Config.Effects.sourceFlashNearby then return end

    local myServerId = GetPlayerServerId(PlayerId())
    if myServerId == sourceServerId or myServerId == targetServerId then return end

    local ped = PlayerPedId()
    local myCoords = GetEntityCoords(ped)
    local srcVec = vector3(sourceCoords.x + 0.0, sourceCoords.y + 0.0, sourceCoords.z + 0.0)
    local distance = #(myCoords - srcVec)

    if distance <= Config.Effects.sourceFlashRadius then
        flashScreen(Config.Effects.nearbyFlashMs, 'nearby')
    end
end)

if Config.UseCommand then
    RegisterCommand(Config.CommandName, function()
        useNeuralizer()
    end, false)
end

if Config.Keybind.enabled and Config.UseCommand and Config.Keybind.defaultKey and Config.Keybind.defaultKey ~= '' then
    RegisterKeyMapping(Config.CommandName, Config.Keybind.description, 'keyboard', Config.Keybind.defaultKey)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    deleteHandProp()
end)
