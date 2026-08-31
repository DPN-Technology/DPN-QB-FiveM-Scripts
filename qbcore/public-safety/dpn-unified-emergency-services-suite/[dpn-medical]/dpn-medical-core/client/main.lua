local QBCore = exports['qb-core']:GetCoreObject()
LocalMedicalState = nil
DPNMedicalClient = DPNMedicalClient or {}
local PlayerData = {}

local function refreshPlayerData() PlayerData = QBCore.Functions.GetPlayerData() or {} end
local function clearVisuals()
    local ped = PlayerPedId()
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    AnimpostfxStopAll()
    TriggerScreenblurFadeOut(0.0)
    SetNightvision(false)
    SetSeethrough(false)
    StopGameplayCamShaking(true)
    ResetPedMovementClipset(ped, 0.25)
    SetPedMoveRateOverride(ped, 1.0)
end

local function hardScreenReset(showNotice)
    clearVisuals()
    local adminOpen = LocalPlayer and LocalPlayer.state and LocalPlayer.state.dpnMedicalAdminOpen == true
    if not adminOpen then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
    SendNUIMessage({ action = 'forceClose' })
    TriggerEvent('dpn-hospital:client:forceCloseUI')
    if IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(0) end
    if showNotice then QBCore.Functions.Notify('DPN Medical screen and controls reset.', 'success') end
end
local function requestState() TriggerServerEvent(DPN_MED.Events.RequestState) end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshPlayerData(); hardScreenReset(false); Wait(500); requestState()
end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}; LocalMedicalState = nil; hardScreenReset(false)
end)
RegisterNetEvent('QBCore:Player:SetPlayerData', function(data) PlayerData = data or {} end)
RegisterNetEvent(DPN_MED.Events.SyncState, function(state)
    LocalMedicalState = DPN_MED.NormalizeState(state)
    if DPNMedicalUI and DPNMedicalUI.Sync then DPNMedicalUI.Sync(LocalMedicalState) end
end)
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    refreshPlayerData(); hardScreenReset(false); Wait(1200); hardScreenReset(false); requestState()
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then hardScreenReset(false) end
end)
CreateThread(function()
    hardScreenReset(false)
    Wait(750)
    hardScreenReset(false)
    Wait(1250)
    refreshPlayerData()
    requestState()
end)

RegisterNetEvent('dpn-medical-core:client:resetScreen', function() hardScreenReset(false) end)
RegisterCommand('medresetui', function() hardScreenReset(true) end, false)
DPNMedicalClient.ClearVisuals = clearVisuals
DPNMedicalClient.HardScreenReset = hardScreenReset
DPNMedicalClient.RequestState = requestState
DPNMedicalClient.GetPlayerData = function() return PlayerData end
exports('GetLocalMedicalState', function() return LocalMedicalState end)
exports('GetMedicalSummary', function() return LocalMedicalState and DPN_MED.GetSummary(LocalMedicalState) or nil end)
exports('GetLifeState', function() return LocalMedicalState and LocalMedicalState.status.lifeState or 'alive' end)
