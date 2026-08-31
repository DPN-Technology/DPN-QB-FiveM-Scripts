local cases, evidence = {}, {}
local autoEvidenceRate = {}

local function log(msg) if Config.Debug then print(('^3[dpn-evidence-ai]^7 %s'):format(msg)) end end
local function id(prefix) return prefix .. '-' .. os.time() .. '-' .. math.random(1000, 9999) end
local function now() return os.date('%Y-%m-%d %H:%M:%S') end


local function sanitizeEvidenceType(value)
    value = tostring(value or 'other'):lower()
    for _, allowed in ipairs(Config.EvidenceTypes) do
        if value == allowed then return value end
    end
    return 'other'
end

local function encodeMetadata(value)
    local metadata = type(value) == 'table' and value or { value = tostring(value or '') }
    local encoded = json.encode(metadata)
    if #encoded > (Config.MaxMetadataLength or 12000) then
        encoded = json.encode({ truncated = true, summary = encoded:sub(1, Config.MaxMetadataLength or 12000) })
    end
    return encoded
end

local function webhook(kind, title, data)
    if not Config.Webhooks.enabled then return end
    local url = Config.Webhooks[kind]
    if not url or url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = 'DPN Evidence AI',
        embeds = {{ title = title, description = ('```json\n%s\n```'):format(json.encode(data)), color = 15158332 }}
    }), { ['Content-Type'] = 'application/json' })
end

local function dbReady()
    return GetResourceState('oxmysql') == 'started'
end

local function refresh(src)
    local officer = DPN_EvidenceBridge.GetOfficer(src)
    MySQL.query('SELECT * FROM dpn_evidence_cases ORDER BY updated_at DESC LIMIT 100', {}, function(caseRows)
        MySQL.query('SELECT * FROM dpn_evidence_items ORDER BY created_at DESC LIMIT 200', {}, function(eRows)
            TriggerClientEvent('dpn-evidence-ai:client:data', src, {
                officer = officer,
                supervisor = DPN_EvidenceBridge.IsSupervisor(src),
                cases = caseRows or {},
                evidence = eRows or {},
                config = { types = Config.EvidenceTypes, statuses = Config.CaseStatuses }
            })
        end)
    end)
end

RegisterNetEvent('dpn-evidence-ai:server:open', function()
    local src = source
    if not DPN_EvidenceBridge.IsLEO(src) then return DPN_EvidenceBridge.Notify(src, 'Evidence access denied.', 'error') end
    refresh(src)
end)

RegisterNetEvent('dpn-evidence-ai:server:createCase', function(data)
    local src = source
    if not DPN_EvidenceBridge.IsLEO(src) or type(data) ~= 'table' then return end
    local officer = DPN_EvidenceBridge.GetOfficer(src)
    local caseId = id('CASE')
    local title = tostring(data.title or 'Untitled Case'):sub(1, 128)
    local desc = tostring(data.description or ''):sub(1, Config.MaxNoteLength)
    MySQL.insert('INSERT INTO dpn_evidence_cases (case_id,title,description,status,created_by,created_by_name,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)', {
        caseId, title, desc, 'open', officer.identifier, officer.name, now(), now()
    }, function()
        webhook('cases', 'Case Created', { case_id = caseId, title = title, officer = officer.name })
        refresh(src)
    end)
end)

RegisterNetEvent('dpn-evidence-ai:server:addEvidence', function(data)
    local src = source
    if not DPN_EvidenceBridge.IsLEO(src) or type(data) ~= 'table' then return end
    local officer = DPN_EvidenceBridge.GetOfficer(src)
    if not officer then return end
    local evId = id('EVD')
    local evType = sanitizeEvidenceType(data.type)
    local title = tostring(data.title or 'Evidence Item'):sub(1, 128)
    local notes = tostring(data.notes or ''):sub(1, Config.MaxNoteLength)
    local meta = encodeMetadata(data.meta or {})
    local caseId = data.case_id and tostring(data.case_id):sub(1, 64) or nil
    if caseId then
        local exists = MySQL.scalar.await('SELECT COUNT(*) FROM dpn_evidence_cases WHERE case_id=?', { caseId }) or 0
        if tonumber(exists) < 1 then return DPN_EvidenceBridge.Notify(src, 'Evidence case not found.', 'error') end
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM dpn_evidence_items WHERE case_id=?', { caseId }) or 0
        if tonumber(count) >= Config.MaxEvidencePerCase then return DPN_EvidenceBridge.Notify(src, 'This case has reached its evidence-item limit.', 'error') end
    end
    MySQL.insert('INSERT INTO dpn_evidence_items (evidence_id,case_id,type,title,notes,metadata,collected_by,collected_by_name,custody_holder,custody_holder_name,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', {
        evId, caseId, evType, title, notes, meta, officer.identifier, officer.name, officer.identifier, officer.name, now(), now()
    }, function()
        MySQL.insert('INSERT INTO dpn_evidence_custody (evidence_id,action,from_holder,to_holder,officer_identifier,officer_name,notes,created_at) VALUES (?,?,?,?,?,?,?,?)', {
            evId, 'COLLECTED', '', officer.identifier, officer.identifier, officer.name, notes, now()
        })
        if caseId then MySQL.update('UPDATE dpn_evidence_cases SET updated_at=? WHERE case_id=?', { now(), caseId }) end
        webhook('evidence', 'Evidence Added', { evidence_id = evId, case_id = caseId, title = title, type = evType, officer = officer.name })
        refresh(src)
    end)
end)

