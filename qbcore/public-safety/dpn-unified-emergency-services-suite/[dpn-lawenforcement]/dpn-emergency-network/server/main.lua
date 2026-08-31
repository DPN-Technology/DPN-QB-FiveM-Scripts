local QBCore = exports['qb-core']:GetCoreObject()
local ResourceSnapshot = {}
local MemoryEvents = {}
local RateLimits = {}
local RegisteredAdapters = {}
local LastBroadcastAt = 0

math.randomseed(os.time())

local function debugPrint(...)
    if Config.Debug then print('^5[dpn-emergency-network]^7', ...) end
end

local function clean(value, maxLength)
    local text = tostring(value or ''):gsub('[%z\1-\8\11\12\14-\31]', '')
    maxLength = tonumber(maxLength) or Config.MaxStringLength
    if #text > maxLength then text = text:sub(1, maxLength) end
    return text
end

local function trim(value, maxLength)
    return clean(value, maxLength):gsub('^%s*(.-)%s*$', '%1')
end

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.max(minimum, math.min(maximum, value))
end

local function decode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, result = pcall(json.decode, value)
    return ok and result or fallback
end

local function cloneSerializable(value, depth)
    depth = depth or 0
    if depth > 6 then return nil end
    local kind = type(value)
    if kind == 'nil' or kind == 'boolean' or kind == 'number' then return value end
    if kind == 'string' then return clean(value, Config.MaxStringLength) end
    if kind ~= 'table' then return tostring(value) end
    local output = {}
    local count = 0
    for key, item in pairs(value) do
        count = count + 1
        if count > 150 then break end
        local safeKey = type(key) == 'number' and key or clean(key, 80)
        output[safeKey] = cloneSerializable(item, depth + 1)
    end
    return output
end

local function encodePayload(payload)
    local safe = cloneSerializable(payload or {}) or {}
    local encoded = json.encode(safe)
    if #encoded > Config.MaxPayloadBytes then
        safe = { truncated=true, title=clean(safe.title, 180), message=clean(safe.message, 1200), reference=clean(safe.reference, 96) }
        encoded = json.encode(safe)
    end
    return safe, encoded
end

local function makeId(prefix)
    return ('%s-%s-%04d'):format(prefix, os.date('%y%m%d%H%M%S'), math.random(1000, 9999))
end

