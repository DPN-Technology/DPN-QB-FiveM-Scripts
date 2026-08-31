local Officers = {}
local LocalCalls = {}
local Restrained = {}
local Escorting = {}
local RateLimits = {}
local LocalCallCounter = 0

math.randomseed(os.time())

local function now()
    return os.time()
end

local function debugPrint(...)
    if Config.Debug then print('^3[dpn-le-core:server]^7', ...) end
end

local function cleanString(value, maxLength)
    local text = tostring(value or '')
    text = text:gsub('[%z\1-\8\11\12\14-\31]', '')
    maxLength = maxLength or Config.Security.MaxStringLength
    if #text > maxLength then text = text:sub(1, maxLength) end
    return text
end

local function webhook(url, title, description, color)
    if not Config.Webhooks.Enabled or not url or url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = 'DPN Law Enforcement Network',
        embeds = {{
            title = title,
            description = description,
            color = color or 3447003,
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') }
        }}
    }), { ['Content-Type'] = 'application/json' })
end

local function rateAllowed(src, action)
    if src <= 0 then return true end
    local stamp = now()
    RateLimits[src] = RateLimits[src] or {}
    local bucket = RateLimits[src][action]
    if not bucket or stamp - bucket.started >= Config.Security.RateWindowSeconds then
        RateLimits[src][action] = { started = stamp, count = 1 }
        return true
    end
    bucket.count = bucket.count + 1
    return bucket.count <= Config.Security.MaxActionsPerWindow
end

local function playerExists(src)
    src = tonumber(src)
    return src and src > 0 and GetPlayerName(src) ~= nil
end

local function withinDistance(src, target, maxDistance)
    if not playerExists(src) or not playerExists(target) then return false end
    local sourcePed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(target)
    if sourcePed <= 0 or targetPed <= 0 then return false end
    local sourceCoords = GetEntityCoords(sourcePed)
    local targetCoords = GetEntityCoords(targetPed)
    return #(sourceCoords - targetCoords) <= (maxDistance or Config.Interactions.MaxDistance)
end

local function actionAllowed(src, lawOnly)
    if not rateAllowed(src, 'law-action') then
        DPNBridge.Notify(src, 'Too many actions. Slow down and try again.', 'error')
        return false
    end
    local allowed = DPNBridge.IsAllowed(src, true, lawOnly ~= false)
    if not allowed then
        DPNBridge.Notify(src, Config.RequireOnDuty and 'You must be an on-duty law enforcement officer.' or 'Law enforcement access denied.', 'error')
        return false
    end
    return true
end

local function getDefaultUnit(job, src)
    local definition = Config.AllowedJobs[job] or {}
    return ('%s-%s'):format(definition.defaultUnitPrefix or string.upper(job:sub(1, 3)), src)
end

local function serializeOfficer(src)
    local allowed, job, grade, label, onDuty = DPNBridge.IsAllowed(src, false, false)
    if not allowed then return nil end
    local previous = Officers[src]
    return {
        source = src,
        identifier = DPNBridge.GetIdentifier(src),
        name = DPNBridge.GetPlayerName(src),
        job = job,
        jobLabel = label,
        grade = grade,
        onDuty = onDuty,
        status = previous and previous.status or (onDuty and Config.DefaultStatus or '10-7'),
        unit = previous and previous.unit or getDefaultUnit(job, src),
        supervisor = DPNBridge.IsSupervisor(src),
        coords = previous and previous.coords or nil,
        lastSeen = now()
    }
end

local function dispatchStarted()
    return GetResourceState(Config.DispatchResource) == 'started'
end

local function getDispatchCalls()
    if dispatchStarted() then
        local ok, calls = pcall(function()
            return exports[Config.DispatchResource]:GetActiveCalls()
        end)
        if ok and type(calls) == 'table' then return calls end
    end
    return LocalCalls
end

