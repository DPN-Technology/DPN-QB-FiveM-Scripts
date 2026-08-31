local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    Wait(1000)
    exports['dpn-medical-core']:RegisterModule('dpn-medical-records','2.0.1',{'records','timeline','patient_history','legacy_schema_migration'})
end)

local function resolve(target)
    if type(target) == 'string' then return target end
    local player = QBCore.Functions.GetPlayer(tonumber(target))
    return player and player.PlayerData.citizenid or nil
end

local function encodeRecordData(data)
    local ok, encoded = pcall(json.encode, data or {})
    if ok then return encoded end
    return json.encode({ encodingError = tostring(encoded), fallback = tostring(data) })
end

local function add(target, entryType, data, author)
    local cid = resolve(target)
    if not cid then return false, 'patient could not be resolved' end

    local recordType = tostring(entryType or 'note'):sub(1, 64)
    local authorCid = author and tostring(author):sub(1, 64) or nil
    local ok, result = DPNRecordsDB.Insert(cid, recordType, authorCid, encodeRecordData(data))
    if not ok then
        print(('[dpn-medical-records] failed to store %s for %s: %s'):format(recordType, cid, tostring(result)))
        return false, result
    end
    return true, result
end

exports('AddEntry', add)
exports('GetRecords', function(target, limit)
    local cid = resolve(target)
    if not cid then return {} end
    return DPNRecordsDB.Fetch(cid, limit)
end)
exports('GetSchemaStatus', function()
    return {
        ready = DPNRecordsDB.ready,
        failed = DPNRecordsDB.failed,
        columns = DPNRecordsDB.columns,
        migratedFrom = DPNRecordsDB.diagnostics
    }
end)

AddEventHandler('dpn-medical:server:stateChanged', function(src, cid, state, eventType, data)
    if eventType and eventType ~= 'decay' then
        add(cid, eventType, data, 'dpn-medical-core')
    end
end)

QBCore.Commands.Add('medrecord', 'View recent medical record entries', {{name='id'}}, true, function(src, args)
    local requester = QBCore.Functions.GetPlayer(src)
    local job = requester and requester.PlayerData.job or {}
    if not Config.AllowedJobs[job.name] and not QBCore.Functions.HasPermission(src, 'admin') then return end

    local target = tonumber(args[1])
    local rows = exports['dpn-medical-records']:GetRecords(target, Config.MaxDisplay)
    TriggerClientEvent('chat:addMessage', src, {args={'DPN Records', ('Found %s entries.'):format(#rows)}})
    for _, row in ipairs(rows) do
        TriggerClientEvent('chat:addMessage', src, {
            args={tostring(row.entry_type or 'record'), ('%s | %s'):format(tostring(row.created_at or 'unknown time'), tostring(row.entry_data or '{}'))}
        })
    end
end)

QBCore.Commands.Add('medrecordschema', 'Show DPN Medical Records schema status', {}, false, function(src)
    if src ~= 0 and not QBCore.Functions.HasPermission(src, 'admin') then return end
    local status = exports['dpn-medical-records']:GetSchemaStatus()
    local message = ('ready=%s failed=%s patient_cid=%s entry_type=%s entry_data=%s'):format(
        tostring(status.ready), tostring(status.failed), tostring(status.columns.patient_cid ~= nil),
        tostring(status.columns.entry_type ~= nil), tostring(status.columns.entry_data ~= nil)
    )
    if src == 0 then
        print('[dpn-medical-records] ' .. message)
    else
        TriggerClientEvent('chat:addMessage', src, {args={'DPN Records Schema', message}})
    end
end)
