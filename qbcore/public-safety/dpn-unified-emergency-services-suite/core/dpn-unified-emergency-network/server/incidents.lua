local function uuid(prefix)
    return ('%s-%s-%04d'):format(prefix or 'UNES', os.date('%Y%m%d%H%M%S'), math.random(1000,9999))
end

local function getCoords(src)
    if not src or src == 0 then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function hasAgency(list, agency)
    for _, a in ipairs(list or {}) do if a == agency then return true end end
    return false
end

local function addHistory(incident, action, unit, note, extra)
    incident.history = incident.history or {}
    table.insert(incident.history, 1, { time = os.time(), action = action, callsign = unit and unit.callsign or 'SYSTEM', agency = unit and unit.agency or 'system', note = note, extra = extra })
    while #incident.history > 80 do table.remove(incident.history) end
end

local function normalizeIncident(src, data)
    data = data or {}
    local unit = src ~= 0 and DPN_UNES.Server.GetUnitProfile(src) or nil
    local incidentType = data.type or 'custom'
    local typeCfg = DPN_UNES.Config.IncidentTypes[incidentType] or DPN_UNES.Config.IncidentTypes.custom or {}
    local agencies = data.agencies or typeCfg.agencies or { unit and unit.agency or 'law' }
    local incident = {
        id = data.id or uuid('UNES'),
        type = incidentType,
        title = data.title or typeCfg.label or 'Emergency Incident',
        description = data.description or '',
        priority = tonumber(data.priority or typeCfg.priority or 3),
        agencies = agencies,
        escalation = data.escalation or typeCfg.escalation or {},
        status = DPN_UNES.Constants.STATUS_CREATED,
        createdBy = unit or { callsign = 'SYSTEM', agency = 'system' },
        assigned = {},
        staging = {},
        patients = data.patients or {},
        suspects = data.suspects or {},
        vehicles = data.vehicles or {},
        evidence = data.evidence or {},
        linkedRecords = data.linkedRecords or {},
        objectives = data.objectives or {},
        notes = data.notes or {},
        history = {},
        coords = data.coords or getCoords(src),
        postal = data.postal or 'UNKNOWN',
        sceneCommander = data.sceneCommander,
        commandAgency = data.commandAgency,
        hazardLevel = data.hazardLevel or 'unknown',
        caller = data.caller or '',
        callback = data.callback or '',
        stagingLocation = data.staging or data.stagingLocation or '',
        crossStreet = data.crossStreet or '',
        tac = data.tac or data.radioChannel or '',
        responseMode = data.responseMode or 'normal',
        callSource = data.callSource or 'manual',
        callTaker = unit and unit.callsign or 'SYSTEM',
        triage = data.triage or { red = 0, yellow = 0, green = 0, black = 0 },
        createdAt = os.time(),
        updatedAt = os.time()
    }
    addHistory(incident, 'created', unit, incident.description)
    return incident
end

local function saveIncident(incident)
    MySQL.insert('INSERT INTO dpn_unes_incidents (incident_id, type, title, description, priority, status, agencies, created_by, coords, postal, history, payload, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW()) ON DUPLICATE KEY UPDATE type=VALUES(type), title=VALUES(title), description=VALUES(description), priority=VALUES(priority), status=VALUES(status), agencies=VALUES(agencies), coords=VALUES(coords), postal=VALUES(postal), history=VALUES(history), payload=VALUES(payload), updated_at=NOW()', {
        incident.id, incident.type, incident.title, incident.description, incident.priority, incident.status,
        json.encode(incident.agencies), json.encode(incident.createdBy), json.encode(incident.coords), incident.postal, json.encode(incident.history), json.encode(incident)
    })
end

local function broadcast(incident)
    TriggerEvent('dpn-unes:server:broadcastIncident', incident)
    TriggerClientEvent('dpn-unes:client:incidentUpdated', -1, incident)
end

