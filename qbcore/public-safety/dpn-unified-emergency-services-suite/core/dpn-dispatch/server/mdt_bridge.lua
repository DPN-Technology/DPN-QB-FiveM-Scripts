
DPNDispatchMDT = DPNDispatchMDT or {}

local function Debug(...)
    if Config and Config.MDT and Config.MDT.debug then
        print('[dpn-dispatch:mdt]', ...)
    end
end

local function MdtReady()
    return Config.MDT and Config.MDT.enabled and Config.MDT.resource and GetResourceState(Config.MDT.resource) == 'started'
end

local function SafeExport(exportName, payload)
    if not MdtReady() or not Config.MDT.exports or not Config.MDT.exports.enabled or not exportName or exportName == '' then
        return false, nil
    end

    local ok, result = pcall(function()
        return exports[Config.MDT.resource][exportName](payload)
    end)

    if not ok then
        Debug(('export failed: %s'):format(exportName), result)
        return false, result
    end

    return true, result
end

local function FireEvent(eventName, payload)
    if not Config.MDT.events or not Config.MDT.events.enabled or not eventName or eventName == '' then return end
    local ok, err = pcall(function()
        TriggerEvent(eventName, payload)
    end)
    if not ok then Debug(('event failed: %s'):format(eventName), err) end
end

local function MakeRef(kind, id)
    return ('%s-%s-%s-%s'):format(Config.MDT.referencePrefix or 'DPN-MDT', kind, os.date('%Y%m%d'), tostring(id or math.random(1000, 9999)))
end

function DPNDispatchMDT.BuildCallPayload(call, action)
    if not call then return nil end
    call.meta = call.meta or {}
    call.meta.mdtRef = call.meta.mdtRef or MakeRef('CALL', call.id)

    return {
        source = 'dpn-dispatch',
        action = action or 'sync',
        mdtRef = call.meta.mdtRef,
        dispatchCallId = call.id,
        caseId = call.caseId,
        code = call.code,
        title = call.title,
        description = call.description,
        departments = call.departments or {},
        primaryDepartment = call.primaryDepartment,
        priority = call.priority,
        status = call.status,
        location = call.location,
        coords = call.coords,
        caller = call.caller,
        assignedUnits = call.assignedUnits or {},
        linkedReports = call.linkedReports or {},
        tags = call.tags or {},
        incidentClass = call.incidentClass,
        responseLevel = call.responseLevel,
        riskFlags = call.riskFlags or {},
        staging = call.staging,
        command = call.command,
        radioChannel = call.radioChannel,
        unitsRequested = call.unitsRequested or {},
        recommendedResponse = call.recommendedResponse or {},
        sop = call.sop or {},
        disposition = call.disposition,
        notes = call.notes or {},
        createdBy = call.createdBy,
        createdAt = call.createdAt,
        updatedAt = call.updatedAt,
        raw = call
    }
end

function DPNDispatchMDT.BuildReportPayload(report, action)
    if not report then return nil end
    report.meta = report.meta or {}
    report.meta.mdtRef = report.meta.mdtRef or MakeRef('RPT', report.id)

    return {
        source = 'dpn-dispatch',
        action = action or 'sync',
        mdtRef = report.meta.mdtRef,
        dispatchReportId = report.id,
        reportNumber = report.reportNumber,
        caseId = report.caseId,
        dispatchCallId = report.callId,
        type = report.type,
        title = report.title,
        summary = report.summary,
        narrative = report.narrative,
        department = report.department,
        departments = report.departments or {},
        priority = report.priority,
        status = report.status,
        location = report.location,
        coords = report.coords,
        reportingUnit = report.reportingUnit,
        involved = report.involved or {},
        tags = report.tags or {},
        approvals = report.approvals or {},
        sealed = report.sealed == true,
        confidential = report.confidential == true,
        locked = report.locked == true,
        audit = report.audit or {},
        createdBy = report.createdBy,
        createdAt = report.createdAt,
        updatedAt = report.updatedAt,
        raw = report
    }
end

function DPNDispatchMDT.SyncCall(call, action)
    if not Config.MDT or not Config.MDT.enabled or not call then return end
    local payload = DPNDispatchMDT.BuildCallPayload(call, action)
    if not payload then return end

    if action == 'created' and Config.MDT.createMdtCaseOnCall then
        local ok, result = SafeExport(Config.MDT.exports and Config.MDT.exports.createCaseFromCall, payload)
        if ok and result then
            call.meta = call.meta or {}
            call.meta.mdtCaseId = type(result) == 'table' and (result.caseId or result.id or result.mdtCaseId) or result
            payload.mdtCaseId = call.meta.mdtCaseId
        end
        SafeExport(Config.MDT.exports and Config.MDT.exports.syncCall, payload)
        FireEvent(Config.MDT.events and Config.MDT.events.callCreated, payload)
    else
        SafeExport(Config.MDT.exports and (Config.MDT.exports.updateCall or Config.MDT.exports.syncCall), payload)
        FireEvent(Config.MDT.events and Config.MDT.events.callUpdated, payload)
    end
end

function DPNDispatchMDT.SyncReport(report, action)
    if not Config.MDT or not Config.MDT.enabled or not Config.MDT.syncReportsToMdt or not report then return end
    if (report.sealed or report.confidential) and not Config.MDT.syncSealedReports then return end
    local payload = DPNDispatchMDT.BuildReportPayload(report, action)
    if not payload then return end

    if action == 'created' then
        local ok, result = SafeExport(Config.MDT.exports and Config.MDT.exports.attachReportToCase, payload)
        if ok and result then
            report.meta = report.meta or {}
            report.meta.mdtReportId = type(result) == 'table' and (result.reportId or result.id or result.mdtReportId) or result
            payload.mdtReportId = report.meta.mdtReportId
        end
        SafeExport(Config.MDT.exports and Config.MDT.exports.syncReport, payload)
        FireEvent(Config.MDT.events and Config.MDT.events.reportCreated, payload)
    else
        SafeExport(Config.MDT.exports and (Config.MDT.exports.updateReport or Config.MDT.exports.syncReport), payload)
        FireEvent(Config.MDT.events and Config.MDT.events.reportUpdated, payload)
    end
end

function DPNDispatchMDT.SyncUnit(unit, action)
    if not Config.MDT or not Config.MDT.enabled or not unit then return end
    local payload = {
        source = 'dpn-dispatch',
        action = action or 'updated',
        unit = unit,
        updatedAt = os.time()
    }
    FireEvent(Config.MDT.events and Config.MDT.events.unitUpdated, payload)
end
