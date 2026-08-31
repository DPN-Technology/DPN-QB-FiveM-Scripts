-- Add this style of export/event inside dpn-dispatch when a new call is created.

local function SendCallToDpnMdt(call)
    if GetResourceState('dpn-mdt') ~= 'started' then return end

    exports['dpn-mdt']:CreateDispatchCall({
        call_id = call.id,
        code = call.code or call.callCode or '911',
        title = call.title or call.message or 'Emergency Call',
        description = call.description or call.message or '',
        priority = call.priority or 'normal',
        department = call.department or call.job or 'shared',
        caller = call.caller or 'Dispatch',
        location = call.location or call.street or 'Unknown Location',
        coords = call.coords or {},
        metadata = {
            source = 'dpn-dispatch',
            original = call
        }
    })
end

-- Example usage when dpn-dispatch creates a 911 call:
-- SendCallToDpnMdt(newCall)

RegisterNetEvent('dpn-dispatch:server:NewCall', function(call)
    SendCallToDpnMdt(call)
end)
