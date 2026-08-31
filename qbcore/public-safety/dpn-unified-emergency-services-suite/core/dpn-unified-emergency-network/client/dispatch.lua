local activeIncidentBlips = {}

local function createIncidentBlip(incident)
    if not DPN_UNES.Config.AlertBlips.Enabled or not incident.coords then return end
    if activeIncidentBlips[incident.id] and DoesBlipExist(activeIncidentBlips[incident.id]) then
        RemoveBlip(activeIncidentBlips[incident.id])
    end
    local blip = AddBlipForCoord(incident.coords.x, incident.coords.y, incident.coords.z)
    SetBlipSprite(blip, DPN_UNES.Config.AlertBlips.Sprite)
    SetBlipScale(blip, DPN_UNES.Config.AlertBlips.Scale)
    SetBlipColour(blip, DPN_UNES.Config.AlertBlips.Colors[(incident.agencies or {'law'})[1]] or 1)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('[%s] %s'):format(incident.id, incident.title))
    EndTextCommandSetBlipName(blip)
    activeIncidentBlips[incident.id] = blip
    SetTimeout(DPN_UNES.Config.AlertBlips.TimeMs, function()
        if activeIncidentBlips[incident.id] == blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
            activeIncidentBlips[incident.id] = nil
        end
    end)
end

RegisterNetEvent('dpn-unes:client:newIncident', function(incident)
    createIncidentBlip(incident)
    SendNUIMessage({ action = 'newIncident', incident = incident })
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
    TriggerEvent('QBCore:Notify', ('UNES Alert: %s | Priority %s'):format(incident.title, incident.priority), 'primary', 9000)
end)

RegisterNetEvent('dpn-unes:client:incidentUpdated', function(incident)
    SendNUIMessage({ action = 'incidentUpdated', incident = incident })
end)
