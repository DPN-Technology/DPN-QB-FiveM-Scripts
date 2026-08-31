-- Integration examples from other DPN systems:
-- TriggerEvent('dpn-unes:client:createIncident', { type = 'shots', title = 'Shots Fired', priority = 1 })
RegisterNetEvent('dpn-unes:client:createIncident', function(data)
    TriggerServerEvent('dpn-unes:server:createIncident', data)
end)

-- StarChase hook example
RegisterNetEvent('dpn-starchase:client:trackerFired', function(vehicleNetId, coords)
    TriggerServerEvent('dpn-unes:server:createIncident', {
        type = 'pursuit',
        title = 'StarChase Tracker Deployed',
        description = 'GPS tracker deployed during a pursuit. Units can coordinate through UNES.',
        priority = 2,
        coords = coords
    })
end)
