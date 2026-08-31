local QBCore = exports['qb-core']:GetCoreObject()

DPNMedicalUI = DPNMedicalUI or {}

local hudEnabled = Config.UI.defaultHudEnabled
local uiOpen = false
local inspectedTarget = nil
local inspectedState = nil

local function treatmentsForUi()
    local result = {}
    for key, value in pairs(Config.Treatments) do
        result[#result + 1] = {
            id = key,
            label = value.label,
            level = value.level,
            global = value.global == true,
            limbOnly = value.limbOnly == true
        }
    end
    table.sort(result, function(a, b) return a.label < b.label end)
    return result
end

local function sendState(action, state, target, selfView)
    SendNUIMessage({
        action = action,
        state = state,
        target = target,
        selfView = selfView,
        hudEnabled = hudEnabled,
        bodyMeta = Config.BodyParts,
        treatments = treatmentsForUi()
    })
end

local function adminDashboardOpen()
    return LocalPlayer and LocalPlayer.state and LocalPlayer.state.dpnMedicalAdminOpen == true
end

local function closeUi()
    local ownedFocus = uiOpen == true
    uiOpen = false
    inspectedTarget = nil
    inspectedState = nil
    if ownedFocus and not adminDashboardOpen() then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
    SendNUIMessage({ action = 'forceClose' })
end

local function openPatient(target)
    target = tonumber(target)
    QBCore.Functions.TriggerCallback('dpn-medical-core:server:getPatientState', function(state, errorMessage)
        if not state then return QBCore.Functions.Notify(errorMessage or 'Unable to load patient.', 'error') end
        inspectedTarget = target
        inspectedState = DPN_MED.NormalizeState(state)
        uiOpen = true
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        sendState('open', inspectedState, inspectedTarget, inspectedTarget == GetPlayerServerId(PlayerId()))
    end, target)
end

local function closestServerId()
    local player, distance = QBCore.Functions.GetClosestPlayer()
    if player == -1 or not distance or distance > Config.Security.maxInspectDistance then return nil end
    return GetPlayerServerId(player)
end

RegisterCommand(Config.UI.openCommand, function()
    openPatient(GetPlayerServerId(PlayerId()))
end, false)

RegisterCommand(Config.UI.inspectCommand, function(_, args)
    local target = tonumber(args[1]) or closestServerId()
    if not target then return QBCore.Functions.Notify('No nearby patient found.', 'error') end
    openPatient(target)
end, false)

RegisterCommand(Config.UI.hudCommand, function()
    hudEnabled = not hudEnabled
    SendNUIMessage({ action = 'hud', enabled = hudEnabled, state = LocalMedicalState })
    QBCore.Functions.Notify(('Medical HUD %s.'):format(hudEnabled and 'enabled' or 'disabled'), 'primary')
end, false)

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    if inspectedTarget then openPatient(inspectedTarget) end
    cb({ ok = true })
end)

RegisterNUICallback('treat', function(data, cb)
    if not inspectedTarget then return cb({ ok = false, error = 'No patient selected' }) end
    local treatmentType = type(data) == 'table' and tostring(data.treatment or '') or ''
    local part = type(data) == 'table' and data.part or nil
    if not Config.Treatments[treatmentType] then return cb({ ok = false, error = 'Invalid treatment' }) end
    if part ~= nil and not Config.BodyParts[part] then return cb({ ok = false, error = 'Invalid body part' }) end

    TriggerServerEvent(DPN_MED.Events.TreatPart, inspectedTarget, part, { type = treatmentType })
    SetTimeout(700, function()
        if inspectedTarget then openPatient(inspectedTarget) end
    end)
    cb({ ok = true })
end)

function DPNMedicalUI.Sync(state)
    if hudEnabled then SendNUIMessage({ action = 'hud', enabled = true, state = state }) end
    if uiOpen and inspectedTarget == GetPlayerServerId(PlayerId()) then
        inspectedState = state
        sendState('sync', state, inspectedTarget, true)
    end
end

CreateThread(function()
    SendNUIMessage({ action = 'forceClose' })
    Wait(1000)
    SendNUIMessage({ action = 'hud', enabled = hudEnabled, state = LocalMedicalState })
end)


function DPNMedicalUI.IsOpen()
    return uiOpen == true
end

RegisterNetEvent('dpn-medical-core:client:forceCloseUI', function()
    closeUi()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then closeUi() end
end)
