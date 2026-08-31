exports('GetActiveIncidents', function()
    return DPN_UNES.Cache.incidents
end)

exports('GetActiveUnits', function()
    return DPN_UNES.Cache.units
end)

exports('RequestSupport', function(incidentId, agencies, note)
    local incident = DPN_UNES.Cache.incidents[incidentId]
    if not incident then return false end
    incident.agencies = incident.agencies or {}
    local exists = {}; for _, a in ipairs(incident.agencies) do exists[a] = true end
    for _, agency in ipairs(agencies or {}) do
        if agency and not exists[agency] then table.insert(incident.agencies, agency); exists[agency] = true end
    end
    incident.history = incident.history or {}
    table.insert(incident.history, { time = os.time(), action = 'support-request-export', callsign = 'SYSTEM', note = note or 'Support requested.' })
    TriggerEvent('dpn-unes:server:broadcastIncident', incident)
    TriggerClientEvent('dpn-unes:client:incidentUpdated', -1, incident)
    return true
end)

exports('LinkRecord', function(incidentId, systemName, recordType, recordId, metadata)
    TriggerEvent('dpn-unes:server:linkRecord', incidentId, systemName, recordType, recordId, metadata or {})
    return true
end)