RegisterNetEvent('dpn-unes:server:createIncident', function(srcOverride, dataOverride)
    local networkSource = tonumber(source) or 0
    local src
    local data

    -- Network callers can only create incidents as themselves. The optional
    -- (source, data) form remains available for trusted server-side TriggerEvent calls.
    if networkSource > 0 then
        src = networkSource
        data = type(srcOverride) == 'table' and srcOverride or {}
    else
        src = type(srcOverride) == 'number' and srcOverride or 0
        data = type(dataOverride) == 'table' and dataOverride
            or (type(srcOverride) == 'table' and srcOverride or {})
    end

    if src ~= 0 and not DPN_UNES.Server.IsEmergencyUnit(src) then return end
    local incident = normalizeIncident(src, data)
    DPN_UNES.Cache.incidents[incident.id] = incident
    saveIncident(incident)
    DPN_UNES.Server.Audit(src, 'incident_created', incident.id, { type = incident.type, priority = incident.priority })
    TriggerEvent('dpn-unes:server:broadcastIncident', incident)
    TriggerEvent('dpn-unes:server:integrationIncidentCreated', incident)
end)

RegisterNetEvent('dpn-unes:server:updateIncidentStatus', function(incidentId, status)
    local src = source
    local unit = DPN_UNES.Server.GetUnitProfile(src)
    local incident = DPN_UNES.Cache.incidents[incidentId]
    if not unit or not incident then return end

    local allowedStatus = false
    for _, candidate in pairs(DPN_UNES.Constants) do
        if type(candidate) == 'string' and candidate == status then
            allowedStatus = true
            break
        end
    end
    if not allowedStatus then return end

    incident.status = status
    incident.updatedAt = os.time()
    addHistory(incident, 'status:' .. status, unit)
    if status == DPN_UNES.Constants.STATUS_RESOLVED then incident.resolvedAt = os.time() end
    saveIncident(incident)
    DPN_UNES.Server.Audit(source, 'incident_status', incidentId, { status = status })
    broadcast(incident)
end)

RegisterNetEvent('dpn-unes:server:assignSelf', function(incidentId)
    local src = source
    local unit = DPN_UNES.Server.GetUnitProfile(src)
    local incident = DPN_UNES.Cache.incidents[incidentId]
    if not unit or not incident then return end
    local key = unit.unitKey or DPN_UNES.Server.GetUnitKey(unit)
    incident.assigned[key] = unit
    incident.status = DPN_UNES.Constants.STATUS_ASSIGNED
    incident.updatedAt = os.time()
    if not incident.sceneCommander then incident.sceneCommander = unit.callsign; incident.commandAgency = unit.agency end
    local cached = DPN_UNES.Cache.units[key]
    if cached then cached.assignment = incidentId; cached.status = 'enroute'; TriggerClientEvent('dpn-unes:client:unitUpdated', -1, cached) end
    addHistory(incident, 'assigned', unit)
    MySQL.insert('INSERT INTO dpn_unes_assignments (incident_id, citizenid, callsign, agency, unit_name, assigned_at) VALUES (?, ?, ?, ?, ?, NOW())', { incidentId, unit.citizenid, unit.callsign, unit.agency, unit.name })
    saveIncident(incident)
    DPN_UNES.Server.Audit(src, 'assigned_self', incidentId, {})
    broadcast(incident)
end)

RegisterNetEvent('dpn-unes:server:unassignSelf', function(incidentId)
    local unit = DPN_UNES.Server.GetUnitProfile(source)
    local incident = DPN_UNES.Cache.incidents[incidentId]
    if not unit or not incident then return end
    local key = unit.unitKey or DPN_UNES.Server.GetUnitKey(unit)
    incident.assigned[key] = nil
    if DPN_UNES.Cache.units[key] then DPN_UNES.Cache.units[key].assignment = nil; DPN_UNES.Cache.units[key].status = 'available'; TriggerClientEvent('dpn-unes:client:unitUpdated', -1, DPN_UNES.Cache.units[key]) end
    addHistory(incident, 'unassigned', unit)
    saveIncident(incident)
    DPN_UNES.Server.Audit(source, 'unassigned_self', incidentId, {})
    broadcast(incident)
end)

