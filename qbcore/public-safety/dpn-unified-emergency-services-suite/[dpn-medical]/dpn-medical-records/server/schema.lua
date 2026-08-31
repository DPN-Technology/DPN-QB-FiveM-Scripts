local RESOURCE = GetCurrentResourceName()

DPNRecordsDB = DPNRecordsDB or {
    ready = false,
    failed = false,
    columns = {},
    insertSql = nil,
    insertValueBuilders = {},
    diagnostics = {}
}

local function log(message)
    print(('[%s] %s'):format(RESOURCE, message))
end

local function safeIdentifier(value)
    value = tostring(value or '')
    if not value:match('^[%w_]+$') then return nil end
    return ('`%s`'):format(value)
end

local function queryAwait(sql, params)
    local ok, result = pcall(function()
        return MySQL.query.await(sql, params or {})
    end)
    if not ok then
        return nil, tostring(result)
    end
    return result
end

local function executeAwait(sql, params)
    local ok, result = pcall(function()
        return MySQL.update.await(sql, params or {})
    end)
    if not ok then
        return nil, tostring(result)
    end
    return result
end

local function loadColumns()
    local rows, err = queryAwait('SHOW COLUMNS FROM `dpn_medical_records`')
    if not rows then return nil, err end

    local columns = {}
    for _, row in ipairs(rows) do
        local name = row.Field or row.field
        if name then
            columns[name] = {
                name = name,
                type = tostring(row.Type or row.type or ''):lower(),
                nullable = tostring(row.Null or row.null or 'YES'):upper() == 'YES',
                default = row.Default,
                extra = tostring(row.Extra or row.extra or ''):lower()
            }
        end
    end
    DPNRecordsDB.columns = columns
    return columns
end

local function addColumnIfMissing(name, definition)
    if DPNRecordsDB.columns[name] then return true end
    local ident = safeIdentifier(name)
    if not ident then return false end

    local _, err = executeAwait(('ALTER TABLE `dpn_medical_records` ADD COLUMN %s %s'):format(ident, definition))
    if err then
        log(('schema migration could not add %s: %s'):format(name, err))
        return false
    end
    log(('schema migration added column %s'):format(name))
    return true
end

local function compatibleAlias(names, kind)
    for _, name in ipairs(names) do
        local column = DPNRecordsDB.columns[name]
        if column then
            local t = column.type
            if kind == 'text' and (t:find('char', 1, true) or t:find('text', 1, true) or t:find('json', 1, true)) then
                return name
            elseif kind == 'date' and (t:find('date', 1, true) or t:find('time', 1, true)) then
                return name
            end
        end
    end
    return nil
end

local function backfillCanonicalColumns()
    local mappings = {
        patient_cid = { aliases = {'citizenid', 'patient_identifier', 'patient_identifier_cid'}, kind = 'text' },
        entry_type = { aliases = {'type', 'record_type', 'category'}, kind = 'text' },
        author_cid = { aliases = {'author', 'author_identifier', 'created_by', 'provider_cid'}, kind = 'text' },
        entry_data = { aliases = {'data', 'details', 'record_data', 'metadata', 'content'}, kind = 'text' },
        created_at = { aliases = {'timestamp', 'recorded_at', 'date_created', 'created'}, kind = 'date' }
    }

    for canonical, config in pairs(mappings) do
        local alias = compatibleAlias(config.aliases, config.kind)
        if alias and DPNRecordsDB.columns[canonical] then
            local canonicalIdent = safeIdentifier(canonical)
            local aliasIdent = safeIdentifier(alias)
            if canonicalIdent and aliasIdent then
                local condition
                if canonical == 'created_at' then
                    condition = ('%s IS NULL'):format(canonicalIdent)
                else
                    condition = ('(%s IS NULL OR %s = \'\')'):format(canonicalIdent, canonicalIdent)
                end
                local sql = ('UPDATE `dpn_medical_records` SET %s = %s WHERE %s'):format(canonicalIdent, aliasIdent, condition)
                local _, err = executeAwait(sql)
                if err then
                    log(('legacy backfill %s <- %s failed: %s'):format(canonical, alias, err))
                else
                    DPNRecordsDB.diagnostics[canonical] = alias
                end
            end
        end
    end