local function playerInfo(src)
    src = tonumber(src) or 0
    if src <= 0 then
        return { source=0, citizenid='SYSTEM', name='DPN Network', job='system', grade=99, onDuty=true, department='system', supervisor=true }
    end
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return nil end
    local data = player.PlayerData or {}
    local job = data.job or {}
    local grade = job.grade
    if type(grade) == 'table' then grade = grade.level or grade.grade or 0 end
    local charinfo = data.charinfo or {}
    local name = trim(('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''), 120)
    local department = Config.AllowedJobs[job.name]
    local supervisor = job.isboss == true or IsPlayerAceAllowed(src, Config.SupervisorAce)
    local minimum = Config.SupervisorGrades[job.name]
    if minimum ~= nil and tonumber(grade or 0) >= tonumber(minimum) then supervisor = true end
    return {
        source=src,
        citizenid=data.citizenid or ('src:%s'):format(src),
        name=name ~= '' and name or GetPlayerName(src) or ('Unit %s'):format(src),
        job=job.name or 'unemployed',
        grade=tonumber(grade) or 0,
        onDuty=job.onduty == true,
        department=department,
        supervisor=supervisor
    }
end

local function isAuthorized(src, requireDuty)
    src = tonumber(src) or 0
    if src <= 0 or IsPlayerAceAllowed(src, Config.AdminAce) then return true, playerInfo(src) end
    local info = playerInfo(src)
    if not info or not info.department then return false, info end
    if requireDuty ~= false and Config.RequireDutyForPlayerPublish and not info.onDuty and info.department ~= 'justice' and info.department ~= 'mib' then return false, info end
    return true, info
end

local function rateAllowed(src)
    src = tonumber(src) or 0
    if src <= 0 then return true end
    local current = os.time()
    local bucket = RateLimits[src]
    if not bucket or current - bucket.started >= Config.RateWindowSeconds then
        RateLimits[src] = { started=current, count=1 }
        return true
    end
    bucket.count = bucket.count + 1
    return bucket.count <= Config.MaxPlayerPublishesPerWindow
end

local function playerCoords(src)
    src = tonumber(src) or 0
    if src <= 0 then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    return { x=coords.x + 0.0, y=coords.y + 0.0, z=coords.z + 0.0 }
end

local function normalizeCoords(value)
    if type(value) ~= 'table' then return nil end
    local x, y, z = tonumber(value.x or value[1]), tonumber(value.y or value[2]), tonumber(value.z or value[3])
    if not x or not y or not z then return nil end
    if math.abs(x) > 100000.0 or math.abs(y) > 100000.0 or math.abs(z) > 20000.0 then return nil end
    return { x=x + 0.0, y=y + 0.0, z=z + 0.0 }
end

local function resourceResolution(logicalSystem)
    local definition = Config.Systems[logicalSystem]
    if not definition then return { logical=logicalSystem, label=logicalSystem, state='missing', category='unknown', critical=false } end
    local fallbackName, fallbackState = nil, 'missing'
    for _, resourceName in ipairs(definition.aliases or {}) do
        local state = GetResourceState(resourceName)
        if state == 'started' then
            return { logical=logicalSystem, label=definition.label, resource=resourceName, state='started', category=definition.category, critical=definition.critical == true }
        end
        if not fallbackName or state ~= 'missing' then
            fallbackName, fallbackState = resourceName, state
        end
    end
    return { logical=logicalSystem, label=definition.label, resource=fallbackName, state=fallbackState, category=definition.category, critical=definition.critical == true }
end

local function refreshResources(persistTransitions)
    local nextSnapshot = {}
    for logicalSystem in pairs(Config.Systems) do
        local status = resourceResolution(logicalSystem)
        local previous = ResourceSnapshot[logicalSystem]
        nextSnapshot[logicalSystem] = status
        if persistTransitions and previous and (previous.state ~= status.state or previous.resource ~= status.resource) then
            MySQL.insert('INSERT INTO dpn_network_resource_history (logical_system, resource_name, previous_state, new_state, details, created_at) VALUES (?, ?, ?, ?, ?, NOW())', {
                logicalSystem, status.resource, previous.state, status.state, json.encode({ previousResource=previous.resource, critical=status.critical, category=status.category })
            })
        end
    end
    ResourceSnapshot = nextSnapshot
    return nextSnapshot
end

local function resolvedResource(logicalSystem)
    local cached = ResourceSnapshot[logicalSystem]
    if not cached or cached.state ~= 'started' then cached = resourceResolution(logicalSystem) end
    return cached and cached.state == 'started' and cached.resource or nil
end

local function callExport(logicalSystem, exportName, ...)
    local resourceName = resolvedResource(logicalSystem)
    if not resourceName then return false, nil end
    local args = table.pack(...)
    local ok, result = pcall(function()
        return exports[resourceName][exportName](table.unpack(args, 1, args.n))
    end)
    if not ok then debugPrint(('Export %s:%s failed: %s'):format(resourceName, exportName, result)) end
    return ok, result
end

local function notify(src, message, kind)
    src = tonumber(src) or 0
    if src > 0 then TriggerClientEvent('QBCore:Notify', src, clean(message, 500), kind or 'primary', 5000) end
end

local function audit(info, action, referenceId, details)
    info = info or playerInfo(0)
    MySQL.insert('INSERT INTO dpn_network_audit (actor_cid, actor_name, action, reference_id, details, created_at) VALUES (?, ?, ?, ?, ?, NOW())', {
        info.citizenid, info.name, clean(action, 80), referenceId and clean(referenceId, 96) or nil, json.encode(cloneSerializable(details or {}))
    })
end

local function pushMemoryEvent(event)
    table.insert(MemoryEvents, 1, cloneSerializable(event))
    while #MemoryEvents > Config.RecentEventLimit do table.remove(MemoryEvents) end
end

local function eventPolicy(eventType)
    return Config.Routes[eventType] or Config.Routes.generic
end

local function dispatchRoute(event, policy)
    if not policy.dispatch or event.sourceSystem == 'dispatch' then return nil end
    local ok, createdCall = callExport('dispatch', 'CreateDispatchCall', {
        code=policy.code or 'DPN',
        title=event.title,
        description=event.message,
        message=event.message,
        priority=event.severity,
        coords=event.coords,
        departments=policy.departments,
        department=event.department,
        source='dpn-emergency-network',
        metadata={ networkEventId=event.eventId, sourceSystem=event.sourceSystem, eventType=event.eventType, reference=event.payload.reference }
    }, 0)
    if not ok then return nil end
    if type(createdCall) == 'table' then
        return createdCall.callId or createdCall.call_id or createdCall.id
    end
    return createdCall
end

local function incidentRoute(event, policy)
    if not policy.incident or event.sourceSystem == 'incident_command' then return nil end
    local ok, incidentId = callExport('incident_command', 'CreateIncident', event.title, event.eventType, event.severity, event.coords, event.message)
    return ok and incidentId or nil
end

local function evidenceRoute(event, policy)
    if not policy.evidence or event.sourceSystem == 'evidence' then return nil end
    local reference = event.payload.evidenceReference or event.payload.caseId or event.payload.caseReference
    callExport('evidence', 'AddSystemRecord', 'network_event', event.title, {
        eventId=event.eventId, sourceSystem=event.sourceSystem, eventType=event.eventType, severity=event.severity,
        message=event.message, coords=event.coords, payload=event.payload, dispatchCallId=event.dispatchCallId, incidentId=event.incidentId
    }, 'dpn-emergency-network')
    return reference and clean(reference, 64) or nil
end

local function intelligenceRoute(event, policy)
    if not policy.intelligence or event.sourceSystem == 'intelligence' then return end
    callExport('intelligence', 'CreateIntelAlert', {
        alertType=event.eventType,
        title=event.title,
        description=event.message,
        priority=event.severity,
        subjectType=event.payload.subjectType,
        subjectKey=event.payload.subjectKey or event.payload.plate or event.payload.citizenid,
        metadata={ networkEventId=event.eventId, sourceSystem=event.sourceSystem, payload=event.payload }
    })
end

local function operationsRoute(event)
    if event.sourceSystem == 'law_operations' then return end
    callExport('law_operations', 'CreateOperationalAudit', 0, 'NETWORK_EVENT', event.eventId, {
        sourceSystem=event.sourceSystem, eventType=event.eventType, severity=event.severity,
        dispatchCallId=event.dispatchCallId, incidentId=event.incidentId, reference=event.payload.reference
    })
end

local function persistEvent(event, payloadJson)
    MySQL.insert([[INSERT INTO dpn_network_events
        (event_id, source_system, event_type, severity, title, message, actor_cid, actor_name, actor_job, department, coords, payload,
         dispatch_call_id, incident_id, evidence_reference, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'open', NOW(), NOW())]], {
        event.eventId, event.sourceSystem, event.eventType, event.severity, event.title, event.message,
        event.actor.citizenid, event.actor.name, event.actor.job, event.department, event.coords and json.encode(event.coords) or nil,
        payloadJson, event.dispatchCallId, event.incidentId, event.evidenceReference
    })
end

local function broadcastStateSoon()
    local now = os.time()
    if now == LastBroadcastAt then return end
    LastBroadcastAt = now
    SetTimeout(350, function()
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            local allowed = src and isAuthorized(src, false)
            if allowed then
                local ok, state = pcall(function() return exports[GetCurrentResourceName()]:GetNetworkState(src) end)
                if ok then TriggerClientEvent('dpn-emergency-network:client:stateChanged', src, state) end
            end
        end
    end)
end

local function publishEvent(sourceSystem, eventType, payload, sourceId, trusted)
    sourceSystem = trim(sourceSystem, 64):lower():gsub('[^%w_%-]', '')
    eventType = trim(eventType, 64):lower():gsub('[^%w_%-]', '')
    if sourceSystem == '' then sourceSystem = 'unknown' end
    if eventType == '' then eventType = 'generic' end
    sourceId = tonumber(sourceId) or 0

    local allowed, info = isAuthorized(sourceId, true)
    if sourceId > 0 and (not allowed or not rateAllowed(sourceId)) then return nil, 'unauthorized_or_rate_limited' end
    info = info or playerInfo(0)

    payload = type(payload) == 'table' and payload or { message=tostring(payload or '') }
    local safePayload, payloadJson = encodePayload(payload)
    local policy = eventPolicy(eventType)
    local coords = sourceId > 0 and playerCoords(sourceId) or normalizeCoords(safePayload.coords or safePayload.location)
    local severity = clamp(safePayload.severity or safePayload.priority or policy.severity or 3, 1, 5)
    local title = trim(safePayload.title or policy.title or eventType, 180)
    local message = trim(safePayload.message or safePayload.description or safePayload.notes or title, 1800)
    local department = trim(safePayload.department or info.department or (policy.departments and policy.departments[1]) or 'all', 32)
    local event = {
        eventId=makeId('NET'), sourceSystem=sourceSystem, eventType=eventType, severity=severity,
        title=title, message=message, coords=coords, department=department, payload=safePayload,
        actor=info, createdAt=os.time(), status='open', trusted=trusted == true
    }

    local suppressRouting = (sourceId <= 0 or trusted == true) and safePayload.suppressRouting == true
    if not suppressRouting then
        event.dispatchCallId = dispatchRoute(event, policy)
        event.incidentId = incidentRoute(event, policy)
        event.evidenceReference = evidenceRoute(event, policy)
        intelligenceRoute(event, policy)
        operationsRoute(event)
    end
    persistEvent(event, payloadJson)
    pushMemoryEvent(event)
    audit(info, 'EVENT_PUBLISHED', event.eventId, { sourceSystem=sourceSystem, eventType=eventType, severity=severity, dispatchCallId=event.dispatchCallId, incidentId=event.incidentId })

    if severity <= 1 then
        for _, playerId in ipairs(GetPlayers()) do
            local target = tonumber(playerId)
            local canView, targetInfo = target and isAuthorized(target, false)
            if canView and targetInfo and (targetInfo.department == 'law' or targetInfo.department == 'dispatch' or targetInfo.supervisor) then
                TriggerClientEvent('dpn-emergency-network:client:criticalSignal', target, event)
            end
        end
    end
    broadcastStateSoon()
    return event.eventId, event
end

local function safeRows(logicalSystem, exportName, limit)
    local ok, rows = callExport(logicalSystem, exportName)
    if not ok or type(rows) ~= 'table' then return {} end
    local result, count = {}, 0
    for key, row in pairs(rows) do
        count = count + 1
        if count > (limit or 100) then break end
        local safe = cloneSerializable(row)
        if type(safe) == 'table' and safe.id == nil and safe.callId == nil and type(key) ~= 'number' then safe.id = key end
        result[#result+1] = safe
    end
    return result
end

local function scalar(query, params)
    local ok, value = pcall(function() return MySQL.scalar.await(query, params or {}) end)
    return ok and tonumber(value) or 0
end

local function queryRecentEvents(limit)
    limit = clamp(limit or Config.RecentEventLimit, 1, 150)
    local rows = MySQL.query.await(([[SELECT event_id, source_system, event_type, severity, title, message, actor_cid, actor_name, actor_job,
        department, coords, payload, dispatch_call_id, incident_id, evidence_reference, status, acknowledged_by, acknowledged_at,
        resolved_by, resolution, resolved_at, created_at, updated_at
        FROM dpn_network_events ORDER BY created_at DESC LIMIT %d]]):format(limit), {}) or {}
    for _, row in ipairs(rows) do
        row.coords = decode(row.coords, nil)
        row.payload = decode(row.payload, {})
    end
    return rows
end

local function buildNetworkState(src)
    local allowed, info = isAuthorized(src, false)
    if not allowed then return nil end
    refreshResources(false)
    local resources, summary = {}, { online=0, degraded=0, offline=0, criticalOffline=0, total=0 }
    for logical, status in pairs(ResourceSnapshot) do
        resources[#resources+1] = cloneSerializable(status)
        summary.total = summary.total + 1
        if status.state == 'started' then
            summary.online = summary.online + 1
        elseif status.state == 'starting' or status.state == 'stopping' or status.state == 'unknown' then
            summary.degraded = summary.degraded + 1
        else
            summary.offline = summary.offline + 1
            if status.critical then summary.criticalOffline = summary.criticalOffline + 1 end
        end
    end
    table.sort(resources, function(a,b)
        if a.critical ~= b.critical then return a.critical end
        if a.category ~= b.category then return tostring(a.category) < tostring(b.category) end
        return tostring(a.label) < tostring(b.label)
    end)

    local activeCalls = safeRows('dispatch', 'GetActiveCalls', 100)
    local dispatchUnits = safeRows('dispatch', 'GetUnits', 150)
    local incidents = safeRows('incident_command', 'GetIncidents', 75)
    local safetyAlerts = safeRows('officer_safety', 'GetAlerts', 75)
    local drones = safeRows('drone', 'GetActiveDrones', 50)
    local bolos = safeRows('smart_city', 'GetActiveBolos', 75)

    local counts = {
        dispatchCalls=#activeCalls,
        dispatchUnits=#dispatchUnits,
        incidents=#incidents,
        safetyAlerts=#safetyAlerts,
        activeDrones=#drones,
        activeBolos=#bolos,
        openNetworkEvents=scalar("SELECT COUNT(*) FROM dpn_network_events WHERE status IN ('open','acknowledged')"),
        criticalNetworkEvents=scalar("SELECT COUNT(*) FROM dpn_network_events WHERE status IN ('open','acknowledged') AND severity = 1"),
        evidenceCases=scalar("SELECT COUNT(*) FROM dpn_evidence_cases WHERE status <> 'closed'"),
        activeWarrants=scalar("SELECT COUNT(*) FROM dpn_le_warrants WHERE status='approved' AND (expires_at IS NULL OR expires_at > NOW())"),
        openSupervisorTasks=scalar("SELECT COUNT(*) FROM dpn_le_supervisor_tasks WHERE status='open'")
    }

    return {
        generatedAt=os.time(),
        viewer={ citizenid=info.citizenid, name=info.name, department=info.department, supervisor=info.supervisor },
        summary=summary,
        counts=counts,
        resources=resources,
        events=queryRecentEvents(Config.RecentEventLimit),
        activeCalls=activeCalls,
        dispatchUnits=dispatchUnits,
        incidents=incidents,
        safetyAlerts=safetyAlerts,
        drones=drones,
        bolos=bolos,
        adapters=cloneSerializable(RegisteredAdapters)
    }
end

local function acknowledgeEvent(src, eventId)
    local allowed, info = isAuthorized(src, true)
    if not allowed or not info then return false, 'access_denied' end
    eventId = trim(eventId, 64)
    local changed = MySQL.update.await([[UPDATE dpn_network_events SET status='acknowledged', acknowledged_by=?, acknowledged_at=NOW(), updated_at=NOW()
        WHERE event_id=? AND status='open']], { info.citizenid, eventId })
    if tonumber(changed or 0) > 0 then
        audit(info, 'EVENT_ACKNOWLEDGED', eventId, {})
        broadcastStateSoon()
        return true
    end
    return false, 'not_open'
end

local function resolveEvent(src, eventId, resolution)
    local allowed, info = isAuthorized(src, true)
    if not allowed or not info then return false, 'access_denied' end
    eventId, resolution = trim(eventId, 64), trim(resolution, 1800)
    if resolution == '' then return false, 'resolution_required' end
    local changed = MySQL.update.await([[UPDATE dpn_network_events SET status='resolved', resolved_by=?, resolution=?, resolved_at=NOW(), updated_at=NOW()
        WHERE event_id=? AND status IN ('open','acknowledged')]], { info.citizenid, resolution, eventId })
    if tonumber(changed or 0) > 0 then
        audit(info, 'EVENT_RESOLVED', eventId, { resolution=resolution })
        broadcastStateSoon()
        return true
    end
    return false, 'not_active'
end

local function linkRecords(src, data)
    local allowed, info = isAuthorized(src, true)
    if not allowed or not info then return nil, 'access_denied' end
    data = type(data) == 'table' and data or {}
    local leftSystem, leftType, leftId = trim(data.leftSystem,64), trim(data.leftType,64), trim(data.leftId,96)
    local rightSystem, rightType, rightId = trim(data.rightSystem,64), trim(data.rightType,64), trim(data.rightId,96)
    if leftSystem == '' or leftType == '' or leftId == '' or rightSystem == '' or rightType == '' or rightId == '' then return nil, 'invalid_link' end
    local linkId = makeId('LINK')
    MySQL.insert.await([[INSERT INTO dpn_network_record_links
        (link_id,left_system,left_type,left_id,right_system,right_type,right_id,relationship,metadata,created_by_cid,created_by_name,created_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,NOW())]], {
        linkId,leftSystem,leftType,leftId,rightSystem,rightType,rightId,trim(data.relationship or 'related',80),
        json.encode(cloneSerializable(data.metadata or {})),info.citizenid,info.name
    })
    audit(info, 'RECORDS_LINKED', linkId, data)
    return linkId
end

RegisterNetEvent('dpn-emergency-network:server:publish', function(eventType, payload)
    local src = source
    local info = playerInfo(src)
    local system = info and info.department or 'player'
    local eventId, err = publishEvent(system, eventType, payload, src, false)
    if not eventId and src > 0 then notify(src, ('Network event rejected: %s'):format(err or 'unknown'), 'error') end
end)

RegisterNetEvent('dpn-emergency-network:server:requestState', function()
    local src = source
    local state = buildNetworkState(src)
    if state then TriggerClientEvent('dpn-emergency-network:client:state', src, state) end
end)

RegisterNetEvent('dpn-emergency-network:server:acknowledge', function(eventId)
    local src = source
    local ok, err = acknowledgeEvent(src, eventId)
    notify(src, ok and 'Network event acknowledged.' or ('Unable to acknowledge: '..tostring(err)), ok and 'success' or 'error')
end)

RegisterNetEvent('dpn-emergency-network:server:resolve', function(eventId, resolution)
    local src = source
    local ok, err = resolveEvent(src, eventId, resolution)
    notify(src, ok and 'Network event resolved.' or ('Unable to resolve: '..tostring(err)), ok and 'success' or 'error')
end)

RegisterNetEvent('dpn-emergency-network:server:linkRecords', function(data)
    local src = source
    local linkId, err = linkRecords(src, data)
    notify(src, linkId and ('Records linked: '..linkId) or ('Unable to link records: '..tostring(err)), linkId and 'success' or 'error')
end)

-- Compatibility aliases are deliberately server-only. External DPN resources call
-- TriggerEvent on the server; clients must use the authorized canonical publish event.
for eventName, fixedSystem in pairs(Config.SystemEventAliases or {}) do
    local aliasName, aliasSystem = eventName, fixedSystem
    AddEventHandler(aliasName, function(eventType, payload)
        publishEvent(aliasSystem, eventType, payload, 0, true)
    end)
end

AddEventHandler('playerDropped', function()
    RateLimits[source] = nil
end)

CreateThread(function()
    Wait(2000)
    refreshResources(false)
    while true do
        Wait(math.max(10, tonumber(Config.HealthIntervalSeconds) or 20) * 1000)
        local before = ResourceSnapshot
        refreshResources(true)
        local changed = false
        for logical, status in pairs(ResourceSnapshot) do
            local previous = before[logical]
            if previous and (previous.state ~= status.state or previous.resource ~= status.resource) then
                changed = true
                if status.critical and status.state ~= 'started' then
                    publishEvent('emergency_network', 'infrastructure_failure', {
                        title=('Critical DPN resource offline: %s'):format(status.label),
                        message=('The %s integration changed from %s to %s.'):format(status.resource or logical, previous.state or 'unknown', status.state),
                        severity=2,
                        logicalSystem=logical,
                        resource=status.resource,
                        previousState=previous.state,
                        newState=status.state
                    }, 0, true)
                end
            end
        end
        if changed then broadcastStateSoon() end
    end
end)

exports('PublishEvent', function(sourceSystem, eventType, payload, sourceId)
    return publishEvent(sourceSystem, eventType, payload, tonumber(sourceId) or 0, true)
end)

exports('GetNetworkState', function(sourceId)
    return buildNetworkState(tonumber(sourceId) or 0)
end)

exports('GetIntegrationStatus', function(logicalSystem)
    refreshResources(false)
    return cloneSerializable(ResourceSnapshot[logicalSystem] or resourceResolution(logicalSystem))
end)

exports('ResolveResource', function(logicalSystem)
    return resolvedResource(logicalSystem)
end)

exports('AcknowledgeEvent', function(sourceId, eventId)
    return acknowledgeEvent(tonumber(sourceId) or 0, eventId)
end)

exports('ResolveEvent', function(sourceId, eventId, resolution)
    return resolveEvent(tonumber(sourceId) or 0, eventId, resolution)
end)

exports('LinkRecords', function(sourceId, data)
    return linkRecords(tonumber(sourceId) or 0, data)
end)

exports('RegisterAdapter', function(name, metadata)
    name = trim(name, 64)
    if name == '' then return false end
    RegisteredAdapters[name] = cloneSerializable(metadata or {})
    RegisteredAdapters[name].registeredAt = os.time()
    return true
end)
