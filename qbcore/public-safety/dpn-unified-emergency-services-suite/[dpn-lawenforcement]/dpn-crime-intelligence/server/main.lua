local QBCore = exports['qb-core']:GetCoreObject()

local function clean(value, maxLength)
    local text = tostring(value or ''):gsub('[%z\1-\8\11\12\14-\31]', '')
    if #text > maxLength then text = text:sub(1, maxLength) end
    return text
end

local function playerData(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return nil end
    local data = player.PlayerData
    local charinfo = data.charinfo or {}
    local grade = data.job and data.job.grade or 0
    if type(grade) == 'table' then grade = grade.level or grade.grade or 0 end
    return {
        citizenid = data.citizenid,
        name = (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1'),
        job = data.job and data.job.name or 'unemployed',
        grade = tonumber(grade) or 0,
        onDuty = data.job and data.job.onduty == true,
        isBoss = data.job and data.job.isboss == true
    }
end

local function allowed(src, supervisor)
    if IsPlayerAceAllowed(src, supervisor and 'dpn.intel.supervisor' or 'dpn.intel') then return true, playerData(src) end
    local info = playerData(src)
    if not info or not Config.AllowedJobs[info.job] then return false, info end
    if Config.RequireDuty and not info.onDuty then return false, info end
    if supervisor and not info.isBoss and info.grade < (Config.SupervisorGrades[info.job] or 999) then return false, info end
    return true, info
end

local function notify(src, message, kind)
    TriggerClientEvent('QBCore:Notify', src, message, kind or 'primary')
end

local function audit(src, action, details)
    local info = playerData(src) or { citizenid='SYSTEM', name='DPN System' }
    MySQL.insert('INSERT INTO dpn_intel_audit (officer_cid, officer_name, action, details) VALUES (?, ?, ?, ?)', {
        info.citizenid, info.name, action, json.encode(details or {})
    })
end

local function decode(value, fallback)
    if type(value) == 'table' then return value end
    local ok, result = pcall(json.decode, value or '')
    return ok and result or fallback
end

local function riskLevel(score)
    for _, level in ipairs(Config.RiskLevels) do
        if score >= level.minimum then return level end
    end
    return Config.RiskLevels[#Config.RiskLevels]
end

local function getRiskProfile(citizenid)
    local bookings = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM dpn_le_bookings WHERE citizenid = ?', { citizenid })) or 0
    local citations = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM dpn_le_citations WHERE citizenid = ?', { citizenid })) or 0
    local watchlist = tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM dpn_intel_watchlists WHERE subject_type='person' AND subject_key=? AND active=1", { citizenid })) or 0
    local linkedReports = tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM dpn_intel_links WHERE entity_type='person' AND entity_key=?", { citizenid })) or 0
    local activeWarrants = tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM dpn_le_warrants WHERE subject_type='person' AND subject_key=? AND status='approved' AND (expires_at IS NULL OR expires_at > NOW())", { citizenid:upper() })) or 0
    local criticalWarrants = tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM dpn_le_warrants WHERE subject_type='person' AND subject_key=? AND status='approved' AND risk_level='critical' AND (expires_at IS NULL OR expires_at > NOW())", { citizenid:upper() })) or 0
    local score = math.min(100,
        bookings * Config.RiskWeights.booking + citations * Config.RiskWeights.citation +
        watchlist * Config.RiskWeights.watchlist + linkedReports * Config.RiskWeights.linkedReport +
        activeWarrants * Config.RiskWeights.activeWarrant + criticalWarrants * Config.RiskWeights.criticalWarrant)
    local level = riskLevel(score)
    return { score=score, level=level.label, color=level.color, bookings=bookings, citations=citations, watchlists=watchlist, linkedReports=linkedReports, activeWarrants=activeWarrants, criticalWarrants=criticalWarrants }
end

local function getDashboard(src)
    local reports = MySQL.query.await('SELECT report_id, title, classification, status, created_by_name, created_at, updated_at FROM dpn_intel_reports ORDER BY updated_at DESC LIMIT 30', {}) or {}
    local watchlists = MySQL.query.await('SELECT * FROM dpn_intel_watchlists WHERE active=1 ORDER BY priority ASC, created_at DESC LIMIT 50', {}) or {}
    local links = MySQL.query.await('SELECT * FROM dpn_intel_links ORDER BY created_at DESC LIMIT 100', {}) or {}
    TriggerClientEvent('dpn-crime-intelligence:client:data', src, { reports=reports, watchlists=watchlists, links=links, supervisor=select(1, allowed(src, true)) })
end

RegisterNetEvent('dpn-crime-intelligence:server:open', function()
    local src = source
    if not allowed(src, false) then return notify(src, 'Crime-intelligence access denied.', 'error') end
    getDashboard(src)
end)

RegisterNetEvent('dpn-crime-intelligence:server:search', function(query)
    local src = source
    if not allowed(src, false) then return end
    query = clean(query, 64):gsub('^%s*(.-)%s*$', '%1')
    if #query < 2 then return notify(src, 'Enter at least two characters.', 'error') end
    local wildcard = '%' .. query .. '%'

    local people = MySQL.query.await([[
        SELECT citizenid, charinfo, metadata FROM players
        WHERE citizenid LIKE ?
           OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ?
           OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?
        LIMIT ?]], { wildcard, wildcard, wildcard, Config.MaxSearchResults }) or {}

    local personResults = {}
    for _, row in ipairs(people) do
        local charinfo = decode(row.charinfo, {})
        personResults[#personResults + 1] = {
            type='person', citizenid=row.citizenid,
            name=(('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1'),
            birthdate=charinfo.birthdate, nationality=charinfo.nationality, phone=charinfo.phone,
            risk=getRiskProfile(row.citizenid)
        }
    end

    local vehicles = MySQL.query.await('SELECT citizenid, plate, vehicle, garage, state FROM player_vehicles WHERE plate LIKE ? OR vehicle LIKE ? LIMIT ?', { wildcard, wildcard, Config.MaxSearchResults }) or {}
    for _, vehicle in ipairs(vehicles) do
        vehicle.type = 'vehicle'
        vehicle.plate = clean(vehicle.plate, 16):upper():gsub('^%s*(.-)%s*$', '%1')
        local watch = MySQL.single.await("SELECT reason, priority FROM dpn_intel_watchlists WHERE subject_type='vehicle' AND subject_key=? AND active=1 LIMIT 1", { vehicle.plate })
        local warrant = MySQL.single.await("SELECT warrant_id, warrant_type, charges, risk_level FROM dpn_le_warrants WHERE subject_type='vehicle' AND subject_key=? AND status='approved' AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY created_at DESC LIMIT 1", { vehicle.plate })
        vehicle.flagged = watch ~= nil or warrant ~= nil
        vehicle.reason = warrant and (('Active %s: %s'):format(warrant.warrant_type, warrant.charges)) or (watch and watch.reason or nil)
        vehicle.priority = warrant and (warrant.risk_level == 'critical' and 1 or 2) or (watch and watch.priority or nil)
        vehicle.warrant = warrant
    end

    audit(src, 'SEARCH', { query=query, people=#personResults, vehicles=#vehicles })
    TriggerClientEvent('dpn-crime-intelligence:client:searchResults', src, { people=personResults, vehicles=vehicles, query=query })
end)

RegisterNetEvent('dpn-crime-intelligence:server:createReport', function(data)
    local src = source
    local ok, info = allowed(src, false)
    if not ok or type(data) ~= 'table' then return end
    local reportId = ('INT-%s-%04d'):format(os.date('%Y%m%d%H%M%S'), math.random(1000,9999))
    local title = clean(data.title or 'Untitled Intelligence Report', Config.MaxTitleLength)
    local narrative = clean(data.narrative or '', Config.MaxReportLength)
    local classification = clean(data.classification or 'law-enforcement-sensitive', 64)
    MySQL.insert('INSERT INTO dpn_intel_reports (report_id, title, narrative, classification, status, created_by, created_by_name, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        reportId, title, narrative, classification, 'active', info.citizenid, info.name, json.encode(type(data.metadata)=='table' and data.metadata or {})
    })
    audit(src, 'CREATE_REPORT', { reportId=reportId, title=title })
    notify(src, ('Intelligence report %s created.'):format(reportId), 'success')
    getDashboard(src)
end)

RegisterNetEvent('dpn-crime-intelligence:server:addWatchlist', function(data)
    local src = source
    local ok, info = allowed(src, true)
    if not ok or type(data) ~= 'table' then return notify(src, 'Supervisor authorization required.', 'error') end
    local subjectType = data.subjectType == 'vehicle' and 'vehicle' or 'person'
    local subjectKey = clean(data.subjectKey, 80):upper()
    local label = clean(data.label or subjectKey, 160)
    local reason = clean(data.reason or 'Intelligence watchlist', 1000)
    local priority = math.max(1, math.min(4, math.floor(tonumber(data.priority) or 2)))
    if subjectKey == '' then return end
    MySQL.query([[INSERT INTO dpn_intel_watchlists (subject_type, subject_key, label, reason, priority, active, created_by, created_by_name)
        VALUES (?, ?, ?, ?, ?, 1, ?, ?)
        ON DUPLICATE KEY UPDATE label=VALUES(label), reason=VALUES(reason), priority=VALUES(priority), active=1, created_by=VALUES(created_by), created_by_name=VALUES(created_by_name), updated_at=NOW()]], {
        subjectType, subjectKey, label, reason, priority, info.citizenid, info.name
    })
    audit(src, 'ADD_WATCHLIST', { subjectType=subjectType, subjectKey=subjectKey, priority=priority })
    notify(src, ('%s added to the intelligence watchlist.'):format(label), 'success')
    getDashboard(src)
end)

RegisterNetEvent('dpn-crime-intelligence:server:clearWatchlist', function(id)
    local src = source
    if not allowed(src, true) then return end
    MySQL.update('UPDATE dpn_intel_watchlists SET active=0, updated_at=NOW() WHERE id=?', { tonumber(id) })
    audit(src, 'CLEAR_WATCHLIST', { id=id })
    getDashboard(src)
end)

RegisterNetEvent('dpn-crime-intelligence:server:addLink', function(data)
    local src = source
    local ok, info = allowed(src, false)
    if not ok or type(data) ~= 'table' then return end
    local reportId = clean(data.reportId, 64)
    local entityType = clean(data.entityType, 32)
    local entityKey = clean(data.entityKey, 80):upper()
    local relationship = clean(data.relationship or 'associated', 128)
    MySQL.insert('INSERT INTO dpn_intel_links (report_id, entity_type, entity_key, relationship, created_by, created_by_name) VALUES (?, ?, ?, ?, ?, ?)', {
        reportId, entityType, entityKey, relationship, info.citizenid, info.name
    })
    audit(src, 'ADD_LINK', data)
    getDashboard(src)
end)

local function intelligenceAlert(payload)
    payload = type(payload) == 'table' and payload or {}
    if GetResourceState(Config.DispatchResource) == 'started' then
        exports[Config.DispatchResource]:CreateDispatchCall({
            type='bolo', title=clean(payload.title or 'Crime Intelligence Alert', 128),
            description=clean(payload.description or payload.message or payload.reason or 'Intelligence watchlist hit.', 1000),
            priority=tonumber(payload.priority) or 2, coords=payload.coords,
            departments={'law','dispatch'}, metadata={ intelligence=true, subject=payload.subject }
        }, 0)
    end
end

RegisterNetEvent('dpn-crime-intelligence:server:alert', function(payload)
    local src = source
    if src > 0 and not allowed(src, false) then return end
    intelligenceAlert(payload)
end)

exports('CreateIntelAlert', intelligenceAlert)
exports('GetRiskProfile', getRiskProfile)
exports('IsWatchlisted', function(subjectType, subjectKey)
    return MySQL.single.await('SELECT * FROM dpn_intel_watchlists WHERE subject_type=? AND subject_key=? AND active=1 LIMIT 1', { subjectType, clean(subjectKey,80):upper() })
end)
