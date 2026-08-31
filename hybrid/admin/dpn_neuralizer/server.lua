local QBCore = nil
local ESX = nil
local cooldowns = {}
local targetCooldowns = {}
local eventRates = {}
local itemRegistered = false

local function debugPrint(...)
    if Config.Debug then
        print('[DPN Neuralizer:SERVER]', ...)
    end
end

local function consoleLog(message)
    if Config.Logging.enableConsole then
        print(('[DPN Neuralizer] %s'):format(message))
    end
end

local function tryLoadFramework()
    if (Config.Framework == 'auto' or Config.Framework == 'qb') and GetResourceState('qb-core') == 'started' then
        local ok, obj = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok and obj then
            QBCore = obj
            ESX = nil
            debugPrint('QBCore detected')
            return 'qb'
        end
    end

    if (Config.Framework == 'auto' or Config.Framework == 'esx') and GetResourceState('es_extended') == 'started' then
        local ok, obj = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and obj then
            ESX = obj
            QBCore = nil
            debugPrint('ESX detected')
            return 'esx'
        end
    end

    return 'standalone'
end

local function notify(src, message, msgType)
    TriggerClientEvent('dpn_neuralizer:client:notify', src, message, msgType or 'primary')
end

local function getIdentifierMap(src)
    local identifiers = {}
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        identifiers[string.lower(identifier)] = true
    end
    return identifiers
end

local function identifierInList(src, list)
    if not list or #list == 0 then return false end
    local identifiers = getIdentifierMap(src)
    for _, configuredIdentifier in ipairs(list) do
        if identifiers[string.lower(configuredIdentifier)] then
            return true
        end
    end
    return false
end

local function hasQBCorePermission(src, groups)
    if not QBCore or not QBCore.Functions or not QBCore.Functions.HasPermission then return false end
    for _, group in ipairs(groups or {}) do
        local ok, allowed = pcall(function()
            return QBCore.Functions.HasPermission(src, group)
        end)
        if ok and allowed then
            return true
        end
    end
    return false
end

local function hasESXGroup(src, groups)
    if not ESX or not ESX.GetPlayerFromId then return false end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not xPlayer.getGroup then return false end

    local group = string.lower(xPlayer.getGroup() or '')
    for _, allowedGroup in ipairs(groups or {}) do
        if group == string.lower(allowedGroup) then
            return true
        end
    end

    return false
end

local function isAdmin(src)
    if not src or src <= 0 then return false end

    if Config.Security.adminAce and Config.Security.adminAce ~= '' and IsPlayerAceAllowed(src, Config.Security.adminAce) then
        return true
    end

    if identifierInList(src, Config.Security.adminIdentifiers) then
        return true
    end

    if hasQBCorePermission(src, Config.Security.qbAdminGroups) then
        return true
    end

    if hasESXGroup(src, Config.Security.esxAdminGroups) then
        return true
    end

    return false
end

local function canUse(src)
    if Config.Security.requireAceToUse and not IsPlayerAceAllowed(src, Config.Security.useAce) then
        return false, 'You do not have permission to use the neuralizer.'
    end

    return true, nil
end

local function playerExists(src)
    return src and src > 0 and GetPlayerName(src) ~= nil
end

local function distanceBetweenPlayers(src, target)
    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(target)

    if not srcPed or srcPed == 0 or not targetPed or targetPed == 0 then
        return nil
    end

    local a = GetEntityCoords(srcPed)
    local b = GetEntityCoords(targetPed)
    local dx = (a.x or 0.0) - (b.x or 0.0)
    local dy = (a.y or 0.0) - (b.y or 0.0)
    local dz = (a.z or 0.0) - (b.z or 0.0)

    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz)), a, b
end

local function sendWebhook(title, description, color)
    if not Config.Logging.discordWebhook or Config.Logging.discordWebhook == '' then return end

    local payload = {
        username = Config.Logging.webhookName or 'DPN Neuralizer Logs',
        embeds = {
            {
                title = title,
                description = description,
                color = color or 3447003,
                footer = { text = os.date('%Y-%m-%d %H:%M:%S') }
            }
        }
    }

    PerformHttpRequest(Config.Logging.discordWebhook, function() end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json'
    })
end

local function registerFrameworkItem()
    if itemRegistered or not Config.UseAsItem then return end

    local framework = tryLoadFramework()

    if framework == 'qb' and QBCore and QBCore.Functions and QBCore.Functions.CreateUseableItem then
        QBCore.Functions.CreateUseableItem(Config.ItemName, function(source, item)
            TriggerClientEvent('dpn_neuralizer:client:use', source)
        end)
        itemRegistered = true
        consoleLog(('Registered QBCore usable item: %s'):format(Config.ItemName))
        return
    end

    if framework == 'esx' and ESX and ESX.RegisterUsableItem then
        ESX.RegisterUsableItem(Config.ItemName, function(source)
            TriggerClientEvent('dpn_neuralizer:client:use', source)
        end)
        itemRegistered = true
        consoleLog(('Registered ESX usable item: %s'):format(Config.ItemName))
        return
    end

    if framework == 'standalone' then
        consoleLog('Standalone mode active. Use /' .. Config.CommandName .. ' or wire your inventory to dpn_neuralizer:client:use.')
    end
