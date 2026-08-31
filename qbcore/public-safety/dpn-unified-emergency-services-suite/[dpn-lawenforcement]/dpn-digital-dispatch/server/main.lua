local QBCore = exports['qb-core']:GetCoreObject()
local ActiveCalls = {}
local Units = {}
local CallRate = {}

math.randomseed(os.time())

local function debugPrint(...)
    if Config.Debug then print('^3[dpn-digital-dispatch]^7', ...) end
end

local function clean(value, maxLength)
    local text = tostring(value or ''):gsub('[%z\1-\8\11\12\14-\31]', '')
    if #text > maxLength then text = text:sub(1, maxLength) end
    return text
end

local function decode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, data = pcall(json.decode, value)
    return ok and data or fallback
end

local function getPlayerInfo(src)
    local player = QBCore.Functions.GetPlayer(tonumber(src))
    if not player then return nil end
    local data = player.PlayerData or {}
    local job = data.job or {}
    local grade = job.grade
    if type(grade) == 'table' then grade = grade.level or grade.grade or 0 end
    local charinfo = data.charinfo or {}
    local name = (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1')
    local definition = Config.AllowedJobs[job.name]
    return {
        source = tonumber(src),
        identifier = data.citizenid or ('src:%s'):format(src),
        name = name ~= '' and name or GetPlayerName(src) or ('Unit %s'):format(src),
        job = job.name or 'unemployed',
        grade = tonumber(grade) or 0,
        onDuty = job.onduty == true,
        isBoss = job.isboss == true,
        department = definition and definition.department or nil
    }
end

local function isAllowed(src, requireDuty)
    if src == 0 then return true, { source = 0, identifier = 'SYSTEM', name = 'DPN System', job = 'system', department = 'all', onDuty = true } end
    if IsPlayerAceAllowed(src, 'dpn.dispatch') then return true, getPlayerInfo(src) end
    local info = getPlayerInfo(src)
    if not info or not Config.AllowedJobs[info.job] then return false, info end
    if requireDuty ~= false and Config.RequireDuty and not info.onDuty then return false, info end
    return true, info
end

local function isSupervisor(src)
    if src == 0 or IsPlayerAceAllowed(src, 'dpn.dispatch.supervisor') then return true end
    local info = getPlayerInfo(src)
    if not info then return false end
    return info.isBoss or (Config.SupervisorGrades[info.job] and info.grade >= Config.SupervisorGrades[info.job])
end

local function playerCoords(src)
    local ped = src > 0 and GetPlayerPed(src) or 0
    if ped <= 0 then return { x = 0.0, y = 0.0, z = 0.0 } end
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function departmentsContain(call, department)
    if department == 'dispatch' then return true end
    for _, item in ipairs(call.departments or {}) do
        if item == 'all' or item == department then return true end
    end
    return false
end

local function visibleCallsFor(info)
    local result = {}
    for id, call in pairs(ActiveCalls) do
        if info and departmentsContain(call, info.department) then result[id] = call end
    end
    return result
end

local function visibleUnitsFor(info)
    local result = {}
    for identifier, unit in pairs(Units) do
        if not info or info.department == 'dispatch' or unit.department == info.department or unit.department == 'dispatch' then
            result[identifier] = unit
        end
    end
    return result
end

local function broadcast(eventName, payload, call)
    for _, value in ipairs(GetPlayers()) do
        local src = tonumber(value)
        local allowed, info = isAllowed(src, true)
        if allowed and (not call or departmentsContain(call, info.department)) then
            TriggerClientEvent(eventName, src, payload)
        end
    end
end

local function networkPublish(eventType, payload)
    if GetResourceState('dpn-emergency-network') ~= 'started' then return end
    pcall(function() exports['dpn-emergency-network']:PublishEvent('dispatch', eventType, payload or {}, 0) end)
end

local function webhook(title, description, color)
    if not Config.LogEvents or Config.DiscordWebhook == '' then return end
    PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST', json.encode({
        username = 'DPN Digital Dispatch',
        embeds = {{ title = title, description = description, color = color or 3447003, footer = { text = os.date('%Y-%m-%d %H:%M:%S') } }}
    }), { ['Content-Type'] = 'application/json' })
