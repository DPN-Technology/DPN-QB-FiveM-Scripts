local QBCore = exports['qb-core']:GetCoreObject()
local ActiveShifts = {}
local OperationalUnits = {}
local UnitByMember = {}
local ActivePursuits = {}
local RateLimits = {}
local WeaponDraftCooldown = {}

math.randomseed(os.time())

local function debugPrint(...)
    if Config.Debug then print('^3[dpn-le-operations]^7', ...) end
end

local function clean(value, maxLength)
    local text = tostring(value or ''):gsub('[%z\1-\8\11\12\14-\31]', '')
    maxLength = tonumber(maxLength) or Config.Security.MaxString
    if #text > maxLength then text = text:sub(1, maxLength) end
    return text
end

local function trim(value)
    return clean(value, Config.Security.MaxString):gsub('^%s*(.-)%s*$', '%1')
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

local function makeId(prefix)
    return ('%s-%s-%04d'):format(prefix, os.date('%y%m%d%H%M%S'), math.random(1000, 9999))
end

local function playerInfo(src)
    src = tonumber(src)
    if not src or src <= 0 then
        return { source=0, citizenid='SYSTEM', name='DPN System', job='system', grade=99, onDuty=true, department='all', role='system' }
    end
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return nil end
    local data = player.PlayerData or {}
    local job = data.job or {}
    local grade = job.grade
    if type(grade) == 'table' then grade = grade.level or grade.grade or 0 end
    local charinfo = data.charinfo or {}
    local name = trim(('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''))
    local definition = Config.AllowedJobs[job.name]
    local justice = Config.JusticeJobs[job.name] == true
    return {
        source=src,
        citizenid=data.citizenid or ('src:%s'):format(src),
        name=name ~= '' and name or GetPlayerName(src) or ('Unit %s'):format(src),
        job=job.name or 'unemployed',
        jobLabel=job.label or job.name or 'Unemployed',
        grade=tonumber(grade) or 0,
        onDuty=job.onduty == true,
        isBoss=job.isboss == true,
        department=definition and definition.department or (justice and 'justice' or nil),
        role=justice and 'justice' or (definition and definition.department or nil)
    }
end

local function notify(src, message, kind, duration)
    if tonumber(src) and tonumber(src) > 0 then
        TriggerClientEvent('QBCore:Notify', src, clean(message, 500), kind or 'primary', duration or 5000)
    else
        print(('[dpn-le-operations] %s'):format(message))
    end
end

local function isAllowed(src, requireDuty)
    if src == 0 or IsPlayerAceAllowed(src, Config.AdminAce) then return true, playerInfo(src) end
    local info = playerInfo(src)
    if not info or not info.role then return false, info end
    if info.role == 'justice' then return true, info end
    if requireDuty ~= false and Config.RequireDuty and not info.onDuty then return false, info end
    return true, info
end

local function isLaw(src, requireDuty)
    local allowed, info = isAllowed(src, requireDuty)
    return allowed and info and info.department == 'law', info
end

local function isSupervisor(src)
    if src == 0 or IsPlayerAceAllowed(src, Config.AdminAce) or IsPlayerAceAllowed(src, Config.SupervisorAce) then return true end
    local info = playerInfo(src)
    if not info then return false end
    return info.isBoss or (Config.SupervisorGrades[info.job] and info.grade >= tonumber(Config.SupervisorGrades[info.job]))
end

local function isJudge(src)
    if src == 0 or IsPlayerAceAllowed(src, Config.AdminAce) or IsPlayerAceAllowed(src, Config.JudgeAce) then return true end
    local info = playerInfo(src)
    if not info or not Config.JusticeJobs[info.job] then return false end
    local minimum = Config.JudgeGrades[info.job]
    return minimum == nil or info.grade >= minimum
end

local function rateAllowed(src, action)
    src = tonumber(src) or 0
    if src <= 0 then return true end
    local current = os.time()
    RateLimits[src] = RateLimits[src] or {}
    local bucket = RateLimits[src][action]
    if not bucket or current - bucket.started >= Config.Security.RateWindowSeconds then
        RateLimits[src][action] = { started=current, count=1 }
        return true
    end
    bucket.count = bucket.count + 1
    return bucket.count <= Config.Security.MaxActionsPerWindow
end

local function playerCoords(src)
    local ped = tonumber(src) and GetPlayerPed(tonumber(src)) or 0
    if not ped or ped <= 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    return { x=coords.x, y=coords.y, z=coords.z }
end

local function distance(a, b)
    if not a or not b then return 999999.0 end
    local dx, dy, dz = (a.x or 0.0)-(b.x or 0.0), (a.y or 0.0)-(b.y or 0.0), (a.z or 0.0)-(b.z or 0.0)
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function audit(src, action, referenceId, details)
    local info = playerInfo(src) or playerInfo(0)
    MySQL.insert('INSERT INTO dpn_le_operational_audit (actor_cid, actor_name, action, reference_id, details, created_at) VALUES (?, ?, ?, ?, ?, NOW())', {
        info.citizenid, info.name, clean(action, 80), referenceId and clean(referenceId, 64) or nil, json.encode(details or {})
    })
end

local function webhook(title, description, color)
    if not Config.Webhook or Config.Webhook == '' then return end
    PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
        username='DPN Law Enforcement Operations',
        embeds={{ title=clean(title, 200), description=clean(description, 3000), color=color or 3447003, footer={ text=os.date('%Y-%m-%d %H:%M:%S') } }}
    }), { ['Content-Type']='application/json' })
end

local function createSupervisorTask(taskType, referenceId, title, priority, assignedJob, metadata)
    local taskId = makeId('TASK')
    MySQL.insert('INSERT INTO dpn_le_supervisor_tasks (task_id, task_type, reference_id, title, priority, assigned_job, status, metadata, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())', {
        taskId, clean(taskType, 40), clean(referenceId, 64), clean(title, 180), clamp(priority, 1, 5), assignedJob and clean(assignedJob, 50) or nil, 'open', json.encode(metadata or {})
    })
    return taskId
end

local function completeSupervisorTasks(taskType, referenceId)
    MySQL.update('UPDATE dpn_le_supervisor_tasks SET status = ?, completed_at = NOW() WHERE task_type = ? AND reference_id = ? AND status = ?', {
        'completed', clean(taskType, 40), clean(referenceId, 64), 'open'
    })
end

local function activeShiftFor(info)
    return info and ActiveShifts[info.citizenid] or nil
end

local function incrementShift(identifier, field, amount)
    local shift = ActiveShifts[identifier]
    if not shift then return end
    local allowedFields = { calls_handled=true, citations=true, arrests=true, searches=true, force_reports=true }
    if not allowedFields[field] then return end
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    shift[field] = (tonumber(shift[field]) or 0) + amount
    MySQL.update(('UPDATE dpn_le_shifts SET `%s` = `%s` + ? WHERE shift_id = ?'):format(field, field), { amount, shift.shiftId })
end

local function dispatchCall(data)
    if GetResourceState(Config.DispatchResource) ~= 'started' then return nil end
    local ok, result = pcall(function() return exports[Config.DispatchResource]:CreateDispatchCall(data, 0) end)
    return ok and result or nil
end

local function updateDispatchUnit(src, data)
    if GetResourceState(Config.DispatchResource) ~= 'started' then return end
    pcall(function() exports[Config.DispatchResource]:UpdateUnit(src, data, true) end)
end

local function coreSetUnit(src, unitCode)
    if GetResourceState(Config.CoreResource) ~= 'started' then return end
    pcall(function() exports[Config.CoreResource]:SetOfficerUnit(src, unitCode) end)
end

local function coreSetStatus(src, status)
    if GetResourceState(Config.CoreResource) ~= 'started' then return end
    pcall(function() exports[Config.CoreResource]:SetOfficerStatus(src, status) end)
end

local function incidentCreate(title, incidentType, priority, coords, notes)
    if GetResourceState(Config.IncidentResource) ~= 'started' then return nil end
    local ok, result = pcall(function() return exports[Config.IncidentResource]:CreateIncident(title, incidentType, priority, coords, notes) end)
    return ok and result or nil
end

local function evidenceRecord(recordType, title, metadata, sourceResource)
    if GetResourceState(Config.EvidenceResource) ~= 'started' then return end
    pcall(function() exports[Config.EvidenceResource]:AddSystemRecord(recordType, title, metadata or {}, sourceResource or GetCurrentResourceName()) end)
end

local function intelAlert(payload)
    if GetResourceState(Config.IntelligenceResource) ~= 'started' then return end
    pcall(function() exports[Config.IntelligenceResource]:CreateIntelAlert(payload) end)
end

local function networkPublish(eventType, payload)
    if not Config.NetworkResource or GetResourceState(Config.NetworkResource) ~= 'started' then return nil end
    local ok, eventId = pcall(function()
        return exports[Config.NetworkResource]:PublishEvent('law_operations', eventType, payload or {}, 0)
    end)
    return ok and eventId or nil
end

