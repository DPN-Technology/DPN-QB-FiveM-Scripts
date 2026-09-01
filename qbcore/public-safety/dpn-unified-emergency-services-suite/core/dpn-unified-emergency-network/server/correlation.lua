--[[
    DPN Technology — Unified Emergency Correlation Contract
    Phase 3B

    Root emergency IDs are issued server-side by dpn-unified-emergency-network.
    Callers may reuse an existing eventId only when that eventId is already known
    to this authority. Unknown caller-supplied root IDs are replaced.
]]

DPN_UNES = DPN_UNES or {}
DPN_UNES.Server = DPN_UNES.Server or {}
DPN_UNES.Cache = DPN_UNES.Cache or {}
DPN_UNES.Cache.correlations = DPN_UNES.Cache.correlations or {}

local correlationCounter = 0
local MAX_ID_LENGTH = 96
local CHILD_FIELDS = {
    medicalCallId = true,
    dispatchCallId = true,
    incidentId = true,
    mdtCaseId = true
}

local function now()
    return os.time()
end

local function clean(value, maxLength)
    if value == nil then return nil end
    local text = tostring(value):gsub('[%c]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return nil end
    return text:sub(1, maxLength or MAX_ID_LENGTH)
end

local function generateEventId()
    correlationCounter = correlationCounter + 1
    if correlationCounter > 999999 then correlationCounter = 1 end
    local entropy = math.random(0, 0xFFFFFF)
    return ('DPN-EVT-%d-%06d-%06X'):format(now(), correlationCounter, entropy)
end

local function copyCorrelation(record)
    if type(record) ~= 'table' then return nil end
    return {
        eventId = record.eventId,
        medicalCallId = record.medicalCallId,
        dispatchCallId = record.dispatchCallId,
        incidentId = record.incidentId,
        mdtCaseId = record.mdtCaseId,
        sourceResource = record.sourceResource,
        createdAt = record.createdAt,
        updatedAt = record.updatedAt
    }
end

local function resolveSourceResource(requested)
    local invoking = GetInvokingResource and GetInvokingResource() or nil
    return clean(invoking or requested or GetCurrentResourceName(), 96) or GetCurrentResourceName()
end

function DPN_UNES.Server.CreateCorrelation(payload, requestedSourceResource)
    payload = type(payload) == 'table' and payload or {}
    local requestedRoot = clean(payload.eventId)
    local existing = requestedRoot and DPN_UNES.Cache.correlations[requestedRoot] or nil

    if existing then
        return copyCorrelation(existing), false
    end

    local eventId = generateEventId()
    local stamp = now()
    local record = {
        eventId = eventId,
        medicalCallId = clean(payload.medicalCallId),
        dispatchCallId = clean(payload.dispatchCallId),
        incidentId = clean(payload.incidentId),
        mdtCaseId = clean(payload.mdtCaseId),
        sourceResource = resolveSourceResource(requestedSourceResource or payload.sourceResource),
        createdAt = stamp,
        updatedAt = stamp
    }

    DPN_UNES.Cache.correlations[eventId] = record
    return copyCorrelation(record), true
end

function DPN_UNES.Server.GetCorrelation(eventId)
    return copyCorrelation(DPN_UNES.Cache.correlations[clean(eventId)])
end

function DPN_UNES.Server.LinkCorrelation(eventId, field, value)
    eventId = clean(eventId)
    field = clean(field, 32)
    value = clean(value)
    if not eventId or not field or not value or not CHILD_FIELDS[field] then
        return false, 'invalid-correlation-link'
    end

    local record = DPN_UNES.Cache.correlations[eventId]
    if not record then return false, 'unknown-event-id' end

    local current = record[field]
    if current and current ~= value then
        return false, 'immutable-link-conflict'
    end

    record[field] = value
    record.updatedAt = now()
    return true, copyCorrelation(record)
end

function DPN_UNES.Server.NormalizeCorrelation(payload, requestedSourceResource)
    local correlation, created = DPN_UNES.Server.CreateCorrelation(payload, requestedSourceResource)
    if not correlation then return nil, false end

    for field in pairs(CHILD_FIELDS) do
        local requested = type(payload) == 'table' and clean(payload[field]) or nil
        if requested then
            local ok = DPN_UNES.Server.LinkCorrelation(correlation.eventId, field, requested)
            if not ok then
                correlation = DPN_UNES.Server.GetCorrelation(correlation.eventId)
            end
        end
    end

    return DPN_UNES.Server.GetCorrelation(correlation.eventId), created
end

function DPN_UNES.Server.ValidateCorrelation(payload)
    if type(payload) ~= 'table' then return false, 'payload-not-table' end
    local eventId = clean(payload.eventId)
    if not eventId then return false, 'missing-event-id' end
    local record = DPN_UNES.Cache.correlations[eventId]
    if not record then return false, 'unknown-event-id' end

    for field in pairs(CHILD_FIELDS) do
        local supplied = clean(payload[field])
        if supplied and record[field] and supplied ~= record[field] then
            return false, ('%s-conflict'):format(field)
        end
    end

    return true, copyCorrelation(record)
end

-- Server-only internal event. Deliberately not registered as a network event.
AddEventHandler('dpn-unes:server:correlationLink', function(eventId, field, value)
    DPN_UNES.Server.LinkCorrelation(eventId, field, value)
end)

exports('CreateEmergencyCorrelation', function(payload)
    return DPN_UNES.Server.NormalizeCorrelation(payload or {}, GetInvokingResource())
end)

exports('GetEmergencyCorrelation', function(eventId)
    return DPN_UNES.Server.GetCorrelation(eventId)
end)

exports('LinkEmergencyCorrelation', function(eventId, field, value)
    return DPN_UNES.Server.LinkCorrelation(eventId, field, value)
end)

exports('ValidateEmergencyCorrelation', function(payload)
    return DPN_UNES.Server.ValidateCorrelation(payload)
end)

CreateThread(function()
    math.randomseed(os.time() + (GetGameTimer and GetGameTimer() or 0))
    print('[DPN-UNES] Phase 3B emergency correlation authority active')
end)
