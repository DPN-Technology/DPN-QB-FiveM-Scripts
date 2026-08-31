local dispatchFleet = {}

AddEventHandler('dpn-medical:dispatch:unitStatusChanged', function(call, unitSource, status)
    unitSource = tonumber(unitSource)
    if not unitSource then return end
    dispatchFleet[tostring(unitSource)] = {
        source = unitSource,
        unitName = GetPlayerName(unitSource) or ('EMS Unit ' .. tostring(unitSource)),
        callId = call and call.id,
        callPriority = call and call.priority,
        status = status,
        coords = call and call.coords,
        updatedAt = os.time()
    }
    TriggerEvent('dpn-medical:ambulance:dispatchStatusChanged', dispatchFleet[tostring(unitSource)])
end)

exports('GetDispatchFleetBoard', function()
    return dispatchFleet
end)

exports('SetAmbulanceDispatchAvailability', function(unitSource, available, reason)
    unitSource = tonumber(unitSource)
    if not unitSource then return false, 'Invalid unit.' end
    dispatchFleet[tostring(unitSource)] = dispatchFleet[tostring(unitSource)] or {
        source = unitSource,
        unitName = GetPlayerName(unitSource) or ('EMS Unit ' .. tostring(unitSource))
    }
    local unit = dispatchFleet[tostring(unitSource)]
    unit.status = available and 'available' or 'unavailable'
    unit.unavailableReason = available and nil or reason
    unit.updatedAt = os.time()
    TriggerEvent('dpn-medical:ambulance:availabilityChanged', unit)
    return true, unit
end)

CreateThread(function()
    Wait(2900)
    pcall(function()
        exports['dpn-medical-core']:RegisterModule('dpn-medical-ambulance', '4.0.0', {
            'fleet_management', 'vehicle_readiness', 'crew_assignment', 'dispatch_availability', 'unit_status_board'
        })
    end)
    print('[dpn-medical-ambulance] v4.0.0 dispatch fleet readiness board active')
end)
