--[[
    DPN Technology — Phase 3C Dispatch Correlation Bridge

    Adds correlation-first idempotency around the existing dispatch call creator
    without replacing legacy call IDs, events, exports, MDT sync, persistence,
    or gameplay behavior.
]]

if not DPNDispatchServer or not DPNDispatchServer.CreateCall then
    error('[dpn-dispatch] Phase 3C correlation bridge loaded before dispatch server core')
end

local Dispatch = DPNDispatchServer
local BaseCreateCall = Dispatch.CreateCall
local EventIndex = {}
local CorrelationResource = 'dpn-unified-emergency-network'

local function CopyCorrelation(correlation)
    if type(correlation) ~= 'table' then return nil end
    return {
        eventId = correlation.eventId,
        medicalCallId = correlation.medicalCallId,
        dispatchCallId = correlation.dispatchCallId,
        incidentId = correlation.incidentId,
        mdtCaseId = correlation.mdtCaseId,
        sourceResource = correlation.sourceResource,
        createdAt = correlation.createdAt,
        updatedAt = correlation.updatedAt
    }
end

local function RequestedCorrelation(data)
    data = type(data) == 'table' and data or {}
    local nested = type(data.correlation) == 'table' and data.correlation or {}
    local meta = type(data.meta) == 'table' and data.meta or {}
    local metaCorrelation = type(meta.emergencyCorrelation) == 'table' and meta.emergencyCorrelation or {}

    return {
        eventId = data.eventId or nested.eventId or metaCorrelation.eventId,
        medicalCallId = data.medicalCallId or nested.medicalCallId or metaCorrelation.medicalCallId,
        dispatchCallId = data.dispatchCallId or nested.dispatchCallId or metaCorrelation.dispatchCallId,
        incidentId = data.incidentId or nested.incidentId or metaCorrelation.incidentId,
        mdtCaseId = data.mdtCaseId or nested.mdtCaseId or metaCorrelation.mdtCaseId
    }
end

local function CorrelationReady()
    return GetResourceState(CorrelationResource) == 'started'
end

local function NormalizeCorrelation(data)
    if not CorrelationReady() then return nil end

    local ok, correlation = pcall(function()
        return exports[CorrelationResource]:CreateEmergencyCorrelation(RequestedCorrelation(data))
    end)

    if not ok or type(correlation) ~= 'table' or not correlation.eventId then
        print(('[dpn-dispatch] Phase 3C correlation normalization failed: %s'):format(tostring(correlation)))
        return nil
    end

    return correlation
end

local function GetCalls()
    if not Dispatch.GetCalls then return {} end
    return Dispatch.GetCalls() or {}
end

local function FindExistingCall(eventId)
    if not eventId then return nil, nil end

    local calls = GetCalls()
    local indexedId = EventIndex[eventId]
    if indexedId and calls[indexedId] then
        return indexedId, calls[indexedId]
    end

    for callId, call in pairs(calls) do
        local correlation = type(call) == 'table' and call.correlation or nil
        local meta = type(call) == 'table' and call.meta or nil
        local metaCorrelation = type(meta) == 'table' and meta.emergencyCorrelation or nil
        if (call and call.eventId == eventId)
            or (type(correlation) == 'table' and correlation.eventId == eventId)
            or (type(metaCorrelation) == 'table' and metaCorrelation.eventId == eventId) then
            EventIndex[eventId] = callId
            return callId, call
        end
    end

    return nil, nil
end

local function EnsureDispatchLink(correlation, callId)
    if type(correlation) ~= 'table' or not correlation.eventId then return correlation end
    if correlation.dispatchCallId then return correlation end

    local desired = ('DPN-DSP-%s'):format(tostring(callId))
    local ok, linked = pcall(function()
        return exports[CorrelationResource]:LinkEmergencyCorrelation(correlation.eventId, 'dispatchCallId', desired)
    end)

    if not ok or not linked then
        local getOk, current = pcall(function()
            return exports[CorrelationResource]:GetEmergencyCorrelation(correlation.eventId)
        end)
        if getOk and type(current) == 'table' then return current end
        return correlation
    end

    local getOk, current = pcall(function()
        return exports[CorrelationResource]:GetEmergencyCorrelation(correlation.eventId)
    end)
    if getOk and type(current) == 'table' then return current end
    return correlation
end

local function AttachCorrelation(call, correlation)
    if type(call) ~= 'table' or type(correlation) ~= 'table' then return end

    local canonical = CopyCorrelation(correlation)
    call.eventId = canonical.eventId
    call.medicalCallId = canonical.medicalCallId
    call.dispatchCallId = canonical.dispatchCallId
    call.incidentId = canonical.incidentId
    call.mdtCaseId = canonical.mdtCaseId
    call.sourceResource = canonical.sourceResource
    call.correlation = canonical
    call.meta = type(call.meta) == 'table' and call.meta or {}
    call.meta.emergencyCorrelation = CopyCorrelation(canonical)

    EventIndex[canonical.eventId] = call.id

    -- The base creator already persisted and broadcast the legacy-compatible call.
    -- Refresh those surfaces after additive correlation metadata is attached.
    if DPNDispatchDatabase and DPNDispatchDatabase.UpdateCall then
        DPNDispatchDatabase.UpdateCall(call)
    end
    if DPNDispatchMDT and DPNDispatchMDT.SyncCall then
        DPNDispatchMDT.SyncCall(call, 'correlation_linked')
    end
    if Dispatch.BroadcastState then
        Dispatch.BroadcastState()
    end
end

function Dispatch.CreateCall(data, creator)
    data = type(data) == 'table' and data or {}

    local correlation = NormalizeCorrelation(data)
    if correlation and correlation.eventId then
        local existingId, existingCall = FindExistingCall(correlation.eventId)
        if existingId and existingCall then
            return existingId, existingCall, true
        end
    end

    local id, call = BaseCreateCall(data, creator)
    if not id or type(call) ~= 'table' then return id, call, false end

    if correlation then
        correlation = EnsureDispatchLink(correlation, id)
        AttachCorrelation(call, correlation)
    end

    return id, call, false
end

print('[dpn-dispatch] Phase 3C correlation-first dispatch deduplication active')
