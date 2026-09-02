local QBCore = exports['qb-core']:GetCoreObject()

-- Server variables
local deployedSpikes = {}
local playerSpikes = {}
local lastDeploymentAt = {}

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

local function IsFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function NormalizeSpikeId(spikeId)
    local numericId = tonumber(spikeId)
    if not IsFiniteNumber(numericId) or numericId <= 0 or numericId % 1 ~= 0 then
        return nil
    end
    return numericId
end

local function NormalizeCoords(coords)
    if coords == nil then return nil end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)
    if not IsFiniteNumber(x) or not IsFiniteNumber(y) or not IsFiniteNumber(z) then
        return nil
    end

    return vector3(x, y, z)
end

local function CountEntries(entries)
    local count = 0
    for _ in pairs(entries or {}) do
        count = count + 1
    end
    return count
end

local function IsDeploymentRateLimited(src)
    local cooldownMs = math.max(0, tonumber(Config.Limits.deploymentCooldown) or 0)
    if cooldownMs <= 0 then return false end

    local now = GetGameTimer()
    local previous = lastDeploymentAt[src]
    if previous and now - previous < cooldownMs then
        return true
    end

    lastDeploymentAt[src] = now
    return false
end

local function IsTooCloseToExistingSpike(coords)
    local minimumDistance = math.max(0.0, tonumber(Config.Limits.minDistanceBetweenSpikes) or 0.0)
    if minimumDistance <= 0.0 then return false end

    for _, spikeData in pairs(deployedSpikes) do
        if spikeData.coords and #(coords - spikeData.coords) < minimumDistance then
            return true
        end
    end

    return false
end

local function RemoveSpike(spikeId)
    local spikeData = deployedSpikes[spikeId]
    if not spikeData then return false end

    deployedSpikes[spikeId] = nil
    if playerSpikes[spikeData.owner] then
        playerSpikes[spikeData.owner][spikeId] = nil
        if not next(playerSpikes[spikeData.owner]) then
            playerSpikes[spikeData.owner] = nil
        end
    end

    TriggerClientEvent('qb-mobilespikes:client:removeSpike', -1, spikeId)
    return true
end

local function CleanupPlayerSpikes(src)
    if not playerSpikes[src] then
        lastDeploymentAt[src] = nil
        return
    end

    local ownedSpikeIds = {}
    for spikeId in pairs(playerSpikes[src]) do
        ownedSpikeIds[#ownedSpikeIds + 1] = spikeId
    end

    for _, spikeId in ipairs(ownedSpikeIds) do
        RemoveSpike(spikeId)
    end

    playerSpikes[src] = nil
    lastDeploymentAt[src] = nil
end

-- Events
RegisterNetEvent('qb-mobilespikes:server:deploySpike', function(coords, heading, spikeId)
    local src = source
    local Player = GetPlayer(src)

    if not Player or not HasAuthorization(src) then return end

    local normalizedSpikeId = NormalizeSpikeId(spikeId)
    local normalizedCoords = NormalizeCoords(coords)
    local normalizedHeading = tonumber(heading)

    if not normalizedSpikeId or not normalizedCoords or not IsFiniteNumber(normalizedHeading) then
        print(('[qb-mobilespikes] Rejected invalid deployment payload from player %s'):format(src))
        return
    end

    if deployedSpikes[normalizedSpikeId] then
        print(('[qb-mobilespikes] Rejected duplicate spike id %s from player %s'):format(normalizedSpikeId, src))
        return
    end

    if IsDeploymentRateLimited(src) then
        return
    end

    local maxGlobal = math.max(0, tonumber(Config.Limits.maxSpikesGlobal) or 0)
    if maxGlobal > 0 and CountEntries(deployedSpikes) >= maxGlobal then
        return
    end

    if not playerSpikes[src] then
        playerSpikes[src] = {}
    end

    local maxPerPlayer = math.max(0, tonumber(Config.Limits.maxSpikesPerPlayer) or 0)
    if maxPerPlayer > 0 and CountEntries(playerSpikes[src]) >= maxPerPlayer then
        return
    end

    if IsTooCloseToExistingSpike(normalizedCoords) then
        return
    end

    local spikeData = {
        coords = normalizedCoords,
        heading = normalizedHeading,
        owner = src,
        netId = normalizedSpikeId,
        timestamp = os.time()
    }

    deployedSpikes[normalizedSpikeId] = spikeData
    playerSpikes[src][normalizedSpikeId] = spikeData

    TriggerClientEvent('qb-mobilespikes:client:syncSpike', -1, normalizedCoords, normalizedHeading, normalizedSpikeId, src)

    print(('[qb-mobilespikes] Player %s (%s) deployed spike strip %s'):format(Player.PlayerData.name, src, normalizedSpikeId))
end)

RegisterNetEvent('qb-mobilespikes:server:removeSpike', function(spikeId)
    local src = source
    local Player = GetPlayer(src)

    if not Player or not HasAuthorization(src) then return end

    local normalizedSpikeId = NormalizeSpikeId(spikeId)
    if not normalizedSpikeId then return end

    local spikeData = deployedSpikes[normalizedSpikeId]
    if not spikeData then return end

    -- Normal client removal is owner-only. Administrative bulk removal remains
    -- available through the permission-protected clearspikes command below.
    if spikeData.owner ~= src then
        print(('[qb-mobilespikes] Rejected removal of spike %s by non-owner player %s'):format(normalizedSpikeId, src))
        return
    end

    if RemoveSpike(normalizedSpikeId) then
        print(('[qb-mobilespikes] Player %s (%s) removed spike strip %s'):format(Player.PlayerData.name, src, normalizedSpikeId))
    end
end)

-- Player disconnect cleanup
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(src)
    CleanupPlayerSpikes(src)
end)