end

local function addIndexIfMissing(indexName, columnName)
    local rows = queryAwait('SHOW INDEX FROM `dpn_medical_records`')
    if rows then
        for _, row in ipairs(rows) do
            if tostring(row.Key_name or row.key_name or '') == indexName then return end
        end
    end
    local indexIdent, columnIdent = safeIdentifier(indexName), safeIdentifier(columnName)
    if not indexIdent or not columnIdent then return end
    local _, err = executeAwait(('ALTER TABLE `dpn_medical_records` ADD INDEX %s (%s)'):format(indexIdent, columnIdent))
    if err then
        log(('could not add index %s: %s'):format(indexName, err))
    end
end

local aliasValueKinds = {
    citizenid = 'patient', patient_identifier = 'patient', patient_identifier_cid = 'patient',
    type = 'entryType', record_type = 'entryType', category = 'entryType',
    author = 'author', author_identifier = 'author', created_by = 'author', provider_cid = 'author',
    data = 'data', details = 'data', record_data = 'data', metadata = 'data', content = 'data'
}

local function genericRequiredValue(column)
    local t = column.type
    if t:find('int', 1, true) or t:find('decimal', 1, true) or t:find('float', 1, true) or t:find('double', 1, true) then
        return function() return 0 end
    end
    if t:find('date', 1, true) or t:find('time', 1, true) then
        return function() return os.date('%Y-%m-%d %H:%M:%S') end
    end
    return function() return '' end
end

