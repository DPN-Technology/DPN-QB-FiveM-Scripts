local QBCore = exports['qb-core']:GetCoreObject()

PlayerAdmission = nil
HospitalBeds = {}

local dataLoaded = false
local placingInBed = false
local PlacePlayerInBed

DPNHospitalUI = DPNHospitalUI or { open = false }

local function safeFadeOut(duration)
    duration = tonumber(duration) or 300
    DoScreenFadeOut(duration)
    local timeout = GetGameTimer() + math.max(1500, duration + 1000)
    while not IsScreenFadedOut() and GetGameTimer() < timeout do Wait(0) end
end

local function safeFadeIn(duration)
    DoScreenFadeIn(tonumber(duration) or 500)
end

local function releaseNuiFocus()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end

local function adminDashboardOpen()
    return LocalPlayer and LocalPlayer.state and LocalPlayer.state.dpnMedicalAdminOpen == true
end

local function closeHospitalUI(forceFocusRelease)
    local ownedFocus = DPNHospitalUI.open == true
    DPNHospitalUI.open = false
    if forceFocusRelease == true or (ownedFocus and not adminDashboardOpen()) then
        releaseNuiFocus()
    end
    SendNUIMessage({ action = 'forceClose' })
end

local function syncHospitalUI(action)
    SendNUIMessage({
        action = action or 'sync',
        admission = PlayerAdmission,
        beds = HospitalBeds,
        wardLabels = WardLabels,
        stateLabels = HospitalStateLabels
    })
end

DPNHospitalUI.Close = closeHospitalUI
DPNHospitalUI.Sync = syncHospitalUI

local bedBoundStates = {
    [HospitalStates.ADMITTED] = true,
    [HospitalStates.TREATING] = true,
    [HospitalStates.SURGERY_REQUIRED] = true,
    [HospitalStates.IN_SURGERY] = true
}

local function RefreshHospitalData()
    if dataLoaded then return end
    dataLoaded = true

    QBCore.Functions.TriggerCallback('dpn-hospital:server:getBeds', function(beds)
        HospitalBeds = beds or {}
        SendNUIMessage({ action = 'syncBeds', beds = HospitalBeds })
    end)

    QBCore.Functions.TriggerCallback('dpn-hospital:server:getAdmission', function(admission, bed)
        PlayerAdmission = admission
        if admission then
            if bed and bedBoundStates[admission.status] then PlacePlayerInBed(bed) end
            SendNUIMessage({
                action = 'sync',
                admission = admission,
                beds = HospitalBeds,
                wardLabels = WardLabels,
                stateLabels = HospitalStateLabels
            })
        end
    end)
end

PlacePlayerInBed = function(bed)
    if placingInBed or not bed or not bed.coords then return end
    placingInBed = true

    local ped = PlayerPedId()
    safeFadeOut(350)

    local ok, err = pcall(function()
        ClearPedTasksImmediately(ped)
        SetEntityCoordsNoOffset(ped, bed.coords.x, bed.coords.y, bed.coords.z - 1.0, false, false, false)
        SetEntityHeading(ped, bed.coords.w or 0.0)
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_SUNBATHE_BACK', 0, true)
        Wait(250)
    end)

    safeFadeIn(500)
    placingInBed = false
    if not ok then print(('[dpn-medical-hospital] bed placement failed: %s'):format(err)) end
end


RegisterNetEvent('dpn-hospital:client:forceCloseUI', function()
    closeHospitalUI()
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    dataLoaded = false
    RefreshHospitalData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerAdmission = nil
    HospitalBeds = {}
    dataLoaded = false
    closeHospitalUI(true)
end)

RegisterNetEvent('dpn-hospital:client:syncBeds', function(beds)
    HospitalBeds = beds or {}
    SendNUIMessage({ action = 'syncBeds', beds = HospitalBeds })
end)

RegisterNetEvent('dpn-hospital:client:updateAdmission', function(admission)
    PlayerAdmission = admission

    if admission and admission.status == HospitalStates.RECOVERY and (tonumber(admission.remaining_minutes) or 0) <= 0 then
        ClearPedTasks(PlayerPedId())
    end

    SendNUIMessage({
        action = 'sync',
        admission = admission,
        beds = HospitalBeds,
        wardLabels = WardLabels,
        stateLabels = HospitalStateLabels
    })
end)

RegisterNetEvent('dpn-hospital:client:admitted', function(admission, bed)
    PlayerAdmission = admission

    if admission and bedBoundStates[admission.status] and bed and bed.coords then
        PlacePlayerInBed(bed)
    end

    -- Admission must never auto-open a full-screen NUI. The old behavior displayed
    -- the overlay without focus, producing a dark/brown screen that could not be closed.
    syncHospitalUI('sync')
    QBCore.Functions.Notify('Hospital admission synchronized. Press F7 to view your patient portal.', 'primary')
end)

RegisterNetEvent('dpn-hospital:client:discharged', function(discharge)
    PlayerAdmission = nil

    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)
    ClearTimecycleModifier()
    SetEntityHealth(ped, math.max(1, math.min(GetEntityMaxHealth(ped), tonumber(Config.DischargeHealth) or 180)))
    SetPedArmour(ped, math.max(0, tonumber(Config.DischargeArmor) or 0))

    if discharge and discharge.x and discharge.y and discharge.z then
        safeFadeOut(300)
        local ok, err = pcall(function()
            SetEntityCoordsNoOffset(ped, discharge.x, discharge.y, discharge.z - 1.0, false, false, false)
            SetEntityHeading(ped, discharge.w or 0.0)
            Wait(150)
        end)
        safeFadeIn(500)
        if not ok then print(('[dpn-medical-hospital] discharge teleport failed: %s'):format(err)) end
    end

    closeHospitalUI()
    SendNUIMessage({ action = 'discharged' })
    QBCore.Functions.Notify('You have been discharged from the hospital.', 'success')
end)

RegisterCommand(Config.Commands.status or 'hospitalstatus', function()
    DPNHospitalUI.open = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    syncHospitalUI('open')
end, false)

RegisterKeyMapping(Config.Commands.status or 'hospitalstatus', 'Open Hospital Status', 'keyboard', 'F7')

CreateThread(function()
    closeHospitalUI()
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(1000)
    closeHospitalUI()
    RefreshHospitalData()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeHospitalUI()
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
end)
