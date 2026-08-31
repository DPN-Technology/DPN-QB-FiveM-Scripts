local QBCore = exports['qb-core']:GetCoreObject()
local playerCooldowns = {} -- Table for per-player cooldowns

-- Server event to handle doorbell ring
RegisterNetEvent('qb-pd-doorbell:ringBell', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Cooldown check
    local currentTime = os.time() * 1000
    if playerCooldowns[src] and currentTime - playerCooldowns[src] < Config.Cooldown then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait before ringing again.', 'error', 2000)
        return
    end
    playerCooldowns[src] = currentTime

    -- Check if player is at reception (server-side validation)
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    if #(playerCoords - Config.PDReception) > Config.InteractDistance then
        TriggerClientEvent('QBCore:Notify', src, 'You must be at the reception desk!', 'error', 2000)
        return
    end

    -- Check if player is police (can't ring if on-duty)
    if Player.PlayerData.job.name == Config.PoliceJob and Player.PlayerData.job.onduty then
        TriggerClientEvent('QBCore:Notify', src, 'Police don\'t need to ring the bell.', 'error', 2000)
        return
    end

    -- Notify the ringer and play sound
    TriggerClientEvent('qb-pd-doorbell:playSound', src)

    -- Notify all on-duty police
    local notifiedCount = 0
    for _, playerId in ipairs(GetPlayers()) do
        playerId = tonumber(playerId)
        local PolicePlayer = QBCore.Functions.GetPlayer(playerId)
        if PolicePlayer and PolicePlayer.PlayerData.job.name == Config.PoliceJob and 
           PolicePlayer.PlayerData.job.onduty and PolicePlayer.PlayerData.job.grade.level >= Config.RequiredGrade then
            TriggerClientEvent('QBCore:Notify', playerId, Config.PoliceNotifyMessage, 'primary', 5000)
            -- Optional: Add blip to reception for police
            TriggerClientEvent('qb-pd-doorbell:addBlip', playerId)
            notifiedCount = notifiedCount + 1
        end
    end

    -- Optional: Log to console
    print(('PD Doorbell rung by %s (ID: %d). Notified %d officers.'):format(Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname, src, notifiedCount))
end)

-- Clean up cooldowns on player disconnect
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(source)
    playerCooldowns[source] = nil
end)

-- Optional: Remove blip after 30s (client-side event)
-- This is triggered per police player; handle in client.lua if adding blip