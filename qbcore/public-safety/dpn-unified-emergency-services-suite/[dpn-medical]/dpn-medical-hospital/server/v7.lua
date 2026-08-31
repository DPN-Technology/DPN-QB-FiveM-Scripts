local prealerts = {}

local function callKey(callId) return tostring(callId or '') end

local function persist(prealert)
    CreateThread(function()
        pcall(function()
            MySQL.insert.await([[
                INSERT INTO dpn_medical_v7_hospital_prealerts
                    (call_id, patient_cid, priority, destination, status, prealert_data)
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE priority = VALUES(priority), destination = VALUES(destination),
                    status = VALUES(status), prealert_data = VALUES(prealert_data), updated_at = CURRENT_TIMESTAMP
            ]], {
                tostring(prealert.callId), prealert.patientCid, prealert.priority,
                prealert.destination, prealert.status, json.encode(prealert)
            })
        end)
    end)
end

AddEventHandler('dpn-medical:dispatch:callCreated', function(call)
    if type(call) ~= 'table' or tonumber(call.priority or 5) > 2 then return end
    local patient = type(call.patient) == 'table' and call.patient or {}
    local prealert = {
        callId = call.id,
        patientSource = patient.source,
        patientCid = patient.citizenid,
        patientName = patient.name,
        priority = call.priority,
        status = 'incoming',
        destination = 'Emergency Department',
        etaMinutes = nil,
        clinical = call.clinical or patient.clinical or {},
        coords = call.coords,
        createdAt = os.time(),
        acknowledged = false
    }
    prealerts[callKey(call.id)] = prealert
    persist(prealert)
    TriggerEvent('dpn-medical:hospital:prealertCreated', prealert)
end)

AddEventHandler('dpn-medical:dispatch:unitStatusChanged', function(call, unitSource, status)
    if type(call) ~= 'table' then return end
    local prealert = prealerts[callKey(call.id)]
    if not prealert then return end
    prealert.transportUnit = unitSource
    prealert.status = status == 'transporting' and 'transporting' or (status == 'onscene' and 'scene-care' or prealert.status)
    prealert.updatedAt = os.time()
    persist(prealert)
    TriggerEvent('dpn-medical:hospital:prealertUpdated', prealert)
end)

exports('GetHospitalPrealerts', function()
    return prealerts
end)

exports('AcknowledgeHospitalPrealert', function(callId, actor, destination, etaMinutes)
    local prealert = prealerts[callKey(callId)]
    if not prealert then return false, 'Prealert not found.' end
    prealert.acknowledged = true
    prealert.acknowledgedBy = actor or 'hospital-command'
    prealert.acknowledgedAt = os.time()
    prealert.destination = destination or prealert.destination
    prealert.etaMinutes = tonumber(etaMinutes) or prealert.etaMinutes
    prealert.status = 'acknowledged'
    persist(prealert)
    TriggerEvent('dpn-medical:hospital:prealertAcknowledged', prealert)
    return true, prealert
end)

exports('CloseHospitalPrealert', function(callId, actor, disposition)
    local prealert = prealerts[callKey(callId)]
    if not prealert then return false, 'Prealert not found.' end
    prealert.status = 'closed'
    prealert.closedBy = actor or 'hospital-command'
    prealert.closedAt = os.time()
    prealert.disposition = disposition
    persist(prealert)
    return true, prealert
end)

CreateThread(function()
    Wait(2700)
    pcall(function()
        exports['dpn-medical-core']:RegisterModule('dpn-medical-hospital', '5.0.0', {
            'admissions', 'bed_management', 'ed_command', 'surge_capacity', 'transfer_center',
            'dispatch_prealerts', 'incoming_patient_coordination'
        })
    end)
    print('[dpn-medical-hospital] v5.0.0 dispatch prealert and receiving-center coordination active')
end)
