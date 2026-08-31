local QBCore = exports['qb-core']:GetCoreObject()
local Calls = {}
local Units = {}
local Reports = {}
local NextCallId = math.random(1000, 9999)
local NextReportId = math.random(5000, 9999)

local Dispatch = {}
_G.DPNDispatchServer = Dispatch

local function Now()
    return os.time()
end

local function SafePlayerName(src)
    if not src or src == 0 then return 'System' end
    local name = GetPlayerName(src)
    return name or ('Player ' .. tostring(src))
end

local function GetQbPlayer(src)
    if not src or src == 0 then return nil end
    return QBCore.Functions.GetPlayer(src)
end

local function GetJob(src)
    local Player = GetQbPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.job then return nil end
    return Player.PlayerData.job
end

local function HasQbPermission(src, permission)
    if not src or src == 0 then return true end
    local ok, result = pcall(function()
        return QBCore.Functions.HasPermission(src, permission)
    end)
    return ok and result or false
end

local function IsAdmin(src)
    if not src or src == 0 then return true end
    if IsPlayerAceAllowed(src, Config.AcePermissions.admin) then return true end
    if IsPlayerAceAllowed(src, 'command') then return true end
    if HasQbPermission(src, 'god') or HasQbPermission(src, 'admin') then return true end
    return false
end