RegisterNetEvent('dpn-unes:server:requestAgencySupport', function(data)
    local src = source
    local incidentId = type(data) == 'table' and data.incidentId or data
    local agencies = type(data) == 'table' and data.agencies or {}
    local note = type(data) == 'table' and data.note or ''
    local incident = DPN_UNES.Cache.incidents[incidentId]
    local unit = DPN_UNES.Server.GetUnitProfile(src)
    if not incident or not unit then return end
    incident.agencies = incident.agencies or {}
    for _, agency in ipairs(agencies or {}) do if agency and agency ~= '' and not hasAgency(incident.agencies, agency) then table.insert(incident.agencies, agency) end end
    incident.updatedAt = os.time()
    addHistory(incident, 'support-request', unit, note, { agencies = agencies })
    saveIncident(incident)
    DPN_UNES.Server.Audit(src, 'support_requested', incidentId, { agencies = agencies, note = note })
    TriggerEvent('dpn-unes:server:broadcastIncident', incident)
    broadcast(incident)
end)

RegisterNetEvent('dpn-unes:server:setSceneCommander', function(data)
    local src = source
    local unit = DPN_UNES.Server.GetUnitProfile(src)
    if not unit then return end
    local incident = DPN_UNES.Cache.incidents[data.incidentId]
    if not incident then return end
    if DPN_UNES.Config.RequireDispatcherForCommandOverride and not unit.canCommand and not unit.canDispatch then return end
    incident.sceneCommander = data.commander or unit.callsign
    incident.commandAgency = data.agency or unit.agency
    addHistory(incident, 'scene-commander', unit, incident.sceneCommander)
    saveIncident(incident)
    DPN_UNES.Server.Audit(src, 'scene_commander_set', incident.id, { commander = incident.sceneCommander })
    broadcast(incident)
end)

RegisterNetEvent('dpn-unes:server:addIncidentNote', function(data)
    local unit = DPN_UNES.Server.GetUnitProfile(source)
    local incident = DPN_UNES.Cache.incidents[data.incidentId]
    if not unit or not incident or not data.note or data.note == '' then return end
    incident.notes = incident.notes or {}
    table.insert(incident.notes, 1, { time = os.time(), callsign = unit.callsign, agency = unit.agency, note = data.note })
    addHistory(incident, 'note', unit, data.note)
    saveIncident(incident)
    broadcast(incident)
end)

RegisterNetEvent('dpn-unes:server:addObjective', function(data)
    local unit = DPN_UNES.Server.GetUnitProfile(source)
    local incident = DPN_UNES.Cache.incidents[data.incidentId]
    if not unit or not incident or not data.text then return end
    incident.objectives = incident.objectives or {}
    table.insert(incident.objectives, { id = uuid('OBJ'), text = data.text, done = false, addedBy = unit.callsign })
    addHistory(incident, 'objective-added', unit, data.text)
    saveIncident(incident)
    broadcast(incident)
end)

RegisterNetEvent('dpn-unes:server:toggleObjective', function(data)
    local unit = DPN_UNES.Server.GetUnitProfile(source)
    local incident = DPN_UNES.Cache.incidents[data.incidentId]
    if not unit or not incident then return end
    for _, obj in ipairs(incident.objectives or {}) do if obj.id == data.objectiveId then obj.done = not obj.done; obj.completedBy = unit.callsign; obj.completedAt = os.time() end end
    addHistory(incident, 'objective-updated', unit, data.objectiveId)
    saveIncident(incident)
    broadcast(incident)
end)

RegisterNetEvent('dpn-unes:server:updateTriage', function(data)
    local unit = DPN_UNES.Server.GetUnitProfile(source)
    local incident = DPN_UNES.Cache.incidents[data.incidentId]
    if not unit or not incident then return end
    incident.triage = { red = tonumber(data.red or 0) or 0, yellow = tonumber(data.yellow or 0) or 0, green = tonumber(data.green or 0) or 0, black = tonumber(data.black or 0) or 0 }
    addHistory(incident, 'triage-updated', unit, json.encode(incident.triage))
    saveIncident(incident)
    broadcast(incident)
end)