local function networkState(src)
    if not Config.NetworkResource or GetResourceState(Config.NetworkResource) ~= 'started' then
        return { summary={ online=0, degraded=0, offline=0, criticalOffline=1, total=0 }, counts={}, resources={}, events={}, activeCalls={}, dispatchUnits={}, incidents={}, safetyAlerts={}, drones={}, bolos={} }
    end
    local ok, result = pcall(function() return exports[Config.NetworkResource]:GetNetworkState(src) end)
    if ok and type(result) == 'table' then return result end
    return { summary={ online=0, degraded=1, offline=0, criticalOffline=0, total=0 }, counts={}, resources={}, events={}, activeCalls={}, dispatchUnits={}, incidents={}, safetyAlerts={}, drones={}, bolos={} }
end

local function broadcastRefresh()
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and isAllowed(src, false) then TriggerClientEvent('dpn-le-operations:client:refreshAvailable', src) end
    end
end

local function broadcastLawClient(eventName, ...)
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local allowed = src and isLaw(src, true)
        if allowed then TriggerClientEvent(eventName, src, ...) end
    end
end

local function memberArray(unit)
    local result = {}
    for citizenid, member in pairs(unit.members or {}) do
        local copy = {}
        for key, value in pairs(member) do copy[key] = value end
        copy.citizenid = citizenid
        result[#result + 1] = copy
    end
    table.sort(result, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return result
end

local function memberCount(unit)
    local count = 0
    for _ in pairs(unit and unit.members or {}) do count = count + 1 end
    return count
end

local function syncOperationalUnitMembers(unit)
    if not unit then return end
    for citizenid, member in pairs(unit.members or {}) do
        local partners = {}
        for otherCid, other in pairs(unit.members or {}) do
            if otherCid ~= citizenid then partners[#partners + 1] = other.name end
        end
        if member.source and GetPlayerName(member.source) then
            coreSetUnit(member.source, unit.unitCode)
            updateDispatchUnit(member.source, {
                unit = unit.unitCode,
                status = '10-8',
                metadata = { operationalUnit=unit.unitId, role=unit.role, memberRole=member.role, partners=partners }
            })
        end
    end
end

local function serializeUnits()
    local result = {}
    for unitId, unit in pairs(OperationalUnits) do
        result[unitId] = {
            unitId=unit.unitId, unitCode=unit.unitCode, unitName=unit.unitName, role=unit.role,
            department=unit.department, leaderIdentifier=unit.leaderIdentifier, status=unit.status,
            members=memberArray(unit), createdAt=unit.createdAt, metadata=unit.metadata or {}
        }
    end
    return result
end

local function serializeShifts()
    local result = {}
    for identifier, shift in pairs(ActiveShifts) do
        result[identifier] = shift
    end
    return result
end

local function serializePursuits()
    local result = {}
    for id, pursuit in pairs(ActivePursuits) do
        local copy = {}
        for key, value in pairs(pursuit) do copy[key] = value end
        result[id] = copy
    end
    return result
end

local function queryCertifications(identifier)
    return MySQL.query.await('SELECT cert_id, cert_label, score, issued_at, expires_at FROM dpn_academy_certs WHERE identifier = ? AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY cert_label', { identifier }) or {}
end

local function hasCertification(identifier, certId)
    if not certId or certId == '' or not Config.Armory.RequireValidCertification then return true end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM dpn_academy_certs WHERE identifier = ? AND cert_id = ? AND (expires_at IS NULL OR expires_at > NOW())', { identifier, certId })
    return tonumber(count) and tonumber(count) > 0
end

local function dashboardCounts()
    local dispatchCount = 0
    if GetResourceState(Config.DispatchResource) == 'started' then
        local ok, calls = pcall(function() return exports[Config.DispatchResource]:GetActiveCalls() end)
        if ok and type(calls) == 'table' then for _ in pairs(calls) do dispatchCount = dispatchCount + 1 end end
    end
    local shifts, units, pursuits = 0, 0, 0
    for _ in pairs(ActiveShifts) do shifts = shifts + 1 end
    for _ in pairs(OperationalUnits) do units = units + 1 end
    for _ in pairs(ActivePursuits) do pursuits = pursuits + 1 end
    return { activeShifts=shifts, activeUnits=units, activePursuits=pursuits, activeDispatchCalls=dispatchCount }
end

local function buildState(src)
    local allowed, info = isAllowed(src, false)
    if not allowed or not info then return nil end
    local supervisor = isSupervisor(src)
    local judge = isJudge(src)
    local warrants = MySQL.query.await([[SELECT warrant_id, warrant_type, subject_type, subject_key, subject_name, charges, probable_cause, risk_level,
        requester_cid, requester_name, reviewer_cid, reviewer_name, review_notes, status, expires_at, served_by_name, served_at, created_at, updated_at
        FROM dpn_le_warrants WHERE status <> 'archived' ORDER BY created_at DESC LIMIT 150]], {}) or {}

    local forceReports
    if supervisor then
        forceReports = MySQL.query.await('SELECT * FROM dpn_le_force_reports ORDER BY created_at DESC LIMIT 100', {}) or {}
    else
        forceReports = MySQL.query.await('SELECT * FROM dpn_le_force_reports WHERE officer_cid = ? ORDER BY created_at DESC LIMIT 100', { info.citizenid }) or {}
    end

    local fleet, armory
    if supervisor then
        fleet = MySQL.query.await('SELECT * FROM dpn_le_fleet_checkouts WHERE status = ? ORDER BY checked_out_at DESC LIMIT 100', { 'active' }) or {}
        armory = MySQL.query.await('SELECT * FROM dpn_le_armory_checkouts WHERE status = ? ORDER BY issued_at DESC LIMIT 150', { 'active' }) or {}
    else
        fleet = MySQL.query.await('SELECT * FROM dpn_le_fleet_checkouts WHERE officer_cid = ? AND status = ? ORDER BY checked_out_at DESC LIMIT 25', { info.citizenid, 'active' }) or {}
        armory = MySQL.query.await('SELECT * FROM dpn_le_armory_checkouts WHERE officer_cid = ? AND status = ? ORDER BY issued_at DESC LIMIT 50', { info.citizenid, 'active' }) or {}
    end

    local tasks = {}
    local recentPursuits = {}
    if supervisor or judge then
        tasks = MySQL.query.await('SELECT * FROM dpn_le_supervisor_tasks WHERE status = ? ORDER BY priority ASC, created_at ASC LIMIT 150', { 'open' }) or {}
    end
    if supervisor then
        recentPursuits = MySQL.query.await("SELECT * FROM dpn_le_pursuits WHERE status='closed' ORDER BY ended_at DESC LIMIT 75", {}) or {}
    end

    local counts = dashboardCounts()
    counts.pendingWarrants = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM dpn_le_warrants WHERE status = ?', { 'pending' })) or 0
    counts.activeWarrants = tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM dpn_le_warrants WHERE status = 'approved' AND (expires_at IS NULL OR expires_at > NOW())", {})) or 0
    counts.pendingForceReviews = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM dpn_le_force_reports WHERE status = ?', { 'pending' })) or 0
    counts.activeFleet = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM dpn_le_fleet_checkouts WHERE status = ?', { 'active' })) or 0
    counts.activeArmory = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM dpn_le_armory_checkouts WHERE status = ?', { 'active' })) or 0

    return {
        profile={
            source=src, citizenid=info.citizenid, name=info.name, job=info.job, jobLabel=info.jobLabel,
            grade=info.grade, onDuty=info.onDuty, department=info.department, supervisor=supervisor,
            judge=judge, activeShift=ActiveShifts[info.citizenid], unitId=UnitByMember[info.citizenid]
        },
        dashboard=counts,
        shifts=serializeShifts(), units=serializeUnits(), pursuits=serializePursuits(),
        warrants=warrants, forceReports=forceReports, fleet=fleet, armory=armory, tasks=tasks, recentPursuits=recentPursuits,
        certifications=queryCertifications(info.citizenid),
        network=networkState(src),
        config={
            unitRoles=Config.UnitRoles, warrantTypes=Config.Warrants.Types, warrantRisks=Config.Warrants.RiskLevels,
            pursuitStages=Config.Pursuits.Stages, pursuitTactics=Config.Pursuits.Tactics, pursuitReviewFindings=Config.Pursuits.ReviewFindings,
            forceLevels=Config.Force.Levels, reviewFindings=Config.Force.ReviewFindings,
            armoryCatalog=Config.Armory.Catalog, moduleLauncher=Config.ModuleLauncher, networkQuickSignals=Config.NetworkQuickSignals,
            commandCenterTitle=Config.CommandCenterTitle, commandCenterSubtitle=Config.CommandCenterSubtitle
        }
    }
end

local function syncSource(src)
    local state = buildState(src)
    if state then TriggerClientEvent('dpn-le-operations:client:sync', src, state) end
end

local function syncAndRefresh(src)
    syncSource(src)
    broadcastRefresh()
end

local function closeUnitIfEmpty(unitId, reason)
    local unit = OperationalUnits[unitId]
    if not unit then return end
    if next(unit.members or {}) then return end
    unit.status = 'closed'
    MySQL.update('UPDATE dpn_le_operational_units SET status = ?, closed_at = NOW(), members = ? WHERE unit_id = ?', { 'closed', json.encode({}), unitId })
    OperationalUnits[unitId] = nil
    audit(0, 'UNIT_CLOSED', unitId, { reason=reason or 'empty' })
end

local function leaveOperationalUnit(info, reason)
    local unitId = info and UnitByMember[info.citizenid]
    local unit = unitId and OperationalUnits[unitId] or nil
    if not unit then return false end
    local wasLeader = unit.leaderIdentifier == info.citizenid
    unit.members[info.citizenid] = nil
    UnitByMember[info.citizenid] = nil

    if wasLeader and next(unit.members or {}) then
        for citizenid, member in pairs(unit.members) do
            unit.leaderIdentifier = citizenid
            member.role = 'leader'
            audit(member.source or 0, 'UNIT_LEADERSHIP_TRANSFERRED', unitId, { from=info.citizenid, to=citizenid })
            break
        end
    end

    MySQL.update('UPDATE dpn_le_operational_units SET leader_identifier = ?, members = ? WHERE unit_id = ?', {
        unit.leaderIdentifier, json.encode(memberArray(unit)), unitId
    })
    if info.source and info.source > 0 then
        local defaultUnit = ('%s-%s'):format(info.job:sub(1, 3):upper(), info.source)
        coreSetUnit(info.source, defaultUnit)
        updateDispatchUnit(info.source, { unit=defaultUnit, status='10-8', metadata={ operationalUnit=nil, role='patrol', partners={} } })
    end
    syncOperationalUnitMembers(unit)
    audit(info.source or 0, 'UNIT_LEFT', unitId, { reason=reason or 'voluntary' })
    closeUnitIfEmpty(unitId, reason)
    return true
end

RegisterNetEvent('dpn-le-operations:server:requestState', function()
    local src = source
    if not isAllowed(src, false) then return notify(src, 'Access denied.', 'error') end
    syncSource(src)
end)

RegisterNetEvent('dpn-le-operations:server:startShift', function(notes)
    local src = source
    if not rateAllowed(src, 'shift') then return end
    local allowed, info = isLaw(src, true)
    if not allowed then return notify(src, 'You must be an on-duty law-enforcement officer.', 'error') end
    if ActiveShifts[info.citizenid] then return notify(src, 'You already have an active shift.', 'error') end
    local shiftId = makeId('SHIFT')
    local shift = {
        shiftId=shiftId, identifier=info.citizenid, officerName=info.name, source=src, job=info.job, grade=info.grade,
        calls_handled=0, citations=0, arrests=0, searches=0, force_reports=0,
        notes=clean(notes, 1500), startedAt=os.time()
    }
    ActiveShifts[info.citizenid] = shift
    MySQL.insert([[INSERT INTO dpn_le_shifts (shift_id, identifier, officer_name, job, grade, notes, started_at)
        VALUES (?, ?, ?, ?, ?, ?, NOW())]], { shiftId, info.citizenid, info.name, info.job, info.grade, shift.notes })
    audit(src, 'SHIFT_STARTED', shiftId, { job=info.job, grade=info.grade })
    notify(src, ('Shift %s started.'):format(shiftId), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:endShift', function(data)
    local src = source
    if not rateAllowed(src, 'shift') then return end
    local _, info = isLaw(src, false)
    if not info then return end
    local shift = ActiveShifts[info.citizenid]
    if not shift then return notify(src, 'No active shift was found.', 'error') end
    data = type(data) == 'table' and data or {}
    leaveOperationalUnit(info, 'shift_ended')
    ActiveShifts[info.citizenid] = nil
    MySQL.update('UPDATE dpn_le_shifts SET notes = ?, ended_at = NOW(), end_reason = ? WHERE shift_id = ?', {
        clean(data.notes or shift.notes, 2500), clean(data.reason or 'completed', 80), shift.shiftId
    })
    audit(src, 'SHIFT_ENDED', shift.shiftId, { reason=data.reason or 'completed', summary=shift })
    notify(src, ('Shift %s ended.'):format(shift.shiftId), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:createUnit', function(data)
    local src = source
    if not rateAllowed(src, 'unit') then return end
    local allowed, info = isLaw(src, true)
    if not allowed then return notify(src, 'Law-enforcement duty access required.', 'error') end
    if not activeShiftFor(info) then return notify(src, 'Start a shift before forming an operational unit.', 'error') end
    if UnitByMember[info.citizenid] then return notify(src, 'Leave your current unit first.', 'error') end
    data = type(data) == 'table' and data or {}
    local code = clean(data.unitCode, 24):upper():gsub('[^%w%-]', '')
    if code == '' then return notify(src, 'A valid unit code is required.', 'error') end
    for _, unit in pairs(OperationalUnits) do if unit.unitCode == code then return notify(src, 'That unit code is already active.', 'error') end end
    local role = Config.UnitRoles[data.role] and data.role or 'patrol'
    local unitId = makeId('UNIT')
    local unit = {
        unitId=unitId, unitCode=code, unitName=clean(data.unitName or (code .. ' Operational Unit'), 120), role=role,
        department='law', leaderIdentifier=info.citizenid, status='active', createdAt=os.time(), metadata={},
        members={ [info.citizenid]={ source=src, name=info.name, job=info.job, role='leader', joinedAt=os.time() } }
    }
    OperationalUnits[unitId] = unit
    UnitByMember[info.citizenid] = unitId
    MySQL.insert([[INSERT INTO dpn_le_operational_units (unit_id, unit_code, unit_name, role, department, leader_identifier, members, metadata, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active', NOW())]], {
        unitId, code, unit.unitName, role, unit.department, info.citizenid, json.encode(memberArray(unit)), json.encode({})
    })
    syncOperationalUnitMembers(unit)
    audit(src, 'UNIT_CREATED', unitId, { code=code, role=role })
    notify(src, ('Operational unit %s created.'):format(code), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:joinUnit', function(unitId)
    local src = source
    if not rateAllowed(src, 'unit') then return end
    local allowed, info = isLaw(src, true)
    if not allowed or not activeShiftFor(info) then return notify(src, 'An active law-enforcement shift is required.', 'error') end
    if UnitByMember[info.citizenid] then return notify(src, 'Leave your current unit first.', 'error') end
    unitId = clean(unitId, 64)
    local unit = OperationalUnits[unitId]
    if not unit or unit.status ~= 'active' then return notify(src, 'Operational unit not found.', 'error') end
    if memberCount(unit) >= Config.MaxUnitMembers then return notify(src, 'That operational unit is full.', 'error') end
    unit.members[info.citizenid] = { source=src, name=info.name, job=info.job, role='member', joinedAt=os.time() }
    UnitByMember[info.citizenid] = unitId
    MySQL.update('UPDATE dpn_le_operational_units SET members = ? WHERE unit_id = ?', { json.encode(memberArray(unit)), unitId })
    syncOperationalUnitMembers(unit)
    audit(src, 'UNIT_JOINED', unitId, { code=unit.unitCode })
    notify(src, ('Joined operational unit %s.'):format(unit.unitCode), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:leaveUnit', function()
    local src = source
    local _, info = isLaw(src, false)
    if not info or not leaveOperationalUnit(info, 'voluntary') then return notify(src, 'You are not assigned to an operational unit.', 'error') end
    notify(src, 'You left your operational unit.', 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:requestWarrant', function(data)
    local src = source
    if not rateAllowed(src, 'warrant') then return end
    local allowed, info = isLaw(src, true)
    if not allowed then return notify(src, 'Law-enforcement duty access required.', 'error') end
    data = type(data) == 'table' and data or {}
    local warrantType = Config.Warrants.Types[data.warrantType] and data.warrantType or nil
    local subjectType = data.subjectType == 'vehicle' and 'vehicle' or 'person'
    local subjectKey = clean(data.subjectKey, 100):upper()
    local subjectName = clean(data.subjectName, 160)
    local charges = clean(data.charges, Config.Warrants.MaxChargesLength)
    local probableCause = clean(data.probableCause, Config.Warrants.MaxProbableCauseLength)
    local risk = Config.Warrants.RiskLevels[data.riskLevel] and data.riskLevel or 'standard'
    local expiryDays = math.floor(clamp(data.expiryDays or Config.Warrants.DefaultExpiryDays, 1, Config.Warrants.MaximumExpiryDays))
    if not warrantType or subjectKey == '' or subjectName == '' or charges == '' or probableCause == '' then
        return notify(src, 'Warrant type, subject, charges, and probable cause are required.', 'error')
    end
    local warrantId = makeId('WAR')
    local initialStatus = Config.Warrants.RequireJudicialApproval and 'pending' or 'approved'
    local expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + (expiryDays * 86400))
    MySQL.insert([[INSERT INTO dpn_le_warrants (warrant_id, warrant_type, subject_type, subject_key, subject_name, charges, probable_cause, risk_level,
        requester_cid, requester_name, status, expires_at, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())]], {
        warrantId, warrantType, subjectType, subjectKey, subjectName, charges, probableCause, risk,
        info.citizenid, info.name, initialStatus, expiresAt, json.encode({ requesterJob=info.job })
    })
    MySQL.insert('INSERT INTO dpn_le_warrant_actions (warrant_id, actor_cid, actor_name, action, notes, created_at) VALUES (?, ?, ?, ?, ?, NOW())', {
        warrantId, info.citizenid, info.name, 'requested', probableCause
    })
    if initialStatus == 'pending' then createSupervisorTask('warrant_review', warrantId, ('Review warrant for %s'):format(subjectName), risk == 'critical' and 1 or 2, 'justice', { risk=risk }) end
    if GetResourceState(Config.JusticeResource) == 'started' then TriggerEvent('dpn-justice:server:warrantRequested', warrantId, data, info) end
    if GetResourceState(Config.MdtResource) == 'started' then TriggerEvent('dpn-mdt:server:warrantUpdated', warrantId, initialStatus) end
    audit(src, 'WARRANT_REQUESTED', warrantId, { subject=subjectKey, type=warrantType, risk=risk })
    networkPublish('warrant_requested', { title='Warrant Requested', message=('%s requested %s for %s.'):format(info.name, warrantType, subjectName), severity=risk == 'critical' and 2 or 4, warrantId=warrantId, subjectType=subjectType, subjectKey=subjectKey, subjectName=subjectName, risk=risk, suppressRouting=true })
    webhook('Warrant Requested', ('%s requested %s for %s'):format(info.name, warrantType, subjectName), 15844367)
    notify(src, ('Warrant %s submitted for review.'):format(warrantId), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:reviewWarrant', function(data)
    local src = source
    if not rateAllowed(src, 'warrant-review') then return end
    if not (isJudge(src) or isSupervisor(src)) then return notify(src, 'Judicial or supervisor authorization required.', 'error') end
    local info = playerInfo(src)
    data = type(data) == 'table' and data or {}
    local warrantId = clean(data.warrantId, 64)
    local decision = data.decision == 'approved' and 'approved' or (data.decision == 'denied' and 'denied' or nil)
    if not decision then return end
    local warrant = MySQL.single.await('SELECT * FROM dpn_le_warrants WHERE warrant_id = ?', { warrantId })
    if not warrant or warrant.status ~= 'pending' then return notify(src, 'That warrant is no longer pending.', 'error') end
    local notes = clean(data.notes, 2500)
    MySQL.update('UPDATE dpn_le_warrants SET status = ?, reviewer_cid = ?, reviewer_name = ?, review_notes = ?, updated_at = NOW() WHERE warrant_id = ?', {
        decision, info.citizenid, info.name, notes, warrantId
    })
    MySQL.insert('INSERT INTO dpn_le_warrant_actions (warrant_id, actor_cid, actor_name, action, notes, created_at) VALUES (?, ?, ?, ?, ?, NOW())', {
        warrantId, info.citizenid, info.name, decision, notes
    })
    completeSupervisorTasks('warrant_review', warrantId)
    if decision == 'approved' then
        intelAlert({ type='warrant', title='Active Warrant', message=('%s has an approved %s.'):format(warrant.subject_name, warrant.warrant_type), priority=warrant.risk_level == 'critical' and 1 or 2, subjectType=warrant.subject_type, subjectKey=warrant.subject_key, metadata={ warrantId=warrantId } })
    end
    if GetResourceState(Config.JusticeResource) == 'started' then TriggerEvent('dpn-justice:server:warrantReviewed', warrantId, decision, info, notes) end
    if GetResourceState(Config.MdtResource) == 'started' then TriggerEvent('dpn-mdt:server:warrantUpdated', warrantId, decision) end
    audit(src, 'WARRANT_REVIEWED', warrantId, { decision=decision, notes=notes })
    networkPublish(decision == 'approved' and 'warrant_approved' or 'warrant_denied', { title=('Warrant %s'):format(decision), message=('%s for %s was %s by %s.'):format(warrantId, warrant.subject_name, decision, info.name), severity=decision == 'approved' and (warrant.risk_level == 'critical' and 2 or 3) or 4, warrantId=warrantId, subjectType=warrant.subject_type, subjectKey=warrant.subject_key, subjectName=warrant.subject_name, risk=warrant.risk_level, suppressRouting=true })
    notify(src, ('Warrant %s %s.'):format(warrantId, decision), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:serveWarrant', function(data)
    local src = source
    local allowed, info = isLaw(src, true)
    if not allowed then return end
    data = type(data) == 'table' and data or {}
    local warrantId = clean(data.warrantId, 64)
    local warrant = MySQL.single.await("SELECT * FROM dpn_le_warrants WHERE warrant_id = ? AND status = 'approved' AND (expires_at IS NULL OR expires_at > NOW())", { warrantId })
    if not warrant then return notify(src, 'No active approved warrant was found.', 'error') end
    local notes = clean(data.notes, 2500)
    MySQL.update("UPDATE dpn_le_warrants SET status = 'served', served_by_cid = ?, served_by_name = ?, served_at = NOW(), updated_at = NOW() WHERE warrant_id = ?", {
        info.citizenid, info.name, warrantId
    })
    MySQL.insert('INSERT INTO dpn_le_warrant_actions (warrant_id, actor_cid, actor_name, action, notes, created_at) VALUES (?, ?, ?, ?, ?, NOW())', {
        warrantId, info.citizenid, info.name, 'served', notes
    })
    if Config.Warrants.HighRiskDispatch and (warrant.risk_level == 'high' or warrant.risk_level == 'critical') then
        dispatchCall({ type='warrant', title='High-Risk Warrant Service', description=('%s is serving %s on %s.'):format(info.name, warrantId, warrant.subject_name), priority=warrant.risk_level == 'critical' and 1 or 2, coords=playerCoords(src), departments={'law','dispatch'}, metadata={ warrantId=warrantId, risk=warrant.risk_level } })
    end
    evidenceRecord('document', ('Warrant %s served'):format(warrantId), { warrantId=warrantId, subject=warrant.subject_key, notes=notes, servedBy=info.name })
    if GetResourceState(Config.MdtResource) == 'started' then TriggerEvent('dpn-mdt:server:warrantUpdated', warrantId, 'served') end
    audit(src, 'WARRANT_SERVED', warrantId, { notes=notes })
    networkPublish('warrant_served', { title='Warrant Served', message=('%s served %s on %s.'):format(info.name, warrantId, warrant.subject_name), severity=warrant.risk_level == 'critical' and 2 or 3, warrantId=warrantId, subjectKey=warrant.subject_key, notes=notes, suppressRouting=true })
    notify(src, ('Warrant %s marked served.'):format(warrantId), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:revokeWarrant', function(data)
    local src = source
    if not (isJudge(src) or isSupervisor(src)) then return notify(src, 'Judicial or supervisor authorization required.', 'error') end
    local info = playerInfo(src)
    data = type(data) == 'table' and data or {}
    local warrantId = clean(data.warrantId, 64)
    local notes = clean(data.notes, 2500)
    if notes == '' then return notify(src, 'A revocation reason is required.', 'error') end
    local warrant = MySQL.single.await("SELECT * FROM dpn_le_warrants WHERE warrant_id=? AND status IN ('pending','approved')", { warrantId })
    if not warrant then return notify(src, 'Revocable warrant not found.', 'error') end
    MySQL.update("UPDATE dpn_le_warrants SET status='revoked', reviewer_cid=?, reviewer_name=?, review_notes=?, updated_at=NOW() WHERE warrant_id=?", {
        info.citizenid, info.name, notes, warrantId
    })
    MySQL.insert('INSERT INTO dpn_le_warrant_actions (warrant_id, actor_cid, actor_name, action, notes, created_at) VALUES (?, ?, ?, ?, ?, NOW())', {
        warrantId, info.citizenid, info.name, 'revoked', notes
    })
    completeSupervisorTasks('warrant_review', warrantId)
    if GetResourceState(Config.MdtResource) == 'started' then TriggerEvent('dpn-mdt:server:warrantUpdated', warrantId, 'revoked') end
    audit(src, 'WARRANT_REVOKED', warrantId, { notes=notes })
    networkPublish('warrant_revoked', { title='Warrant Revoked', message=('%s revoked %s.'):format(info.name, warrantId), severity=4, warrantId=warrantId, subjectKey=warrant.subject_key, notes=notes, suppressRouting=true })
    notify(src, ('Warrant %s revoked.'):format(warrantId), 'success')
    syncAndRefresh(src)
end)

local function getNetworkVehicle(netId)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return nil end
    local ok, entity = pcall(NetworkGetEntityFromNetworkId, netId)
    if not ok or not entity or entity <= 0 or not DoesEntityExist(entity) then return nil end
    if GetEntityType(entity) ~= 2 then return nil end
    return entity
end

local function vehicleSnapshot(entity)
    if not entity or entity <= 0 then return nil end
    local coords = GetEntityCoords(entity)
    local plate, model, speed = 'UNKNOWN', tostring(GetEntityModel(entity)), GetEntitySpeed(entity) * 2.236936
    pcall(function() plate = trim(GetVehicleNumberPlateText(entity)):upper() end)
    return {
        netId=NetworkGetNetworkIdFromEntity(entity), plate=plate ~= '' and plate or 'UNKNOWN', model=model,
        speed=math.floor(speed * 10) / 10, coords={ x=coords.x, y=coords.y, z=coords.z },
        body=GetVehicleBodyHealth(entity), engine=GetVehicleEngineHealth(entity)
    }
end

RegisterNetEvent('dpn-le-operations:server:startPursuit', function(data)
    local src = source
    if not rateAllowed(src, 'pursuit') then return end
    local allowed, info = isLaw(src, true)
    if not allowed then return notify(src, 'Law-enforcement duty access required.', 'error') end
    if not activeShiftFor(info) then return notify(src, 'Start your shift before initiating a pursuit.', 'error') end
    local activeCount = 0
    for _ in pairs(ActivePursuits) do activeCount = activeCount + 1 end
    if activeCount >= Config.Pursuits.MaxActive then return notify(src, 'The pursuit system is at capacity.', 'error') end
    data = type(data) == 'table' and data or {}
    local entity = getNetworkVehicle(data.vehicleNetId)
    if not entity then return notify(src, 'Aim at or approach the suspect vehicle and try again.', 'error') end
    local snapshot = vehicleSnapshot(entity)
    if distance(playerCoords(src), snapshot.coords) > Config.Pursuits.AcquisitionDistance then return notify(src, 'The suspect vehicle is too far away to acquire.', 'error') end
    local reason = clean(data.reason, 1200)
    if reason == '' then return notify(src, 'A pursuit reason is required.', 'error') end
    local pursuitId = makeId('PUR')
    local unitCode = info.name
    local operationalUnit = UnitByMember[info.citizenid] and OperationalUnits[UnitByMember[info.citizenid]] or nil
    if operationalUnit then unitCode = operationalUnit.unitCode end
    local pursuit = {
        pursuitId=pursuitId, primaryCid=info.citizenid, primaryName=info.name,
        plate=snapshot.plate, model=snapshot.model, vehicleNetId=snapshot.netId,
        stage='active', riskLevel=Config.Warrants.RiskLevels[data.riskLevel] and data.riskLevel or 'standard', reason=reason,
        units={ [info.citizenid]={ source=src, name=info.name, unit=unitCode, role='primary', joinedAt=os.time() } },
        authorizations={}, lastCoords=snapshot.coords, speed=snapshot.speed, maxSpeed=snapshot.speed,
        status='active', startedAt=os.time(), direction=clean(data.direction, 80)
    }
    if Config.Pursuits.AutoDispatch then
        local call = dispatchCall({ type='pursuit', title=('Vehicle Pursuit • %s'):format(snapshot.plate), description=('%s initiated a pursuit. Reason: %s'):format(info.name, reason), priority=pursuit.riskLevel == 'critical' and 1 or 2, coords=snapshot.coords, departments={'law','dispatch'}, metadata={ pursuitId=pursuitId, plate=snapshot.plate } })
        pursuit.dispatchCallId = call and call.callId or nil
    end
    if Config.Pursuits.AutoIncident then
        pursuit.incidentId = incidentCreate(('Vehicle Pursuit %s'):format(snapshot.plate), 'pursuit', pursuit.riskLevel == 'critical' and 'critical' or 'high', snapshot.coords, reason)
    end
    ActivePursuits[pursuitId] = pursuit
    MySQL.insert([[INSERT INTO dpn_le_pursuits (pursuit_id, primary_cid, primary_name, vehicle_plate, vehicle_model, vehicle_net_id, stage, risk_level,
        reason, units, authorizations, last_coords, max_speed, dispatch_call_id, incident_id, status, started_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', NOW())]], {
        pursuitId, info.citizenid, info.name, snapshot.plate, snapshot.model, snapshot.netId, pursuit.stage, pursuit.riskLevel,
        reason, json.encode(pursuit.units), json.encode(pursuit.authorizations), json.encode(snapshot.coords), pursuit.maxSpeed,
        pursuit.dispatchCallId, pursuit.incidentId
    })
    coreSetStatus(src, '10-11')
    incrementShift(info.citizenid, 'calls_handled', 1)
    audit(src, 'PURSUIT_STARTED', pursuitId, { plate=snapshot.plate, reason=reason })
    networkPublish('pursuit', { title='Vehicle Pursuit Initiated', message=('%s initiated pursuit %s of %s: %s'):format(info.name, pursuitId, snapshot.plate, reason), severity=1, pursuitId=pursuitId, plate=snapshot.plate, coords=snapshot.coords, risk=risk, dispatchCallId=pursuit.dispatchCallId, incidentId=pursuit.incidentId, suppressRouting=true })
    evidenceRecord('vehicle', ('Pursuit %s initiated'):format(pursuitId), { plate=snapshot.plate, reason=reason, coords=snapshot.coords, primary=info.name })
    notify(src, ('Pursuit %s initiated on %s.'):format(pursuitId, snapshot.plate), 'success')
    broadcastLawClient('dpn-le-operations:client:pursuitActivated', pursuitId, pursuit)
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:updatePursuit', function(data)
    local src = source
    if not rateAllowed(src, 'pursuit-update') then return end
    local allowed, info = isLaw(src, true)
    if not allowed then return end
    data = type(data) == 'table' and data or {}
    local pursuit = ActivePursuits[clean(data.pursuitId, 64)]
    if not pursuit or not pursuit.units[info.citizenid] then return end
    local entity = getNetworkVehicle(pursuit.vehicleNetId)
    if entity then
        local snapshot = vehicleSnapshot(entity)
        pursuit.lastCoords, pursuit.speed = snapshot.coords, snapshot.speed
        pursuit.maxSpeed = math.max(tonumber(pursuit.maxSpeed) or 0, snapshot.speed)
    end
    if data.stage and Config.Pursuits.Stages[data.stage] then pursuit.stage = data.stage end
    pursuit.direction = clean(data.direction or pursuit.direction, 80)
    pursuit.updatedAt = os.time()
    MySQL.update('UPDATE dpn_le_pursuits SET stage = ?, last_coords = ?, max_speed = ?, units = ?, authorizations = ? WHERE pursuit_id = ?', {
        pursuit.stage, json.encode(pursuit.lastCoords), pursuit.maxSpeed, json.encode(pursuit.units), json.encode(pursuit.authorizations), pursuit.pursuitId
    })
    broadcastLawClient('dpn-le-operations:client:pursuitUpdated', pursuit.pursuitId, pursuit)
end)

RegisterNetEvent('dpn-le-operations:server:joinPursuit', function(pursuitId)
    local src = source
    local allowed, info = isLaw(src, true)
    if not allowed then return end
    pursuitId = clean(pursuitId, 64)
    local pursuit = ActivePursuits[pursuitId]
    if not pursuit then return notify(src, 'Active pursuit not found.', 'error') end
    local operationalUnit = UnitByMember[info.citizenid] and OperationalUnits[UnitByMember[info.citizenid]] or nil
    pursuit.units[info.citizenid] = { source=src, name=info.name, unit=operationalUnit and operationalUnit.unitCode or tostring(src), role='support', joinedAt=os.time() }
    MySQL.update('UPDATE dpn_le_pursuits SET units = ? WHERE pursuit_id = ?', { json.encode(pursuit.units), pursuitId })
    coreSetStatus(src, '10-97')
    audit(src, 'PURSUIT_JOINED', pursuitId, {})
    notify(src, ('Joined pursuit %s.'):format(pursuitId), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:requestTactic', function(data)
    local src = source
    local allowed, info = isLaw(src, true)
    if not allowed then return end
    data = type(data) == 'table' and data or {}
    local pursuitId = clean(data.pursuitId, 64)
    local tactic = Config.Pursuits.Tactics[data.tactic] and data.tactic or nil
    local pursuit = ActivePursuits[pursuitId]
    if not pursuit or not tactic or not pursuit.units[info.citizenid] then return end
    local requiresApproval = (tactic == 'pit' and Config.Pursuits.SupervisorRequiredForPit) or (tactic == 'roadblock' and Config.Pursuits.SupervisorRequiredForRoadblock)
    local approved = isSupervisor(src) or not requiresApproval
    pursuit.authorizations[tactic] = {
        status=approved and 'approved' or 'requested', requestedBy=info.name, requestedByCid=info.citizenid,
        requestedAt=os.time(), notes=clean(data.notes, 500)
    }
    if not approved then createSupervisorTask('pursuit_tactic', pursuitId .. ':' .. tactic, ('%s authorization requested for pursuit %s'):format(Config.Pursuits.Tactics[tactic], pursuitId), tactic == 'pit' and 1 or 2, info.job, { pursuitId=pursuitId, tactic=tactic }) end
    MySQL.update('UPDATE dpn_le_pursuits SET authorizations = ? WHERE pursuit_id = ?', { json.encode(pursuit.authorizations), pursuitId })
    audit(src, 'PURSUIT_TACTIC_' .. (approved and 'APPROVED' or 'REQUESTED'), pursuitId, { tactic=tactic })
    notify(src, approved and ('%s authorized.'):format(Config.Pursuits.Tactics[tactic]) or ('%s requested from a supervisor.'):format(Config.Pursuits.Tactics[tactic]), approved and 'success' or 'primary')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:reviewTactic', function(data)
    local src = source
    if not isSupervisor(src) then return notify(src, 'Supervisor authorization required.', 'error') end
    local info = playerInfo(src)
    data = type(data) == 'table' and data or {}
    local pursuitId, tactic = clean(data.pursuitId, 64), clean(data.tactic, 40)
    local pursuit = ActivePursuits[pursuitId]
    if not pursuit or not pursuit.authorizations[tactic] then return end
    pursuit.authorizations[tactic].status = data.approved == true and 'approved' or 'denied'
    pursuit.authorizations[tactic].reviewedBy = info.name
    pursuit.authorizations[tactic].reviewedAt = os.time()
    pursuit.authorizations[tactic].reviewNotes = clean(data.notes, 500)
    MySQL.update('UPDATE dpn_le_pursuits SET authorizations = ? WHERE pursuit_id = ?', { json.encode(pursuit.authorizations), pursuitId })
    completeSupervisorTasks('pursuit_tactic', pursuitId .. ':' .. tactic)
    audit(src, 'PURSUIT_TACTIC_REVIEWED', pursuitId, { tactic=tactic, approved=data.approved == true })
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:endPursuit', function(data)
    local src = source
    local allowed, info = isLaw(src, true)
    if not allowed then return end
    data = type(data) == 'table' and data or {}
    local pursuitId = clean(data.pursuitId, 64)
    local pursuit = ActivePursuits[pursuitId]
    if not pursuit then return notify(src, 'Active pursuit not found.', 'error') end
    if pursuit.primaryCid ~= info.citizenid and not isSupervisor(src) then return notify(src, 'Only the primary unit or a supervisor may terminate this pursuit.', 'error') end
    local disposition = clean(data.disposition or 'terminated', 80)
    local notes = clean(data.notes, 5000)
    pursuit.status, pursuit.stage, pursuit.disposition, pursuit.terminationNotes, pursuit.endedAt = 'closed', 'terminated', disposition, notes, os.time()
    MySQL.update([[UPDATE dpn_le_pursuits SET stage='terminated', status='closed', disposition=?, termination_notes=?, units=?, authorizations=?, last_coords=?, max_speed=?, ended_at=NOW() WHERE pursuit_id=?]], {
        disposition, notes, json.encode(pursuit.units), json.encode(pursuit.authorizations), json.encode(pursuit.lastCoords), pursuit.maxSpeed, pursuitId
    })
    createSupervisorTask('pursuit_review', pursuitId, ('Post-pursuit review for %s'):format(pursuit.plate), pursuit.riskLevel == 'critical' and 1 or 3, info.job, { disposition=disposition, maxSpeed=pursuit.maxSpeed })
    evidenceRecord('vehicle', ('Pursuit %s terminated'):format(pursuitId), { disposition=disposition, notes=notes, maxSpeed=pursuit.maxSpeed, units=pursuit.units })
    audit(src, 'PURSUIT_ENDED', pursuitId, { disposition=disposition, maxSpeed=pursuit.maxSpeed })
    networkPublish('pursuit_ended', { title='Vehicle Pursuit Terminated', message=('%s ended %s: %s.'):format(info.name, pursuitId, disposition), severity=3, pursuitId=pursuitId, plate=pursuit.plate, disposition=disposition, maxSpeed=pursuit.maxSpeed, notes=notes, suppressRouting=true })
    ActivePursuits[pursuitId] = nil
    coreSetStatus(src, '10-8')
    broadcastLawClient('dpn-le-operations:client:pursuitEnded', pursuitId)
    notify(src, ('Pursuit %s terminated and queued for review.'):format(pursuitId), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:reviewPursuit', function(data)
    local src = source
    if not isSupervisor(src) then return notify(src, 'Supervisor authorization required.', 'error') end
    local info = playerInfo(src)
    data = type(data) == 'table' and data or {}
    local pursuitId = clean(data.pursuitId, 64)
    local finding = Config.Pursuits.ReviewFindings[data.finding] and data.finding or nil
    if not finding then return notify(src, 'A valid review finding is required.', 'error') end
    local pursuit = MySQL.single.await("SELECT * FROM dpn_le_pursuits WHERE pursuit_id=? AND status='closed'", { pursuitId })
    if not pursuit then return notify(src, 'Closed pursuit not found.', 'error') end
    local notes = clean(data.notes, 5000)
    MySQL.update([[UPDATE dpn_le_pursuits SET review_status='reviewed', reviewer_cid=?, reviewer_name=?, review_finding=?, review_notes=?, reviewed_at=NOW() WHERE pursuit_id=?]], {
        info.citizenid, info.name, finding, notes, pursuitId
    })
    completeSupervisorTasks('pursuit_review', pursuitId)
    if finding == 'investigation' then
        createSupervisorTask('administrative_investigation', pursuitId, ('Pursuit investigation required for %s'):format(pursuit.vehicle_plate), 1, info.job, { finding=finding })
    end
    audit(src, 'PURSUIT_REVIEWED', pursuitId, { finding=finding, notes=notes })
    notify(src, ('Pursuit %s review completed.'):format(pursuitId), 'success')
    syncAndRefresh(src)
end)

local function createForceReport(src, data, automatic)
    local allowed, info = isLaw(src, true)
    if not allowed then return nil, 'access_denied' end
    data = type(data) == 'table' and data or {}
    local forceLevel = Config.Force.Levels[data.forceLevel] and data.forceLevel or (automatic and 'lethal' or nil)
    local reason = clean(data.reason or (automatic and 'Automatic weapon-discharge draft' or ''), 255)
    if not forceLevel or reason == '' then return nil, 'invalid' end
    local reportId = makeId('UOF')
    local coords = playerCoords(src)
    MySQL.insert([[INSERT INTO dpn_le_force_reports (report_id, officer_cid, officer_name, officer_job, subject_cid, subject_name, force_level, reason,
        weapons_used, injuries, medical_aid, bodycam_reference, case_reference, narrative, coords, automatic_draft, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', NOW())]], {
        reportId, info.citizenid, info.name, info.job, clean(data.subjectCid, 80), clean(data.subjectName, 160), forceLevel, reason,
        clean(data.weaponsUsed or data.weapon or '', 1000), clean(data.injuries, 1500), clean(data.medicalAid, 1500),
        clean(data.bodycamReference, 255), clean(data.caseReference, 100), clean(data.narrative, Config.Force.NarrativeMaxLength),
        json.encode(coords or {}), automatic and 1 or 0
    })
    createSupervisorTask('force_review', reportId, ('Review use-of-force report by %s'):format(info.name), forceLevel == 'lethal' and 1 or 2, info.job, { forceLevel=forceLevel, automatic=automatic })
    incrementShift(info.citizenid, 'force_reports', 1)
    evidenceRecord('other', ('Use-of-force report %s'):format(reportId), { officer=info.name, forceLevel=forceLevel, reason=reason, automatic=automatic, coords=coords })
    audit(src, automatic and 'FORCE_DRAFT_CREATED' or 'FORCE_REPORT_CREATED', reportId, { forceLevel=forceLevel, automatic=automatic })
    networkPublish('use_of_force', { title=automatic and 'Automatic Force Draft Created' or 'Use-of-Force Report Submitted', message=('%s created force report %s (%s).'):format(info.name, reportId, forceLevel), severity=forceLevel == 'lethal' and 1 or 3, reportId=reportId, forceLevel=forceLevel, officerCid=info.citizenid, subjectCid=clean(data.subjectCid,80), bodycamReference=clean(data.bodycamReference,255), suppressRouting=true })
    if forceLevel == 'lethal' then dispatchCall({ type='use_of_force', title='Lethal Force Report Initiated', description=('%s generated use-of-force report %s.'):format(info.name, reportId), priority=2, coords=coords, departments={'law','dispatch'}, metadata={ reportId=reportId } }) end
    return reportId
end

RegisterNetEvent('dpn-le-operations:server:createForceReport', function(data)
    local src = source
    if not rateAllowed(src, 'force') then return end
    local reportId, reason = createForceReport(src, data, false)
    if not reportId then return notify(src, ('Unable to create report: %s'):format(reason or 'unknown'), 'error') end
    notify(src, ('Use-of-force report %s submitted.'):format(reportId), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:autoForceDraft', function(data)
    local src = source
    if not Config.Force.AutoDraftOnWeaponDischarge then return end
    local allowed, info = isLaw(src, true)
    if not allowed then return end
    local current = os.time()
    if WeaponDraftCooldown[info.citizenid] and current - WeaponDraftCooldown[info.citizenid] < Config.Force.DischargeCooldownSeconds then return end
    WeaponDraftCooldown[info.citizenid] = current
    local ped = GetPlayerPed(src)
    local weapon = 0
    if ped and ped > 0 then pcall(function() weapon = GetSelectedPedWeapon(ped) end) end
    data = type(data) == 'table' and data or {}
    data.weapon = ('Hash %s'):format(weapon ~= 0 and weapon or clean(data.weaponHash, 40))
    data.forceLevel = 'lethal'
    data.reason = 'Automatic weapon-discharge draft — officer completion required'
    data.narrative = 'This draft was generated automatically after the system detected an officer weapon discharge. Complete subject, justification, injuries, medical response, and bodycam references.'
    local reportId = createForceReport(src, data, true)
    if reportId then notify(src, ('Automatic force draft %s created. Complete it in LE Operations.'):format(reportId), 'error', 9000); broadcastRefresh() end
end)

RegisterNetEvent('dpn-le-operations:server:updateForceReport', function(data)
    local src = source
    if not rateAllowed(src, 'force-update') then return end
    local allowed, info = isLaw(src, true)
    if not allowed then return end
    data = type(data) == 'table' and data or {}
    local reportId = clean(data.reportId, 64)
    local report = MySQL.single.await("SELECT * FROM dpn_le_force_reports WHERE report_id=? AND officer_cid=? AND status='pending'", { reportId, info.citizenid })
    if not report then return notify(src, 'Pending report not found or not owned by you.', 'error') end
    local forceLevel = Config.Force.Levels[data.forceLevel] and data.forceLevel or report.force_level
    local reason = clean(data.reason or report.reason, 255)
    local narrative = clean(data.narrative or report.narrative, Config.Force.NarrativeMaxLength)
    if reason == '' or narrative == '' then return notify(src, 'Reason and complete narrative are required.', 'error') end
    MySQL.update([[UPDATE dpn_le_force_reports SET subject_cid=?, subject_name=?, force_level=?, reason=?, weapons_used=?, injuries=?, medical_aid=?,
        bodycam_reference=?, case_reference=?, narrative=?, automatic_draft=0 WHERE report_id=? AND officer_cid=?]], {
        clean(data.subjectCid,80), clean(data.subjectName,160), forceLevel, reason, clean(data.weaponsUsed,1000), clean(data.injuries,1500),
        clean(data.medicalAid,1500), clean(data.bodycamReference,255), clean(data.caseReference,100), narrative, reportId, info.citizenid
    })
    audit(src, 'FORCE_REPORT_UPDATED', reportId, { forceLevel=forceLevel })
    evidenceRecord('other', ('Use-of-force report %s completed'):format(reportId), { officer=info.name, forceLevel=forceLevel, bodycam=data.bodycamReference, case=data.caseReference })
    notify(src, ('Use-of-force report %s updated.'):format(reportId), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:reviewForceReport', function(data)
    local src = source
    if not isSupervisor(src) then return notify(src, 'Supervisor authorization required.', 'error') end
    local info = playerInfo(src)
    data = type(data) == 'table' and data or {}
    local reportId = clean(data.reportId, 64)
    local finding = Config.Force.ReviewFindings[data.finding] and data.finding or nil
    if not finding or finding == 'pending' then return end
    local report = MySQL.single.await("SELECT * FROM dpn_le_force_reports WHERE report_id = ? AND status = 'pending'", { reportId })
    if not report then return notify(src, 'Pending report not found.', 'error') end
    if tonumber(report.automatic_draft) == 1 then
        return notify(src, 'The involved officer must complete the automatic draft before supervisor review.', 'error')
    end
    local notes = clean(data.notes, 4000)
    MySQL.update([[UPDATE dpn_le_force_reports SET status='reviewed', reviewer_cid=?, reviewer_name=?, review_finding=?, review_notes=?, reviewed_at=NOW() WHERE report_id=?]], {
        info.citizenid, info.name, finding, notes, reportId
    })
    completeSupervisorTasks('force_review', reportId)
    audit(src, 'FORCE_REPORT_REVIEWED', reportId, { finding=finding, notes=notes })
    networkPublish('force_review_completed', { title='Force Review Completed', message=('%s reviewed %s: %s.'):format(info.name, reportId, finding), severity=(finding == 'investigation' or finding == 'criminal') and 2 or 4, reportId=reportId, finding=finding, notes=notes, suppressRouting=true })
    if finding == 'investigation' or finding == 'criminal' then
        createSupervisorTask('administrative_investigation', reportId, ('Administrative investigation required for %s'):format(report.officer_name), 1, report.officer_job, { finding=finding })
    end
    notify(src, ('Force report %s reviewed: %s.'):format(reportId, Config.Force.ReviewFindings[finding]), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:checkoutVehicle', function(data)
    local src = source
    if not rateAllowed(src, 'fleet') then return end
    local allowed, info = isLaw(src, true)
    if not allowed then return end
    local active = tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM dpn_le_fleet_checkouts WHERE officer_cid = ? AND status = 'active'", { info.citizenid })) or 0
    if active >= Config.Fleet.MaxActivePerOfficer then return notify(src, 'Return your current fleet vehicle first.', 'error') end
    data = type(data) == 'table' and data or {}
    local entity = getNetworkVehicle(data.vehicleNetId)
    if not entity then return notify(src, 'You must be in or near a valid fleet vehicle.', 'error') end
    local snapshot = vehicleSnapshot(entity)
    if distance(playerCoords(src), snapshot.coords) > Config.Fleet.CheckoutDistance then return notify(src, 'Fleet vehicle is too far away.', 'error') end
    if Config.Fleet.RequireEmergencyClass and not Config.Fleet.AllowedVehicleClasses[GetVehicleClass(entity)] then return notify(src, 'This is not an authorized fleet vehicle.', 'error') end
    local checkoutId = makeId('FLEET')
    local fuel = clamp(data.fuel, 0, 100)
    MySQL.insert([[INSERT INTO dpn_le_fleet_checkouts (checkout_id, officer_cid, officer_name, vehicle_plate, vehicle_model, vehicle_net_id,
        starting_body, starting_engine, starting_fuel, status, checked_out_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', NOW())]], {
        checkoutId, info.citizenid, info.name, snapshot.plate, snapshot.model, snapshot.netId, snapshot.body, snapshot.engine, fuel
    })
    audit(src, 'FLEET_CHECKOUT', checkoutId, snapshot)
    networkPublish('fleet_checkout', { title='Fleet Vehicle Checked Out', message=('%s checked out %s.'):format(info.name, snapshot.plate), severity=5, checkoutId=checkoutId, plate=snapshot.plate, model=snapshot.model, suppressRouting=true })
    notify(src, ('Fleet vehicle %s checked out under %s.'):format(snapshot.plate, checkoutId), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:returnVehicle', function(data)
    local src = source
    local allowed, info = isLaw(src, true)
    if not allowed then return end
    data = type(data) == 'table' and data or {}
    local checkoutId = clean(data.checkoutId, 64)
    local row = MySQL.single.await("SELECT * FROM dpn_le_fleet_checkouts WHERE checkout_id = ? AND status = 'active'", { checkoutId })
    if not row or (row.officer_cid ~= info.citizenid and not isSupervisor(src)) then return notify(src, 'Active fleet checkout not found.', 'error') end
    local entity = getNetworkVehicle(data.vehicleNetId)
    local snapshot = entity and vehicleSnapshot(entity) or { plate=row.vehicle_plate, body=clamp(data.body, 0, 1000), engine=clamp(data.engine, -4000, 1000) }
    if snapshot.plate ~= row.vehicle_plate and not isSupervisor(src) then return notify(src, 'Return the same vehicle that was checked out.', 'error') end
    local fuel = clamp(data.fuel, 0, 100)
    local notes = clean(data.damageNotes, 2500)
    MySQL.update([[UPDATE dpn_le_fleet_checkouts SET ending_body=?, ending_engine=?, ending_fuel=?, damage_notes=?, status='returned', returned_at=NOW() WHERE checkout_id=?]], {
        snapshot.body, snapshot.engine, fuel, notes, checkoutId
    })
    local bodyDelta = (tonumber(row.starting_body) or 1000) - (tonumber(snapshot.body) or 1000)
    if bodyDelta >= Config.Fleet.DamageReportThreshold then createSupervisorTask('fleet_damage', checkoutId, ('Fleet damage review for %s'):format(row.vehicle_plate), 2, info.job, { bodyDelta=bodyDelta, notes=notes }) end
    audit(src, 'FLEET_RETURN', checkoutId, { body=snapshot.body, engine=snapshot.engine, fuel=fuel, damage=bodyDelta, notes=notes })
    networkPublish(bodyDelta >= Config.Fleet.DamageReportThreshold and 'emergency_vehicle_oos' or 'fleet_return', { title=bodyDelta >= Config.Fleet.DamageReportThreshold and 'Fleet Damage Review Required' or 'Fleet Vehicle Returned', message=('%s returned %s with %.0f body damage delta.'):format(info.name, row.vehicle_plate, bodyDelta), severity=bodyDelta >= Config.Fleet.DamageReportThreshold and 3 or 5, checkoutId=checkoutId, plate=row.vehicle_plate, bodyDamage=bodyDelta, notes=notes, suppressRouting=true })
    notify(src, ('Fleet checkout %s returned.'):format(checkoutId), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:checkoutArmory', function(data)
    local src = source
    if not rateAllowed(src, 'armory') then return end
    local allowed, info = isLaw(src, true)
    if not allowed then return end
    data = type(data) == 'table' and data or {}
    local catalogId = clean(data.catalogId, 80)
    local item = Config.Armory.Catalog[catalogId]
    local quantity = math.floor(clamp(data.quantity, 1, Config.Armory.MaximumQuantity))
    if not item then return notify(src, 'Invalid armory item.', 'error') end
    if not hasCertification(info.citizenid, item.cert) then return notify(src, ('Valid certification required: %s'):format(item.cert), 'error') end
    local player = QBCore.Functions.GetPlayer(src)
    if not Config.Armory.TrackOnly then
        local added = player and player.Functions.AddItem(item.item, quantity, false, { dpnIssued=true, issuedAt=os.time() })
        if not added then return notify(src, 'Inventory could not receive this equipment.', 'error') end
    end
    local checkoutId = makeId('ARM')
    local serial = clean(data.serialNumber, 100)
    MySQL.insert([[INSERT INTO dpn_le_armory_checkouts (checkout_id, officer_cid, officer_name, catalog_id, item_name, item_label, quantity, serial_number, status, issued_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active', NOW())]], {
        checkoutId, info.citizenid, info.name, catalogId, item.item, item.label, quantity, serial ~= '' and serial or nil
    })
    audit(src, 'ARMORY_CHECKOUT', checkoutId, { catalogId=catalogId, quantity=quantity, serial=serial })
    networkPublish('armory_checkout', { title='Armory Equipment Issued', message=('%s was issued %s x%s.'):format(info.name, item.label, quantity), severity=5, checkoutId=checkoutId, catalogId=catalogId, serial=serial, suppressRouting=true })
    notify(src, ('%s issued under %s.'):format(item.label, checkoutId), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:returnArmory', function(checkoutId)
    local src = source
    local allowed, info = isLaw(src, true)
    if not allowed then return end
    checkoutId = clean(checkoutId, 64)
    local row = MySQL.single.await("SELECT * FROM dpn_le_armory_checkouts WHERE checkout_id = ? AND status = 'active'", { checkoutId })
    if not row or (row.officer_cid ~= info.citizenid and not isSupervisor(src)) then return notify(src, 'Active armory checkout not found.', 'error') end
    local player = QBCore.Functions.GetPlayer(src)
    if not Config.Armory.TrackOnly and row.officer_cid == info.citizenid then
        local removed = player and player.Functions.RemoveItem(row.item_name, tonumber(row.quantity) or 1)
        if not removed then return notify(src, 'Return the issued item to your inventory before checking it in.', 'error') end
    end
    MySQL.update("UPDATE dpn_le_armory_checkouts SET status='returned', returned_at=NOW() WHERE checkout_id=?", { checkoutId })
    audit(src, 'ARMORY_RETURN', checkoutId, { item=row.item_name, quantity=row.quantity })
    networkPublish('armory_return', { title='Armory Equipment Returned', message=('%s returned %s x%s.'):format(info.name, row.item_label, row.quantity), severity=5, checkoutId=checkoutId, item=row.item_name, suppressRouting=true })
    notify(src, ('Armory checkout %s returned.'):format(checkoutId), 'success')
    syncAndRefresh(src)
end)

RegisterNetEvent('dpn-le-operations:server:completeTask', function(taskId)
    local src = source
    if not isSupervisor(src) and not isJudge(src) then return end
    taskId = clean(taskId, 64)
    MySQL.update("UPDATE dpn_le_supervisor_tasks SET status='completed', completed_at=NOW() WHERE task_id=? AND status='open'", { taskId })
    audit(src, 'SUPERVISOR_TASK_COMPLETED', taskId, {})
    syncAndRefresh(src)
end)

AddEventHandler('dpn-le-operations:server:coreAction', function(officerSrc, action, target, details)
    local info = playerInfo(tonumber(officerSrc) or 0)
    if not info or not ActiveShifts[info.citizenid] then return end
    if action == 'CITATION' then incrementShift(info.citizenid, 'citations', 1)
    elseif action == 'BOOKING' then incrementShift(info.citizenid, 'arrests', 1)
    elseif action == 'SEARCH' then incrementShift(info.citizenid, 'searches', 1)
    end
end)

AddEventHandler('dpn-dispatch:server:unitAssignedInternal', function(sourceId)
    local info = playerInfo(sourceId)
    if info then incrementShift(info.citizenid, 'calls_handled', 1) end
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(src)
    src = tonumber(src)
    if not src then return end
    SetTimeout(250, function()
        local info = playerInfo(src)
        if not info then return end
        local shift = ActiveShifts[info.citizenid]
        if shift and (info.department ~= 'law' or not info.onDuty) then
            leaveOperationalUnit(info, 'duty_ended')
            ActiveShifts[info.citizenid] = nil
            MySQL.update("UPDATE dpn_le_shifts SET ended_at=NOW(), end_reason='duty_ended' WHERE shift_id=?", { shift.shiftId })
            audit(src, 'SHIFT_AUTO_ENDED', shift.shiftId, { reason='duty_ended' })
            notify(src, 'Your DPN operational shift ended because you went off duty or changed jobs.', 'primary')
            broadcastRefresh()
        end
    end)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local info = playerInfo(src)
    if not info then
        for identifier, shift in pairs(ActiveShifts) do
            if shift.source == src then
                info = { source=src, citizenid=identifier, name=shift.officerName, job=shift.job, grade=shift.grade, department='law' }
                break
            end
        end
    end
    RateLimits[src] = nil
    if not info then return end
    leaveOperationalUnit(info, 'disconnect')
    local shift = ActiveShifts[info.citizenid]
    if shift then
        ActiveShifts[info.citizenid] = nil
        MySQL.update("UPDATE dpn_le_shifts SET ended_at=NOW(), end_reason=? WHERE shift_id=?", { 'disconnect', shift.shiftId })
        audit(0, 'SHIFT_AUTO_ENDED', shift.shiftId, { officer=info.name, reason=reason })
    end
    for pursuitId, pursuit in pairs(ActivePursuits) do
        if pursuit.units[info.citizenid] then
            pursuit.units[info.citizenid] = nil
            if pursuit.primaryCid == info.citizenid then
                createSupervisorTask('pursuit_primary_lost', pursuitId, ('Primary unit disconnected from pursuit %s'):format(pursuitId), 1, info.job, {})
            end
        end
    end
    broadcastRefresh()
end)

CreateThread(function()
    Wait(1000)
    MySQL.update("UPDATE dpn_le_shifts SET ended_at=NOW(), end_reason='server_restart' WHERE ended_at IS NULL", {})
    MySQL.update("UPDATE dpn_le_operational_units SET status='closed', closed_at=NOW() WHERE status='active'", {})
    MySQL.update("UPDATE dpn_le_pursuits SET status='interrupted', ended_at=NOW(), termination_notes=CONCAT(COALESCE(termination_notes,''), '\nServer restart interrupted this pursuit.') WHERE status='active'", {})
    MySQL.update("UPDATE dpn_le_warrants SET status='expired', updated_at=NOW() WHERE status='approved' AND expires_at IS NOT NULL AND expires_at <= NOW()", {})
    debugPrint('Advanced Operations Center initialized.')
end)

CreateThread(function()
    while true do
        Wait(60000)
        MySQL.update("UPDATE dpn_le_warrants SET status='expired', updated_at=NOW() WHERE status='approved' AND expires_at IS NOT NULL AND expires_at <= NOW()", {})
        local current = os.time()
        for src, actions in pairs(RateLimits) do
            local keep = false
            for _, bucket in pairs(actions) do if current - bucket.started < Config.Security.RateWindowSeconds * 3 then keep = true break end end
            if not keep then RateLimits[src] = nil end
        end
        for identifier, stamp in pairs(WeaponDraftCooldown) do if current - stamp > Config.Force.DischargeCooldownSeconds * 3 then WeaponDraftCooldown[identifier] = nil end end
    end
end)

exports('GetActiveShifts', function() return ActiveShifts end)
exports('GetOperationalUnits', function() return serializeUnits() end)
exports('GetActivePursuits', function() return serializePursuits() end)
exports('GetOfficerUnit', function(identifier) local unitId=UnitByMember[identifier]; return unitId and OperationalUnits[unitId] or nil end)
exports('HasActiveShift', function(identifier) return ActiveShifts[identifier] ~= nil end)
exports('CreateSupervisorTask', createSupervisorTask)
exports('CreateForceReport', function(sourceId, data) return createForceReport(tonumber(sourceId) or 0, data, false) end)
exports('CreateOperationalAudit', function(sourceId, action, referenceId, details) audit(tonumber(sourceId) or 0, action, referenceId, details); return true end)
