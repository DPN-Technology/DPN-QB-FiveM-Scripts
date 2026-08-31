local QBCore = exports['qb-core']:GetCoreObject()
local incidents, units, markers = {}, {}, {}
local autoIncidentRate = {}

local function uid(prefix)
    return ('%s-%s-%04d'):format(prefix, os.time(), math.random(1000, 9999))
end

local function clean(value, maxLength)
    return tostring(value or ''):gsub('[%z\1-\31]', ''):sub(1, maxLength or 255)
end

local function gradeLevel(job)
    local grade = job and job.grade or 0
    if type(grade) == 'table' then grade = grade.level or grade.grade or 0 end
    return tonumber(grade) or 0
end

local function getPlayerData(src)
    local player = QBCore.Functions.GetPlayer(tonumber(src))
    if not player then return nil end
    local data = player.PlayerData or {}
    local charinfo = data.charinfo or {}
    local job = data.job or {}
    return {
        name = (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1'),
        identifier = data.citizenid or tostring(src),
        job = job.name or 'unemployed',
        grade = gradeLevel(job),
        duty = job.onduty == true,
        isBoss = job.isboss == true
    }
end

local function isAllowed(src, requireCommand)
    src = tonumber(src) or 0
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, requireCommand and DPN_IC_Config.CommandAce or DPN_IC_Config.SupervisorAce) then return true end
    local player = getPlayerData(src)
    if not player or not DPN_IC_Config.AllowedJobs[player.job] then return false end
    if DPN_IC_Config.RequireDuty and not player.duty then return false end
    if not requireCommand then return true end
    if player.isBoss then return true end
    for _, grade in ipairs(DPN_IC_Config.CommandRanks[player.job] or {}) do
        if tonumber(grade) == player.grade then return true end
    end
    return false
end

local function getCoords(src)
    local ok, value = pcall(function()
        local ped = GetPlayerPed(src)
        if not ped or ped <= 0 or not DoesEntityExist(ped) then return nil end
        local coords = GetEntityCoords(ped)
        return { x = coords.x, y = coords.y, z = coords.z }
    end)
    return ok and value or nil
end

local function normalizeCoords(value)
    if type(value) ~= 'table' then return nil end
    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z then return nil end
    if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 2500 then return nil end
    return { x=x, y=y, z=z }
end

