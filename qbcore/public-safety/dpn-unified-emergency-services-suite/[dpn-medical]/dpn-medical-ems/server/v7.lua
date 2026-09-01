local dispatchResponses = {}

local function persist(callId, unitSource, status, data)
    CreateThread(function()
        pcall(function()
            MySQL.insert.await([[
                INSERT INTO dpn_medical_v7_dispatch_responses
                    (call_id, unit_source, unit_name, status, response_data)
                VALUES (?, ?, ?, ?, ?)
            ]], {
                tostring(callId), tonumber(unitSource), tostring(data.unitName or ''), tostring(status), json.encode(data)
            })
        end)
    end)
end

AddEventHandler('dpn-medical:dispatch:callCreated', function(call)
    if type(call) ~= 'table' then return end
    dispatchResponses[tostring(call.id)] = {
        callId = call.id,
        status = call.status or 'open',
        priority = call.priority,
        patient = call.patient,
        coords = call.coords,
        createdAt = call.createdAt or os.time(),
        units = {},
        clinical = call.clinical or {}
    }
    TriggerEvent('dpn-medical:ems:dispatchResponseCreated', dispatchResponses[tostring(call.id)])
end)

AddEventHandler('dpn-medical:dispatch:unitStatusChanged', function(call, unitSource, status)
    if type(call) ~= 'table' then return end
    local key = tostring(call.id)
    dispatchResponses[key] = dispatchResponses[key] or {
        callId = call.id,
        priority = call.priority,
        patient = call.patient,
        coords = call.coords,
        createdAt = call.createdAt or os.time(),
        units = {}
    }
    local response = dispatchResponses[key]
    response.status = call.status or response.status
    response.updatedAt = os.time()
    response.units[tostring(unitSource)] = {
        source = unitSource,
        unitName = GetPlayerName(tonumber(unitSource)) or ('EMS Unit ' .. tostring(unitSource)),
        status = status,
        updatedAt = os.time()
    }
    persist(call.id, unitSource, status, response.units[tostring(unitSource)])
    TriggerEvent('dpn-medical:ems:responseStatusChanged', response, unitSource, status)
end)

exports('GetMedicalDispatchResponses', function()
    return dispatchResponses
end)

exports('GetMedicalDispatchResponse', function(callId)
    return dispatchResponses[tostring(callId)]
end)

exports('CreatePrehospitalHandoff', function(callId, target, destination, narrative, actor)
    local response = dispatchResponses[tostring(callId)]
    if not response then return false, 'Dispatch response not found.' end
    local ok, handoffId = pcall(function()
        return exports['dpn-medical-core']:CreateStructuredHandoff(tonumber(target), destination or 'Emergency Department', {
            situation = narrative or 'Prehospital handoff from active EMS dispatch response.',
            metadata = { callId = callId, source = 'dpn-medical-ems', response = response }
        }, actor or 'ems-dispatch')
    end)
    if not ok or not handoffId then return false, tostring(handoffId or 'Unable to create handoff.') end
    response.handoffId = handoffId
    response.destination = destination
    response.handoffAt = os.time()
    return true, handoffId
end)

CreateThread(function()
    Wait(2500)
    print('[dpn-medical-ems] v4.0.0 dispatch response coordination active')
end)