local function GetPlayerDepartments(src)
    if not src or src == 0 then
        local all = {}
        for name in pairs(Config.Departments) do all[#all + 1] = name end
        return all
    end

    local job = GetJob(src)
    local departments = DPNDispatch.GetDepartmentByJob(job and job.name)

    if IsPlayerAceAllowed(src, Config.AcePermissions.open) or IsAdmin(src) then
        for name in pairs(Config.Departments) do
            if not DPNDispatch.TableContains(departments, name) then departments[#departments + 1] = name end
        end
    end

    if job and Config.DispatchCenterJobs[job.name] then
        for name in pairs(Config.Departments) do
            if not DPNDispatch.TableContains(departments, name) then departments[#departments + 1] = name end
        end
    end

    return departments
end

local function CanOpenDispatch(src)
    if not src or src == 0 then return true end
    if IsAdmin(src) then return true end
    if IsPlayerAceAllowed(src, Config.AcePermissions.open) then return true end

    local job = GetJob(src)
    if not job then return false end
    if Config.DispatchCenterJobs[job.name] then return true end
    return #DPNDispatch.GetDepartmentByJob(job.name) > 0
end

local function CanSeeAll(src)
    if not src or src == 0 then return true end
    if IsAdmin(src) then return true end
    local job = GetJob(src)
    if job and Config.DispatchCenterJobs[job.name] then return true end
    return false
end

local function HasMibAccess(src)
    if CanSeeAll(src) then return true end
    local departments = GetPlayerDepartments(src)
    return DPNDispatch.TableContains(departments, 'mib')
end

local function CanAccessCall(src, call)
    if CanSeeAll(src) then return true end
    if Config.CrossDepartmentView then return CanOpenDispatch(src) end

    local departments = GetPlayerDepartments(src)
    for _, department in pairs(call.departments or {}) do
        if DPNDispatch.TableContains(departments, department) then return true end
    end
    return false
end

local function CanAccessReport(src, report)
    if CanSeeAll(src) then return true end
    if not report then return false end
    if report.createdBy and tonumber(report.createdBy) == tonumber(src) then return true end
    if report.callId and Calls[tonumber(report.callId)] and CanAccessCall(src, Calls[tonumber(report.callId)]) then
        if not report.sealed and not report.confidential then return true end
    end

    if Config.RestrictSealedReports and (report.sealed or report.confidential) and not HasMibAccess(src) then return false end

    local departments = GetPlayerDepartments(src)
    if report.department and DPNDispatch.TableContains(departments, report.department) then return true end
    for _, department in pairs(report.departments or {}) do
        if DPNDispatch.TableContains(departments, department) then return true end
    end
    return false
end

local function FormatUnit(src)
    local Player = GetQbPlayer(src)
    if not Player or not Player.PlayerData then return nil end

    local pd = Player.PlayerData
    local job = pd.job or {}
    local charinfo = pd.charinfo or {}
    local metadata = pd.metadata or {}
    local callsign = metadata.callsign or metadata.callsign2 or metadata.radiochannel or ('U-' .. tostring(src))
    local name = ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then name = SafePlayerName(src) end

    return {
        source = src,
        citizenid = pd.citizenid,
        name = name,
        callsign = tostring(callsign),
        job = job.name or 'unknown',
        jobLabel = job.label or job.name or 'Unknown',
        grade = job.grade and (job.grade.name or job.grade.level) or '',
        departments = GetPlayerDepartments(src),
        status = Units[src] and Units[src].status or 'available',
        assignedCall = Units[src] and Units[src].assignedCall or nil,
        coords = Units[src] and Units[src].coords or nil,
        radio = Units[src] and Units[src].radio or nil,
        lastSeen = Now()
    }
end

local function GetReportingUnit(src)
    local unit = Units[src] or FormatUnit(src)
    local Player = GetQbPlayer(src)
    return {
        source = src or 0,
        name = unit and unit.name or SafePlayerName(src or 0),
        callsign = unit and unit.callsign or ('U-' .. tostring(src or 0)),
        job = unit and unit.job or (GetJob(src or 0) and GetJob(src or 0).name) or 'system',
        jobLabel = unit and unit.jobLabel or 'System',
        citizenid = Player and Player.PlayerData and Player.PlayerData.citizenid or nil,
        departments = unit and unit.departments or GetPlayerDepartments(src or 0)
    }
end

local function SendDiscordLog(title, description, color, fields)
    if not Config.Discord.enabled or Config.Discord.webhook == '' then return end
    local embed = {
        {
            title = title,
            description = description or 'No description provided.',
            color = color or 3447003,
            fields = fields or {},
            footer = { text = 'DPN Dispatch' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }
    }

    PerformHttpRequest(Config.Discord.webhook, function() end, 'POST', json.encode({
        username = Config.Discord.username,
        avatar_url = Config.Discord.avatar,
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

local function SendCallDiscordLog(call, action)
    local departments = table.concat(call.departments or {}, ', ')
    SendDiscordLog(('%s | #%s %s'):format(action or 'Dispatch Call', call.id, call.code), call.description or 'No description provided.', call.priority == 1 and 16711680 or 3447003, {
        { name = 'Title', value = call.title or 'Unknown', inline = true },
        { name = 'Priority', value = tostring(call.priority), inline = true },
        { name = 'Status', value = call.status or 'pending', inline = true },
        { name = 'Departments', value = departments ~= '' and departments or 'Unknown', inline = true },
        { name = 'Location', value = call.location or 'Unknown', inline = true },
        { name = 'Caller', value = call.caller and call.caller.name or 'Unknown', inline = true }
    })
end

local function SendReportDiscordLog(report, action)
    SendDiscordLog(('%s | %s'):format(action or 'Dispatch Report', report.reportNumber or ('RPT-' .. tostring(report.id))), report.summary or report.narrative or 'No report summary.', report.priority == 1 and 16711680 or 9442302, {
        { name = 'Type', value = Config.ReportTypes[report.type] and Config.ReportTypes[report.type].label or report.type or 'Unknown', inline = true },
        { name = 'Department', value = report.department or 'Unknown', inline = true },
        { name = 'Status', value = report.status or 'draft', inline = true },
        { name = 'Linked Call', value = report.callId and ('#' .. tostring(report.callId)) or 'None', inline = true },
        { name = 'Created By', value = report.reportingUnit and report.reportingUnit.name or 'Unknown', inline = true }
    })
end

local function NormalizeCoords(coords)
    if type(coords) ~= 'table' then return nil end
    local x = tonumber(coords.x) or tonumber(coords[1])
    local y = tonumber(coords.y) or tonumber(coords[2])
    local z = tonumber(coords.z) or tonumber(coords[3]) or 0.0
    if not x or not y then return nil end
    return { x = DPNDispatch.Round(x, 2), y = DPNDispatch.Round(y, 2), z = DPNDispatch.Round(z, 2) }
end

local function GetCoords(src)
    if not src or src == 0 then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    return { x = DPNDispatch.Round(coords.x, 2), y = DPNDispatch.Round(coords.y, 2), z = DPNDispatch.Round(coords.z, 2) }
end

local function BuildAnalytics(src)
    local analytics = {
        totalCalls = 0,
        activeCalls = 0,
        criticalCalls = 0,
        availableUnits = 0,
        busyUnits = 0,
        totalUnits = 0,
        openReports = 0,
        pendingApprovals = 0,
        sealedReports = 0,
        departmentLoad = {}
    }

    for id, call in pairs(Calls) do
        if CanAccessCall(src, call) then
            analytics.totalCalls = analytics.totalCalls + 1
            if call.status ~= 'closed' and call.status ~= 'cancelled' then analytics.activeCalls = analytics.activeCalls + 1 end
            if tonumber(call.priority) == 1 and call.status ~= 'closed' and call.status ~= 'cancelled' then analytics.criticalCalls = analytics.criticalCalls + 1 end
            for _, department in pairs(call.departments or {}) do
                analytics.departmentLoad[department] = analytics.departmentLoad[department] or { calls = 0, reports = 0 }
                analytics.departmentLoad[department].calls = analytics.departmentLoad[department].calls + 1
            end
        end
    end

    for _, unit in pairs(Units) do
        local visible = CanSeeAll(src)
        if not visible then
            local myDepartments = GetPlayerDepartments(src)
            for _, department in pairs(unit.departments or {}) do
                if DPNDispatch.TableContains(myDepartments, department) then visible = true break end
            end
        end
        if visible then
            analytics.totalUnits = analytics.totalUnits + 1
            if unit.status == 'available' then analytics.availableUnits = analytics.availableUnits + 1 else analytics.busyUnits = analytics.busyUnits + 1 end
        end
    end

    for _, report in pairs(Reports) do
        if CanAccessReport(src, report) then
            if report.status ~= 'approved' and report.status ~= 'archived' then analytics.openReports = analytics.openReports + 1 end
            if report.status == 'supervisor_review' or report.status == 'doj_review' or report.status == 'submitted' then analytics.pendingApprovals = analytics.pendingApprovals + 1 end
            if report.sealed or report.confidential then analytics.sealedReports = analytics.sealedReports + 1 end
            analytics.departmentLoad[report.department] = analytics.departmentLoad[report.department] or { calls = 0, reports = 0 }
            analytics.departmentLoad[report.department].reports = analytics.departmentLoad[report.department].reports + 1
        end
    end

    return analytics
end

local function BuildStateFor(src)
    local visibleCalls = {}
    for id, call in pairs(Calls) do
        if CanAccessCall(src, call) then visibleCalls[tostring(id)] = DPNDispatch.Copy(call) end
    end

    local visibleUnits = {}
    for unitSrc, unit in pairs(Units) do
        if CanSeeAll(src) then
            visibleUnits[tostring(unitSrc)] = DPNDispatch.Copy(unit)
        else
            local myDepartments = GetPlayerDepartments(src)
            for _, department in pairs(unit.departments or {}) do
                if DPNDispatch.TableContains(myDepartments, department) then
                    visibleUnits[tostring(unitSrc)] = DPNDispatch.Copy(unit)
                    break
                end
            end
        end
    end

    local visibleReports = {}
    for id, report in pairs(Reports) do
        if CanAccessReport(src, report) then visibleReports[tostring(id)] = DPNDispatch.Copy(report) end
    end

    return {
        calls = visibleCalls,
        units = visibleUnits,
        reports = visibleReports,
        departments = Config.Departments,
        statuses = Config.Statuses,
        unitStatuses = Config.UnitStatuses,
        reportTypes = Config.ReportTypes,
        reportStatuses = Config.ReportStatuses,
        uiTheme = Config.UITheme or {},
        incidentClasses = Config.IncidentClasses or {},
        responseLevels = Config.ResponseLevels or {},
        dispatchSOPs = Config.DispatchSOPs or {},
        defaultCallTypes = Config.DefaultCallTypes or {},
        allowedDepartments = GetPlayerDepartments(src),
        canSeeAll = CanSeeAll(src),
        analytics = BuildAnalytics(src),
        serverTime = Now()
    }
end

function Dispatch.BuildStateFor(src)
    return BuildStateFor(src)
end

local function BroadcastState()
    for _, playerId in pairs(GetPlayers()) do
        local src = tonumber(playerId)
        if CanOpenDispatch(src) then TriggerClientEvent('dpn-dispatch:client:syncState', src, BuildStateFor(src)) end
    end
end

function Dispatch.BroadcastState()
    BroadcastState()
end


function Dispatch.SyncMdtFor(src)
    if not DPNDispatchMDT or not Config.MDT or not Config.MDT.enabled then return false, 'MDT bridge is disabled.' end
    if src and src > 0 and not CanOpenDispatch(src) then return false, 'Access denied' end

    local count = 0
    for _, call in pairs(Calls) do
        if not src or src == 0 or CanAccessCall(src, call) then
            DPNDispatchMDT.SyncCall(call, 'manual_resync')
            count = count + 1
        end
    end
    for _, report in pairs(Reports) do
        if not src or src == 0 or CanAccessReport(src, report) then
            DPNDispatchMDT.SyncReport(report, 'manual_resync')
            count = count + 1
        end
    end
    for _, unit in pairs(Units) do
        DPNDispatchMDT.SyncUnit(unit, 'manual_resync')
        count = count + 1
    end
    return true, count
end

local function Notify(src, message, msgType, length)
    if src and src > 0 then TriggerClientEvent('QBCore:Notify', src, message, msgType or 'primary', length or 5000) end
end

function Dispatch.CreateCall(data, creator)
    data = data or {}
    creator = tonumber(creator or source or 0) or 0

    local departments = DPNDispatch.NormalizeDepartments(data.departments or data.department)
    local id = NextCallId
    NextCallId = NextCallId + 1
    if NextCallId > 99999 then NextCallId = 1000 end

    local Player = GetQbPlayer(creator)
    local charinfo = Player and Player.PlayerData and Player.PlayerData.charinfo or {}
    local callerName = data.callerName or (((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''))
    if callerName == '' then callerName = SafePlayerName(creator) end

    local call = {
        id = id,
        caseId = data.caseId or ('DPN-' .. os.date('%Y%m%d') .. '-' .. tostring(id)),
        code = DPNDispatch.SanitizeString(data.code, '911', 20),
        title = DPNDispatch.SanitizeString(data.title, 'Emergency Dispatch Call', 80),
        description = DPNDispatch.SanitizeMultiline(data.description or data.message, 'No details provided.', 1200),
        departments = departments,
        primaryDepartment = departments[1],
        priority = DPNDispatch.ClampPriority(data.priority),
        status = 'pending',
        location = DPNDispatch.SanitizeString(data.location, 'Unknown Location', 120),
        coords = NormalizeCoords(data.coords) or GetCoords(creator),
        caller = {
            source = creator,
            name = DPNDispatch.SanitizeString(callerName, 'Unknown Caller', 80),
            phone = data.phone or (charinfo and charinfo.phone) or nil,
            citizenid = Player and Player.PlayerData and Player.PlayerData.citizenid or nil
        },
        assignedUnits = {},
        linkedReports = {},
        tags = DPNDispatch.NormalizeLines(data.tags or {}, 12, 40),
        incidentClass = DPNDispatch.SanitizeString(data.incidentClass or '', '', 60),
        responseLevel = DPNDispatch.SanitizeString(data.responseLevel or '', '', 40),
        riskFlags = DPNDispatch.NormalizeLines(data.riskFlags or {}, 12, 60),
        staging = DPNDispatch.SanitizeString(data.staging or '', '', 140),
        command = DPNDispatch.SanitizeString(data.command or '', '', 120),
        radioChannel = DPNDispatch.SanitizeString(data.radioChannel or data.channel or '', '', 60),
        unitsRequested = DPNDispatch.NormalizeLines(data.unitsRequested or {}, 12, 80),
        recommendedResponse = DPNDispatch.NormalizeLines(data.recommendedResponse or {}, 20, 120),
        sop = DPNDispatch.NormalizeLines(data.sop or {}, 20, 140),
        disposition = DPNDispatch.SanitizeString(data.disposition or '', '', 120),
        notes = {},
        meta = type(data.meta) == 'table' and data.meta or {},
        createdBy = creator,
        createdAt = Now(),
        updatedAt = Now()
    }

    Calls[id] = call
    if DPNDispatchMDT then DPNDispatchMDT.SyncCall(call, 'created') end
    if DPNDispatchDatabase then DPNDispatchDatabase.InsertCall(call) end
    SendCallDiscordLog(call, 'New Dispatch Call')

    for _, playerId in pairs(GetPlayers()) do
        local src = tonumber(playerId)
        if CanAccessCall(src, call) then TriggerClientEvent('dpn-dispatch:client:newCall', src, call) end
    end
    BroadcastState()
    return id, call
end

function Dispatch.GetCalls()
    return Calls
end

function Dispatch.GetUnits()
    return Units
end

function Dispatch.GetReports()
    return Reports
end

function Dispatch.GetCall(id)
    return Calls[tonumber(id)]
end

function Dispatch.GetReport(id)
    return Reports[tonumber(id)]
end

function Dispatch.UpdateCall(id, changes, updater)
    id = tonumber(id)
    if not id or not Calls[id] then return false, 'Call not found' end
    if updater and updater > 0 and not CanAccessCall(updater, Calls[id]) then return false, 'Access denied' end

    local call = Calls[id]
    changes = changes or {}

    if changes.status and Config.Statuses[changes.status] then call.status = changes.status end
    if changes.priority then call.priority = DPNDispatch.ClampPriority(changes.priority) end
    if changes.title then call.title = DPNDispatch.SanitizeString(changes.title, call.title, 80) end
    if changes.description then call.description = DPNDispatch.SanitizeMultiline(changes.description, call.description, 1200) end
    if changes.location then call.location = DPNDispatch.SanitizeString(changes.location, call.location, 120) end
    if changes.coords then call.coords = NormalizeCoords(changes.coords) or call.coords end
    if changes.tags then call.tags = DPNDispatch.NormalizeLines(changes.tags, 12, 40) end
    if changes.incidentClass ~= nil then call.incidentClass = DPNDispatch.SanitizeString(changes.incidentClass, call.incidentClass or '', 60) end
    if changes.responseLevel ~= nil then call.responseLevel = DPNDispatch.SanitizeString(changes.responseLevel, call.responseLevel or '', 40) end
    if changes.riskFlags then call.riskFlags = DPNDispatch.NormalizeLines(changes.riskFlags, 12, 60) end
    if changes.staging ~= nil then call.staging = DPNDispatch.SanitizeString(changes.staging, call.staging or '', 140) end
    if changes.command ~= nil then call.command = DPNDispatch.SanitizeString(changes.command, call.command or '', 120) end
    if changes.radioChannel ~= nil then call.radioChannel = DPNDispatch.SanitizeString(changes.radioChannel, call.radioChannel or '', 60) end
    if changes.unitsRequested then call.unitsRequested = DPNDispatch.NormalizeLines(changes.unitsRequested, 12, 80) end
    if changes.recommendedResponse then call.recommendedResponse = DPNDispatch.NormalizeLines(changes.recommendedResponse, 20, 120) end
    if changes.sop then call.sop = DPNDispatch.NormalizeLines(changes.sop, 20, 140) end
    if changes.disposition ~= nil then call.disposition = DPNDispatch.SanitizeString(changes.disposition, call.disposition or '', 120) end
    if changes.note then
        call.notes[#call.notes + 1] = {
            text = DPNDispatch.SanitizeString(changes.note, '', 300),
            by = updater or 0,
            byName = SafePlayerName(updater or 0),
            at = Now()
        }
    end

    call.updatedAt = Now()
    if DPNDispatchMDT then DPNDispatchMDT.SyncCall(call, 'updated') end
    if DPNDispatchDatabase then DPNDispatchDatabase.UpdateCall(call) end
    BroadcastState()
    return true, call
end

local function NormalizeReportStructured(data)
    data = type(data) == 'table' and data or {}
    return {
        involvedPersons = DPNDispatch.NormalizeLines(data.involvedPersons, 40, 180),
        vehicles = DPNDispatch.NormalizeLines(data.vehicles, 30, 180),
        evidence = DPNDispatch.NormalizeLines(data.evidence, 40, 180),
        charges = DPNDispatch.NormalizeLines(data.charges, 30, 180),
        medical = DPNDispatch.NormalizeLines(data.medical, 30, 220),
        fire = DPNDispatch.NormalizeLines(data.fire, 30, 220),
        court = DPNDispatch.NormalizeLines(data.court, 30, 220),
        corrections = DPNDispatch.NormalizeLines(data.corrections, 30, 220),
        adminActions = DPNDispatch.NormalizeLines(data.adminActions, 30, 220),
        witnesses = DPNDispatch.NormalizeLines(data.witnesses, 30, 180),
        attachments = DPNDispatch.NormalizeLines(data.attachments, 30, 220),
        riskFlags = DPNDispatch.NormalizeLines(data.riskFlags, 20, 100),
        dispatchTimeline = DPNDispatch.NormalizeLines(data.dispatchTimeline, 60, 220),
        supervisorNotes = DPNDispatch.NormalizeLines(data.supervisorNotes, 40, 220),
        disposition = DPNDispatch.NormalizeLines(data.disposition, 20, 220),
        mdtLinks = DPNDispatch.NormalizeLines(data.mdtLinks, 30, 220),
        qaChecklist = DPNDispatch.NormalizeLines(data.qaChecklist, 40, 140),
        ncicChecks = DPNDispatch.NormalizeLines(data.ncicChecks, 30, 180),
        property = DPNDispatch.NormalizeLines(data.property, 30, 180),
        chainOfCustody = DPNDispatch.NormalizeLines(data.chainOfCustody, 40, 220)
    }
end

local function ValidateReportType(reportType)
    if reportType and Config.ReportTypes[reportType] then return reportType end
    return 'incident'
end

local function DefaultReportDepartment(reportType, creator, explicit)
    if explicit and Config.Departments[explicit] then return explicit end
    local allowed = GetPlayerDepartments(creator)
    local typeConfig = Config.ReportTypes[reportType] or {}
    for _, department in pairs(typeConfig.departments or {}) do
        if DPNDispatch.TableContains(allowed, department) then return department end
    end
    return allowed[1] or 'law'
end

function Dispatch.CreateReport(data, creator)
    data = data or {}
    creator = tonumber(creator or source or 0) or 0
    if creator > 0 and not CanOpenDispatch(creator) then return false, 'Access denied' end

    local reportType = ValidateReportType(data.type)
    local department = DefaultReportDepartment(reportType, creator, data.department)
    local typeConfig = Config.ReportTypes[reportType] or {}
    local callId = tonumber(data.callId)
    if callId and not Calls[callId] then callId = nil end
    if callId and creator > 0 and not CanAccessCall(creator, Calls[callId]) then return false, 'Cannot link to that call' end

    local id = NextReportId
    NextReportId = NextReportId + 1
    if NextReportId > 99999 then NextReportId = 5000 end

    local linkedCall = callId and Calls[callId] or nil
    local structured = NormalizeReportStructured(data.involved or data)
    local status = data.status and Config.ReportStatuses[data.status] and data.status or 'draft'
    local sealed = data.sealed == true or typeConfig.defaultSealed == true
    local confidential = data.confidential == true or sealed

    local report = {
        id = id,
        reportNumber = data.reportNumber or ('DPN-RPT-' .. os.date('%Y%m%d') .. '-' .. tostring(id)),
        caseId = data.caseId or (linkedCall and linkedCall.caseId) or ('DPN-CASE-' .. os.date('%Y%m%d') .. '-' .. tostring(id)),
        callId = callId,
        type = reportType,
        title = DPNDispatch.SanitizeString(data.title, linkedCall and linkedCall.title or 'Dispatch Report', 120),
        summary = DPNDispatch.SanitizeMultiline(data.summary, linkedCall and linkedCall.description or 'No summary provided.', 1200),
        narrative = DPNDispatch.SanitizeMultiline(data.narrative, '', 6000),
        department = department,
        departments = DPNDispatch.NormalizeDepartments(data.departments or { department }),
        priority = DPNDispatch.ClampPriority(data.priority or (linkedCall and linkedCall.priority) or 3),
        status = status,
        location = DPNDispatch.SanitizeString(data.location, linkedCall and linkedCall.location or 'Unknown Location', 160),
        coords = NormalizeCoords(data.coords) or (linkedCall and linkedCall.coords) or GetCoords(creator),
        reportingUnit = GetReportingUnit(creator),
        involved = structured,
        tags = DPNDispatch.NormalizeLines(data.tags or {}, 16, 50),
        approvals = {
            supervisor = DPNDispatch.SanitizeString(data.supervisor or '', '', 80),
            doj = DPNDispatch.SanitizeString(data.dojReviewer or '', '', 80),
            mib = DPNDispatch.SanitizeString(data.mibReviewer or '', '', 80)
        },
        sealed = sealed,
        confidential = confidential,
        locked = data.locked == true,
        meta = type(data.meta) == 'table' and data.meta or {},
        audit = {
            { action = 'created', by = creator, byName = SafePlayerName(creator), at = Now() }
        },
        createdBy = creator,
        createdAt = Now(),
        updatedAt = Now()
    }

    Reports[id] = report
    if linkedCall then
        linkedCall.linkedReports = linkedCall.linkedReports or {}
        if not DPNDispatch.TableContains(linkedCall.linkedReports, id) then linkedCall.linkedReports[#linkedCall.linkedReports + 1] = id end
        linkedCall.updatedAt = Now()
        if DPNDispatchDatabase then DPNDispatchDatabase.UpdateCall(linkedCall) end
    end

    if DPNDispatchMDT then DPNDispatchMDT.SyncReport(report, 'created') end
    if DPNDispatchDatabase then DPNDispatchDatabase.InsertReport(report) end
    SendReportDiscordLog(report, 'New Dispatch Report')
    BroadcastState()
    return true, report
end

function Dispatch.UpdateReport(reportId, changes, updater)
    reportId = tonumber(reportId)
    if not reportId or not Reports[reportId] then return false, 'Report not found' end
    local report = Reports[reportId]
    updater = tonumber(updater or 0) or 0
    if updater > 0 and not CanAccessReport(updater, report) then return false, 'Access denied' end
    if report.locked and not CanSeeAll(updater) then return false, 'Report is locked' end
    changes = changes or {}

    if changes.type then report.type = ValidateReportType(changes.type) end
    if changes.department and Config.Departments[changes.department] then report.department = changes.department end
    if changes.departments then report.departments = DPNDispatch.NormalizeDepartments(changes.departments) end
    if changes.status and Config.ReportStatuses[changes.status] then report.status = changes.status end
    if changes.priority then report.priority = DPNDispatch.ClampPriority(changes.priority) end
    if changes.title then report.title = DPNDispatch.SanitizeString(changes.title, report.title, 120) end
    if changes.summary then report.summary = DPNDispatch.SanitizeMultiline(changes.summary, report.summary, 1200) end
    if changes.narrative ~= nil then report.narrative = DPNDispatch.SanitizeMultiline(changes.narrative, '', 6000) end
    if changes.location then report.location = DPNDispatch.SanitizeString(changes.location, report.location, 160) end
    if changes.coords then report.coords = NormalizeCoords(changes.coords) or report.coords end
    if changes.tags then report.tags = DPNDispatch.NormalizeLines(changes.tags, 16, 50) end
    if changes.involved then report.involved = NormalizeReportStructured(changes.involved) end
    if changes.approvals then
        local approvals = type(changes.approvals) == 'table' and changes.approvals or {}
        report.approvals = {
            supervisor = DPNDispatch.SanitizeString(approvals.supervisor or '', '', 80),
            doj = DPNDispatch.SanitizeString(approvals.doj or approvals.dojReviewer or '', '', 80),
            mib = DPNDispatch.SanitizeString(approvals.mib or approvals.mibReviewer or '', '', 80)
        }
    end
    if changes.sealed ~= nil and (CanSeeAll(updater) or HasMibAccess(updater)) then report.sealed = changes.sealed == true end
    if changes.confidential ~= nil and (CanSeeAll(updater) or HasMibAccess(updater)) then report.confidential = changes.confidential == true end
    if changes.locked ~= nil and CanSeeAll(updater) then report.locked = changes.locked == true end

    if changes.callId ~= nil then
        local newCallId = tonumber(changes.callId)
        if newCallId and Calls[newCallId] and (updater == 0 or CanAccessCall(updater, Calls[newCallId])) then
            report.callId = newCallId
            report.caseId = report.caseId or Calls[newCallId].caseId
            Calls[newCallId].linkedReports = Calls[newCallId].linkedReports or {}
            if not DPNDispatch.TableContains(Calls[newCallId].linkedReports, report.id) then Calls[newCallId].linkedReports[#Calls[newCallId].linkedReports + 1] = report.id end
        elseif changes.callId == false or changes.callId == '' then
            report.callId = nil
        end
    end

    report.audit = report.audit or {}
    report.audit[#report.audit + 1] = { action = changes.auditAction or 'updated', by = updater, byName = SafePlayerName(updater), at = Now() }
    report.updatedAt = Now()

    if DPNDispatchMDT then DPNDispatchMDT.SyncReport(report, 'updated') end
    if DPNDispatchDatabase then DPNDispatchDatabase.UpdateReport(report) end
    BroadcastState()
    return true, report
end

local function SetUnitStatus(src, status, radio)
    if not Config.UnitStatuses[status] then status = 'available' end
    local unit = FormatUnit(src)
    if not unit then return false end
    unit.status = status
    unit.radio = radio or (Units[src] and Units[src].radio) or nil
    unit.coords = Units[src] and Units[src].coords or GetCoords(src)
    unit.assignedCall = Units[src] and Units[src].assignedCall or nil
    Units[src] = unit
    if DPNDispatchMDT then DPNDispatchMDT.SyncUnit(unit, 'status') end
    BroadcastState()
    return true
end

local function AssignUnit(callId, unitSrc, assignedBy)
    callId = tonumber(callId)
    unitSrc = tonumber(unitSrc)
    if not callId or not Calls[callId] then return false, 'Call not found' end
    if not unitSrc or not GetQbPlayer(unitSrc) then return false, 'Unit not found' end
    if assignedBy and assignedBy > 0 and not CanAccessCall(assignedBy, Calls[callId]) then return false, 'Access denied' end

    Units[unitSrc] = FormatUnit(unitSrc) or Units[unitSrc] or {}
    Units[unitSrc].assignedCall = callId
    Units[unitSrc].status = 'enroute'
    Units[unitSrc].lastSeen = Now()

    local call = Calls[callId]
    if not DPNDispatch.TableContains(call.assignedUnits, unitSrc) then call.assignedUnits[#call.assignedUnits + 1] = unitSrc end
    if call.status == 'pending' then call.status = 'assigned' end
    call.notes[#call.notes + 1] = { text = ('Unit %s assigned.'):format(Units[unitSrc].callsign or unitSrc), by = assignedBy or 0, byName = SafePlayerName(assignedBy or 0), at = Now() }
    call.updatedAt = Now()

    TriggerClientEvent('dpn-dispatch:client:assignedToCall', unitSrc, call)
    if DPNDispatchMDT then
        DPNDispatchMDT.SyncCall(call, 'assigned')
        DPNDispatchMDT.SyncUnit(Units[unitSrc], 'assigned')
    end
    if DPNDispatchDatabase then DPNDispatchDatabase.UpdateCall(call) end
    BroadcastState()
    return true
end

local function UnassignUnit(callId, unitSrc, bySrc)
    callId = tonumber(callId)
    unitSrc = tonumber(unitSrc)
    if not callId or not Calls[callId] then return false, 'Call not found' end
    if bySrc and bySrc > 0 and not CanAccessCall(bySrc, Calls[callId]) then return false, 'Access denied' end

    local call = Calls[callId]
    local newAssigned = {}
    for _, src in pairs(call.assignedUnits or {}) do if tonumber(src) ~= unitSrc then newAssigned[#newAssigned + 1] = src end end
    call.assignedUnits = newAssigned
    call.notes[#call.notes + 1] = { text = ('Unit %s unassigned.'):format(unitSrc), by = bySrc or 0, byName = SafePlayerName(bySrc or 0), at = Now() }
    call.updatedAt = Now()

    if Units[unitSrc] then
        Units[unitSrc].assignedCall = nil
        Units[unitSrc].status = 'available'
    end

    if #call.assignedUnits == 0 and call.status ~= 'closed' and call.status ~= 'cancelled' then call.status = 'pending' end

    TriggerClientEvent('dpn-dispatch:client:unassignedFromCall', unitSrc, callId)
    if DPNDispatchMDT then
        DPNDispatchMDT.SyncCall(call, 'unassigned')
        if Units[unitSrc] then DPNDispatchMDT.SyncUnit(Units[unitSrc], 'unassigned') end
    end
    if DPNDispatchDatabase then DPNDispatchDatabase.UpdateCall(call) end
    BroadcastState()
    return true
end

RegisterNetEvent('dpn-dispatch:server:registerUnit', function(payload)
    local src = source
    if not CanOpenDispatch(src) then return end
    local unit = FormatUnit(src)
    if not unit then return end
    if type(payload) == 'table' then
        unit.coords = NormalizeCoords(payload.coords) or unit.coords
        unit.status = Config.UnitStatuses[payload.status] and payload.status or unit.status
        unit.radio = payload.radio or unit.radio
    end
    Units[src] = unit
    if DPNDispatchMDT then DPNDispatchMDT.SyncUnit(unit, 'registered') end
    BroadcastState()
end)

RegisterNetEvent('dpn-dispatch:server:updateUnitPosition', function(coords)
    local src = source
    if not CanOpenDispatch(src) then return end
    if not Units[src] then Units[src] = FormatUnit(src) or {} end
    Units[src].coords = NormalizeCoords(coords) or GetCoords(src)
    Units[src].lastSeen = Now()
    if DPNDispatchMDT then DPNDispatchMDT.SyncUnit(Units[src], 'position') end
end)

RegisterNetEvent('dpn-dispatch:server:setUnitStatus', function(status, radio)
    local src = source
    if not CanOpenDispatch(src) then return end
    SetUnitStatus(src, tostring(status or 'available'), radio)
end)

RegisterNetEvent('dpn-dispatch:server:createCall', function(data)
    local src = source or 0
    if src > 0 and data and data.fromDispatch and not CanOpenDispatch(src) then
        Notify(src, 'You are not authorized to create dispatch calls.', 'error')
        return
    end
    local id = Dispatch.CreateCall(data or {}, src)
    if id then Notify(src, 'Dispatch call created.', 'success') end
end)

RegisterNetEvent('dpn-dispatch:server:createReport', function(data)
    local src = source or 0
    local ok, reportOrErr = Dispatch.CreateReport(data or {}, src)
    if not ok then Notify(src, reportOrErr or 'Could not create report.', 'error') return end
    Notify(src, ('Report %s created.'):format(reportOrErr.reportNumber), 'success')
end)

RegisterNetEvent('dpn-dispatch:server:updateReport', function(reportId, changes)
    local src = source or 0
    local ok, reportOrErr = Dispatch.UpdateReport(reportId, changes or {}, src)
    if not ok then Notify(src, reportOrErr or 'Could not update report.', 'error') return end
    Notify(src, ('Report %s updated.'):format(reportOrErr.reportNumber), 'success')
end)

RegisterNetEvent('dpn-dispatch:server:assignUnit', function(callId, unitSrc)
    local src = source
    if not CanOpenDispatch(src) then return end
    local ok, err = AssignUnit(callId, unitSrc, src)
    if not ok then Notify(src, err, 'error') end
end)

RegisterNetEvent('dpn-dispatch:server:assignSelf', function(callId)
    local src = source
    if not CanOpenDispatch(src) then return end
    local ok, err = AssignUnit(callId, src, src)
    if not ok then Notify(src, err, 'error') end
end)

RegisterNetEvent('dpn-dispatch:server:unassignUnit', function(callId, unitSrc)
    local src = source
    if not CanOpenDispatch(src) then return end
    local ok, err = UnassignUnit(callId, unitSrc or src, src)
    if not ok then Notify(src, err, 'error') end
end)

RegisterNetEvent('dpn-dispatch:server:updateCall', function(callId, changes)
    local src = source
    if not CanOpenDispatch(src) then return end
    local ok, err = Dispatch.UpdateCall(callId, changes, src)
    if not ok then Notify(src, err, 'error') end
end)

RegisterNetEvent('dpn-dispatch:server:panic', function(message)
    local src = source
    if not CanOpenDispatch(src) then return end
    SetUnitStatus(src, 'panic')
    local unit = Units[src] or FormatUnit(src)
    local departments = unit and unit.departments or { 'law', 'ems' }
    Dispatch.CreateCall({
        code = '10-99',
        title = 'PANIC BUTTON ACTIVATED',
        description = DPNDispatch.SanitizeString(message, 'Unit panic button activated. Immediate backup required.', 300),
        departments = departments,
        priority = 1,
        location = 'Unit Location',
        coords = unit and unit.coords or GetCoords(src),
        tags = { 'panic', 'officer safety' },
        meta = { panic = true, unit = unit }
    }, src)
end)


-- dpn-mdt can use these events when it wants dispatch to generate a live CAD call/report.
AddEventHandler('dpn-dispatch:server:mdtCreateCall', function(data)
    local src = source or 0
    local payload = type(data) == 'table' and data or {}
    payload.meta = payload.meta or {}
    payload.meta.sourceResource = payload.meta.sourceResource or 'dpn-mdt'
    payload.fromDispatch = src > 0
    Dispatch.CreateCall(payload, src)
end)

AddEventHandler('dpn-dispatch:server:mdtCreateReport', function(data)
    local src = source or 0
    local payload = type(data) == 'table' and data or {}
    payload.meta = payload.meta or {}
    payload.meta.sourceResource = payload.meta.sourceResource or 'dpn-mdt'
    Dispatch.CreateReport(payload, src)
end)


RegisterNetEvent('dpn-dispatch:server:forceMdtSync', function()
    local src = source or 0
    local ok, result = Dispatch.SyncMdtFor(src)
    if ok then
        Notify(src, ('MDT sync pushed for %s records.'):format(tostring(result or 0)), 'success')
    else
        Notify(src, result or 'MDT sync failed.', 'error')
    end
end)

QBCore.Functions.CreateCallback('dpn-dispatch:server:getState', function(source, cb)
    if not CanOpenDispatch(source) then cb({ denied = true }) return end
    cb(BuildStateFor(source))
end)

QBCore.Functions.CreateCallback('dpn-dispatch:server:canOpen', function(source, cb)
    cb(CanOpenDispatch(source))
end)

QBCore.Commands.Add(Config.Commands.dispatch, 'Open DPN Dispatch Center', {}, false, function(source)
    if not CanOpenDispatch(source) then Notify(source, 'You are not authorized to use dispatch.', 'error') return end
    TriggerClientEvent('dpn-dispatch:client:open', source)
end)

QBCore.Commands.Add(Config.Commands.report, 'Open DPN Dispatch Reporting UI', {}, false, function(source)
    if not CanOpenDispatch(source) then Notify(source, 'You are not authorized to use dispatch reports.', 'error') return end
    TriggerClientEvent('dpn-dispatch:client:openReport', source)
end)

QBCore.Commands.Add(Config.Commands.emergency911, 'Send an emergency 911 dispatch call', {
    { name = 'message', help = 'What is the emergency?' }
}, false, function(source, args)
    local message = table.concat(args, ' ')
    if message == '' then message = 'Emergency assistance requested.' end
    Dispatch.CreateCall({
        code = '911',
        title = '911 Emergency Call',
        description = message,
        departments = { 'law', 'ems', 'fire' },
        priority = 2,
        location = 'Caller Location',
        coords = GetCoords(source),
        tags = { 'public 911' }
    }, source)
    Notify(source, '911 call sent to dispatch.', 'success')
end)

QBCore.Commands.Add(Config.Commands.panic, 'Activate emergency panic button', {}, false, function(source)
    if not CanOpenDispatch(source) then return end
    TriggerEvent('dpn-dispatch:server:panic', 'Unit panic command activated. Immediate backup required.')
end)

QBCore.Commands.Add(Config.Commands.status, 'Set your dispatch unit status', {
    { name = 'status', help = 'available, busy, enroute, onscene, transporting, court, unavailable' }
}, false, function(source, args)
    if not CanOpenDispatch(source) then return end
    local status = tostring(args[1] or 'available')
    if not Config.UnitStatuses[status] then Notify(source, 'Invalid status.', 'error') return end
    SetUnitStatus(source, status)
    Notify(source, 'Unit status set to ' .. Config.UnitStatuses[status].label, 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    Units[src] = nil
    for _, call in pairs(Calls) do
        local assigned = {}
        for _, unitSrc in pairs(call.assignedUnits or {}) do if tonumber(unitSrc) ~= tonumber(src) then assigned[#assigned + 1] = unitSrc end end
        call.assignedUnits = assigned
    end
    BroadcastState()
end)

CreateThread(function()
    while true do
        Wait(60000)
        local cutoff = Now() - (Config.ClosedCallCleanupMinutes * 60)
        local changed = false
        for id, call in pairs(Calls) do
            if (call.status == 'closed' or call.status == 'cancelled') and (call.updatedAt or call.createdAt) < cutoff then
                Calls[id] = nil
                changed = true
            end
        end
        if changed then BroadcastState() end
    end
end)
