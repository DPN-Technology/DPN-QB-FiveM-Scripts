-- Example bridge for dpn-unified-emergency-network.

RegisterNetEvent('dpn-uen:server:IncidentCreated', function(incident)
    if GetResourceState('dpn-mdt') ~= 'started' then return end

    exports['dpn-mdt']:CreateDispatchCall({
        call_id = incident.id,
        code = incident.code or 'UEN',
        title = incident.title or 'Unified Network Incident',
        description = incident.description or '',
        priority = incident.priority or 'normal',
        department = incident.department or 'shared',
        caller = incident.createdBy or 'Unified Emergency Network',
        location = incident.location or 'Unknown Location',
        coords = incident.coords or {},
        metadata = {
            source = 'dpn-unified-emergency-network',
            linkedUnits = incident.units,
            linkedResources = incident.resources
        }
    })
end)

-- When MDT updates a record, dpn-mdt triggers Config.UnifiedNetwork.incidentEvent.
-- Listen for that event inside your network resource if you want two-way syncing.