RegisterNetEvent('dpn-evidence-ai:server:transferCustody', function(data)
    local src = source
    if not DPN_EvidenceBridge.IsLEO(src) or type(data) ~= 'table' then return end
    local officer = DPN_EvidenceBridge.GetOfficer(src)
    local evId = tostring(data.evidence_id or '')
    local toHolder = tostring(data.to_holder or officer.identifier)
    local toName = tostring(data.to_name or toHolder)
    local notes = tostring(data.notes or ''):sub(1, Config.MaxNoteLength)
    MySQL.single('SELECT custody_holder FROM dpn_evidence_items WHERE evidence_id=?', { evId }, function(row)
        if not row then return DPN_EvidenceBridge.Notify(src, 'Evidence item not found.', 'error') end
        MySQL.update('UPDATE dpn_evidence_items SET custody_holder=?, custody_holder_name=?, updated_at=? WHERE evidence_id=?', { toHolder, toName, now(), evId })
        MySQL.insert('INSERT INTO dpn_evidence_custody (evidence_id,action,from_holder,to_holder,officer_identifier,officer_name,notes,created_at) VALUES (?,?,?,?,?,?,?,?)', {
            evId, 'TRANSFERRED', row.custody_holder or '', toHolder, officer.identifier, officer.name, notes, now()
        })
        webhook('custody', 'Custody Transfer', { evidence_id = evId, to = toName, by = officer.name })
        refresh(src)
    end)
end)

RegisterNetEvent('dpn-evidence-ai:server:updateCaseStatus', function(caseId, status)
    local src = source
    if not DPN_EvidenceBridge.IsSupervisor(src) then return DPN_EvidenceBridge.Notify(src, 'Supervisor access required.', 'error') end
    caseId = tostring(caseId or ''):sub(1, 64)
    status = tostring(status or ''):sub(1, 32)
    if caseId == '' or not Config.CaseStatuses[status] then return end
    local officer = DPN_EvidenceBridge.GetOfficer(src)
    MySQL.update('UPDATE dpn_evidence_cases SET status=?, updated_at=? WHERE case_id=?', { status, now(), caseId })
    MySQL.insert('INSERT INTO dpn_evidence_case_notes (case_id,officer_identifier,officer_name,note,created_at) VALUES (?,?,?,?,?)', { caseId, officer.identifier, officer.name, 'Status changed to ' .. status, now() })
    refresh(src)
end)