AddEventHandler('playerDropped', function(reason)
    CleanupPlayerSpikes(source)
end)

-- Cleanup old spikes thread
CreateThread(function()
    while true do
        Wait(300000) -- Check every 5 minutes

        if Config.Limits.autoRetractTime > 0 then
            local currentTime = os.time()
            local autoRetractSeconds = Config.Limits.autoRetractTime / 1000
            local expiredSpikeIds = {}

            for spikeId, spikeData in pairs(deployedSpikes) do
                if currentTime - spikeData.timestamp > autoRetractSeconds then
                    expiredSpikeIds[#expiredSpikeIds + 1] = spikeId
                end
            end

            for _, spikeId in ipairs(expiredSpikeIds) do
                if RemoveSpike(spikeId) then
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
    if not Player then return end

    if Player.PlayerData.metadata['jailduration'] > 0 then return end

    if QBCore.Functions.HasPermission(src, 'admin') then
        local clearedCount = CountEntries(deployedSpikes)
        local spikeIds = {}

        for spikeId in pairs(deployedSpikes) do
            spikeIds[#spikeIds + 1] = spikeId
        end

        for _, spikeId in ipairs(spikeIds) do
            RemoveSpike(spikeId)
        end

        deployedSpikes = {}
        playerSpikes = {}
        lastDeploymentAt = {}

        TriggerClientEvent('QBCore:Notify', src, ('Cleared %d spike strips'):format(clearedCount), 'success')
        print(('[qb-mobilespikes] Admin %s cleared all spike strips'):format(Player.PlayerData.name))
    else
        TriggerClientEvent('QBCore:Notify', src, 'You don\'t have permission to use this command', 'error')
    end
end, 'admin')

QBCore.Commands.Add('spikestats', 'Show spike strip statistics (Admin Only)', {}, false, function(source, args)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

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
    if not playerSpikes[src] then return false end
    CleanupPlayerSpikes(src)
    return true
end)

-- Callback for getting spike information
QBCore.Functions.CreateCallback('qb-mobilespikes:server:getSpikeInfo', function(source, cb, spikeId)
    local normalizedSpikeId = NormalizeSpikeId(spikeId)
    if not normalizedSpikeId then
        cb(nil)
        return
    end

    cb(deployedSpikes[normalizedSpikeId])
end)

-- Resource startup
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('[qb-mobilespikes] Mobile Spike System has been started!')
        print('[qb-mobilespikes] Version: 2.0.0')
        print('[qb-mobilespikes] Framework: QBCore')
    end
end)