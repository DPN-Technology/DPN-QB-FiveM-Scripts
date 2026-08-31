local Queue = {}
local ActiveProfiles = {}
local Admitting = {}
local RecentDisconnects = {}
local AttemptHistory = {}
local Serial = 0

local function debugPrint(msg)
    if Config.Debug then
        print(('[dpn-queue] %s'):format(msg))
    end
end

local function now()
    return os.time()
end

local function countTable(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

local function getMaxClients()
    local maxClients = GetConvarInt(Config.MaxClientsConvar or 'sv_maxclients', 32)
    if maxClients < 1 then maxClients = 32 end
    return maxClients
end

local function getReservedSlots()
    local maxClients = getMaxClients()
    local reserved = tonumber(Config.ReservedAdminSlots) or 0
    if reserved < 0 then reserved = 0 end
    if reserved > maxClients then reserved = maxClients end
    return reserved
end

local function getPublicSlots()
    return math.max(getMaxClients() - getReservedSlots(), 0)
end

local function cleanAdmitting()
    local t = now()
    for src, data in pairs(Admitting) do
        if not data.expiresAt or data.expiresAt <= t then
            Admitting[src] = nil
        end
    end
end

local function cleanRecentDisconnects()
    local t = now()
    for identifier, expiresAt in pairs(RecentDisconnects) do
        if expiresAt <= t then
            RecentDisconnects[identifier] = nil
        end
    end
end

local function getActiveCount()
    -- GetPlayers() is preferred here over GetNumPlayerIndices because it returns current player handles.
    return #GetPlayers()
end

local function getUsedSlotCount()
    cleanAdmitting()
    return getActiveCount() + countTable(Admitting)
end

local function getIdentifiers(src)
    local identifiers = {}
    local map = {}

    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        identifiers[#identifiers + 1] = identifier
        map[identifier] = true

        local prefix = identifier:match('^([^:]+):')
        if prefix then
            map[prefix] = identifier
        end
    end

    return identifiers, map
end

local function getPrimaryIdentifier(map, identifiers)
    return map.license or map.fivem or map.steam or map.discord or identifiers[1]
end

local function identifierInList(map, list)
    if type(list) ~= 'table' then return false end

    for _, identifier in ipairs(list) do
        if identifier and map[identifier] then
            return true
        end
    end

    return false
end

local function hasAce(src, permissions)
    if type(permissions) ~= 'table' then return false end

    for _, permission in ipairs(permissions) do
        if permission and permission ~= '' and IsPlayerAceAllowed(src, permission) then
            return true
        end
    end

    return false
end

local function isAdmin(src, map)
    if not Config.Admin or not Config.Admin.Enabled then return false end
    if hasAce(src, Config.Admin.AcePermissions) then return true end
    if identifierInList(map, Config.Admin.Identifiers) then return true end
    return false
end

local function getPriority(map, admin)
    cleanRecentDisconnects()

    local points = tonumber(Config.Priority.Default) or 0
    local labels = {}

    if admin then
        points = points + (tonumber(Config.Priority.Admin) or 0)
        labels[#labels + 1] = 'Admin Reserved'
    end

    local reconnectApplied = false
    for identifier in pairs(map) do
        if type(identifier) == 'string' and identifier:find(':', 1, true) and RecentDisconnects[identifier] then
            points = points + (tonumber(Config.Priority.ReconnectGrace) or 0)
            reconnectApplied = true
            break
        end
    end

    if reconnectApplied then
        labels[#labels + 1] = 'Reconnect Grace'
    end

    if Config.Priority and type(Config.Priority.IdentifierBoosts) == 'table' then
        for identifier, boost in pairs(Config.Priority.IdentifierBoosts) do
            if map[identifier] then
                local boostPoints = tonumber(boost.points) or 0
                points = points + boostPoints
                labels[#labels + 1] = boost.label or ('Boost +' .. boostPoints)
            end
        end
    end

    if #labels == 0 then
        labels[#labels + 1] = 'Standard'
    end

    return points, table.concat(labels, ' + ')
end

local function buildProfile(src, playerName)
    local identifiers, map = getIdentifiers(src)
    local admin = isAdmin(src, map)
    local priority, priorityLabel = getPriority(map, admin)

    return {
        src = src,
        name = playerName or ('Player ' .. tostring(src)),
        identifiers = identifiers,
        identifierMap = map,
        primaryIdentifier = getPrimaryIdentifier(map, identifiers),
        admin = admin,
        priority = priority,
        priorityLabel = priorityLabel
    }
end

local function canAdmit(profile)
    local usedSlots = getUsedSlotCount()
    local maxClients = getMaxClients()

    if usedSlots >= maxClients then
        return false
    end

    -- Admins can use the reserved pool when the public pool is full.
    if profile.admin then
        return true
    end

    return usedSlots < getPublicSlots()
end

local function sortQueue()
    table.sort(Queue, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end

        if a.admin ~= b.admin then
            return a.admin and not b.admin
        end

        if a.joinedAt ~= b.joinedAt then
            return a.joinedAt < b.joinedAt
        end

        return a.serial < b.serial
    end)
end

local function getQueuePosition(queueId)
    sortQueue()
    for index, item in ipairs(Queue) do
        if item.queueId == queueId then
            return index
        end
    end

    return nil
end

local function removeQueueItem(queueId)
    for index = #Queue, 1, -1 do
        if Queue[index].queueId == queueId then
            local item = Queue[index]
            table.remove(Queue, index)
            return item
        end
    end

    return nil
end

local function safeUpdate(item, message)
    if item and item.deferrals and not item.finished then
        item.deferrals.update(message)
    end
end

local function safeDone(item, reason)
    if not item or item.finished then return end
    item.finished = true
    item.cancelled = reason ~= nil

    -- FiveM deferrals require at least a tick between deferral method calls.
    Citizen.Wait(0)
    item.deferrals.done(reason)
end

local function replaceDuplicateQueuedConnection(primaryIdentifier)
    if not Config.ReplaceDuplicateQueueConnection or not primaryIdentifier then return end

    for index = #Queue, 1, -1 do
        local item = Queue[index]
        if item.primaryIdentifier == primaryIdentifier then
            table.remove(Queue, index)
            safeUpdate(item, Config.Messages.DuplicateReplaced)
            safeDone(item, Config.Messages.DuplicateReplaced)
        end
    end
end

local function checkSpam(primaryIdentifier)
    if not Config.Queue.AntiSpamEnabled or not primaryIdentifier then return true end

    local t = now()
    local window = tonumber(Config.Queue.AntiSpamWindowSeconds) or 60
    local maxAttempts = tonumber(Config.Queue.AntiSpamMaxAttempts) or 8

    local history = AttemptHistory[primaryIdentifier]
    if not history or history.windowStartedAt + window < t then
        AttemptHistory[primaryIdentifier] = {
            windowStartedAt = t,
            attempts = 1
        }
        return true
    end

    history.attempts = history.attempts + 1
    return history.attempts <= maxAttempts
end

local function addToQueue(profile, deferrals)
    Serial = Serial + 1

    local item = {
        queueId = ('%s:%d:%d'):format(profile.primaryIdentifier or 'unknown', now(), Serial),
        src = profile.src,
        name = profile.name,
        identifiers = profile.identifiers,
        identifierMap = profile.identifierMap,
        primaryIdentifier = profile.primaryIdentifier,
        admin = profile.admin,
        priority = profile.priority,
        priorityLabel = profile.priorityLabel,
        joinedAt = now(),
        serial = Serial,
        deferrals = deferrals,
        finished = false,
        cancelled = false
    }

    Queue[#Queue + 1] = item
    sortQueue()

    debugPrint(('Queued %s | admin=%s | priority=%d'):format(item.name, tostring(item.admin), item.priority))
    return item
end

local function formatQueueMessage(item, position)
    local active = getUsedSlotCount()
    local maxClients = getMaxClients()
    local publicSlots = getPublicSlots()
    local reservedSlots = getReservedSlots()

    return (Config.Messages.QueueFormat):format(
        Config.Brand,
        position,
        #Queue,
        active,
        maxClients,
        publicSlots,
        reservedSlots,
        item.priorityLabel or 'Standard'
    )
end

local function admit(item)
    local removed = removeQueueItem(item.queueId)
    if not removed then return false end

    Admitting[item.src] = {
        primaryIdentifier = item.primaryIdentifier,
        admin = item.admin,
        expiresAt = now() + (tonumber(Config.Queue.AdmitReserveSeconds) or 45)
    }

    ActiveProfiles[item.src] = {
        primaryIdentifier = item.primaryIdentifier,
        identifiers = item.identifiers,
        admin = item.admin
    }

    safeUpdate(item, Config.Messages.Admitting)
    safeDone(item, nil)

    debugPrint(('Admitted %s | admin=%s'):format(item.name, tostring(item.admin)))
    return true
end

local function queueLoop(item)
    while not item.finished do
        local position = getQueuePosition(item.queueId)

        if not position then
            return
        end

        local heldFor = now() - item.joinedAt
        if heldFor >= (tonumber(Config.Queue.ConnectionHoldTimeoutSeconds) or 900) then
            removeQueueItem(item.queueId)
            safeDone(item, Config.Messages.QueueTimeout)
            return
        end

        if position == 1 and canAdmit(item) then
            admit(item)
            return
        end

        safeUpdate(item, formatQueueMessage(item, position))
        Citizen.Wait((tonumber(Config.Queue.UpdateIntervalSeconds) or 5) * 1000)
    end
end

AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source

    deferrals.defer()
    Citizen.Wait(0)
    deferrals.update(Config.Messages.Checking)
    Citizen.Wait(0)

    local profile = buildProfile(src, playerName)

    if Config.RequireIdentifier and not profile.primaryIdentifier then
        deferrals.done(Config.Messages.MissingIdentifier)
        return
    end

    if not checkSpam(profile.primaryIdentifier) then
        deferrals.done(Config.Messages.TooManyAttempts)
        return
    end

    replaceDuplicateQueuedConnection(profile.primaryIdentifier)

    local item = addToQueue(profile, deferrals)
    queueLoop(item)
end)

AddEventHandler('playerJoining', function()
    local src = source
    Admitting[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    local profile = ActiveProfiles[src]

    if profile then
        local expiresAt = now() + (tonumber(Config.Queue.ReconnectGraceSeconds) or 180)
        if profile.identifiers then
            for _, identifier in ipairs(profile.identifiers) do
                RecentDisconnects[identifier] = expiresAt
            end
        end
    end

    ActiveProfiles[src] = nil
    Admitting[src] = nil
end)


AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for index = #Queue, 1, -1 do
        local item = Queue[index]
        table.remove(Queue, index)
        if item and not item.finished then
            safeUpdate(item, 'DPN Queue is restarting. Please reconnect in a moment.')
            safeDone(item, 'DPN Queue is restarting. Please reconnect in a moment.')
        end
    end
end)

CreateThread(function()
    while true do
        cleanAdmitting()
        cleanRecentDisconnects()
        Citizen.Wait(5000)
    end
end)

local function sendCommandMessage(src, message)
    if src == 0 then
        print(message)
    else
        TriggerClientEvent('chat:addMessage', src, {
            args = { Config.Brand, message }
        })
    end
end

RegisterCommand('dpnqueue', function(src)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.ManageAce) then
        sendCommandMessage(src, 'You do not have permission to use this command.')
        return
    end

    sortQueue()

    local status = ('Status: %d queued | %d/%d used | public slots %d | reserved admin slots %d'):format(
        #Queue,
        getUsedSlotCount(),
        getMaxClients(),
        getPublicSlots(),
        getReservedSlots()
    )

    sendCommandMessage(src, status)

    if #Queue > 0 then
        for index, item in ipairs(Queue) do
            sendCommandMessage(src, ('#%d %s | admin=%s | priority=%d | %s'):format(
                index,
                item.name,
                tostring(item.admin),
                item.priority,
                item.priorityLabel
            ))
        end
    end
end, false)

exports('GetQueueCount', function()
    return #Queue
end)

exports('GetReservedSlots', function()
    return getReservedSlots()
end)

exports('GetPublicSlots', function()
    return getPublicSlots()
end)

exports('GetUsedSlots', function()
    return getUsedSlotCount()
end)