local function getDispatchUnits()
    if dispatchStarted() then
        local ok, units = pcall(function()
            return exports[Config.DispatchResource]:GetUnits()
        end)
        if ok and type(units) == 'table' then return units end
    end
    return Officers
end

local function stateRecipients()
    local recipients = {}
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and DPNBridge.IsAllowed(src, true, false) then recipients[#recipients + 1] = src end
    end
    return recipients
end

local function broadcastState(target)
    local payload = { dispatchUnits = getDispatchUnits() }
    target = tonumber(target)
    if target then
        if DPNBridge.IsAllowed(target, true, false) then
            TriggerClientEvent('dpn-le-core:client:syncState', target, Officers, getDispatchCalls(), payload)
        end
        return
    end
    for _, src in ipairs(stateRecipients()) do
        TriggerClientEvent('dpn-le-core:client:syncState', src, Officers, getDispatchCalls(), payload)
    end
end

local function broadcastAuthorized(eventName, ...)
    for _, src in ipairs(stateRecipients()) do TriggerClientEvent(eventName, src, ...) end
end

local function saveOfficerLog(officer, action)
    if GetResourceState('oxmysql') ~= 'started' or not officer then return end
    MySQL.insert('INSERT INTO dpn_le_officer_logs (identifier, name, job, unit, status, action, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())', {
        officer.identifier, officer.name, officer.job, officer.unit, officer.status, action or 'UPDATE'
    })
end

local function saveActionLog(src, action, target, details)
    if GetResourceState('oxmysql') == 'started' then
        MySQL.insert('INSERT INTO dpn_le_action_logs (officer_cid, officer_name, action, target_cid, target_name, details, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())', {
            src > 0 and DPNBridge.GetIdentifier(src) or 'SYSTEM',
            src > 0 and DPNBridge.GetPlayerName(src) or 'DPN System',
            action,
            target and DPNBridge.GetIdentifier(target) or nil,
            target and DPNBridge.GetPlayerName(target) or nil,
            json.encode(details or {})
        })
    end
    webhook(Config.Webhooks.EnforcementActions, action, ('Officer: %s\nTarget: %s\n```json\n%s\n```'):format(
        src > 0 and DPNBridge.GetPlayerName(src) or 'DPN System',
        target and DPNBridge.GetPlayerName(target) or 'N/A',
        json.encode(details or {})
    ), 3447003)
    TriggerEvent('dpn-le-core:server:actionLogged', src, action, target, details or {})
    TriggerEvent('dpn-le-operations:server:coreAction', src, action, target, details or {})
end

local function registerOfficer(src)
    src = tonumber(src)
    if not src or src <= 0 then return false end
    local officer = serializeOfficer(src)
    if not officer then
        Officers[src] = nil
        return false
    end
    Officers[src] = officer
    saveOfficerLog(officer, 'REGISTER')
    broadcastState()
    return true
end

local function createLocalCall(data, createdBy)
    LocalCallCounter = LocalCallCounter + 1
    local callId = ('LOCAL-%06d'):format(LocalCallCounter)
    local call = {
        callId = callId,
        id = callId,
        type = cleanString(data.type or 'general', 32),
        title = cleanString(data.title or 'New Dispatch Call', 128),
        description = cleanString(data.description or 'No details provided.'),
        priority = math.max(1, math.min(5, tonumber(data.priority) or 3)),
        coords = data.coords,
        createdAt = now(),
        createdBy = createdBy or 'system',
        assigned = {},
        status = 'active',
        metadata = type(data.metadata) == 'table' and data.metadata or {}
    }
    LocalCalls[callId] = call
    broadcastAuthorized('dpn-le-core:client:newCall', call)
    broadcastState()
    return call
end

local function createDispatchCall(data, sourceId)
    data = type(data) == 'table' and data or {}
    if dispatchStarted() then
        local ok, result = pcall(function()
            return exports[Config.DispatchResource]:CreateDispatchCall(data, sourceId or 0)
        end)
        if ok then return result end
        debugPrint('Dispatch export failed; using local fallback.', result)
    end
    return createLocalCall(data, sourceId and sourceId > 0 and DPNBridge.GetIdentifier(sourceId) or 'system')
end

AddEventHandler('playerDropped', function()
    local src = source
    Officers[src] = nil
    RateLimits[src] = nil
    Restrained[src] = nil
    Escorting[src] = nil
    for target, officer in pairs(Escorting) do
        if officer == src then
            Escorting[target] = nil
            TriggerClientEvent('dpn-le-core:client:setEscorted', target, false, 0)
        end
    end
    broadcastState()
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player and player.PlayerData and player.PlayerData.source
    if src then SetTimeout(1000, function() registerOfficer(src) end) end
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(src)
    SetTimeout(250, function() registerOfficer(src) end)
end)

RegisterNetEvent('dpn-le-core:server:requestState', function()
    local src = source
    registerOfficer(src)
    broadcastState(src)
end)

RegisterNetEvent('dpn-le-core:server:updatePosition', function()
    local src = source
    if not DPNBridge.IsAllowed(src, true, false) then return end
    if not Officers[src] then registerOfficer(src) end
    if not Officers[src] then return end
    local ok, coords = pcall(function()
        local ped = GetPlayerPed(src)
        if not ped or ped <= 0 or not DoesEntityExist(ped) then return nil end
        local position = GetEntityCoords(ped)
        return { x = position.x, y = position.y, z = position.z }
    end)
    if ok and coords then Officers[src].coords = coords end
    Officers[src].lastSeen = now()
end)

RegisterNetEvent('dpn-le-core:server:toggleDuty', function()
    local src = source
    local allowed = DPNBridge.IsAllowed(src, false, false)
    if not allowed then return DPNBridge.Notify(src, 'Your current job is not part of the DPN Emergency Network.', 'error') end
    local newState = not DPNBridge.IsOnDuty(src)
    if DPNBridge.SetDuty(src, newState) then
        SetTimeout(250, function()
            registerOfficer(src)
            DPNBridge.Notify(src, newState and 'You are now on duty.' or 'You are now off duty.', newState and 'success' or 'primary')
        end)
    end
end)

RegisterNetEvent('dpn-le-core:server:setStatus', function(status)
    local src = source
    status = cleanString(status, 16)
    if not Config.Statuses[status] then return end
    local allowed = DPNBridge.IsAllowed(src, true, false)
    if not allowed then return DPNBridge.Notify(src, 'You must be on duty to update status.', 'error') end
    if not Officers[src] then registerOfficer(src) end
    if not Officers[src] then return end
    Officers[src].status = status
    Officers[src].lastSeen = now()
    saveOfficerLog(Officers[src], 'STATUS')
    if dispatchStarted() then
        pcall(function() exports[Config.DispatchResource]:UpdateUnit(src, { status = status, unit = Officers[src].unit, coords = Officers[src].coords }) end)
    end
    broadcastState()
    webhook(Config.Webhooks.OfficerStatus, 'Officer Status Updated', ('%s changed status to %s'):format(Officers[src].name, status), 3447003)
end)

RegisterNetEvent('dpn-le-core:server:setUnit', function(unit)
    local src = source
    unit = cleanString(unit, Config.Security.MaxUnitLength):upper()
    if unit == '' then return end
    local allowed = DPNBridge.IsAllowed(src, true, false)
    if not allowed then return end
    if not Officers[src] then registerOfficer(src) end
    if not Officers[src] then return end
    Officers[src].unit = unit
    Officers[src].lastSeen = now()
    saveOfficerLog(Officers[src], 'UNIT')
    if dispatchStarted() then
        pcall(function() exports[Config.DispatchResource]:UpdateUnit(src, { status = Officers[src].status, unit = unit, coords = Officers[src].coords }) end)
    end
    broadcastState()
end)

RegisterNetEvent('dpn-le-core:server:createCall', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local allowed = DPNBridge.IsAllowed(src, false, false)
    if not allowed and not Config.Dispatch.AllowCivilianCalls then return end
    if not rateAllowed(src, 'dispatch') then return end
    if not allowed then
        data.type = '911'
        data.priority = nil
        data.staffOnly = false
    end
    createDispatchCall(data, src)
end)

RegisterNetEvent('dpn-le-core:server:assignSelf', function(callId)
    local src = source
    if not DPNBridge.IsAllowed(src, true, false) then return end
    if dispatchStarted() then
        pcall(function() exports[Config.DispatchResource]:AssignUnit(callId, src) end)
        return
    end
    if not LocalCalls[callId] then return end
    LocalCalls[callId].assigned[DPNBridge.GetIdentifier(src)] = Officers[src] and Officers[src].unit or tostring(src)
    LocalCalls[callId].status = 'assigned'
    broadcastState()
end)

RegisterNetEvent('dpn-le-core:server:closeCall', function(callId, disposition, notes)
    local src = source
    if not DPNBridge.IsSupervisor(src) then return DPNBridge.Notify(src, 'Supervisor permission required to close dispatch calls.', 'error') end
    if dispatchStarted() then
        pcall(function() exports[Config.DispatchResource]:CloseCall(callId, src, cleanString(disposition or 'completed', 120), cleanString(notes or '', 1200)) end)
        return
    end
    if LocalCalls[callId] then LocalCalls[callId] = nil; broadcastState() end
end)

RegisterNetEvent('dpn-le-core:server:toggleCuff', function(target, cuffType)
    local src = source
    target = tonumber(target)
    if not actionAllowed(src, true) or not target or target == src then return end
    if not withinDistance(src, target, Config.Interactions.MaxDistance) then return DPNBridge.Notify(src, 'Target is too far away.', 'error') end
    if not DPNBridge.HasItem(src, Config.Interactions.CuffItem, 1) then return DPNBridge.Notify(src, 'You do not have the required restraints.', 'error') end

    local newState = not Restrained[target]
    Restrained[target] = newState or nil
    Escorting[target] = nil
    TriggerClientEvent('dpn-le-core:client:setCuffed', target, newState, cuffType == 'soft' and 'soft' or 'hard', src)
    TriggerClientEvent('dpn-le-core:client:setEscorted', target, false, 0)
    DPNBridge.Notify(src, newState and 'Subject restrained.' or 'Subject released.', 'success')
    DPNBridge.Notify(target, newState and 'You have been restrained.' or 'Your restraints were removed.', newState and 'error' or 'success')
    saveActionLog(src, newState and 'CUFF' or 'UNCUFF', target, { cuffType = cuffType })
end)

RegisterNetEvent('dpn-le-core:server:toggleEscort', function(target)
    local src = source
    target = tonumber(target)
    if not actionAllowed(src, true) or not target or target == src then return end
    if not withinDistance(src, target, Config.Interactions.MaxDistance) then return DPNBridge.Notify(src, 'Target is too far away.', 'error') end
    if not Restrained[target] then return DPNBridge.Notify(src, 'The subject must be restrained first.', 'error') end

    local active = Escorting[target] ~= src
    Escorting[target] = active and src or nil
    TriggerClientEvent('dpn-le-core:client:setEscorted', target, active, src)
    DPNBridge.Notify(src, active and 'Escort started.' or 'Escort stopped.', 'success')
    saveActionLog(src, active and 'ESCORT_START' or 'ESCORT_STOP', target)
end)

RegisterNetEvent('dpn-le-core:server:putInVehicle', function(target, vehicleNetId)
    local src = source
    target = tonumber(target)
    vehicleNetId = tonumber(vehicleNetId)
    if not actionAllowed(src, true) or not target or not vehicleNetId then return end
    if not withinDistance(src, target, Config.Interactions.VehicleDistance) then return end
    if not Restrained[target] then return DPNBridge.Notify(src, 'The subject must be restrained first.', 'error') end
    Escorting[target] = nil
    TriggerClientEvent('dpn-le-core:client:putInVehicle', target, vehicleNetId)
    saveActionLog(src, 'PLACE_IN_VEHICLE', target, { vehicle = vehicleNetId })
end)

RegisterNetEvent('dpn-le-core:server:removeFromVehicle', function(target)
    local src = source
    target = tonumber(target)
    if not actionAllowed(src, true) or not target then return end
    if not withinDistance(src, target, Config.Interactions.VehicleDistance + 3.0) then return end
    TriggerClientEvent('dpn-le-core:client:removeFromVehicle', target)
    saveActionLog(src, 'REMOVE_FROM_VEHICLE', target)
end)

RegisterNetEvent('dpn-le-core:server:searchPlayer', function(target)
    local src = source
    target = tonumber(target)
    if not actionAllowed(src, true) or not target or target == src then return end
    if not withinDistance(src, target, Config.Interactions.MaxDistance) then return DPNBridge.Notify(src, 'Target is too far away.', 'error') end
    if not Restrained[target] then return DPNBridge.Notify(src, 'The subject must be restrained before a full search.', 'error') end

    local targetPlayer = DPNBridge.GetPlayer(target)
    if not targetPlayer then return end
    local items = {}
    if Config.Interactions.SearchShowsInventory then
        for _, item in pairs(DPNBridge.GetInventoryItems(target)) do
            local amount = tonumber(item.amount or item.count) or 0
            if amount > 0 and #items < Config.Interactions.SearchMaxItems then
                items[#items + 1] = {
                    name = cleanString(item.name or item.item or 'unknown', 64),
                    label = cleanString(item.label or item.name or item.item or 'Unknown Item', 96),
                    amount = amount,
                    info = type(item.info) == 'table' and item.info or nil
                }
            end
        end
    end

    local money = {}
    if Config.Interactions.SearchShowsMoney and targetPlayer.PlayerData.money then
        money = {
            cash = tonumber(targetPlayer.PlayerData.money.cash) or 0,
            bank = tonumber(targetPlayer.PlayerData.money.bank) or 0
        }
    end

    TriggerClientEvent('dpn-le-core:client:searchResult', src, {
        source = target,
        citizenid = DPNBridge.GetIdentifier(target),
        name = DPNBridge.GetPlayerName(target),
        items = items,
        money = money
    })
    saveActionLog(src, 'SEARCH', target, { itemCount = #items })
end)

RegisterNetEvent('dpn-le-core:server:issueCitation', function(data)
    local src = source
    if not actionAllowed(src, true) or not Config.Citations.Enabled or type(data) ~= 'table' then return end
    local target = tonumber(data.target)
    local amount = math.floor(tonumber(data.amount) or 0)
    local reason = cleanString(data.reason or 'Traffic / criminal citation', 255)
    if not target or target == src or not withinDistance(src, target, Config.Interactions.MaxDistance) then return DPNBridge.Notify(src, 'A nearby valid subject is required.', 'error') end
    if amount < Config.Citations.Minimum or amount > Config.Citations.Maximum then return DPNBridge.Notify(src, 'Citation amount is outside the configured limits.', 'error') end

    local paid = false
    if Config.Citations.AutoDebit then
        paid = DPNBridge.RemoveMoney(target, Config.Citations.DebitAccount, amount, 'law-enforcement-citation') == true
    end
    local citationId = ('CIT-%s-%04d'):format(os.time(), math.random(1000, 9999))
    MySQL.insert('INSERT INTO dpn_le_citations (citation_id, citizenid, citizen_name, officer_cid, officer_name, amount, reason, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())', {
        citationId, DPNBridge.GetIdentifier(target), DPNBridge.GetPlayerName(target), DPNBridge.GetIdentifier(src), DPNBridge.GetPlayerName(src), amount, reason, paid and 'paid' or 'issued'
    })
    DPNBridge.Notify(src, ('Citation %s issued for $%s.'):format(citationId, amount), 'success')
    DPNBridge.Notify(target, ('You received citation %s for $%s: %s'):format(citationId, amount, reason), 'error', 9000)
    saveActionLog(src, 'CITATION', target, { citationId = citationId, amount = amount, reason = reason, paid = paid })
end)

RegisterNetEvent('dpn-le-core:server:bookSuspect', function(data)
    local src = source
    if not actionAllowed(src, true) or not Config.Booking.Enabled or type(data) ~= 'table' then return end
    local target = tonumber(data.target)
    if not target or target == src or not withinDistance(src, target, Config.Interactions.MaxDistance + 2.0) then return DPNBridge.Notify(src, 'A nearby valid subject is required.', 'error') end
    if not Restrained[target] then return DPNBridge.Notify(src, 'The subject must be restrained before booking.', 'error') end

    local sentence = math.max(0, math.min(Config.Booking.MaxSentenceMinutes, math.floor(tonumber(data.sentence) or 0)))
    local fine = math.max(0, math.min(Config.Booking.MaxFine, math.floor(tonumber(data.fine) or 0)))
    local charges = cleanString(data.charges or 'Unspecified charges', 1000)
    local notes = cleanString(data.notes or '', 2000)
    local bookingId = ('BOOK-%s-%04d'):format(os.time(), math.random(1000, 9999))

    MySQL.insert('INSERT INTO dpn_le_bookings (booking_id, citizenid, citizen_name, officer_cid, officer_name, charges, sentence_minutes, fine, notes, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())', {
        bookingId, DPNBridge.GetIdentifier(target), DPNBridge.GetPlayerName(target), DPNBridge.GetIdentifier(src), DPNBridge.GetPlayerName(src), charges, sentence, fine, notes, 'booked'
    })

    if Config.Booking.SendToCorrections and GetResourceState(Config.CorrectionsResource) == 'started' then
        TriggerEvent('dpn-corrections:server:intake', target, {
            bookingId = bookingId,
            charges = charges,
            sentence = sentence,
            fine = fine,
            officer = DPNBridge.GetPlayerName(src)
        })
    end

    DPNBridge.Notify(src, ('Booking %s completed.'):format(bookingId), 'success')
    DPNBridge.Notify(target, ('You were booked under %s. Sentence: %s minutes.'):format(bookingId, sentence), 'error', 9000)
    saveActionLog(src, 'BOOKING', target, { bookingId = bookingId, charges = charges, sentence = sentence, fine = fine })
end)

-- Canonical bridge used by every DPN module.
local function receiveExternalDispatch(payload)
    local src = tonumber(source) or 0
    payload = type(payload) == 'table' and payload or {}
    if src > 0 then
        if not rateAllowed(src, 'dispatch-compat') then return end
        local allowed = DPNBridge.IsAllowed(src, false, false)
        if not allowed and not Config.Dispatch.AllowCivilianCalls then return end
        if not allowed then
            payload.type = '911'
            payload.priority = nil
            payload.staffOnly = false
        end
    end
    createDispatchCall(payload, src)
end
RegisterNetEvent('dpn-le-core:server:dispatchEvent', receiveExternalDispatch)
RegisterNetEvent('dpn_le_core:server:dispatchEvent', receiveExternalDispatch)

CreateThread(function()
    while true do
        Wait(60000)
        local cutoff = now() - (Config.Dispatch.RetainMinutes * 60)
        if Config.Dispatch.AutoExpire then
            for id, call in pairs(LocalCalls) do
                if call.createdAt and call.createdAt < cutoff then LocalCalls[id] = nil end
            end
        end
        for src in pairs(Officers) do
            if not playerExists(src) then Officers[src] = nil end
        end
        broadcastState()
    end
end)

exports('GetOfficers', function() return Officers end)
exports('GetDispatchCalls', getDispatchCalls)
exports('CreateDispatchCall', function(data, src) return createDispatchCall(data, tonumber(src) or 0) end)
exports('IsAllowed', function(src, requireDuty, lawOnly) return DPNBridge.IsAllowed(src, requireDuty, lawOnly) end)
exports('IsLawEnforcement', function(src) return DPNBridge.IsLawEnforcement(src) end)
exports('IsSupervisor', function(src) return DPNBridge.IsSupervisor(src) end)
exports('GetOfficer', function(src) return Officers[tonumber(src)] end)
exports('IsRestrained', function(src) return Restrained[tonumber(src)] == true end)

exports('SetOfficerStatus', function(src, status)
    src = tonumber(src)
    status = cleanString(status, 16)
    if not src or not Config.Statuses[status] then return false end
    if not DPNBridge.IsAllowed(src, true, false) then return false end
    if not Officers[src] then registerOfficer(src) end
    if not Officers[src] then return false end
    Officers[src].status = status
    Officers[src].lastSeen = now()
    saveOfficerLog(Officers[src], 'STATUS_EXPORT')
    if dispatchStarted() then pcall(function() exports[Config.DispatchResource]:UpdateUnit(src, { status = status, unit = Officers[src].unit, coords = Officers[src].coords }) end) end
    broadcastState()
    return true
end)

exports('SetOfficerUnit', function(src, unit)
    src = tonumber(src)
    unit = cleanString(unit, Config.Security.MaxUnitLength):upper()
    if not src or unit == '' or not DPNBridge.IsAllowed(src, true, false) then return false end
    if not Officers[src] then registerOfficer(src) end
    if not Officers[src] then return false end
    Officers[src].unit = unit
    Officers[src].lastSeen = now()
    saveOfficerLog(Officers[src], 'UNIT_EXPORT')
    if dispatchStarted() then pcall(function() exports[Config.DispatchResource]:UpdateUnit(src, { status = Officers[src].status, unit = unit, coords = Officers[src].coords }) end) end
    broadcastState()
    return true
end)

exports('GetPlayerInfo', function(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local data = DPNBridge.GetPlayerData(src)
    if not data then return nil end
    local job, grade, label, onDuty = DPNBridge.GetJob(src)
    local definition = Config.AllowedJobs[job]
    return {
        source = src,
        citizenid = DPNBridge.GetIdentifier(src),
        name = DPNBridge.GetPlayerName(src),
        job = job,
        jobLabel = label,
        grade = grade,
        onDuty = onDuty,
        department = definition and definition.type or nil,
        supervisor = DPNBridge.IsSupervisor(src)
    }
end)

exports('GetPlayerCoords', function(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z }
end)

exports('GetDepartment', function(src)
    local law, job, grade, label, onDuty = DPNBridge.IsLawEnforcement(tonumber(src) or 0)
    if law then return 'law', job, grade, label, onDuty end
    local allowed, emergencyJob, emergencyGrade, emergencyLabel, emergencyDuty, definition = DPNBridge.IsEmergencyJob(tonumber(src) or 0)
    return allowed and definition and definition.type or nil, emergencyJob, emergencyGrade, emergencyLabel, emergencyDuty
end)

exports('HasCapability', function(src, capability)
    src = tonumber(src)
    local rule = Config.Capabilities[tostring(capability or '')]
    if not src or not rule then return false end
    if DPNBridge.HasAce(src, Config.AdminAce) then return true end
    local law, _, grade, _, onDuty = DPNBridge.IsLawEnforcement(src)
    return law and (not Config.RequireOnDuty or onDuty) and grade >= tonumber(rule.minimumGrade or 0)
end)

exports('CreateAuditLog', function(src, action, target, details)
    src = tonumber(src) or 0
    target = tonumber(target)
    saveActionLog(src, cleanString(action, 80), target, type(details) == 'table' and details or {})
    return true
end)

