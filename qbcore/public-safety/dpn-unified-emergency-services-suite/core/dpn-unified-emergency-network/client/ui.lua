RegisterCommand(DPN_UNES.Config.DispatchCommand, function()
    TriggerServerEvent('dpn-unes:server:createIncident', {
        type = 'custom',
        title = 'Field Dispatch Request',
        description = 'Manual field-created dispatch request.',
        priority = 3
    })
end, false)
