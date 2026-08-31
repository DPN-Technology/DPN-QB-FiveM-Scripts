local QBCore = exports[Config.Framework.resource]:GetCoreObject()

local function dbg(...)
    if Config.Debug then
        print('^3[dpn-mdt]^7', ...)
    end
end

local function encode(value)
    return json.encode(value or {})
end

local function decode(value)
    if not value or value == '' then return {} end
    local ok, result = pcall(json.decode, value)
    if ok and result then return result end
    return {}
end

local function dbError(kind, err)
    print(('^1[dpn-mdt] %s database error: %s^7'):format(kind, tostring(err)))
end

local function dbReady()
    return MySQL ~= nil
end

local function dbQuery(sql, params)
    if not dbReady() or not MySQL.query or not MySQL.query.await then
        dbError('query', 'oxmysql is not ready')
        return {}
    end
    local ok, result = pcall(MySQL.query.await, sql, params or {})
    if not ok then dbError('query', result); return {} end
    return result or {}
end

local function dbSingle(sql, params)
    if not dbReady() or not MySQL.single or not MySQL.single.await then
        dbError('single', 'oxmysql is not ready')
        return nil
    end
    local ok, result = pcall(MySQL.single.await, sql, params or {})
    if not ok then dbError('single', result); return nil end
    return result
end

local function dbScalar(sql, params)
    if not dbReady() or not MySQL.scalar or not MySQL.scalar.await then
        dbError('scalar', 'oxmysql is not ready')
        return 0
    end
    local ok, result = pcall(MySQL.scalar.await, sql, params or {})
    if not ok then dbError('scalar', result); return 0 end
    return result or 0
end

local function dbInsert(sql, params)
    if not dbReady() or not MySQL.insert or not MySQL.insert.await then
        dbError('insert', 'oxmysql is not ready')
        return nil
    end
    local ok, result = pcall(MySQL.insert.await, sql, params or {})
    if not ok then dbError('insert', result); return nil end
    return result
end

local function dbUpdate(sql, params)
    if not dbReady() or not MySQL.update or not MySQL.update.await then
        dbError('update', 'oxmysql is not ready')
        return 0
    end
    local ok, result = pcall(MySQL.update.await, sql, params or {})
    if not ok then dbError('update', result); return 0 end
    return result or 0
end




-- Advanced QBCore database compatibility layer. This lets the MDT pull real player/vehicle data
-- without crashing when a server has slightly different QBCore column sets.
local DPNDB = Config.Database or {}
DPNDB.players = DPNDB.players or 'players'
DPNDB.vehicles = DPNDB.vehicles or 'player_vehicles'
DPNDB.apartments = DPNDB.apartments or 'apartments'
DPNDB.houses = DPNDB.houses or 'player_houses'
DPNDB.phoneVehicles = DPNDB.phoneVehicles or 'phone_vehicles'

local columnCache = {}
local tableCache = {}

local function ident(value)
    value = tostring(value or '')
    if value:match('^[%w_]+$') then
        return ('`%s`'):format(value)
    end
    error(('Unsafe SQL identifier: %s'):format(value))
end

local function qcol(alias, column)
    if alias and alias ~= '' then
        return ident(alias) .. '.' .. ident(column)
    end
    return ident(column)
end

