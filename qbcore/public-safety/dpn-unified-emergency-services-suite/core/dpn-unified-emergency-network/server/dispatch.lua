local function agencyMatches(unitAgency, incidentAgencies)
    for _, agency in ipairs(incidentAgencies or {}) do if agency == unitAgency or agency == 'all' then return true end end
    return false
end

AddEventHandler('dpn-unes:server:broadcastIncident', function(incident)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local unit = DPN_UNES.Server.GetUnitProfile(src)
        if unit and unit.onduty and (agencyMatches(unit.agency, incident.agencies) or unit.canDispatch or unit.agency == 'admin') then
            TriggerClientEvent('dpn-unes:client:newIncident', src, incident)
            TriggerClientEvent('QBCore:Notify', src, ('%s | Priority %s'):format(incident.title, incident.priority), 'primary', 8500)
        end
    end
end)

RegisterCommand('dispatchcall', function(src, args)
    if src == 0 or not DPN_UNES.Server.IsEmergencyUnit(src) then return end
    local msg = table.concat(args or {}, ' ')
    TriggerEvent('dpn-unes:server:createIncident', src, {
        type = 'custom', title = 'Field Dispatch Request', description = msg ~= '' and msg or 'No details provided.', priority = 3
    })
end, false)