end

CreateThread(function()
    Wait(1000)
    registerFrameworkItem()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= 'qb-core' and resourceName ~= 'es_extended' then return end
    Wait(1500)
    registerFrameworkItem()
end)

RegisterNetEvent('dpn_neuralizer:server:attempt', function(targetServerId)
    local src = source
    targetServerId = tonumber(targetServerId)

    local nowMs = GetGameTimer()
    if eventRates[src] and (nowMs - eventRates[src]) < Config.Security.eventRateLimitMs then
        return
    end
    eventRates[src] = nowMs

    if not playerExists(src) then return end

    local allowed, reason = canUse(src)
    if not allowed then
        TriggerClientEvent('dpn_neuralizer:client:denied', src, reason)
        return
    end

    if not targetServerId or not playerExists(targetServerId) then
        TriggerClientEvent('dpn_neuralizer:client:denied', src, 'Target is no longer available.')
        return
    end

    if targetServerId == src and not Config.Targeting.allowSelfTarget then
        TriggerClientEvent('dpn_neuralizer:client:denied', src, 'You cannot neuralize yourself.')
        return
    end

    local now = os.time()
    if cooldowns[src] and cooldowns[src] > now then
        TriggerClientEvent('dpn_neuralizer:client:denied', src, ('Neuralizer cooling down. Wait %s seconds.'):format(cooldowns[src] - now))
        return
    end

    if targetCooldowns[targetServerId] and targetCooldowns[targetServerId] > now then
        TriggerClientEvent('dpn_neuralizer:client:denied', src, 'That target was just neuralized. Wait a moment.')
        return
    end

    if Config.Security.adminImmunity and isAdmin(targetServerId) then
        TriggerClientEvent('dpn_neuralizer:client:denied', src, 'Denied. Admins are immune to the neuralizer.')

        if Config.Security.notifyImmuneAdminsOnAttempt then
            notify(targetServerId, ('%s attempted to neuralize you, but admin immunity blocked it.'):format(GetPlayerName(src) or src), 'error')
        end

        consoleLog(('%s attempted to neuralize immune admin %s'):format(GetPlayerName(src) or src, GetPlayerName(targetServerId) or targetServerId))
        sendWebhook('Admin Immunity Blocked', ('**%s** attempted to neuralize immune admin **%s**.'):format(GetPlayerName(src) or src, GetPlayerName(targetServerId) or targetServerId), 15158332)
        return
    end

    local sourceCoordsForClients = { x = 0.0, y = 0.0, z = 0.0 }

    if Config.Security.enforceServerDistance then
        local distance, sourceCoords = distanceBetweenPlayers(src, targetServerId)
        if not distance then
            TriggerClientEvent('dpn_neuralizer:client:denied', src, 'Server could not verify target distance.')
            return
        end

        if distance > Config.Security.maxServerDistance then
            TriggerClientEvent('dpn_neuralizer:client:denied', src, 'Target is too far away.')
            return
        end

        sourceCoordsForClients = { x = sourceCoords.x, y = sourceCoords.y, z = sourceCoords.z }
    else
        local srcPed = GetPlayerPed(src)
        if srcPed and srcPed ~= 0 then
            local sourceCoords = GetEntityCoords(srcPed)
            sourceCoordsForClients = { x = sourceCoords.x, y = sourceCoords.y, z = sourceCoords.z }
        end
    end

    cooldowns[src] = now + Config.Security.cooldownSeconds
    targetCooldowns[targetServerId] = now + Config.Security.targetCooldownSeconds

    local srcName = GetPlayerName(src) or ('ID ' .. tostring(src))
    local targetName = GetPlayerName(targetServerId) or ('ID ' .. tostring(targetServerId))

    TriggerClientEvent('dpn_neuralizer:client:sourceConfirmed', src, targetName)
    TriggerClientEvent('dpn_neuralizer:client:receive', targetServerId, src)
    TriggerClientEvent('dpn_neuralizer:client:nearbyFlash', -1, src, targetServerId, sourceCoordsForClients)

    consoleLog(('%s neuralized %s'):format(srcName, targetName))
    sendWebhook('Neuralizer Fired', ('**%s** neuralized **%s**.'):format(srcName, targetName), 3066993)
end)

exports('IsAdminImmune', function(src)
    return isAdmin(src)
end)
