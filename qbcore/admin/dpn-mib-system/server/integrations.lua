local QBCore = exports['qb-core']:GetCoreObject()

function SendEmergencyPing(src, msg)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local coords = GetEntityCoords(GetPlayerPed(src))
    local data = {
        title = 'MIB Federal Support Request',
        message = msg or 'Federal MIB unit requesting emergency support.',
        coords = coords,
        job = { 'police', 'ambulance', 'fire', 'mib' }
    }
    if Config.Integrations.PsDispatch and GetResourceState('ps-dispatch') == 'started' then
        exports['ps-dispatch']:CustomAlert(data)
    elseif Config.Integrations.CdDispatch and GetResourceState('cd_dispatch') == 'started' then
        TriggerClientEvent('cd_dispatch:AddNotification', -1, {
            job_table = { 'police', 'ambulance', 'fire' },
            coords = coords,
            title = data.title,
            message = data.message,
            flash = 1,
            unique_id = tostring(math.random(1000000,9999999)),
            blip = { sprite = 487, scale = 1.2, colour = 0, flashes = true, text = 'MIB Support', time = 5, sound = 1 }
        })
    else
        for _, id in pairs(QBCore.Functions.GetPlayers()) do
            local T = QBCore.Functions.GetPlayer(id)
            if T and T.PlayerData.job and ({ police=true, ambulance=true, fire=true, mib=true })[T.PlayerData.job.name] then
                TriggerClientEvent('dpn-mib:client:emergencyPing', id, coords, data.message)
            end
        end
    end
end
