local QBCore = exports['qb-core']:GetCoreObject()
local open = false
local playerData = QBCore.Functions.GetPlayerData() or {}
local lastAutomaticCapture = 0

local function notify(msg, typ)
    QBCore.Functions.Notify(tostring(msg or ''), typ or 'primary')
end

local function isAuthorizedOnDuty()
    local job = playerData.job or {}
    return job.onduty == true and Config.Jobs[job.name] == true
end

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    playerData = data or {}
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    playerData.job = job or {}
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(onDuty)
    playerData.job = playerData.job or {}
    playerData.job.onduty = onDuty == true
end)

RegisterNetEvent('dpn-evidence-ai:client:notify', notify)

local function setOpen(state)
    open = state == true
    SetNuiFocus(open, open)
    SendNUIMessage({ action = open and 'show' or 'hide' })
    if open then TriggerServerEvent('dpn-evidence-ai:server:open') end
end

RegisterCommand(Config.Command, function()
    if not isAuthorizedOnDuty() then
        return notify('You must be on duty with an authorized emergency-services job.', 'error')
    end
    setOpen(not open)
end, false)
RegisterKeyMapping(Config.Command, 'Open DPN Evidence AI', 'keyboard', Config.OpenKey)

RegisterNetEvent('dpn-evidence-ai:client:data', function(data)
    SendNUIMessage({ action = 'data', data = data })
end)

RegisterNetEvent('dpn-evidence-ai:client:courtReport', function(data)
    SendNUIMessage({ action = 'courtReport', data = data })
    setOpen(true)
end)

RegisterNUICallback('close', function(_, cb) setOpen(false); cb(true) end)
RegisterNUICallback('createCase', function(data, cb) TriggerServerEvent('dpn-evidence-ai:server:createCase', data or {}); cb(true) end)
RegisterNUICallback('addEvidence', function(data, cb) TriggerServerEvent('dpn-evidence-ai:server:addEvidence', data or {}); cb(true) end)
RegisterNUICallback('transferCustody', function(data, cb) TriggerServerEvent('dpn-evidence-ai:server:transferCustody', data or {}); cb(true) end)
RegisterNUICallback('status', function(data, cb) TriggerServerEvent('dpn-evidence-ai:server:updateCaseStatus', data.case_id, data.status); cb(true) end)
RegisterNUICallback('court', function(data, cb) TriggerServerEvent('dpn-evidence-ai:server:generateCourtReport', data.case_id); cb(true) end)

RegisterNetEvent('dpn-evidence-ai:client:bookmarkBodycam', function(meta)
    if not isAuthorizedOnDuty() then return end
    TriggerServerEvent('dpn-evidence-ai:server:autoEvidence', {
        type = 'bodycam',
        title = 'Bodycam Bookmark',
        meta = type(meta) == 'table' and meta or {}
    })
end)

CreateThread(function()
    while true do
        Wait(250)
        if Config.AutoEvidence.GunshotCasings and isAuthorizedOnDuty() then
            local ped = PlayerPedId()
            local nowMs = GetGameTimer()
            if IsPedShooting(ped) and nowMs - lastAutomaticCapture >= (Config.AutoEvidenceCooldownMs or 10000) then
                lastAutomaticCapture = nowMs
                local coords = GetEntityCoords(ped)
                local weapon = GetSelectedPedWeapon(ped)
                TriggerServerEvent('dpn-evidence-ai:server:autoEvidence', {
                    type = 'casings',
                    title = 'Weapon Discharge / Casing Evidence',
                    meta = {
                        x = math.floor(coords.x * 100) / 100,
                        y = math.floor(coords.y * 100) / 100,
                        z = math.floor(coords.z * 100) / 100,
                        weapon = weapon
                    },
                    notes = 'Auto-captured firearm discharge location.'
                })
            end
        else
            Wait(750)
        end
    end
end)

-- Public client event for trusted local integrations. Server authorization still applies.
RegisterNetEvent('dpn-evidence-ai:addEvidence', function(data)
    if not isAuthorizedOnDuty() then return end
    TriggerServerEvent('dpn-evidence-ai:server:addEvidence', data or {})
end)
