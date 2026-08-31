local QBCore = exports['qb-core']:GetCoreObject()

-- Server variables
local deployedSpikes = {}
local playerSpikes = {}

-- Helper functions
local function GetPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

local function HasAuthorization(src)
    local Player = GetPlayer(src)
    if not Player then return false end
    
    local job = Player.PlayerData.job
    if not job then return false end
    
    local authorizedJob = Config.AuthorizedJobs[job.name]
    if not authorizedJob then return false end
    
    for _, grade in ipairs(authorizedJob.grades) do
        if job.grade.level == grade then
            return true
        end
    end
    
    return false
end

-- Events
RegisterNetEvent('qb-mobilespikes:server:deploySpike', function(coords, heading, spikeId)
    local src = source
    local Player = GetPlayer(src)
    
    if not Player then return end
    if not HasAuthorization(src) then return end
    
    -- Store spike data
    local spikeData = {
        coords = coords,
        heading = heading,
        owner = src,
        netId = spikeId,
        timestamp = os.time()
    }
    
    deployedSpikes[spikeId] = spikeData
    
    if not playerSpikes[src] then
        playerSpikes[src] = {}
    end
    playerSpikes[src][spikeId] = spikeData
    
    -- Sync with all clients
    TriggerClientEvent('qb-mobilespikes:client:syncSpike', -1, coords, heading, spikeId, src)
    
    -- Log deployment
    print(('[qb-mobilespikes] Player %s (%s) deployed spike strip %s'):format(Player.PlayerData.name, src, spikeId))
end)

RegisterNetEvent('qb-mobilespikes:server:removeSpike', function(spikeId)
    local src = source
    local Player = GetPlayer(src)
    
    if not Player then return end
    
    -- Remove from global spikes
    if deployedSpikes[spikeId] then
        deployedSpikes[spikeId] = nil
    end
    
    -- Remove from player spikes
    if playerSpikes[src] and playerSpikes[src][spikeId] then
        playerSpikes[src][spikeId] = nil
    end
    
    -- Sync removal with all clients
    TriggerClientEvent('qb-mobilespikes:client:removeSpike', -1, spikeId)
    
    -- Log removal
    print(('[qb-mobilespikes] Player %s (%s) removed spike strip %s'):format(Player.PlayerData.name, src, spikeId))
end)

-- Player disconnect cleanup
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(src)
    if playerSpikes[src] then
        for spikeId, _ in pairs(playerSpikes[src]) do
            -- Remove from global spikes
            deployedSpikes[spikeId] = nil
            -- Sync removal with clients
            TriggerClientEvent('qb-mobilespikes:client:removeSpike', -1, spikeId)
        end
        playerSpikes[src] = nil
    end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    if playerSpikes[src] then
        for spikeId, _ in pairs(playerSpikes[src]) do
            deployedSpikes[spikeId] = nil
            TriggerClientEvent('qb-mobilespikes:client:removeSpike', -1, spikeId)
        end
        playerSpikes[src] = nil
    end
end)

-- Cleanup old spikes thread
CreateThread(function()
    while true do
        Wait(300000) -- Check every 5 minutes
        
        if Config.Limits.autoRetractTime > 0 then
            local currentTime = os.time()
            local autoRetractSeconds = Config.Limits.autoRetractTime / 1000
            
            for spikeId, spikeData in pairs(deployedSpikes) do
                if currentTime - spikeData.timestamp > autoRetractSeconds then
                    -- Remove expired spike
                    deployedSpikes[spikeId] = nil
                    
                    -- Remove from player spikes
                    if playerSpikes[spikeData.owner] then
                        playerSpikes[spikeData.owner][spikeId] = nil
                    end
                    
                    -- Sync removal
                    TriggerClientEvent('qb-mobilespikes:client:removeSpike', -1, spikeId)
                    
                    print(('[qb-mobilespikes] Auto-removed expired spike strip %s'):format(spikeId))
                end
            end
        end
    end
end)

-- Admin commands
QBCore.Commands.Add('clearspikes', 'Clear all deployed spike strips (Admin Only)', {}, false, function(source, args)
    local src = source
    local Player = GetPlayer(src)
    
    if Player.PlayerData.metadata['jailduration'] > 0 then return end
    
    -- Check admin permission
    if QBCore.Functions.HasPermission(src, 'admin') then
        local clearedCount = 0
        
        for spikeId, _ in pairs(deployedSpikes) do
            TriggerClientEvent('qb-mobilespikes:client:removeSpike', -1, spikeId)
            clearedCount = clearedCount + 1
        end
        
        deployedSpikes = {}
        playerSpikes = {}
        
        TriggerClientEvent('QBCore:Notify', src, ('Cleared %d spike strips'):format(clearedCount), 'success')
        print(('[qb-mobilespikes] Admin %s cleared all spike strips'):format(Player.PlayerData.name))
    else
        TriggerClientEvent('QBCore:Notify', src, 'You don\'t have permission to use this command', 'error')
    end
end, 'admin')

QBCore.Commands.Add('spikestats', 'Show spike strip statistics (Admin Only)', {}, false, function(source, args)
    local src = source
    local Player = GetPlayer(src)
    
    if QBCore.Functions.HasPermission(src, 'admin') then
        local totalSpikes = 0
        local playerCounts = {}
        
        for _, spikeData in pairs(deployedSpikes) do
            totalSpikes = totalSpikes + 1
            local owner = spikeData.owner
            playerCounts[owner] = (playerCounts[owner] or 0) + 1
        end
        
        TriggerClientEvent('QBCore:Notify', src, ('Total Spikes: %d | Max Global: %d'):format(totalSpikes, Config.Limits.maxSpikesGlobal), 'primary')
        
        for playerId, count in pairs(playerCounts) do
            local TargetPlayer = GetPlayer(playerId)
            if TargetPlayer then
                TriggerClientEvent('QBCore:Notify', src, ('Player %s: %d spikes'):format(TargetPlayer.PlayerData.name, count), 'primary')
            end
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'You don\'t have permission to use this command', 'error')
    end
end, 'admin')

-- Export functions for other resources
exports('GetDeployedSpikes', function()
    return deployedSpikes
end)

exports('GetPlayerSpikes', function(src)
    return playerSpikes[src] or {}
end)

exports('RemovePlayerSpikes', function(src)
    if playerSpikes[src] then
        for spikeId, _ in pairs(playerSpikes[src]) do
            deployedSpikes[spikeId] = nil
            TriggerClientEvent('qb-mobilespikes:client:removeSpike', -1, spikeId)
        end
        playerSpikes[src] = nil
        return true
    end
    return false
end)

-- Callback for getting spike information
QBCore.Functions.CreateCallback('qb-mobilespikes:server:getSpikeInfo', function(source, cb, spikeId)
    local spikeData = deployedSpikes[spikeId]
    cb(spikeData)
end)

-- Resource startup
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('[qb-mobilespikes] Mobile Spike System has been started!')
        print('[qb-mobilespikes] Version: 2.0.0')
        print('[qb-mobilespikes] Framework: QBCore')
    end
end)