RegisterNetEvent('dpn-evidence-ai:server:generateCourtReport', function(caseId)
    local src = source
    if not DPN_EvidenceBridge.IsLEO(src) then return end
    caseId = tostring(caseId or ''):sub(1, 64)
    if caseId == '' then return end
    MySQL.single('SELECT * FROM dpn_evidence_cases WHERE case_id=?', { caseId }, function(c)
        if not c then return DPN_EvidenceBridge.Notify(src, 'Case not found.', 'error') end
        MySQL.query('SELECT * FROM dpn_evidence_items WHERE case_id=? ORDER BY created_at ASC', { caseId }, function(items)
            TriggerClientEvent('dpn-evidence-ai:client:courtReport', src, { case = c, evidence = items or {} })
            webhook('court', 'Court Report Generated', { case_id = caseId, evidence_count = #(items or {}) })
        end)
    end)
end)

-- Ecosystem intake events
local function validEvidenceType(value)
    value = tostring(value or 'other'):lower()
    for _, allowed in ipairs(Config.EvidenceTypes) do
        if value == allowed then return value end
    end
    return 'other'
end

local function safeMetadata(value)
    local metadata = type(value) == 'table' and value or { value = tostring(value or '') }
    local encoded = json.encode(metadata)
    if #encoded > (Config.MaxMetadataLength or 12000) then
        metadata = { truncated = true, summary = encoded:sub(1, Config.MaxMetadataLength or 12000) }
        encoded = json.encode(metadata)
    end
    return encoded
end

RegisterNetEvent('dpn-evidence-ai:server:autoEvidence', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end
    if src > 0 and not DPN_EvidenceBridge.IsLEO(src) then return end

    if src > 0 then
        local nowMs = GetGameTimer()
        local last = autoEvidenceRate[src] or 0
        if nowMs - last < (Config.ServerRateLimitMs or 2500) then return end
        autoEvidenceRate[src] = nowMs
    end

    local officer = src > 0 and DPN_EvidenceBridge.GetOfficer(src) or { identifier = 'SYSTEM', name = 'DPN System' }
    if not officer then return end

    local evId = id('AUTO')
    local title = tostring(payload.title or payload.event or 'Automatic Evidence Event'):sub(1, 128)
    local evType = validEvidenceType(payload.type)
    local notes = tostring(payload.notes or 'Automatically generated by DPN ecosystem.'):sub(1, Config.MaxNoteLength)
    local caseId = payload.case_id and tostring(payload.case_id):sub(1, 64) or nil
    local metadata = safeMetadata(payload.meta or payload)

    MySQL.insert('INSERT INTO dpn_evidence_items (evidence_id,case_id,type,title,notes,metadata,collected_by,collected_by_name,custody_holder,custody_holder_name,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', {
        evId, caseId, evType, title, notes, metadata, officer.identifier, officer.name, 'SYSTEM', 'Digital Evidence Locker', now(), now()
    })
end)

AddEventHandler('playerDropped', function()
    autoEvidenceRate[source] = nil
end)



local function addSystemRecord(recordType, message, metadata, sourceName)
    local payload = {
        type = validEvidenceType(recordType or 'other'),
        title = tostring(message or 'DPN System Record'):sub(1, 128),
        notes = 'Automatically generated by the DPN Emergency Network.',
        meta = type(metadata) == 'table' and metadata or { message = tostring(message or '') },
        source = tostring(sourceName or 'dpn-emergency-network'):sub(1, 64)
    }
    local evId = id('SYS')
    MySQL.insert('INSERT INTO dpn_evidence_items (evidence_id,case_id,type,title,notes,metadata,collected_by,collected_by_name,custody_holder,custody_holder_name,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', {
        evId, nil, payload.type, payload.title, payload.notes, safeMetadata(payload.meta), 'SYSTEM', payload.source, 'SYSTEM', 'Digital Evidence Locker', now(), now()
    })
    return evId
end

RegisterNetEvent('dpn-evidence-ai:server:addSystemRecord', function(recordType, message, metadata)
    -- Kept as a compatibility event for server-side callers only. Client calls are rejected.
    if (tonumber(source) or 0) > 0 then return end
    addSystemRecord(recordType, message, metadata, 'DPN Emergency Network')
end)

exports('AddSystemRecord', addSystemRecord)

exports('CreateCase', function(title, description, createdBy)
    local caseId = id('CASE')
    MySQL.insert.await('INSERT INTO dpn_evidence_cases (case_id,title,description,status,created_by,created_by_name,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)', { caseId, tostring(title or 'Untitled Case'):sub(1,128), tostring(description or ''):sub(1,Config.MaxNoteLength), 'open', createdBy or 'SYSTEM', createdBy or 'SYSTEM', now(), now() })
    return caseId
end)

exports('AddEvidence', function(caseId, evType, title, notes, metadata)
    local evId = id('EVD')
    MySQL.insert.await('INSERT INTO dpn_evidence_items (evidence_id,case_id,type,title,notes,metadata,collected_by,collected_by_name,custody_holder,custody_holder_name,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', { evId, caseId, sanitizeEvidenceType(evType), tostring(title or 'Evidence Item'):sub(1,128), tostring(notes or ''):sub(1,Config.MaxNoteLength), encodeMetadata(metadata or {}), 'SYSTEM', 'DPN System', 'SYSTEM', 'Digital Evidence Locker', now(), now() })
    return evId
end)
