-- DPN Technology - Phase 3D MDT correlation integration

if not DPNDispatchMDT then
    error('[dpn-dispatch] Phase 3D MDT correlation bridge loaded before MDT bridge')
end

local MDT = DPNDispatchMDT
local BaseBuildCallPayload = MDT.BuildCallPayload
local BaseBuildReportPayload = MDT.BuildReportPayload
local BaseSyncCall = MDT.SyncCall
local CorrelationResource = 'dpn-unified-emergency-network'

local function copyCorrelation(value)
    if type(value) ~= 'table' then return nil end
    return {
        eventId = value.eventId,
        medicalCallId = value.medicalCallId,
        dispatchCallId = value.dispatchCallId,
        incidentId = value.incidentId,
        mdtCaseId = value.mdtCaseId,
        sourceResource = value.sourceResource,
        createdAt = value.createdAt,
        updatedAt = value.updatedAt
    }
end

local function getCallCorrelation(call)
    if type(call) ~= 'table' then return nil end
    if type(call.correlation) == 'table' then return copyCorrelation(call.correlation) end
    if type(call.meta) == 'table' and type(call.meta.emergencyCorrelation) == 'table' then
        return copyCorrelation(call.meta.emergencyCorrelation)
    end
    if call.eventId then
        return copyCorrelation(call)
    end
    return nil
end

local function refreshCorrelation(eventId)
    if not eventId or GetResourceState(CorrelationResource) ~= 'started' then return nil end
    local ok, current = pcall(function()
        return exports[CorrelationResource]:GetEmergencyCorrelation(eventId)
    end)
    if ok and type(current) == 'table' then return current end
    return nil
end

local function attachPayloadCorrelation(payload, correlation, legacyCallId)
    if type(payload) ~= 'table' then return payload end
    payload.call_id = payload.call_id or legacyCallId
    payload.legacyDispatchCallId = payload.legacyDispatchCallId or legacyCallId
    if type(correlation) ~= 'table' then return payload end

    payload.eventId = correlation.eventId
    payload.medicalCallId = correlation.medicalCallId
    payload.dispatchCallId = correlation.dispatchCallId or payload.dispatchCallId
    payload.incidentId = correlation.incidentId
    payload.mdtCaseId = correlation.mdtCaseId or payload.mdtCaseId
    payload.sourceResource = correlation.sourceResource
    payload.correlation = copyCorrelation(correlation)
    return payload
end

function MDT.BuildCallPayload(call, action)
    local payload = BaseBuildCallPayload(call, action)
    return attachPayloadCorrelation(payload, getCallCorrelation(call), call and call.id or nil)
end

function MDT.BuildReportPayload(report, action)
    local payload = BaseBuildReportPayload(report, action)
    if type(payload) ~= 'table' then return payload end

    local linkedCall = DPNDispatchServer and DPNDispatchServer.GetCall and report and report.callId
        and DPNDispatchServer.GetCall(report.callId) or nil
    local correlation = getCallCorrelation(linkedCall)
    return attachPayloadCorrelation(payload, correlation, report and report.callId or nil)
end

function MDT.SyncCall(call, action)
    BaseSyncCall(call, action)

    local correlation = getCallCorrelation(call)
    local mdtCaseId = type(call) == 'table' and type(call.meta) == 'table' and call.meta.mdtCaseId or nil
    if not correlation or not correlation.eventId or not mdtCaseId then return end
    if GetResourceState(CorrelationResource) ~= 'started' then return end

    local ok, linked = pcall(function()
        return exports[CorrelationResource]:LinkEmergencyCorrelation(correlation.eventId, 'mdtCaseId', tostring(mdtCaseId))
    end)
    if not ok or not linked then return end

    local current = refreshCorrelation(correlation.eventId)
    if not current then return end

    call.meta = call.meta or {}
    call.correlation = copyCorrelation(current)
    call.meta.emergencyCorrelation = copyCorrelation(current)
    call.eventId = current.eventId
    call.medicalCallId = current.medicalCallId
    call.dispatchCallId = current.dispatchCallId
    call.incidentId = current.incidentId
    call.mdtCaseId = current.mdtCaseId
    call.sourceResource = current.sourceResource
end

print('[dpn-dispatch] Phase 3D MDT correlation integration active')