end

local function saveCall(call)
    MySQL.insert('INSERT INTO dpn_dispatch_calls (call_id, call_type, title, description, priority, status, coords, created_by, caller_name, assigned_units, departments, metadata, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?))', {
        call.callId, call.type, call.title, call.description, call.priority, call.status,
        json.encode(call.coords), call.createdBy, call.callerName, json.encode(call.assigned),
        json.encode(call.departments), json.encode(call.metadata), call.createdAt
    })
end

local function updateCall(call)
    MySQL.update('UPDATE dpn_dispatch_calls SET description = ?, priority = ?, status = ?, assigned_units = ?, metadata = ?, closed_at = ? WHERE call_id = ?', {
        call.description, call.priority, call.status, json.encode(call.assigned or {}), json.encode(call.metadata or {}),
        call.status == 'closed' and os.date('%Y-%m-%d %H:%M:%S') or nil, call.callId
    })
end

local function appendTimeline(call, entryType, actor, text, extra)
    call.metadata = type(call.metadata) == 'table' and call.metadata or {}
    call.metadata.timeline = type(call.metadata.timeline) == 'table' and call.metadata.timeline or {}
    local timeline = call.metadata.timeline
    timeline[#timeline + 1] = {
        type = clean(entryType, 40), actor = clean(actor or 'DPN System', 120),
        text = clean(text or '', Config.MaxNoteLength), timestamp = os.time(), extra = type(extra) == 'table' and extra or nil
    }
    while #timeline > Config.MaxCallNotes do table.remove(timeline, 1) end
end

local function callRateAllowed(src)
    if src <= 0 then return true end
    local current = os.time()
    local bucket = CallRate[src]
    if not bucket or current - bucket.started >= 60 then
        CallRate[src] = { started = current, count = 1 }
        return true
    end
    bucket.count = bucket.count + 1
    return bucket.count <= Config.Security.MaxCallsPerMinute
end

local function tableCount(value)
    local count = 0
    for _ in pairs(value or {}) do count = count + 1 end
    return count
end