local function tableExists(tableName)
    if tableCache[tableName] ~= nil then return tableCache[tableName] end
    local count = dbScalar('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { tableName })
    tableCache[tableName] = (tonumber(count) or 0) > 0
    return tableCache[tableName]
end

local function getColumns(tableName)
    if columnCache[tableName] then return columnCache[tableName] end
    local rows = dbQuery('SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { tableName }) or {}
    local cols = {}
    for _, row in ipairs(rows) do
        cols[row.COLUMN_NAME] = true
    end
    columnCache[tableName] = cols
    return cols
end

local function hasColumn(tableName, column)
    return getColumns(tableName)[column] == true
end

local function selectList(tableName, wanted)
    local out = {}
    for _, col in ipairs(wanted) do
        if hasColumn(tableName, col) then
            out[#out + 1] = ident(col)
        end
    end
    if #out == 0 then return nil end
    return table.concat(out, ', ')
end

local function whereLike(tableName, wanted, searchValue, alias)
    local clauses, params = {}, {}
    for _, col in ipairs(wanted) do
        if hasColumn(tableName, col) then
            clauses[#clauses + 1] = qcol(alias, col) .. ' LIKE ?'
            params[#params + 1] = searchValue
        end
    end
    if #clauses == 0 then
        return '1=1', params
    end
    return '(' .. table.concat(clauses, ' OR ') .. ')', params
end

local function limitNumber(value, defaultValue, maxValue)
    local num = tonumber(value) or defaultValue or 50
    if num < 1 then num = 1 end
    if maxValue and num > maxValue then num = maxValue end
    return math.floor(num)
end

local function displayNameFromCharinfo(charinfo, fallback)
    charinfo = charinfo or {}
    local first = charinfo.firstname or charinfo.firstName or charinfo.first_name or ''
    local last = charinfo.lastname or charinfo.lastName or charinfo.last_name or ''
    local full = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
    if full == '' then return fallback or 'Unknown Citizen' end
    return full
end

local function getLivePlayerByCitizenid(citizenid)
    if not QBCore or not QBCore.Functions or not QBCore.Functions.GetQBPlayers then return nil, nil end
    local players = QBCore.Functions.GetQBPlayers()
    for src, player in pairs(players or {}) do
        if player and player.PlayerData and player.PlayerData.citizenid == citizenid then
            return src, player
        end
    end
    return nil, nil
end

local function normalizeLicenses(metadata)
    metadata = metadata or {}
    local licenses = metadata.licences or metadata.licenses or {}
    if type(licenses) ~= 'table' then licenses = {} end
    return licenses
end

local function countTable(value)
    if type(value) ~= 'table' then return 0 end
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function normalizePlayerRow(row)
    row = row or {}
    row.charinfo = type(row.charinfo) == 'table' and row.charinfo or decode(row.charinfo)
    row.job = type(row.job) == 'table' and row.job or decode(row.job)
    row.gang = type(row.gang) == 'table' and row.gang or decode(row.gang)
    row.metadata = type(row.metadata) == 'table' and row.metadata or decode(row.metadata)
    row.money = type(row.money) == 'table' and row.money or decode(row.money)
    row.position = type(row.position) == 'table' and row.position or decode(row.position)
    local inv = decode(row.inventory)

    local src, live = getLivePlayerByCitizenid(row.citizenid)
    if live and live.PlayerData then
        local pd = live.PlayerData
        row.charinfo = pd.charinfo or row.charinfo
        row.job = pd.job or row.job
        row.gang = pd.gang or row.gang
        row.metadata = pd.metadata or row.metadata
        row.money = pd.money or row.money
        row.position = pd.position or row.position
        row.source = src
        row.online = true
        row.onlineName = GetPlayerName(src)
        row.ping = GetPlayerPing(src)
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            row.liveCoords = { x = coords.x, y = coords.y, z = coords.z }
        end
    else
        row.online = false
    end

    row.name = displayNameFromCharinfo(row.charinfo, row.name)
    row.phone = row.charinfo.phone or row.charinfo.phone_number or row.phone_number or row.metadata.phone or ''
    row.birthdate = row.charinfo.birthdate or row.charinfo.dob or ''
    row.gender = row.charinfo.gender or row.charinfo.sex or ''
    row.nationality = row.charinfo.nationality or ''
    row.account = row.charinfo.account or row.account or ''
    row.cash = tonumber(row.money.cash) or 0
    row.bank = tonumber(row.money.bank) or 0
    row.crypto = tonumber(row.money.crypto) or 0
    row.licenses = normalizeLicenses(row.metadata)
    row.licenseCount = countTable(row.licenses)
    row.bloodtype = row.metadata.bloodtype or row.metadata.blood_type or ''
    row.fingerprint = row.metadata.fingerprint or ''
    row.callsign = row.metadata.callsign or ''
    row.inventoryCount = countTable(inv)
    row.inventory = nil -- keep the NUI fast and avoid sending full inventories by default
    return row
end

local function vehicleStateLabel(value)
    local map = { [0] = 'Out', [1] = 'Garaged', [2] = 'Impounded', [3] = 'Seized' }
    return map[tonumber(value)] or tostring(value or 'Unknown')
end

local function normalizeVehicleRow(row)
    row = row or {}
    row.mods = type(row.mods) == 'table' and row.mods or decode(row.mods)
    row.status = type(row.status) == 'table' and row.status or decode(row.status)
    row.charinfo = type(row.charinfo) == 'table' and row.charinfo or decode(row.charinfo)
    row.ownerName = displayNameFromCharinfo(row.charinfo, row.citizenid or 'Unknown Owner')
    row.model = row.vehicle or row.model or row.hash or 'unknown'
    row.stateLabel = vehicleStateLabel(row.state)
    row.fuel = tonumber(row.fuel) or tonumber(row.status.fuel) or nil
    row.engine = tonumber(row.engine) or tonumber(row.status.engine) or nil
    row.body = tonumber(row.body) or tonumber(row.status.body) or nil
    row.mileage = tonumber(row.drivingdistance) or tonumber(row.mileage) or tonumber(row.status.mileage) or nil
    row.finance = {
        balance = tonumber(row.balance) or 0,
        paymentamount = tonumber(row.paymentamount) or 0,
        paymentsleft = tonumber(row.paymentsleft) or 0,
        financetime = tonumber(row.financetime) or 0
    }
    return row
end

local function getPlayerSelectList()
    return selectList(DPNDB.players, {
        'id', 'citizenid', 'cid', 'license', 'name', 'charinfo', 'job', 'gang', 'money', 'metadata',
        'position', 'inventory', 'phone_number', 'last_updated', 'last_logged_out', 'created_at'
    })
end

local function getVehicleSelectList(alias)
    local tableName = DPNDB.vehicles
    local cols = {
        'id', 'license', 'citizenid', 'vehicle', 'hash', 'mods', 'plate', 'fakeplate', 'garage', 'fuel',
        'engine', 'body', 'state', 'depotprice', 'drivingdistance', 'status', 'balance',
        'paymentamount', 'paymentsleft', 'financetime'
    }
    local out = {}
    for _, col in ipairs(cols) do
        if hasColumn(tableName, col) then
            out[#out + 1] = qcol(alias, col)
        end
    end
    if #out == 0 then return nil end
    return table.concat(out, ', ')
end

local function getCitizenSummary(citizenid)
    if not citizenid or citizenid == '' or not tableExists(DPNDB.players) then return nil end
    local selectCols = getPlayerSelectList()
    if not selectCols then return nil end
    local row = dbSingle(('SELECT %s FROM %s WHERE `citizenid` = ? LIMIT 1'):format(selectCols, ident(DPNDB.players)), { citizenid })
    if not row then return nil end
    return normalizePlayerRow(row)
end

local function countWhere(tableName, column, value, whereExtra)
    if not tableExists(tableName) or not hasColumn(tableName, column) then return 0 end
    local sql = ('SELECT COUNT(*) FROM %s WHERE %s = ?'):format(ident(tableName), ident(column))
    if whereExtra then sql = sql .. ' ' .. whereExtra end
    return tonumber(dbScalar(sql, { value })) or 0
end

local function countLike(tableName, column, value, whereExtra)
    if not tableExists(tableName) or not hasColumn(tableName, column) then return 0 end
    local sql = ('SELECT COUNT(*) FROM %s WHERE %s LIKE ?'):format(ident(tableName), ident(column))
    if whereExtra then sql = sql .. ' ' .. whereExtra end
    return tonumber(dbScalar(sql, { '%' .. tostring(value or '') .. '%' })) or 0
end

local function hasValue(list, value)
    if not list then return false end
    for _, v in pairs(list) do
        if v == value then return true end
    end
    return false
end

local function hasAce(src, aceList)
    if not aceList then return false end
    for _, ace in pairs(aceList) do
        if IsPlayerAceAllowed(src, ace) or IsPlayerAceAllowed(src, 'command.' .. ace) or IsPlayerAceAllowed(src, 'group.' .. ace) then
            return true
        end
    end
    return false
end

local function getPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

local function getJobData(player)
    local job = player and player.PlayerData and player.PlayerData.job or {}
    return {
        name = job.name or 'unemployed',
        label = job.label or job.name or 'Unemployed',
        type = job.type,
        onduty = job.onduty == true,
        grade = tonumber(job.grade and (job.grade.level or job.grade.grade or job.grade)) or 0,
        gradeName = job.grade and (job.grade.name or '') or ''
    }
end

local function getDepartmentForSource(src)
    local player = getPlayer(src)
    if not player then return nil end
    local job = getJobData(player)

    for key, data in pairs(Config.Departments) do
        if hasValue(data.jobs, job.name) or (job.type and job.type == key) then
            return key, data, job
        end
        if key == 'mib' and hasAce(src, data.ace or Config.MIB.allowedAce) then
            return key, data, job
        end
    end

    if hasAce(src, Config.MIB.allowedAce) then
        return 'mib', Config.Departments.mib, job
    end

    return nil, nil, job
end

local function isAuthorized(src)
    local department, data, job = getDepartmentForSource(src)
    if not department then return false, nil, job end
    if Config.OnlyShowOnDuty and department ~= 'mib' and not job.onduty then
        return false, department, job
    end
    return true, department, job, data
end

local function getContext(src)
    local authorized, department, job, data = isAuthorized(src)
    local player = getPlayer(src)
    if not authorized or not player then return nil end

    local charinfo = player.PlayerData.charinfo or {}
    return {
        source = src,
        citizenid = player.PlayerData.citizenid,
        name = ((charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or 'User')),
        department = department,
        departmentLabel = data.label,
        theme = data.theme or department,
        job = job,
        modules = data.modules or {},
        permissions = Config.Permissions
    }
end

local function hasModule(src, module)
    local ctx = getContext(src)
    if not ctx then return false end
    return hasValue(ctx.modules, module)
end

local function hasGrade(src, minGrade)
    local ctx = getContext(src)
    if not ctx then return false end
    return (ctx.job.grade or 0) >= (minGrade or 0) or ctx.department == 'mib'
end

local function audit(src, category, action, target, details)
    local ctx = getContext(src)
    local actor = ctx and ctx.citizenid or ('src:' .. tostring(src))
    local actorName = ctx and ctx.name or GetPlayerName(src) or 'Console'
    dbInsert([[
        INSERT INTO dpn_mdt_audit_logs (actor_citizenid, actor_name, department, category, action, target, details, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
    ]], { actor, actorName, ctx and ctx.department or 'system', category, action, target or '', encode(details or {}) })
end

local function makeCallId(prefix)
    return (prefix or 'DPN') .. '-' .. os.date('%m%d') .. '-' .. math.random(1000, 9999)
end

local function normalizeDispatchCall(call)
    call = call or {}
    return {
        call_id = call.call_id or call.id or makeCallId('CALL'),
        code = call.code or call.callCode or '911',
        title = call.title or call.message or call.description or 'Emergency Call',
        description = call.description or call.message or '',
        priority = call.priority or 'normal',
        status = call.status or 'new',
        department = call.department or call.job or 'shared',
        caller = call.caller or call.callerName or 'Unknown',
        location = call.location or call.street or call.coordsText or 'Unknown Location',
        coords = call.coords or {},
        metadata = call.metadata or call.extra or {}
    }
end

local function createDispatchCall(call, src)
    local c = normalizeDispatchCall(call)
    local inserted = dbInsert([[
        INSERT INTO dpn_mdt_dispatch_calls
        (call_id, code, title, description, priority, status, department, caller, location, coords, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], { c.call_id, c.code, c.title, c.description, c.priority, c.status, c.department, c.caller, c.location, encode(c.coords), encode(c.metadata) })

    TriggerClientEvent('dpn-mdt:client:DispatchUpdated', -1, c)
    if Config.UnifiedNetwork.enabled then
        TriggerEvent(Config.UnifiedNetwork.incidentEvent, {
            sourceResource = 'dpn-mdt',
            type = 'dispatch',
            id = c.call_id,
            status = c.status,
            department = c.department,
            data = c
        })
    end
    if src then audit(src, 'dispatch', 'create_call', c.call_id, c) end
    return c.call_id, inserted
end

local function getDashboard(ctx)
    local dashboard = {}
    dashboard.activeDispatch = dbScalar("SELECT COUNT(*) FROM dpn_mdt_dispatch_calls WHERE status NOT IN ('cleared','cancelled')") or 0
    dashboard.activeWarrants = dbScalar("SELECT COUNT(*) FROM dpn_mdt_warrants WHERE status = 'active'") or 0
    dashboard.openCases = dbScalar("SELECT COUNT(*) FROM dpn_mdt_cases WHERE status NOT IN ('closed','archived')") or 0
    dashboard.reportsToday = dbScalar("SELECT COUNT(*) FROM dpn_mdt_reports WHERE DATE(created_at) = CURDATE()") or 0
    dashboard.chargesToday = dbScalar("SELECT COUNT(*) FROM dpn_mdt_citizen_charges WHERE DATE(created_at) = CURDATE()") or 0
    dashboard.department = ctx.departmentLabel
    dashboard.operator = ctx.name
    return dashboard
end

local function getOnlineRoster()
    local roster = {}
    local players = QBCore.Functions.GetQBPlayers()
    for src, player in pairs(players) do
        local department, deptData, job = getDepartmentForSource(src)
        if department then
            local charinfo = player.PlayerData.charinfo or {}
            roster[#roster + 1] = {
                source = src,
                citizenid = player.PlayerData.citizenid,
                name = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or 'User'),
                department = department,
                departmentLabel = deptData.label,
                theme = deptData.theme or department,
                job = job.name,
                grade = job.grade,
                gradeName = job.gradeName,
                onduty = job.onduty,
                callsign = player.PlayerData.metadata and player.PlayerData.metadata.callsign or (Config.Callsigns.defaultPrefix .. '-' .. tostring(src))
            }
        end
    end
    return roster
end



local function normalizeChargeCount(value)
    local count = tonumber(value) or 1
    if count < 1 then count = 1 end
    if count > 25 then count = 25 end
    return math.floor(count)
end

local function getChargeDefinition(item)
    item = item or {}
    local id = tonumber(item.id)
    local code = tostring(item.code or ''):upper():gsub('^%s+', ''):gsub('%s+$', '')
    if id and id > 0 then
        return dbSingle('SELECT * FROM dpn_mdt_charges WHERE id = ? LIMIT 1', { id })
    end
    if code ~= '' then
        return dbSingle('SELECT * FROM dpn_mdt_charges WHERE code = ? LIMIT 1', { code })
    end
    return nil
end

local function calculateChargeTotals(selected)
    local calculated = {}
    local totals = { fine = 0, jail = 0, points = 0 }
    if type(selected) ~= 'table' then selected = {} end

    for _, item in ipairs(selected) do
        local def = getChargeDefinition(item)
        if def then
            local count = normalizeChargeCount(item.count or item.quantity or 1)
            local fine = (tonumber(def.fine) or 0) * count
            local jail = (tonumber(def.jail) or 0) * count
            local points = (tonumber(def.points) or 0) * count
            totals.fine = totals.fine + fine
            totals.jail = totals.jail + jail
            totals.points = totals.points + points
            calculated[#calculated + 1] = {
                id = def.id,
                code = def.code,
                title = def.title,
                category = def.category,
                class = def.class,
                fine = tonumber(def.fine) or 0,
                jail = tonumber(def.jail) or 0,
                points = tonumber(def.points) or 0,
                count = count,
                totalFine = fine,
                totalJail = jail,
                totalPoints = points,
                description = def.description or ''
            }
        end
    end

    local chargeConfig = Config.Charging or {}
    totals.fine = math.min(totals.fine, tonumber(chargeConfig.maxFine or Config.Fines.maxAmount or 250000) or 250000)
    totals.jail = math.min(totals.jail, tonumber(chargeConfig.maxJail or 999) or 999)
    totals.points = math.min(totals.points, tonumber(chargeConfig.maxPoints or 99) or 99)
    return calculated, totals
end

local function emitChargingHooks(src, record, totals)
    local chargeConfig = Config.Charging or {}
    if chargeConfig.triggerFineEvent and (totals.fine or 0) > 0 then
        TriggerEvent(chargeConfig.fineEvent or 'dpn-mdt:server:FineIssued', src, record.citizenid, totals.fine, record)
    end
    if chargeConfig.triggerJailEvent and (totals.jail or 0) > 0 and record.charge_type == 'arrest' then
        TriggerEvent(chargeConfig.jailEvent or 'dpn-mdt:server:JailSentenceIssued', src, record.citizenid, totals.jail, record)
    end
    if chargeConfig.triggerCourtEvent and (record.charge_type == 'court_referral' or record.status == 'pending_court') then
        TriggerEvent(chargeConfig.courtEvent or 'dpn-mdt:server:CourtReferralCreated', src, record.citizenid, record)
    end
end

local function callback(name, cb)
    QBCore.Functions.CreateCallback('dpn-mdt:server:' .. name, function(source, callbackFn, payload)
        local ok, result = pcall(cb, source, payload or {})
        if not ok then
            print(('^1[dpn-mdt] callback %s failed: %s^7'):format(name, tostring(result)))
            callbackFn({
                ok = false,
                error = ('MDT callback failed: %s. Check server console, SQL import, oxmysql, and job/on-duty setup.'):format(name)
            })
            return
        end
        callbackFn(result or { ok = true })
    end)
end

callback('CanOpen', function(src)
    local ctx = getContext(src)
    if not ctx then
        return { ok = false, error = 'You are not authorized, your job is not listed in Config.Departments, or you are off duty.' }
    end

    -- Never let audit logging block opening the MDT. If SQL is missing, the UI still opens and the console prints the DB error.
    pcall(function() audit(src, 'auth', 'open_mdt', ctx.citizenid, { department = ctx.department }) end)

    return { ok = true, context = ctx }
end)

callback('GetInitialData', function(src)
    local ctx = getContext(src)
    if not ctx then return { ok = false, error = 'Unauthorized' } end

    local dispatch = dbQuery("SELECT * FROM dpn_mdt_dispatch_calls ORDER BY created_at DESC LIMIT 100") or {}
    local bolos = dbQuery("SELECT * FROM dpn_mdt_bolos WHERE status = 'active' ORDER BY created_at DESC LIMIT 50") or {}
    local warrants = dbQuery("SELECT * FROM dpn_mdt_warrants WHERE status = 'active' ORDER BY created_at DESC LIMIT 50") or {}
    local bulletins = dbQuery("SELECT * FROM dpn_mdt_bulletins ORDER BY created_at DESC LIMIT 20") or {}
    local recentCharges = dbQuery("SELECT id, charge_no, citizenid, citizen_name, charge_type, status, total_fine, total_jail, total_points, arresting_officer_name, department, created_at FROM dpn_mdt_citizen_charges ORDER BY created_at DESC LIMIT 50") or {}

    return {
        ok = true,
        context = ctx,
        dashboard = getDashboard(ctx),
        dispatch = dispatch,
        bolos = bolos,
        warrants = warrants,
        bulletins = bulletins,
        recentCharges = recentCharges,
        roster = getOnlineRoster(),
        config = {
            modules = DPN_MDT.Modules,
            departments = Config.Departments,
            theme = Config.DefaultTheme
        }
    }
end)


callback('SearchCitizens', function(src, payload)
    if not hasModule(src, 'citizens') then return { ok = false, error = 'No citizen-search permission' } end
    if not tableExists(DPNDB.players) then return { ok = false, error = ('Missing QBCore players table: %s'):format(DPNDB.players) } end

    local raw = tostring(payload.query or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local limit = limitNumber(payload.limit, 50, 100)
    local q = '%' .. raw .. '%'
    local selectCols = getPlayerSelectList()
    if not selectCols then return { ok = false, error = 'No compatible player columns found.' } end

    local where, params = whereLike(DPNDB.players, { 'citizenid', 'license', 'name', 'charinfo', 'job', 'gang', 'metadata', 'phone_number' }, q)
    local orderBy = hasColumn(DPNDB.players, 'id') and '`id` DESC' or '`citizenid` ASC'
    local rows = dbQuery(('SELECT %s FROM %s WHERE %s ORDER BY %s LIMIT %d'):format(selectCols, ident(DPNDB.players), where, orderBy, limit), params) or {}

    for _, row in ipairs(rows) do
        normalizePlayerRow(row)
        row.vehicleCount = countWhere(DPNDB.vehicles, 'citizenid', row.citizenid)
        row.activeWarrantCount = countWhere('dpn_mdt_warrants', 'citizenid', row.citizenid, "AND status = 'active'")
        row.reportCount = countLike('dpn_mdt_reports', 'involved', row.citizenid)
        row.correctionsCount = countWhere('dpn_mdt_corrections_records', 'citizenid', row.citizenid)
    end

    audit(src, 'search', 'citizens_advanced', raw, { count = #rows })
    return { ok = true, results = rows }
end)

callback('GetCitizenProfile', function(src, payload)
    if not hasModule(src, 'citizens') then return { ok = false, error = 'No profile permission' } end
    local cid = tostring(payload.citizenid or '')
    local player = getCitizenSummary(cid)
    if not player then return { ok = false, error = 'Citizen not found in QBCore players table' } end

    local vehicles = {}
    if tableExists(DPNDB.vehicles) and hasColumn(DPNDB.vehicles, 'citizenid') then
        local vehicleCols = getVehicleSelectList()
        if vehicleCols then
            vehicles = dbQuery(('SELECT %s FROM %s WHERE `citizenid` = ? ORDER BY `plate` ASC LIMIT 150'):format(vehicleCols, ident(DPNDB.vehicles)), { cid }) or {}
            for _, vehicle in ipairs(vehicles) do normalizeVehicleRow(vehicle) end
        end
    end

    local reports = dbQuery('SELECT id, title, type, status, priority, author_name, department, created_at FROM dpn_mdt_reports WHERE involved LIKE ? OR narrative LIKE ? ORDER BY created_at DESC LIMIT 75', { '%' .. cid .. '%', '%' .. cid .. '%' }) or {}
    local cases = dbQuery('SELECT id, case_no, title, status, priority, lead_name, department, created_at FROM dpn_mdt_cases WHERE involved LIKE ? OR summary LIKE ? ORDER BY created_at DESC LIMIT 50', { '%' .. cid .. '%', '%' .. cid .. '%' }) or {}
    local warrants = dbQuery('SELECT * FROM dpn_mdt_warrants WHERE citizenid = ? ORDER BY created_at DESC LIMIT 50', { cid }) or {}
    local bolos = dbQuery('SELECT * FROM dpn_mdt_bolos WHERE citizenid = ? OR description LIKE ? ORDER BY created_at DESC LIMIT 50', { cid, '%' .. cid .. '%' }) or {}
    local medical = dbQuery('SELECT id, incident_id, patient_name, triage, status, provider_name, created_at FROM dpn_mdt_medical_records WHERE patient_citizenid = ? ORDER BY created_at DESC LIMIT 50', { cid }) or {}
    local corrections = dbQuery('SELECT id, record_no, inmate_name, custody_status, housing, created_by, created_at FROM dpn_mdt_corrections_records WHERE citizenid = ? ORDER BY created_at DESC LIMIT 50', { cid }) or {}
    local weapons = dbQuery('SELECT id, weapon_name, serial, status, created_at FROM dpn_mdt_weapons WHERE citizenid = ? ORDER BY created_at DESC LIMIT 50', { cid }) or {}
    local notes = dbQuery('SELECT id, note_type, body, created_by, department, created_at FROM dpn_mdt_citizen_notes WHERE citizenid = ? ORDER BY created_at DESC LIMIT 50', { cid }) or {}
    local citizenCharges = dbQuery('SELECT id, charge_no, charge_type, status, total_fine, total_jail, total_points, arresting_officer_name, department, linked_report_id, linked_case_no, linked_warrant_id, linked_court_docket, created_at FROM dpn_mdt_citizen_charges WHERE citizenid = ? ORDER BY created_at DESC LIMIT 75', { cid }) or {}

    local linked = {
        vehicles = #vehicles,
        reports = #reports,
        cases = #cases,
        warrants = #warrants,
        activeWarrants = countWhere('dpn_mdt_warrants', 'citizenid', cid, "AND status = 'active'"),
        bolos = #bolos,
        medical = #medical,
        corrections = #corrections,
        weapons = #weapons,
        notes = #notes,
        charges = #citizenCharges
    }

    audit(src, 'search', 'citizen_profile_advanced', cid, linked)
    return { ok = true, profile = player, vehicles = vehicles, reports = reports, cases = cases, warrants = warrants, bolos = bolos, medical = medical, corrections = corrections, weapons = weapons, notes = notes, charges = citizenCharges, linked = linked }
end)

callback('SearchVehicles', function(src, payload)
    if not hasModule(src, 'vehicles') then return { ok = false, error = 'No vehicle-search permission' } end
    if not tableExists(DPNDB.vehicles) then return { ok = false, error = ('Missing QBCore vehicle table: %s'):format(DPNDB.vehicles) } end

    local raw = tostring(payload.query or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local limit = limitNumber(payload.limit, 50, 100)
    local q = '%' .. raw .. '%'
    local vehicleCols = getVehicleSelectList('pv')
    if not vehicleCols then return { ok = false, error = 'No compatible vehicle columns found.' } end

    local where, params = whereLike(DPNDB.vehicles, { 'plate', 'fakeplate', 'citizenid', 'vehicle', 'hash', 'garage' }, q, 'pv')
    local join = ''
    local extraSelect = ''
    if tableExists(DPNDB.players) and hasColumn(DPNDB.players, 'citizenid') and hasColumn(DPNDB.players, 'charinfo') and hasColumn(DPNDB.vehicles, 'citizenid') then
        join = (' LEFT JOIN %s %s ON %s = %s'):format(ident(DPNDB.players), ident('p'), qcol('p', 'citizenid'), qcol('pv', 'citizenid'))
        extraSelect = ', ' .. qcol('p', 'charinfo') .. ' AS `charinfo`'
    end

    local sql = ('SELECT %s%s FROM %s %s%s WHERE %s ORDER BY %s ASC LIMIT %d'):format(vehicleCols, extraSelect, ident(DPNDB.vehicles), ident('pv'), join, where, qcol('pv', hasColumn(DPNDB.vehicles, 'plate') and 'plate' or 'citizenid'), limit)
    local rows = dbQuery(sql, params) or {}
    for _, row in ipairs(rows) do
        normalizeVehicleRow(row)
        row.activeBoloCount = countWhere('dpn_mdt_bolos', 'plate', row.plate or '', "AND status = 'active'")
        row.flagCount = countWhere('dpn_mdt_vehicle_flags', 'plate', row.plate or '')
    end

    audit(src, 'search', 'vehicles_advanced', raw, { count = #rows })
    return { ok = true, results = rows }
end)

callback('GetVehicleProfile', function(src, payload)
    if not hasModule(src, 'vehicles') then return { ok = false, error = 'No vehicle-profile permission' } end
    if not tableExists(DPNDB.vehicles) then return { ok = false, error = ('Missing QBCore vehicle table: %s'):format(DPNDB.vehicles) } end
    local plate = tostring(payload.plate or ''):upper():gsub('^%s+', ''):gsub('%s+$', '')
    if plate == '' then return { ok = false, error = 'Missing plate' } end

    local vehicleCols = getVehicleSelectList('pv')
    if not vehicleCols then return { ok = false, error = 'No compatible vehicle columns found.' } end
    local join = ''
    local extraSelect = ''
    if tableExists(DPNDB.players) and hasColumn(DPNDB.players, 'citizenid') and hasColumn(DPNDB.players, 'charinfo') and hasColumn(DPNDB.vehicles, 'citizenid') then
        join = (' LEFT JOIN %s %s ON %s = %s'):format(ident(DPNDB.players), ident('p'), qcol('p', 'citizenid'), qcol('pv', 'citizenid'))
        extraSelect = ', ' .. qcol('p', 'charinfo') .. ' AS `charinfo`'
    end

    local whereParts = { qcol('pv', 'plate') .. ' = ?' }
    local params = { plate }
    if hasColumn(DPNDB.vehicles, 'fakeplate') then
        whereParts[#whereParts + 1] = qcol('pv', 'fakeplate') .. ' = ?'
        params[#params + 1] = plate
    end
    local sql = ('SELECT %s%s FROM %s %s%s WHERE (%s) LIMIT 1'):format(vehicleCols, extraSelect, ident(DPNDB.vehicles), ident('pv'), join, table.concat(whereParts, ' OR '))
    local vehicle = dbSingle(sql, params)
    if not vehicle then return { ok = false, error = 'Vehicle not found' } end
    normalizeVehicleRow(vehicle)

    local owner = getCitizenSummary(vehicle.citizenid)
    local reports = dbQuery('SELECT id, type, title, status, priority, author_name, created_at FROM dpn_mdt_reports WHERE involved LIKE ? OR narrative LIKE ? ORDER BY created_at DESC LIMIT 50', { '%' .. plate .. '%', '%' .. plate .. '%' }) or {}
    local bolos = dbQuery('SELECT * FROM dpn_mdt_bolos WHERE plate = ? OR description LIKE ? ORDER BY created_at DESC LIMIT 50', { plate, '%' .. plate .. '%' }) or {}
    local flags = dbQuery('SELECT id, plate, flag_type, title, notes, status, created_by, department, created_at FROM dpn_mdt_vehicle_flags WHERE plate = ? ORDER BY created_at DESC LIMIT 50', { plate }) or {}

    audit(src, 'search', 'vehicle_profile_advanced', plate, { owner = vehicle.citizenid, bolos = #bolos, flags = #flags })
    return { ok = true, vehicle = vehicle, owner = owner, reports = reports, bolos = bolos, flags = flags }
end)

callback('CreateCitizenNote', function(src, payload)
    if not hasModule(src, 'citizens') then return { ok = false, error = 'No citizen-note permission' } end
    local ctx = getContext(src)
    local id = dbInsert([[
        INSERT INTO dpn_mdt_citizen_notes (citizenid, note_type, body, created_by, department, metadata, created_at)
        VALUES (?, ?, ?, ?, ?, ?, NOW())
    ]], { payload.citizenid or '', payload.note_type or 'general', payload.body or '', ctx.name, ctx.department, encode(payload.metadata) })
    audit(src, 'citizens', 'create_note', payload.citizenid or '', payload)
    return { ok = true, id = id }
end)

callback('CreateVehicleFlag', function(src, payload)
    if not hasModule(src, 'vehicles') then return { ok = false, error = 'No vehicle-flag permission' } end
    local ctx = getContext(src)
    local id = dbInsert([[
        INSERT INTO dpn_mdt_vehicle_flags (plate, flag_type, title, notes, status, created_by, department, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], { tostring(payload.plate or ''):upper(), payload.flag_type or 'watch', payload.title or 'Vehicle Flag', payload.notes or '', payload.status or 'active', ctx.name, ctx.department, encode(payload.metadata) })
    audit(src, 'vehicles', 'create_flag', payload.plate or '', payload)
    return { ok = true, id = id }
end)



callback('SearchPenalCode', function(src, payload)
    if not hasModule(src, 'charges') then return { ok = false, error = 'No penal-code permission' } end
    if not tableExists('dpn_mdt_charges') then return { ok = false, error = 'Missing dpn_mdt_charges table. Import sql/dpn_mdt.sql.' } end
    local raw = tostring(payload.query or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local category = tostring(payload.category or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local class = tostring(payload.class or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local limit = limitNumber(payload.limit, 100, 250)
    local q = '%' .. raw .. '%'
    local where = '(code LIKE ? OR title LIKE ? OR category LIKE ? OR class LIKE ? OR description LIKE ?)'
    local params = { q, q, q, q, q }
    if category ~= '' then
        where = where .. ' AND category = ?'
        params[#params + 1] = category
    end
    if class ~= '' then
        where = where .. ' AND class = ?'
        params[#params + 1] = class
    end
    if hasColumn('dpn_mdt_charges', 'active') then
        where = where .. ' AND active = 1'
    end
    local orderBy = hasColumn('dpn_mdt_charges', 'sort_order') and 'sort_order ASC, category ASC, code ASC' or 'category ASC, code ASC'
    local rows = dbQuery(('SELECT id, code, title, category, class, fine, jail, points, description FROM dpn_mdt_charges WHERE %s ORDER BY %s LIMIT %d'):format(where, orderBy, limit), params) or {}
    audit(src, 'charges', 'search_penal_code', raw, { count = #rows, category = category, class = class })
    return { ok = true, results = rows }
end)

callback('GetCitizenCharges', function(src, payload)
    if not hasModule(src, 'charges') and not hasModule(src, 'citizens') then return { ok = false, error = 'No charge-history permission' } end
    local cid = tostring(payload.citizenid or '')
    if cid == '' then return { ok = false, error = 'Missing citizen ID' } end
    local rows = dbQuery('SELECT * FROM dpn_mdt_citizen_charges WHERE citizenid = ? ORDER BY created_at DESC LIMIT 150', { cid }) or {}
    for _, row in ipairs(rows) do row.charges = decode(row.charges); row.metadata = decode(row.metadata) end
    return { ok = true, results = rows }
end)

callback('CreatePenalCode', function(src, payload)
    if not hasModule(src, 'charges') or not hasGrade(src, Config.Permissions.manageCharges) then return { ok = false, error = 'No penal-code management permission' } end
    local ctx = getContext(src)
    local code = tostring(payload.code or ''):upper():gsub('^%s+', ''):gsub('%s+$', '')
    if code == '' then return { ok = false, error = 'Charge code is required' } end
    local existing = dbSingle('SELECT id FROM dpn_mdt_charges WHERE code = ? LIMIT 1', { code })
    if existing then return { ok = false, error = 'That penal-code already exists. Use your database panel to edit it or create a new code.' } end
    local category = tostring(payload.category or 'general'):lower():gsub('%s+', '_')
    local class = tostring(payload.class or 'misdemeanor'):lower():gsub('%s+', '_')
    local id = dbInsert([[
        INSERT INTO dpn_mdt_charges (code, title, category, class, fine, jail, points, description, active, sort_order, created_by, updated_by, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, 9999, ?, ?, NOW(), NOW())
    ]], { code, payload.title or 'Untitled Charge', category, class, tonumber(payload.fine) or 0, tonumber(payload.jail) or 0, tonumber(payload.points) or 0, payload.description or '', ctx.name, ctx.name })
    audit(src, 'charges', 'create_penal_code', code, payload)
    return { ok = true, id = id }
end)

callback('ChargeCitizen', function(src, payload)
    if not hasModule(src, 'charges') then return { ok = false, error = 'No charging permission' } end
    if not tableExists('dpn_mdt_citizen_charges') then return { ok = false, error = 'Missing dpn_mdt_citizen_charges table. Import sql/dpn_mdt.sql.' } end
    local chargeConfig = Config.Charging or {}
    local ctx = getContext(src)
    local cid = tostring(payload.citizenid or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if chargeConfig.requireCitizenId ~= false and cid == '' then return { ok = false, error = 'Citizen ID is required before charges can be filed.' } end

    local selected = payload.charges or {}
    local charges, totals = calculateChargeTotals(selected)
    if chargeConfig.requireAtLeastOneCharge ~= false and #charges == 0 then return { ok = false, error = 'Select at least one valid penal-code charge.' } end

    local citizen = cid ~= '' and getCitizenSummary(cid) or nil
    local citizenName = tostring(payload.citizen_name or '')
    if citizenName == '' and citizen then citizenName = citizen.name or '' end
    local chargeNo = payload.charge_no or makeCallId('CHG')
    local chargeType = payload.charge_type or chargeConfig.defaultType or 'arrest'
    local status = payload.status or chargeConfig.defaultStatus or 'filed'
    local linkedReport = tonumber(payload.linked_report_id) or nil

    local id = dbInsert([[
        INSERT INTO dpn_mdt_citizen_charges
        (charge_no, citizenid, citizen_name, charge_type, status, linked_report_id, linked_case_no, linked_warrant_id, linked_court_docket, charges, total_fine, total_jail, total_points, notes, arresting_officer_citizenid, arresting_officer_name, department, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], {
        chargeNo, cid, citizenName, chargeType, status, linkedReport, payload.linked_case_no or '', tonumber(payload.linked_warrant_id) or nil, payload.linked_court_docket or '', encode(charges), totals.fine, totals.jail, totals.points, payload.notes or '', ctx.citizenid, ctx.name, ctx.department, encode(payload.metadata)
    })

    if linkedReport then
        dbUpdate('UPDATE dpn_mdt_reports SET charges = ?, updated_at = NOW() WHERE id = ?', { encode(charges), linkedReport })
    end

    local record = {
        id = id,
        charge_no = chargeNo,
        citizenid = cid,
        citizen_name = citizenName,
        charge_type = chargeType,
        status = status,
        linked_report_id = linkedReport,
        charges = charges,
        total_fine = totals.fine,
        total_jail = totals.jail,
        total_points = totals.points,
        officer = ctx.name,
        department = ctx.department
    }

    if Config.UnifiedNetwork.enabled then
        TriggerEvent(Config.UnifiedNetwork.recordEvent, { sourceResource = 'dpn-mdt', type = 'citizen_charges', id = chargeNo, citizenid = cid, department = ctx.department, data = record })
    end

    emitChargingHooks(src, record, totals)
    audit(src, 'charges', 'charge_citizen', chargeNo, record)
    return { ok = true, id = id, charge_no = chargeNo, totals = totals, charges = charges }
end)

callback('CreateReport', function(src, payload)
    if not hasModule(src, 'reports') then return { ok = false, error = 'No report permission' } end
    local ctx = getContext(src)
    local id = dbInsert([[
        INSERT INTO dpn_mdt_reports (type, title, narrative, status, priority, author_citizenid, author_name, department, involved, evidence, charges, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], {
        payload.type or 'incident', payload.title or 'Untitled Report', payload.narrative or '', payload.status or 'open', payload.priority or 'normal',
        ctx.citizenid, ctx.name, ctx.department, encode(payload.involved), encode(payload.evidence), encode(payload.charges)
    })
    audit(src, 'reports', 'create', tostring(id), payload)
    return { ok = true, id = id }
end)

callback('UpdateReport', function(src, payload)
    if not hasModule(src, 'reports') or not hasGrade(src, Config.Permissions.editReport) then return { ok = false, error = 'No report-edit permission' } end
    dbUpdate([[
        UPDATE dpn_mdt_reports
        SET title = ?, narrative = ?, status = ?, priority = ?, involved = ?, evidence = ?, charges = ?, updated_at = NOW()
        WHERE id = ?
    ]], { payload.title, payload.narrative, payload.status, payload.priority, encode(payload.involved), encode(payload.evidence), encode(payload.charges), payload.id })
    audit(src, 'reports', 'update', tostring(payload.id), payload)
    return { ok = true }
end)

callback('SearchReports', function(src, payload)
    if not hasModule(src, 'reports') then return { ok = false, error = 'No report permission' } end
    local q = '%' .. tostring(payload.query or '') .. '%'
    local rows = dbQuery([[
        SELECT id, type, title, status, priority, author_name, department, created_at, updated_at
        FROM dpn_mdt_reports
        WHERE title LIKE ? OR narrative LIKE ? OR involved LIKE ?
        ORDER BY updated_at DESC
        LIMIT 100
    ]], { q, q, q }) or {}
    return { ok = true, results = rows }
end)

callback('GetReport', function(src, payload)
    if not hasModule(src, 'reports') then return { ok = false, error = 'No report permission' } end
    local row = dbSingle('SELECT * FROM dpn_mdt_reports WHERE id = ?', { payload.id })
    if not row then return { ok = false, error = 'Report not found' } end
    row.involved = decode(row.involved); row.evidence = decode(row.evidence); row.charges = decode(row.charges)
    return { ok = true, report = row }
end)

callback('CreateCase', function(src, payload)
    if not hasModule(src, 'cases') then return { ok = false, error = 'No case permission' } end
    local ctx = getContext(src)
    local caseNo = payload.case_no or makeCallId('CASE')
    local id = dbInsert([[
        INSERT INTO dpn_mdt_cases (case_no, title, summary, status, priority, lead_citizenid, lead_name, department, linked_reports, involved, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], { caseNo, payload.title or 'New Case', payload.summary or '', payload.status or 'open', payload.priority or 'normal', ctx.citizenid, ctx.name, ctx.department, encode(payload.linked_reports), encode(payload.involved) })
    audit(src, 'cases', 'create', caseNo, payload)
    return { ok = true, id = id, case_no = caseNo }
end)

callback('CreateBOLO', function(src, payload)
    if not hasModule(src, 'bolos') then return { ok = false, error = 'No BOLO permission' } end
    local ctx = getContext(src)
    local id = dbInsert([[
        INSERT INTO dpn_mdt_bolos (bolo_type, title, description, plate, citizenid, priority, status, created_by, department, expires_at, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], { payload.bolo_type or 'person', payload.title or 'BOLO', payload.description or '', payload.plate or '', payload.citizenid or '', payload.priority or 'normal', payload.status or 'active', ctx.name, ctx.department, payload.expires_at, encode(payload.metadata) })
    TriggerClientEvent('dpn-mdt:client:BoloUpdated', -1, { id = id, title = payload.title, priority = payload.priority })
    audit(src, 'bolos', 'create', tostring(id), payload)
    return { ok = true, id = id }
end)

callback('CreateWarrant', function(src, payload)
    if not hasModule(src, 'warrants') or not hasGrade(src, Config.Permissions.createWarrant) then return { ok = false, error = 'No warrant permission' } end
    local ctx = getContext(src)
    local id = dbInsert([[
        INSERT INTO dpn_mdt_warrants (citizenid, suspect_name, title, reason, charges, status, signed_by, department, expires_at, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, 'active', ?, ?, ?, NOW(), NOW())
    ]], { payload.citizenid, payload.suspect_name or '', payload.title or 'Arrest Warrant', payload.reason or '', encode(payload.charges), ctx.name, ctx.department, payload.expires_at })
    audit(src, 'warrants', 'create', tostring(id), payload)
    return { ok = true, id = id }
end)

callback('UpdateDispatchCall', function(src, payload)
    if not hasModule(src, 'dispatch') then return { ok = false, error = 'No dispatch permission' } end
    local callId = payload.call_id or payload.id
    dbUpdate('UPDATE dpn_mdt_dispatch_calls SET status = ?, assigned_units = ?, updated_at = NOW() WHERE call_id = ? OR id = ?', {
        payload.status or 'assigned', encode(payload.assigned_units), callId, tonumber(callId) or 0
    })
    if Config.Dispatch.enabled and payload.forwardToDispatch ~= false then
        TriggerEvent(Config.Dispatch.updateEvent, callId, payload.status, payload.assigned_units)
    end
    if Config.UnifiedNetwork.enabled then
        TriggerEvent(Config.UnifiedNetwork.incidentEvent, {
            sourceResource = 'dpn-mdt', type = 'dispatch', id = callId, status = payload.status, data = payload
        })
    end
    TriggerClientEvent('dpn-mdt:client:DispatchUpdated', -1, payload)
    audit(src, 'dispatch', 'update_call', tostring(callId), payload)
    return { ok = true }
end)

callback('CreateEvidence', function(src, payload)
    if not hasModule(src, 'evidence') then return { ok = false, error = 'No evidence permission' } end
    local ctx = getContext(src)
    local id = dbInsert([[
        INSERT INTO dpn_mdt_evidence (evidence_no, evidence_type, title, description, serial, location, status, chain_of_custody, linked_case, linked_report, created_by, department, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], {
        payload.evidence_no or makeCallId('EVD'), payload.evidence_type or 'general', payload.title or 'Evidence', payload.description or '', payload.serial or '', payload.location or '', payload.status or 'stored',
        encode({ { name = ctx.name, citizenid = ctx.citizenid, action = 'created', at = os.date('!%Y-%m-%dT%H:%M:%SZ') } }), payload.linked_case, payload.linked_report, ctx.name, ctx.department, encode(payload.metadata)
    })
    audit(src, 'evidence', 'create', tostring(id), payload)
    return { ok = true, id = id }
end)

callback('CreateCourtCase', function(src, payload)
    if not hasModule(src, 'courts') or not hasGrade(src, Config.Permissions.createCourtCase) then return { ok = false, error = 'No court permission' } end
    local ctx = getContext(src)
    local docket = payload.docket_no or makeCallId('COURT')
    local id = dbInsert([[
        INSERT INTO dpn_mdt_court_cases (docket_no, title, case_type, plaintiff, defendant, charges, status, judge, next_hearing, notes, created_by, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], { docket, payload.title or 'Court Case', payload.case_type or 'criminal', encode(payload.plaintiff), encode(payload.defendant), encode(payload.charges), payload.status or 'filed', payload.judge or '', payload.next_hearing, payload.notes or '', ctx.name })
    audit(src, 'courts', 'create_case', docket, payload)
    return { ok = true, id = id, docket_no = docket }
end)

callback('CreateMedicalRecord', function(src, payload)
    if not hasModule(src, 'ems') then return { ok = false, error = 'No EMS permission' } end
    local ctx = getContext(src)
    local incident = payload.incident_id or makeCallId('MED')
    local id = dbInsert([[
        INSERT INTO dpn_mdt_medical_records (incident_id, patient_citizenid, patient_name, triage, complaint, assessment, treatment, transport_to, status, provider_name, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], { incident, payload.patient_citizenid or '', payload.patient_name or '', payload.triage or 'green', payload.complaint or '', payload.assessment or '', payload.treatment or '', payload.transport_to or '', payload.status or 'open', ctx.name, encode(payload.metadata) })
    audit(src, 'ems', 'create_medical_record', incident, payload)
    return { ok = true, id = id, incident_id = incident }
end)

callback('CreateFireRecord', function(src, payload)
    if not hasModule(src, 'fire') then return { ok = false, error = 'No fire permission' } end
    local ctx = getContext(src)
    local incident = payload.incident_id or makeCallId('FIRE')
    local id = dbInsert([[
        INSERT INTO dpn_mdt_fire_records (incident_id, incident_type, address, cause, conditions, actions_taken, units, hazards, status, officer_name, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], { incident, payload.incident_type or 'structure_fire', payload.address or '', payload.cause or 'undetermined', encode(payload.conditions), payload.actions_taken or '', encode(payload.units), encode(payload.hazards), payload.status or 'open', ctx.name, encode(payload.metadata) })
    audit(src, 'fire', 'create_fire_record', incident, payload)
    return { ok = true, id = id, incident_id = incident }
end)

callback('CreateFirePreplan', function(src, payload)
    if not hasModule(src, 'fire') then return { ok = false, error = 'No fire preplan permission' } end
    local ctx = getContext(src)
    local id = dbInsert([[
        INSERT INTO dpn_mdt_fire_preplans (building_name, address, occupancy, hazards, hydrants, utilities, access_points, contact_info, notes, created_by, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], { payload.building_name or 'Building', payload.address or '', payload.occupancy or '', encode(payload.hazards), encode(payload.hydrants), encode(payload.utilities), encode(payload.access_points), encode(payload.contact_info), payload.notes or '', ctx.name })
    audit(src, 'fire', 'create_preplan', tostring(id), payload)
    return { ok = true, id = id }
end)


callback('CreateCorrectionsRecord', function(src, payload)
    if not hasModule(src, 'corrections') then return { ok = false, error = 'No corrections permission' } end
    local ctx = getContext(src)
    local recordNo = payload.record_no or makeCallId('DOC')
    local id = dbInsert([[
        INSERT INTO dpn_mdt_corrections_records (record_no, citizenid, inmate_name, custody_status, housing, movement_log, disciplinary, medical_flags, notes, created_by, department, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], {
        recordNo,
        payload.citizenid or '',
        payload.inmate_name or '',
        payload.status or 'active',
        payload.housing or '',
        encode(payload.movement_log),
        encode(payload.disciplinary),
        encode(payload.medical_flags),
        payload.notes or '',
        ctx.name,
        ctx.department,
        encode(payload.metadata)
    })
    audit(src, 'corrections', 'create_custody_record', recordNo, payload)
    return { ok = true, id = id, record_no = recordNo }
end)

callback('MIBAction', function(src, payload)
    if not hasModule(src, 'mib') or not hasGrade(src, Config.Permissions.mibTools) then return { ok = false, error = 'No MIB/Admin permission' } end
    local action = payload.action or 'unknown'
    if action == 'emergency_override' and Config.MIB.allowEmergencyOverride then
        TriggerEvent('dpn-mdt:server:EmergencyOverride', payload)
    elseif action == 'neuralizer_log' and Config.MIB.neuralizerResource then
        TriggerEvent('dpn-mdt:server:NeuralizerLogged', payload)
    elseif action == 'portal_log' and Config.MIB.portalResource then
        TriggerEvent('dpn-mdt:server:PortalLogged', payload)
    end
    audit(src, 'mib', action, tostring(payload.target or ''), payload)
    return { ok = true }
end)

callback('GetAuditLogs', function(src, payload)
    if not hasModule(src, 'audit') or not hasGrade(src, Config.Permissions.auditView) then return { ok = false, error = 'No audit permission' } end
    local q = '%' .. tostring(payload.query or '') .. '%'
    local rows = dbQuery([[
        SELECT * FROM dpn_mdt_audit_logs
        WHERE actor_name LIKE ? OR actor_citizenid LIKE ? OR category LIKE ? OR action LIKE ? OR target LIKE ?
        ORDER BY created_at DESC
        LIMIT 200
    ]], { q, q, q, q, q }) or {}
    for _, row in ipairs(rows) do row.details = decode(row.details) end
    return { ok = true, results = rows }
end)

RegisterNetEvent('dpn-mdt:server:ReceiveDispatchCall', function(call)
    local src = source
    createDispatchCall(call, src and src > 0 and src or nil)
end)

RegisterNetEvent('dpn-dispatch:server:SendToMDT', function(call)
    local src = source
    createDispatchCall(call, src and src > 0 and src or nil)
end)

RegisterNetEvent('dpn-uen:server:SendIncidentToMDT', function(incident)
    local call = incident or {}
    call.metadata = call.metadata or {}
    call.metadata.unifiedNetwork = true
    createDispatchCall(call, source and source > 0 and source or nil)
end)

RegisterNetEvent('dpn-mdt:server:SetUnitStatus', function(status, callId)
    local src = source
    local ctx = getContext(src)
    if not ctx then return end
    dbInsert([[
        INSERT INTO dpn_mdt_unit_status (citizenid, name, department, status, call_id, updated_at)
        VALUES (?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE status = VALUES(status), call_id = VALUES(call_id), updated_at = NOW()
    ]], { ctx.citizenid, ctx.name, ctx.department, status, callId or '' })
    if Config.UnifiedNetwork.enabled then
        TriggerEvent(Config.UnifiedNetwork.unitStatusEvent, { citizenid = ctx.citizenid, name = ctx.name, department = ctx.department, status = status, call_id = callId })
    end
    audit(src, 'unit_status', 'set_status', status, { call_id = callId })
end)

exports('IsAuthorized', function(source)
    return isAuthorized(source)
end)

exports('CreateDispatchCall', function(call)
    local callId = createDispatchCall(call, nil)
    return callId
end)

exports('RegisterEvidence', function(data)
    local evidenceNo = data.evidence_no or makeCallId('EVD')
    local id = dbInsert([[
        INSERT INTO dpn_mdt_evidence (evidence_no, evidence_type, title, description, serial, location, status, chain_of_custody, linked_case, linked_report, created_by, department, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], { evidenceNo, data.evidence_type or 'external', data.title or 'External Evidence', data.description or '', data.serial or '', data.location or '', data.status or 'stored', encode(data.chain_of_custody), data.linked_case, data.linked_report, data.created_by or 'external', data.department or 'shared', encode(data.metadata) })
    return id, evidenceNo
end)

exports('RegisterWeapon', function(citizenid, weaponName, serial, info)
    local id = dbInsert([[
        INSERT INTO dpn_mdt_weapons (citizenid, weapon_name, serial, info, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, 'registered', NOW(), NOW())
    ]], { citizenid, weaponName, serial, info or '' })
    return id
end)

exports('GetActiveWarrants', function(citizenid)
    return dbQuery('SELECT * FROM dpn_mdt_warrants WHERE citizenid = ? AND status = ?', { citizenid, 'active' }) or {}
end)


exports('ChargeCitizen', function(data)
    if not tableExists('dpn_mdt_citizen_charges') then return nil, 'missing dpn_mdt_citizen_charges table' end
    data = data or {}
    local charges, totals = calculateChargeTotals(data.charges or {})
    if #charges == 0 then return nil, 'no valid charges' end
    local chargeNo = data.charge_no or makeCallId('CHG')
    local id = dbInsert([[
        INSERT INTO dpn_mdt_citizen_charges
        (charge_no, citizenid, citizen_name, charge_type, status, linked_report_id, linked_case_no, charges, total_fine, total_jail, total_points, notes, arresting_officer_citizenid, arresting_officer_name, department, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], { chargeNo, data.citizenid or '', data.citizen_name or '', data.charge_type or 'external', data.status or 'filed', tonumber(data.linked_report_id) or nil, data.linked_case_no or '', encode(charges), totals.fine, totals.jail, totals.points, data.notes or '', data.officer_citizenid or 'external', data.officer_name or 'external', data.department or 'external', encode(data.metadata) })
    return id, chargeNo, totals
end)

exports('SearchPenalCode', function(query)
    local q = '%' .. tostring(query or '') .. '%'
    return dbQuery('SELECT id, code, title, category, class, fine, jail, points, description FROM dpn_mdt_charges WHERE code LIKE ? OR title LIKE ? OR category LIKE ? ORDER BY category ASC, code ASC LIMIT 100', { q, q, q }) or {}
end)
