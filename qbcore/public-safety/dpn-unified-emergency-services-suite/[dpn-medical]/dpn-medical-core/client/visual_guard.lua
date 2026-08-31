local QBCore = exports['qb-core']:GetCoreObject()

DPNMedicalVisualSafety = DPNMedicalVisualSafety or {}

local armedUntil = 0
local fadedSince = 0
local lastClosePulse = 0

local function now()
    return GetGameTimer()
end

local function options()
    return Config.VisualSafety or {}
end

local function clearVisualLayer()
    local cfg = options()

    if cfg.clearTimecycles ~= false then
        ClearTimecycleModifier()
        ClearExtraTimecycleModifier()
    end

    if cfg.clearPostFx ~= false then
        AnimpostfxStopAll()
        StopGameplayCamShaking(true)
    end

    if cfg.clearScreenBlur ~= false then
        TriggerScreenblurFadeOut(0.0)
    end

    if cfg.disableNightVision ~= false then
        SetNightvision(false)
    end

    if cfg.disableThermalVision ~= false then
        SetSeethrough(false)
    end
end

local function closeDpnInterfaces()
    local adminOpen = LocalPlayer and LocalPlayer.state and LocalPlayer.state.dpnMedicalAdminOpen == true
    if not adminOpen then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
    SendNUIMessage({ action = 'forceClose' })
    TriggerEvent('dpn-medical-core:client:forceCloseUI')
    TriggerEvent('dpn-hospital:client:forceCloseUI')
end

local function arm(durationMs, closeInterfaces)
    local cfg = options()
    local duration = math.max(1000, tonumber(durationMs) or tonumber(cfg.startupResetMs) or 20000)
    armedUntil = math.max(armedUntil, now() + duration)

    clearVisualLayer()
    if closeInterfaces == true then closeDpnInterfaces() end
end

local function fullReset(showNotice)
    local ped = PlayerPedId()

    arm(tonumber(options().startupResetMs) or 20000, true)
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)
    ResetPedMovementClipset(ped, 0.0)
    ResetPedWeaponMovementClipset(ped)
    ResetPedStrafeClipset(ped)
    SetPedMoveRateOverride(ped, 1.0)

    if IsScreenFadedOut() or IsScreenFadingOut() then
        DoScreenFadeIn(0)
    end

    if showNotice and QBCore and QBCore.Functions then
        QBCore.Functions.Notify('DPN Medical visual layer fully reset.', 'success')
    end
end

DPNMedicalVisualSafety.Arm = arm
DPNMedicalVisualSafety.Reset = fullReset
DPNMedicalVisualSafety.Clear = clearVisualLayer

RegisterNetEvent('dpn-medical-core:client:aggressiveVisualReset', function()
    fullReset(false)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    arm(nil, true)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    fullReset(false)
end)

RegisterNetEvent(DPN_MED.Events.ReviveClient, function()
    arm(nil, true)
end)

RegisterNetEvent(DPN_MED.Events.RespawnClient, function()
    arm(nil, true)
end)

RegisterNetEvent('dpn-hospital:client:admitted', function()
    arm(8000, false)
end)

RegisterNetEvent('dpn-hospital:client:discharged', function()
    arm(nil, true)
end)

RegisterCommand('dpnvisualreset', function()
    fullReset(true)
end, false)

RegisterCommand('fixmedicalscreen', function()
    fullReset(true)
end, false)

CreateThread(function()
    arm(nil, true)

    while true do
        local cfg = options()
        local current = now()
        local active = cfg.enabled ~= false and (cfg.continuous == true or current < armedUntil)

        if active then
            clearVisualLayer()

            -- A legitimate DPN fade completes in under a second. If the screen remains
            -- faded for several seconds, a previous callback failed before fading back in.
            if IsScreenFadedOut() or IsScreenFadingOut() then
                if fadedSince == 0 then fadedSince = current end
                if current - fadedSince >= (tonumber(cfg.fadedScreenRecoveryMs) or 3000) then
                    DoScreenFadeIn(0)
                    fadedSince = 0
                end
            else
                fadedSince = 0
            end

            -- During startup/recovery, periodically close only DPN interfaces. This does
            -- not interfere with phones, inventory, MDT, or other unrelated NUI resources.
            if current < armedUntil and current - lastClosePulse >= 1000 then
                lastClosePulse = current
                SendNUIMessage({ action = 'forceClose' })
                TriggerEvent('dpn-hospital:client:forceCloseUI')
            end

            Wait(math.max(50, tonumber(cfg.intervalMs) or 250))
        else
            fadedSince = 0
            Wait(1000)
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        arm(nil, true)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        clearVisualLayer()
        closeDpnInterfaces()
    end
end)