RegisterNetEvent('dpn-unes:server:createBolo', function(data)
    local unit = DPN_UNES.Server.GetUnitProfile(source)
    if not unit or not data or not data.title then return end
    local bolo = { id = uuid('BOLO'), title = data.title, description = data.description or '', vehicle = data.vehicle or '', plate = data.plate or '', suspect = data.suspect or '', priority = tonumber(data.priority or 3), lastSeen = data.lastSeen or '', threat = data.threat or '', riskIndicators = data.riskIndicators or '', notifyAgencies = data.notifyAgencies or {'law'}, tags = data.tags or {}, linkedIncident = data.linkedIncident or '', createdBy = unit, active = true, createdAt = os.time() }
    DPN_UNES.Cache.bolos[bolo.id] = bolo
    MySQL.insert('INSERT INTO dpn_unes_bolos (bolo_id, title, description, vehicle, plate, suspect, priority, last_seen, threat, tags, payload, active, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, NOW())', { bolo.id, bolo.title, bolo.description, bolo.vehicle, bolo.plate, bolo.suspect, bolo.priority, bolo.lastSeen, bolo.threat, json.encode(bolo.tags or {}), json.encode(bolo), json.encode(unit) })
    DPN_UNES.Server.Audit(source, 'bolo_created', bolo.id, { plate = bolo.plate })
    TriggerClientEvent('dpn-unes:client:boloUpdated', -1, bolo)
end)

RegisterNetEvent('dpn-unes:server:archiveBolo', function(boloId)
    local unit = DPN_UNES.Server.GetUnitProfile(source)
    local bolo = DPN_UNES.Cache.bolos[boloId]
    if not unit or not bolo then return end
    bolo.active = false; bolo.archivedAt = os.time(); bolo.archivedBy = unit.callsign
    MySQL.update('UPDATE dpn_unes_bolos SET active = 0, archived_at = NOW() WHERE bolo_id = ?', { boloId })
    TriggerClientEvent('dpn-unes:client:boloUpdated', -1, bolo)
end)

-- Record linking is an internal integration operation. Clients must not be able to
-- inject arbitrary linked records or metadata into incident history.
AddEventHandler('dpn-unes:server:linkRecord', function(incidentId, systemName, recordType, recordId, metadata)
    local incident = DPN_UNES.Cache.incidents[incidentId]
    if not incident then return end

    systemName = tostring(systemName or ''):sub(1, 48)
    recordType = tostring(recordType or ''):sub(1, 48)
    recordId = tostring(recordId or ''):sub(1, 128)
    if systemName == '' or recordType == '' or recordId == '' then return end

    local encodedMetadata = '{}'
    local ok, encoded = pcall(json.encode, type(metadata) == 'table' and metadata or {})
    if ok and type(encoded) == 'string' and #encoded <= 8000 then
        encodedMetadata = encoded
    else
        encodedMetadata = json.encode({ truncated = true })
    end

    incident.linkedRecords = incident.linkedRecords or {}
    table.insert(incident.linkedRecords, {
        system = systemName,
        type = recordType,
        id = recordId,
        metadata = type(metadata) == 'table' and metadata or {},
        time = os.time()
    })
    while #incident.linkedRecords > 100 do
        table.remove(incident.linkedRecords)
    end

    MySQL.insert('INSERT INTO dpn_unes_links (incident_id, system_name, record_type, record_id, metadata, created_at) VALUES (?, ?, ?, ?, ?, NOW())', { incidentId, systemName, recordType, recordId, encodedMetadata })
    saveIncident(incident)
    broadcast(incident)
end)

exports('CreateIncident', function(src, data) TriggerEvent('dpn-unes:server:createIncident', src, data) end)
exports('LinkRecord', function(incidentId, systemName, recordType, recordId, metadata) TriggerEvent('dpn-unes:server:linkRecord', incidentId, systemName, recordType, recordId, metadata) end)
exports('CreateBolo', function(src, data) TriggerEvent('dpn-unes:server:createBolo', src, data) end)
