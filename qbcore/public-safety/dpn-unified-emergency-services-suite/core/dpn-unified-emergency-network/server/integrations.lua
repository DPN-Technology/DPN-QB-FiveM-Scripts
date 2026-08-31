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