local validDepartments = { law=true, fire=true, medical=true, dispatch=true, all=true }
local function sanitizeDepartments(value, fallback)
    local result, seen = {}, {}
    for _, department in ipairs(type(value) == 'table' and value or fallback or {}) do
        department = clean(department, 24):lower()
        if validDepartments[department] and not seen[department] then
            result[#result + 1] = department
            seen[department] = true
        end
    end
    if #result == 0 then
        for _, department in ipairs(fallback or { 'law', 'dispatch' }) do result[#result + 1] = department end
    end
    return result
end

local function generateCallId()
    local candidate
    repeat
        candidate = ('DPN-%s-%04d'):format(os.date('%m%d%H%M%S'), math.random(1000, 9999))
    until not ActiveCalls[candidate]
    return candidate
end

local function createCall(data, sourceId, trusted)
    data = type(data) == 'table' and data or {}
    sourceId = tonumber(sourceId) or 0
    local allowed, creator = isAllowed(sourceId, true)

    if sourceId > 0 and not callRateAllowed(sourceId) then
        return nil, 'rate_limited'
    end

    if sourceId > 0 and not allowed then
        if not Config.EnableCivilian911 or data.staffOnly or data.type ~= '911' then return nil, 'access_denied' end
    end

    if tableCount(ActiveCalls) >= Config.MaxActiveCalls then return nil, 'capacity' end

    local requestedType = clean(data.type or '911', 32)
    if not Config.CallTypes[requestedType] then requestedType = allowed and 'incident' or '911' end
    local definition = Config.CallTypes[requestedType]
    local coords = trusted and type(data.coords) == 'table' and data.coords or playerCoords(sourceId)
    local priority = tonumber(data.priority) or definition.priority or 3
    if not trusted and not allowed then priority = definition.priority or 2 end
    priority = math.max(1, math.min(5, math.floor(priority)))

    local call = {
        callId = generateCallId(),
        id = nil,
        type = requestedType,
        title = clean(data.title or definition.label, Config.Security.MaxTitleLength),
        description = clean(data.description or 'No details provided.', Config.Security.MaxDescriptionLength),
        priority = priority,
        status = 'active',
        coords = { x = tonumber(coords.x) or 0.0, y = tonumber(coords.y) or 0.0, z = tonumber(coords.z) or 0.0 },
        createdBy = creator and creator.identifier or 'SYSTEM',
        callerName = clean(data.callerName or (creator and creator.name) or 'DPN System', 128),
        assigned = {},
        departments = sanitizeDepartments(data.departments, definition.departments),
        metadata = trusted and type(data.metadata) == 'table' and data.metadata or {},
        createdAt = os.time(),
        expiresAt = os.time() + (tonumber(data.timeout) or definition.timeout or Config.CallRetentionSeconds)
    }
    call.id = call.callId
    appendTimeline(call, 'created', call.callerName, call.description, { priority = call.priority, type = call.type })
    ActiveCalls[call.callId] = call
    saveCall(call)
    broadcast('dpn_dispatch:client:callCreated', call, call)
    webhook('New Dispatch Call', ('%s | %s | Priority %s'):format(call.callId, call.title, call.priority), call.priority == 1 and 15158332 or 3447003)
    if not (call.metadata and call.metadata.networkEventId) then
        networkPublish('dispatch_call_created', { title=call.title, message=call.description, severity=call.priority, callId=call.callId, callType=call.type, departments=call.departments, coords=call.coords, suppressRouting=true })
    end
    return call
end

local function assignUnit(callId, sourceId)
    sourceId = tonumber(sourceId) or 0
    local allowed, info = isAllowed(sourceId, true)
    local call = ActiveCalls[tostring(callId)]
    if not allowed or not call or not departmentsContain(call, info.department) then return false end
    local unit = Units[info.identifier] or {
        source = sourceId, identifier = info.identifier, name = info.name, job = info.job,
        department = info.department, status = '10-8', unit = tostring(sourceId)
    }
    call.assigned[info.identifier] = { src = sourceId, name = info.name, unit = unit.unit, status = unit.status }
    if call.status == 'active' then call.status = 'assigned' end
    appendTimeline(call, 'unit_assigned', info.name, ('%s assigned to the call.'):format(unit.unit), { unit = unit.unit })
    updateCall(call)
    broadcast('dpn_dispatch:client:callUpdated', call, call)
    TriggerEvent('dpn-dispatch:server:unitAssignedInternal', sourceId, call.callId)
    return true
end

local function closeCall(callId, sourceId, disposition, notes)
    sourceId = tonumber(sourceId) or 0
    local call = ActiveCalls[tostring(callId)]
    if not call or not isSupervisor(sourceId) then return false end
    local actor = sourceId > 0 and getPlayerInfo(sourceId) or { name = 'DPN System' }
    disposition = clean(disposition or '', 120)
    notes = clean(notes or '', Config.MaxNoteLength)
    if sourceId == 0 and disposition == '' then disposition = 'system_closed' end
    if Config.RequireDispositionOnClose and disposition == '' and sourceId > 0 then return false, 'disposition_required' end
    call.status = 'closed'
    call.closedBy = sourceId
    call.metadata.disposition = disposition ~= '' and disposition or 'closed'
    call.metadata.closeNotes = notes
    appendTimeline(call, 'closed', actor and actor.name or 'DPN System', notes ~= '' and notes or disposition, { disposition = disposition })
    updateCall(call)
    broadcast('dpn_dispatch:client:callClosed', call.callId, call)
    ActiveCalls[call.callId] = nil
    webhook('Dispatch Call Closed', ('%s | %s | %s'):format(call.callId, call.title, disposition), 3066993)
    networkPublish('dispatch_call_closed', { title='Dispatch Call Closed', message=('%s closed: %s'):format(call.title, disposition), severity=4, callId=call.callId, disposition=disposition, notes=notes, suppressRouting=true })
    return true
end

local function addCallNote(callId, sourceId, note)
    sourceId = tonumber(sourceId) or 0
    local allowed, info = isAllowed(sourceId, true)
    local call = ActiveCalls[tostring(callId)]
    note = clean(note, Config.MaxNoteLength)
    if not allowed or not info or not call or note == '' or not departmentsContain(call, info.department) then return false end
    appendTimeline(call, 'note', info.name, note)
    updateCall(call)
    broadcast('dpn_dispatch:client:callUpdated', call, call)
    return true
end

local function setCallPriority(callId, sourceId, priority, reason)
    sourceId = tonumber(sourceId) or 0
    local call = ActiveCalls[tostring(callId)]
    if not call or not isSupervisor(sourceId) then return false end
    priority = math.max(1, math.min(5, math.floor(tonumber(priority) or call.priority)))
    local info = sourceId > 0 and getPlayerInfo(sourceId) or { name = 'DPN System' }
    call.priority = priority
    appendTimeline(call, 'priority', info and info.name or 'DPN System', clean(reason or ('Priority changed to ' .. priority), Config.MaxNoteLength), { priority = priority })
    updateCall(call)
    broadcast('dpn_dispatch:client:callUpdated', call, call)
    return true
end

local function setCallStatus(callId, sourceId, status)
    sourceId = tonumber(sourceId) or 0
    local allowed, info = isAllowed(sourceId, true)
    local call = ActiveCalls[tostring(callId)]
    status = clean(status, 24)
    if not allowed or not info or not call or not Config.CallStatuses[status] or status == 'closed' or status == 'expired' then return false end
    local assigned = call.assigned[info.identifier] ~= nil
    if not assigned and not isSupervisor(sourceId) then return false end
    call.status = status
    if assigned then call.assigned[info.identifier].status = status end
    appendTimeline(call, 'status', info.name, ('Call status changed to %s.'):format(Config.CallStatuses[status]), { status = status })
    updateCall(call)
    broadcast('dpn_dispatch:client:callUpdated', call, call)
    return true
end

local function updateUnit(sourceId, data, trusted)
    sourceId = tonumber(sourceId) or 0
    data = type(data) == 'table' and data or {}
    local allowed, info = isAllowed(sourceId, true)
    if not allowed or not info then return false end
    local unit = Units[info.identifier] or {}
    unit.source = sourceId
    unit.src = sourceId
    unit.identifier = info.identifier
    unit.name = info.name
    unit.job = info.job
    unit.department = info.department
    unit.status = Config.UnitStatuses[data.status] and data.status or unit.status or '10-8'
    unit.unit = clean(data.unit or unit.unit or tostring(sourceId), Config.Security.MaxUnitLength):upper()
    -- Never trust a client-supplied unit position; OneSync provides the authoritative player position.
    unit.coords = playerCoords(sourceId)
    if trusted then
        local metadata = type(data.metadata) == 'table' and data.metadata or {}
        unit.metadata = metadata
        unit.role = clean(data.operationalRole or data.role or metadata.role or unit.role or '', 40)
        unit.partners = type(data.partners) == 'table' and data.partners
            or (type(metadata.partners) == 'table' and metadata.partners or unit.partners or {})
        unit.operationalUnit = clean(data.operationalUnit or metadata.operationalUnit or unit.operationalUnit or '', 64)
    end
    unit.updatedAt = os.time()
    Units[info.identifier] = unit

    MySQL.query([[INSERT INTO dpn_dispatch_units (identifier, unit_number, name, job, department, status, last_coords, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE unit_number=VALUES(unit_number), name=VALUES(name), job=VALUES(job), department=VALUES(department), status=VALUES(status), last_coords=VALUES(last_coords), updated_at=NOW()]], {
        info.identifier, unit.unit, unit.name, unit.job, unit.department, unit.status, json.encode(unit.coords)
    })

    for _, value in ipairs(GetPlayers()) do
        local target = tonumber(value)
        local targetAllowed, targetInfo = isAllowed(target, true)
        if targetAllowed then TriggerClientEvent('dpn_dispatch:client:unitsUpdated', target, visibleUnitsFor(targetInfo)) end
    end
    return true
end

local function handleCreate(data)
    local src = source or 0
    local trusted = src == 0
    local call, reason = createCall(data, src, trusted)
    if not call and src > 0 then DPNDispatch.Notify(src, ('Dispatch call rejected: %s'):format(reason or 'unknown'), 'error') end
end

for _, eventName in ipairs({
    'dpn_dispatch:server:createCall',
    'dpn-dispatch:server:createCall',
    'dpn-digital-dispatch:server:createCall'
}) do
    RegisterNetEvent(eventName, handleCreate)
end

RegisterNetEvent('dpn-digital-dispatch:server:createTrainingCall', function(sessionId, session)
    local src = tonumber(source) or 0
    if src > 0 and (not isAllowed(src, true) or not isSupervisor(src)) then return end
    local data = type(session) == 'table' and session or {}
    createCall({
        type = 'training',
        title = clean(data.label or 'Emergency Services Training Scenario', Config.Security.MaxTitleLength),
        description = ('Training session %s is active.'):format(clean(sessionId or 'unknown', 64)),
        priority = 4,
        coords = src == 0 and data.coords or nil,
        departments = { 'law', 'fire', 'medical', 'dispatch' },
        metadata = { sessionId = clean(sessionId or 'unknown', 64), training = true }
    }, src, src == 0)
end)

RegisterNetEvent('dpn_dispatch:server:assignSelf', function(callId) assignUnit(callId, source) end)
RegisterNetEvent('dpn-dispatch:server:assignSelf', function(callId) assignUnit(callId, source) end)
RegisterNetEvent('dpn_dispatch:server:closeCall', function(callId, disposition, notes)
    local ok, reason = closeCall(callId, source, disposition, notes)
    if not ok then DPNDispatch.Notify(source, reason == 'disposition_required' and 'A disposition is required to close this call.' or 'Supervisor permission required to close this call.', 'error') end
end)
RegisterNetEvent('dpn-dispatch:server:closeCall', function(callId, disposition, notes) closeCall(callId, source, disposition, notes) end)
RegisterNetEvent('dpn_dispatch:server:addNote', function(callId, note) if not addCallNote(callId, source, note) then DPNDispatch.Notify(source, 'Unable to add call note.', 'error') end end)
RegisterNetEvent('dpn_dispatch:server:setCallPriority', function(callId, priority, reason) if not setCallPriority(callId, source, priority, reason) then DPNDispatch.Notify(source, 'Supervisor permission required.', 'error') end end)
RegisterNetEvent('dpn_dispatch:server:setCallStatus', function(callId, status) if not setCallStatus(callId, source, status) then DPNDispatch.Notify(source, 'You must be assigned to this call.', 'error') end end)
RegisterNetEvent('dpn_dispatch:server:updateUnit', function(data) updateUnit(source, data, false) end)
RegisterNetEvent('dpn-dispatch:server:updateUnit', function(data) updateUnit(source, data, false) end)

RegisterNetEvent('dpn_dispatch:server:requestSync', function()
    local src = source
    local allowed, info = isAllowed(src, true)
    if not allowed then return DPNDispatch.Notify(src, 'You must be on duty to access dispatch.', 'error') end
    TriggerClientEvent('dpn_dispatch:client:sync', src, {
        calls = visibleCallsFor(info), units = visibleUnitsFor(info), supervisor = isSupervisor(src), officer = info
    })
end)
RegisterNetEvent('dpn-dispatch:server:getCalls', function()
    local src = source
    local allowed, info = isAllowed(src, true)
    if allowed then TriggerClientEvent('dpn_dispatch:client:sync', src, { calls = visibleCallsFor(info), units = visibleUnitsFor(info), supervisor = isSupervisor(src), officer = info }) end
end)

RegisterCommand(Config.Civilian911Command, function(src, args)
    if src <= 0 or not Config.EnableCivilian911 then return end
    local description = clean(table.concat(args, ' '), Config.Security.MaxDescriptionLength)
    if description == '' then return DPNDispatch.Notify(src, 'Usage: /911 [describe the emergency]', 'error') end
    local call = createCall({ type = '911', title = '911 Emergency Call', description = description, callerName = GetPlayerName(src) }, src, false)
    if call then DPNDispatch.Notify(src, ('911 call %s sent to emergency services.'):format(call.callId), 'success') end
end, false)

RegisterCommand(Config.PanicCommand, function(src)
    if src <= 0 then return end
    local allowed, info = isAllowed(src, true)
    if not allowed then return DPNDispatch.Notify(src, 'You must be on duty to use the panic button.', 'error') end
    createCall({ type = 'panic', title = 'OFFICER PANIC BUTTON', description = ('Emergency panic activated by %s.'):format(info.name), priority = 1 }, src, false)
end, false)

AddEventHandler('playerDropped', function()
    local src = source
    CallRate[src] = nil
    for identifier, unit in pairs(Units) do
        if unit.source == src then Units[identifier] = nil end
    end
    for _, value in ipairs(GetPlayers()) do
        local target = tonumber(value)
        local targetAllowed, targetInfo = isAllowed(target, true)
        if targetAllowed and targetInfo then
            TriggerClientEvent('dpn_dispatch:client:unitsUpdated', target, visibleUnitsFor(targetInfo))
        end
    end
end)

CreateThread(function()
    Wait(1000)
    local rows = MySQL.query.await("SELECT * FROM dpn_dispatch_calls WHERE status <> 'closed' AND created_at >= DATE_SUB(NOW(), INTERVAL 2 HOUR)", {}) or {}
    for _, row in ipairs(rows) do
        local call = {
            callId = row.call_id, id = row.call_id, type = row.call_type, title = row.title,
            description = row.description, priority = tonumber(row.priority) or 3, status = row.status or 'active',
            coords = decode(row.coords, {}), createdBy = row.created_by, callerName = row.caller_name,
            assigned = decode(row.assigned_units, {}), departments = decode(row.departments, { 'law', 'fire', 'medical', 'dispatch' }),
            metadata = decode(row.metadata, {}), createdAt = row.created_at and os.time() or os.time(),
            expiresAt = os.time() + Config.CallRetentionSeconds
        }
        ActiveCalls[call.callId] = call
    end
    debugPrint(('Recovered %s active calls.'):format(#rows))
end)

CreateThread(function()
    while true do
        Wait(30000)
        local current = os.time()
        for id, call in pairs(ActiveCalls) do
            if call.expiresAt and current >= call.expiresAt then
                call.status = 'expired'
                updateCall(call)
                broadcast('dpn_dispatch:client:callClosed', id, call)
                ActiveCalls[id] = nil
            end
        end
        for identifier, unit in pairs(Units) do
            if current - (unit.updatedAt or 0) > 60 or not GetPlayerName(unit.source or 0) then Units[identifier] = nil end
        end
    end
end)

exports('CreateDispatchCall', function(data, sourceId) return createCall(data, tonumber(sourceId) or 0, true) end)
exports('GetActiveCalls', function() return ActiveCalls end)
exports('GetCall', function(callId) return ActiveCalls[tostring(callId)] end)
exports('GetUnits', function() return Units end)
exports('AssignUnit', assignUnit)
exports('CloseCall', closeCall)
exports('AddCallNote', addCallNote)
exports('SetCallPriority', setCallPriority)
exports('SetCallStatus', setCallStatus)
exports('UpdateUnit', function(sourceId, data) return updateUnit(sourceId, data, true) end)
exports('IsAllowed', isAllowed)
