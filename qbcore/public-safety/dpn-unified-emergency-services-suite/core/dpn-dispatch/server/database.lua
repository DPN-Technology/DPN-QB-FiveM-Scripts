local Database = {}

local function OxReady()
    return Config.Database.enabled and GetResourceState(Config.Database.resource) == 'started' and exports[Config.Database.resource]
end

function Database.InsertCall(call)
    if not OxReady() then return end

    exports[Config.Database.resource]:insert([[
        INSERT INTO dpn_dispatch_calls
            (call_id, case_id, code, title, description, departments, priority, status, location, coords, caller_name, caller_source, assigned_units, linked_reports, payload)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        call.id,
        call.caseId,
        call.code,
        call.title,
        call.description,
        json.encode(call.departments or {}),
        call.priority,
        call.status,
        call.location,
        json.encode(call.coords or {}),
        call.caller and call.caller.name or 'Unknown',
        call.caller and call.caller.source or 0,
        json.encode(call.assignedUnits or {}),
        json.encode(call.linkedReports or {}),
        json.encode(call)
    })
end

function Database.UpdateCall(call)
    if not OxReady() then return end

    exports[Config.Database.resource]:update([[
        UPDATE dpn_dispatch_calls
        SET status = ?, priority = ?, assigned_units = ?, linked_reports = ?, payload = ?, updated_at = CURRENT_TIMESTAMP
        WHERE call_id = ?
    ]], {
        call.status,
        call.priority,
        json.encode(call.assignedUnits or {}),
        json.encode(call.linkedReports or {}),
        json.encode(call),
        call.id
    })
end

function Database.InsertReport(report)
    if not OxReady() then return end

    exports[Config.Database.resource]:insert([[
        INSERT INTO dpn_dispatch_reports
            (report_id, report_number, case_id, call_id, type, title, summary, narrative, department, departments, priority, status, location, coords, reporting_unit, involved, tags, approvals, sealed, confidential, locked, payload)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        report.id,
        report.reportNumber,
        report.caseId,
        report.callId,
        report.type,
        report.title,
        report.summary,
        report.narrative,
        report.department,
        json.encode(report.departments or {}),
        report.priority,
        report.status,
        report.location,
        json.encode(report.coords or {}),
        json.encode(report.reportingUnit or {}),
        json.encode(report.involved or {}),
        json.encode(report.tags or {}),
        json.encode(report.approvals or {}),
        report.sealed and 1 or 0,
        report.confidential and 1 or 0,
        report.locked and 1 or 0,
        json.encode(report)
    })
end

function Database.UpdateReport(report)
    if not OxReady() then return end

    exports[Config.Database.resource]:update([[
        UPDATE dpn_dispatch_reports
        SET case_id = ?, call_id = ?, type = ?, title = ?, summary = ?, narrative = ?, department = ?, departments = ?, priority = ?, status = ?, location = ?, coords = ?, reporting_unit = ?, involved = ?, tags = ?, approvals = ?, sealed = ?, confidential = ?, locked = ?, payload = ?, updated_at = CURRENT_TIMESTAMP
        WHERE report_id = ?
    ]], {
        report.caseId,
        report.callId,
        report.type,
        report.title,
        report.summary,
        report.narrative,
        report.department,
        json.encode(report.departments or {}),
        report.priority,
        report.status,
        report.location,
        json.encode(report.coords or {}),
        json.encode(report.reportingUnit or {}),
        json.encode(report.involved or {}),
        json.encode(report.tags or {}),
        json.encode(report.approvals or {}),
        report.sealed and 1 or 0,
        report.confidential and 1 or 0,
        report.locked and 1 or 0,
        json.encode(report),
        report.id
    })
end

_G.DPNDispatchDatabase = Database
