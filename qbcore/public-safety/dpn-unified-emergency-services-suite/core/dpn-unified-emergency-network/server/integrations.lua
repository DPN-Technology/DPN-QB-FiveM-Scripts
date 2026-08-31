local function safeTrigger(eventName, ...)
    if eventName and eventName ~= '' then
        TriggerEvent(eventName, ...)
    end
end

RegisterNetEvent('dpn-unes:server:integrationIncidentCreated', function(incident)
    -- These are safe hooks. Your existing resources can listen for them without hard dependency crashes.
    safeTrigger('dpn-law:server:unesIncident', incident)
    safeTrigger('dpn-medical:server:unesIncident', incident)
    safeTrigger('dpn-fire:server:unesIncident', incident)
    safeTrigger('dpn-justice:server:unesIncident', incident)
    safeTrigger('dpn-corrections:server:unesIncident', incident)
    safeTrigger('dpn-bail:server:unesIncident', incident)
    safeTrigger('dpn-mib:server:unesIncident', incident)

    if DPN_UNES.Config.Integrations.DiscordWebhook and DPN_UNES.Config.Integrations.DiscordWebhook ~= '' then
        PerformHttpRequest(DPN_UNES.Config.Integrations.DiscordWebhook, function() end, 'POST', json.encode({
            username = 'DPN UNES',
            embeds = {{
                title = incident.title,
                description = incident.description,
                color = 16711680,
                fields = {
                    { name = 'Incident ID', value = incident.id, inline = true },
                    { name = 'Priority', value = tostring(incident.priority), inline = true },
                    { name = 'Postal', value = incident.postal or 'Unknown', inline = true },
                    { name = 'Agencies', value = table.concat(incident.agencies or {}, ', '), inline = false }
                }
            }}
        }), { ['Content-Type'] = 'application/json' })
    end
end)


-- DPN MDT integration adapter.
-- These are local server events fired by dpn-mdt; they are intentionally not RegisterNetEvent handlers.
local MDT_STATUS_MAP = {
    new = 'created',
    pending = 'created',
    assigned = 'assigned',
    enroute = 'enroute',
    onscene = 'onscene',
    staged = 'staged',
    transporting = 'transporting',
    at_hospital = 'hospital',
    hospital = 'hospital',
    clear = 'resolved',
    cleared = 'resolved',
    closed = 'resolved',
    resolved = 'resolved',
    cancelled = 'archived',
    archived = 'archived'
}

AddEventHandler('dpn-unes:server:mdtIncidentUpdated', function(payload)
    if type(payload) ~= 'table' then return end
    local incidentId = tostring(payload.id or payload.call_id or '')
    if incidentId == '' then return end
    local incident = DPN_UNES.Cache.incidents and DPN_UNES.Cache.incidents[incidentId]
    if not incident then return end

    local mappedStatus = MDT_STATUS_MAP[tostring(payload.status or '')]
    if mappedStatus then incident.status = mappedStatus end
    incident.updatedAt = os.time()
    incident.history = incident.history or {}
    incident.history[#incident.history + 1] = {
        time = os.time(),
        action = 'mdt-sync',
        callsign = 'DPN-MDT',
        note = tostring(payload.status or 'updated')
    }

    MySQL.update('UPDATE dpn_unes_incidents SET status = ?, history = ?, payload = ?, updated_at = NOW() WHERE incident_id = ?', {
        incident.status,
        json.encode(incident.history),
        json.encode(incident),
        incidentId
    })
    TriggerClientEvent('dpn-unes:client:incidentUpdated', -1, incident)
end)

AddEventHandler('dpn-unes:server:mdtUnitStatusChanged', function(payload)
    if type(payload) ~= 'table' then return end
    local citizenid = tostring(payload.citizenid or '')
    local status = tostring(payload.status or '')
    if citizenid == '' or not DPN_UNES.Cache.units then return end

    local allowed = false
    for _, value in ipairs(DPN_UNES.Config.UnitStatuses or {}) do
        if value == status then allowed = true break end
    end
    if not allowed then return end

    for _, unit in pairs(DPN_UNES.Cache.units) do
        if tostring(unit.citizenid or '') == citizenid then
            unit.status = status
            unit.lastSeen = os.time()
            TriggerClientEvent('dpn-unes:client:unitUpdated', -1, unit)
            break
        end
    end
end)

AddEventHandler('dpn-unes:server:mdtRecordLinked', function(payload)
    if type(payload) ~= 'table' then return end
    local data = type(payload.data) == 'table' and payload.data or {}
    local metadata = type(data.metadata) == 'table' and data.metadata or {}
    local incidentId = tostring(payload.incidentId or data.incidentId or metadata.unifiedIncidentId or '')
    if incidentId == '' or not (DPN_UNES.Cache.incidents and DPN_UNES.Cache.incidents[incidentId]) then return end

    TriggerEvent('dpn-unes:server:linkRecord',
        incidentId,
        'dpn-mdt',
        tostring(payload.type or 'record'),
        tostring(payload.id or data.id or ''),
        payload
    )
end)