local function recipients()
    local result = {}
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and isAllowed(src, false) then result[#result+1] = src end
    end
    return result
end

local function broadcast()
    for _, src in ipairs(recipients()) do
        TriggerClientEvent('dpn-incident-command:client:sync', src, incidents, units, markers)
    end
end

local function logAction(incidentUid, src, action, details)
    local player = src and src > 0 and getPlayerData(src) or nil
    MySQL.insert('INSERT INTO dpn_incident_log (incident_uid, actor, action, details) VALUES (?, ?, ?, ?)', {
        incidentUid, player and player.name or 'DPN System', clean(action, 80), json.encode(details or {})
    })
end

local function loadIncidents()
    local rows = MySQL.query.await("SELECT * FROM dpn_incidents WHERE status != 'archived' ORDER BY created_at DESC LIMIT ?", { DPN_IC_Config.MaxActiveIncidents }) or {}
    incidents = {}
    for _, row in ipairs(rows) do
        local ok, coords = pcall(json.decode, row.coords or '{}')
        row.coords = ok and coords or nil
        incidents[row.incident_uid] = row
    end
    units = {}
    for _, entry in ipairs(MySQL.query.await('SELECT * FROM dpn_incident_units WHERE incident_uid IN (SELECT incident_uid FROM dpn_incidents WHERE status != \'archived\')', {}) or {}) do
        units[entry.incident_uid] = units[entry.incident_uid] or {}
        units[entry.incident_uid][#units[entry.incident_uid]+1] = entry
    end
    markers = {}
    for _, marker in ipairs(MySQL.query.await('SELECT * FROM dpn_incident_markers WHERE incident_uid IN (SELECT incident_uid FROM dpn_incidents WHERE status != \'archived\')', {}) or {}) do
        local ok, coords = pcall(json.decode, marker.coords or '{}')
        marker.coords = ok and coords or nil
        markers[marker.incident_uid] = markers[marker.incident_uid] or {}
        markers[marker.incident_uid][#markers[marker.incident_uid]+1] = marker
    end
end

local validPriorities = { low=true, medium=true, high=true, critical=true }
local validStatuses = { active=true, contained=true, monitoring=true, resolved=true, archived=true }
local validMarkerTypes = { staging=true, roadblock=true, search_grid=true, command=true, medical=true, hazard=true }

local function notifyDispatch(title, message, coords, incidentId)
    if GetResourceState('dpn-digital-dispatch') ~= 'started' then return false end
    exports['dpn-digital-dispatch']:CreateDispatchCall({
        type = 'incident',
        title = clean(title or 'Incident Command', 128),
        description = clean(message or 'Incident command activation.', 1000),
        coords = normalizeCoords(coords),
        priority = 1,
        departments = { 'law', 'fire', 'medical', 'dispatch' },
        metadata = { incidentCommand = true, incidentId = incidentId }
    }, 0)
    return true
end

local function createIncidentInternal(data, actorSource, systemCreated)
    data = type(data) == 'table' and data or {}
    local actor = actorSource and actorSource > 0 and getPlayerData(actorSource) or nil
    local incidentId = uid('INC')
    local priority = clean(data.priority or 'medium', 20):lower()
    if not validPriorities[priority] then priority = 'medium' end
    local coords = systemCreated and normalizeCoords(data.coords) or getCoords(actorSource)
    coords = coords or normalizeCoords(data.coords) or { x=0.0, y=0.0, z=0.0 }
    local row = {
        incident_uid = incidentId,
        title = clean(data.title or 'New Incident', 120),
        incident_type = clean(data.incident_type or data.type or 'general', 60),
        priority = priority,
        status = 'active',
        commander = actor and actor.name or clean(data.commander or 'DPN System', 80),
        commander_identifier = actor and actor.identifier or 'SYSTEM',
        coords = coords,
        notes = clean(data.notes or data.message or data.description or '', 4000),
        created_by = actor and actor.name or 'DPN System',
        created_identifier = actor and actor.identifier or 'SYSTEM',
        created_at = os.date('%Y-%m-%d %H:%M:%S')
    }
    incidents[incidentId] = row
    units[incidentId], markers[incidentId] = {}, {}
    MySQL.insert('INSERT INTO dpn_incidents (incident_uid,title,incident_type,priority,status,commander,commander_identifier,coords,notes,created_by,created_identifier) VALUES (?,?,?,?,?,?,?,?,?,?,?)', {
        incidentId, row.title, row.incident_type, row.priority, row.status, row.commander,
        row.commander_identifier, json.encode(coords), row.notes, row.created_by, row.created_identifier
    })
    logAction(incidentId, actorSource, systemCreated and 'automatic_incident' or 'created_incident', row)
    broadcast()
    return incidentId, row
end

CreateThread(function()
    Wait(750)
    loadIncidents()
end)

RegisterNetEvent('dpn-incident-command:server:requestSync', function()
    local src = source
    if isAllowed(src, false) then TriggerClientEvent('dpn-incident-command:client:sync', src, incidents, units, markers) end
end)

RegisterNetEvent('dpn-incident-command:server:createIncident', function(data)
    local src = source
    if not isAllowed(src, true) then return DPN_IC_Bridge.Notify(src, 'Incident-command authorization required.', 'error') end
    local incidentId, row = createIncidentInternal(data, src, false)
    notifyDispatch('Incident Command Created', row.title, row.coords, incidentId)
end)

RegisterNetEvent('dpn-incident-command:server:updateIncident', function(incidentId, patch)
    local src = source
    incidentId = clean(incidentId, 64)
    if not isAllowed(src, true) or not incidents[incidentId] or type(patch) ~= 'table' then return end
    local incident = incidents[incidentId]
    if patch.title ~= nil then incident.title = clean(patch.title, 120) end
    if patch.notes ~= nil then incident.notes = clean(patch.notes, 4000) end
    if patch.incident_type ~= nil then incident.incident_type = clean(patch.incident_type, 60) end
    if patch.priority ~= nil then
        local value = clean(patch.priority, 20):lower()
        if validPriorities[value] then incident.priority = value end
    end
    if patch.status ~= nil then
        local value = clean(patch.status, 30):lower()
        if validStatuses[value] and value ~= 'archived' then incident.status = value end
    end
    MySQL.update('UPDATE dpn_incidents SET title=?, incident_type=?, priority=?, status=?, notes=? WHERE incident_uid=?', {
        incident.title, incident.incident_type, incident.priority, incident.status, incident.notes, incidentId
    })
    logAction(incidentId, src, 'updated_incident', patch)
    broadcast()
end)

RegisterNetEvent('dpn-incident-command:server:archiveIncident', function(incidentId)
    local src = source
    incidentId = clean(incidentId, 64)
    if not isAllowed(src, true) or not incidents[incidentId] then return end
    MySQL.update("UPDATE dpn_incidents SET status='archived', archived_at=NOW() WHERE incident_uid=?", { incidentId })
    logAction(incidentId, src, 'archived_incident', {})
    incidents[incidentId], units[incidentId], markers[incidentId] = nil, nil, nil
    broadcast()
end)

RegisterNetEvent('dpn-incident-command:server:addUnit', function(incidentId, requested)
    local src = source
    incidentId = clean(incidentId, 64)
    if not isAllowed(src, false) or not incidents[incidentId] then return end
    requested = type(requested) == 'table' and requested or {}
    local target = src
    if tonumber(requested.source_id) and tonumber(requested.source_id) ~= src and isAllowed(src, true) then target = tonumber(requested.source_id) end
    if not isAllowed(target, false) then return end
    local player = getPlayerData(target)
    if not player then return end
    for _, existing in ipairs(units[incidentId] or {}) do
        if existing.identifier == player.identifier then return end
    end
    local entry = {
        incident_uid = incidentId,
        unit_name = clean(requested.unit_name or player.name, 80),
        identifier = player.identifier,
        role = clean(requested.role or 'Assigned Unit', 80),
        division = clean(requested.division or 'Operations', 80),
        status = 'assigned', source_id = target
    }
    units[incidentId] = units[incidentId] or {}
    units[incidentId][#units[incidentId]+1] = entry
    MySQL.insert('INSERT INTO dpn_incident_units (incident_uid,unit_name,identifier,role,division,status,source_id) VALUES (?,?,?,?,?,?,?)', {
        incidentId, entry.unit_name, entry.identifier, entry.role, entry.division, entry.status, entry.source_id
    })
    logAction(incidentId, src, 'assigned_unit', entry)
    broadcast()
end)

RegisterNetEvent('dpn-incident-command:server:addMarker', function(incidentId, data)
    local src = source
    incidentId = clean(incidentId, 64)
    if not isAllowed(src, false) or not incidents[incidentId] or type(data) ~= 'table' then return end
    local markerType = clean(data.marker_type or 'staging', 50):lower()
    if not validMarkerTypes[markerType] then markerType = 'staging' end
    local coords = getCoords(src)
    if not coords then return end
    local marker = {
        incident_uid = incidentId, marker_uid = uid('MRK'), marker_type = markerType,
        label = clean(data.label or 'Scene Marker', 120), coords = coords,
        created_by = getPlayerData(src).name
    }
    markers[incidentId] = markers[incidentId] or {}
    markers[incidentId][#markers[incidentId]+1] = marker
    MySQL.insert('INSERT INTO dpn_incident_markers (incident_uid,marker_uid,marker_type,label,coords,created_by) VALUES (?,?,?,?,?,?)', {
        incidentId, marker.marker_uid, marker.marker_type, marker.label, json.encode(coords), marker.created_by
    })
    logAction(incidentId, src, 'added_marker', marker)
    broadcast()
end)

RegisterNetEvent('dpn-incident-command:server:autoIncident', function(alert)
    local src = tonumber(source) or 0
    if src > 0 and not isAllowed(src, false) then return end
    local timestamp = os.time()
    if src > 0 and autoIncidentRate[src] and timestamp - autoIncidentRate[src] < 30 then return end
    if src > 0 then autoIncidentRate[src] = timestamp end
    alert = type(alert) == 'table' and alert or {}
    local incidentId, row = createIncidentInternal({
        title = alert.title or 'Emergency Network Incident',
        incident_type = alert.type or 'officer_safety',
        priority = tonumber(alert.priority) == 1 and 'critical' or 'high',
        coords = alert.coords,
        notes = alert.message or alert.description or 'Automatically created by the DPN Emergency Network.'
    }, src, src == 0)
    notifyDispatch(row.title, row.notes, row.coords, incidentId)
end)

exports('CreateIncident', function(title, incidentType, priority, coords, notes)
    local incidentId = createIncidentInternal({
        title = title, incident_type = incidentType, priority = priority, coords = coords, notes = notes
    }, 0, true)
    return incidentId
end)

exports('NotifyDispatch', function(title, message, coords, incidentId)
    return notifyDispatch(title, message, coords, incidentId)
end)

exports('GetIncidents', function() return incidents end)

AddEventHandler('playerDropped', function()
    local src = source
    autoIncidentRate[src] = nil
    for incidentId, list in pairs(units) do
        for index = #list, 1, -1 do
            if tonumber(list[index].source_id) == src then table.remove(list, index) end
        end
    end
    broadcast()
end)

CreateThread(function()
    while true do
        Wait(300000)
        local archiveHours = math.max(1, math.min(720, math.floor(tonumber(DPN_IC_Config.AutoArchiveHours) or 24)))
        local query = ("UPDATE dpn_incidents SET status='archived', archived_at=NOW() WHERE status IN ('resolved','contained') AND updated_at < DATE_SUB(NOW(), INTERVAL %d HOUR)"):format(archiveHours)
        local changed = MySQL.update.await(query) or 0
        if changed > 0 then
            loadIncidents()
            broadcast()
        end
    end
end)