local function buildInsertPlan()
    local selected = {}
    local builders = {}

    local function include(name, builder)
        if selected[name] or not DPNRecordsDB.columns[name] then return end
        selected[name] = true
        builders[#builders + 1] = { name = name, value = builder }
    end

    include('patient_cid', function(ctx) return ctx.patient end)
    include('entry_type', function(ctx) return ctx.entryType end)
    include('author_cid', function(ctx) return ctx.author or 'dpn-medical-system' end)
    include('entry_data', function(ctx) return ctx.data end)

    -- Populate recognized legacy aliases too. This prevents legacy NOT NULL
    -- columns from rejecting inserts while preserving compatibility.
    for name, kind in pairs(aliasValueKinds) do
        local column = DPNRecordsDB.columns[name]
        if column then
            local isText = column.type:find('char', 1, true) or column.type:find('text', 1, true) or column.type:find('json', 1, true)
            if isText then
                include(name, function(ctx)
                    local value = ctx[kind]
                    if value == nil and not column.nullable then
                        if kind == 'author' then return 'dpn-medical-system' end
                        if kind == 'data' then return '{}' end
                        return ''
                    end
                    return value
                end)
            end
        end
    end

    -- Satisfy unknown legacy NOT NULL/no-default fields rather than allowing
    -- one old custom column to crash the records pipeline.
    for name, column in pairs(DPNRecordsDB.columns) do
        local generated = column.extra:find('auto_increment', 1, true) or column.extra:find('generated', 1, true)
        if not selected[name] and not generated and not column.nullable and column.default == nil then
            include(name, genericRequiredValue(column))
            log(('compatibility insert will supply a fallback for required legacy column %s'):format(name))
        end
    end

    local identifiers, placeholders = {}, {}
    for _, item in ipairs(builders) do
        identifiers[#identifiers + 1] = safeIdentifier(item.name)
        placeholders[#placeholders + 1] = '?'
    end

    DPNRecordsDB.insertSql = ('INSERT INTO `dpn_medical_records` (%s) VALUES (%s)'):format(
        table.concat(identifiers, ','), table.concat(placeholders, ',')
    )
    DPNRecordsDB.insertValueBuilders = builders
end

local function initializeSchema()
    local createSql = [[
        CREATE TABLE IF NOT EXISTS `dpn_medical_records` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `patient_cid` VARCHAR(64) NULL,
            `entry_type` VARCHAR(64) NULL DEFAULT 'note',
            `author_cid` VARCHAR(64) NULL,
            `entry_data` LONGTEXT NULL,
            `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_records_patient` (`patient_cid`),
            KEY `idx_records_type` (`entry_type`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]]

    local _, createErr = executeAwait(createSql)
    if createErr then
        error(('unable to create/read records table: %s'):format(createErr))
    end

    local columns, loadErr = loadColumns()
    if not columns then error(('unable to inspect records table: %s'):format(loadErr)) end

    addColumnIfMissing('patient_cid', "VARCHAR(64) NULL")
    addColumnIfMissing('entry_type', "VARCHAR(64) NULL DEFAULT 'note'")
    addColumnIfMissing('author_cid', "VARCHAR(64) NULL")
    addColumnIfMissing('entry_data', "LONGTEXT NULL")
    addColumnIfMissing('created_at', "TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP")

    columns, loadErr = loadColumns()
    if not columns then error(('unable to refresh records table schema: %s'):format(loadErr)) end

    backfillCanonicalColumns()
    addIndexIfMissing('idx_records_patient', 'patient_cid')
    addIndexIfMissing('idx_records_type', 'entry_type')
    buildInsertPlan()

    DPNRecordsDB.ready = true
    DPNRecordsDB.failed = false
    log(('schema ready with %d columns; canonical patient field is patient_cid'):format((function()
        local n = 0
        for _ in pairs(DPNRecordsDB.columns) do n = n + 1 end
        return n
    end)()))
end

function DPNRecordsDB.WaitUntilReady(timeoutMs)
    local deadline = GetGameTimer() + (tonumber(timeoutMs) or 15000)
    while not DPNRecordsDB.ready and not DPNRecordsDB.failed and GetGameTimer() < deadline do
        Wait(50)
    end
    return DPNRecordsDB.ready
end

function DPNRecordsDB.Insert(patient, entryType, author, encodedData)
    if not DPNRecordsDB.WaitUntilReady(15000) then
        return false, 'records schema is not ready'
    end

    local context = {
        patient = patient,
        entryType = entryType,
        author = author,
        data = encodedData
    }
    local values = {}
    for _, item in ipairs(DPNRecordsDB.insertValueBuilders) do
        values[#values + 1] = item.value(context)
    end

    local ok, result = pcall(function()
        return MySQL.insert.await(DPNRecordsDB.insertSql, values)
    end)
    if not ok then return false, tostring(result) end
    return result ~= nil and result ~= false, result
end

function DPNRecordsDB.Fetch(patient, limit)
    if not DPNRecordsDB.WaitUntilReady(15000) then return {} end
    local safeLimit = math.max(1, math.min(100, tonumber(limit) or 25))
    local sql = ([=[
        SELECT *
        FROM `dpn_medical_records`
        WHERE `patient_cid` = ?
        ORDER BY `id` DESC
        LIMIT %d
    ]=]):format(safeLimit)
    local rows, err = queryAwait(sql, {patient})
    if not rows then
        log(('record fetch failed for %s: %s'):format(tostring(patient), tostring(err)))
        return {}
    end
    return rows
end

CreateThread(function()
    local ok, err = pcall(initializeSchema)
    if not ok then
        DPNRecordsDB.failed = true
        DPNRecordsDB.ready = false
        log(('SCHEMA INITIALIZATION FAILED: %s'):format(tostring(err)))
        log('Import sql/dpn_medical_records_v5.0.1_migration.sql using your database administrator, then restart this resource.')
    end
end)
