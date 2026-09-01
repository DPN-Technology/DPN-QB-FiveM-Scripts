local VERSION = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'unknown'
local pathways, telemetry, trajectories, reconciliations = {}, {}, {}, {}
local resilienceQueue, replayStats = {}, { queued = 0, replayed = 0, failed = 0, lastReplayAt = 0 }

local function now() return os.time() end
local function uid(prefix, target) return ('%s-%s-%s-%04d'):format(prefix, now(), tostring(target or 0), math.random(0, 9999)) end
local function encode(value) local ok, data = pcall(json.encode, value); return ok and data or '{}' end
local function player(target) local ok, p = pcall(function() return exports['qb-core']:GetCoreObject().Functions.GetPlayer(tonumber(target)) end); return ok and p or nil end
local function cid(target) local p = player(target); return p and p.PlayerData and p.PlayerData.citizenid or ('source:%s'):format(tostring(target)) end
local function stateFor(target) if not DPNMedicalServer or not DPNMedicalServer.EnsureState then return nil end; return DPNMedicalServer.EnsureState(tonumber(target)) end
local function commit(target, state, eventType, data)
    local _, patientCid = DPNMedicalServer.EnsureState(tonumber(target))
    if not patientCid then return false end
    DPNMedicalServer.Commit(tonumber(target), patientCid, state, eventType, data or {})
    return true
end
local function persist(sql, params)
    CreateThread(function() pcall(function() MySQL.insert.await(sql, params) end) end)
end

local function queueIntegration(moduleName, eventName, payload, reason)
    local item = { id = uid('RES', payload and payload.target), module = tostring(moduleName or 'unknown'), event = tostring(eventName or 'unknown'), payload = payload or {}, reason = tostring(reason or 'delivery_failed'), attempts = 0, status = 'queued', createdAt = now() }
    resilienceQueue[item.id] = item; replayStats.queued = replayStats.queued + 1
    persist('INSERT INTO dpn_medical_v9_resilience_queue (queue_id,module_name,event_name,payload,status,attempts,last_error) VALUES (?,?,?,?,?,?,?)', { item.id, item.module, item.event, encode(item.payload), item.status, item.attempts, item.reason })
    return item.id, item
end

local function deliver(item)
    if not item then return false, 'missing queue item' end
    item.attempts = (item.attempts or 0) + 1
    local ok, err = pcall(function()
        TriggerEvent(item.event, item.payload)
        TriggerEvent('dpn-medical:server:v9IntegrationReplay', item.module, item.event, item.payload, item.id)
    end)
    if ok then
        item.status = 'replayed'; item.replayedAt = now(); replayStats.replayed = replayStats.replayed + 1
        CreateThread(function() pcall(function() MySQL.update.await('UPDATE dpn_medical_v9_resilience_queue SET status=?,attempts=?,replayed_at=NOW(),last_error=NULL WHERE queue_id=?', { item.status, item.attempts, item.id }) end) end)
        return true
    end
    item.status = 'queued'; item.lastError = tostring(err); replayStats.failed = replayStats.failed + 1
    CreateThread(function() pcall(function() MySQL.update.await('UPDATE dpn_medical_v9_resilience_queue SET attempts=?,last_error=? WHERE queue_id=?', { item.attempts, item.lastError, item.id }) end) end)
    return false, item.lastError
end

exports('GetV9Twin', function(target)
    local state = stateFor(target); return state and DPN_MED.BuildV9Twin(state) or nil
end)

exports('PredictPatientTrajectory', function(target, horizonMinutes)
    local state = stateFor(target); if not state then return false, 'Patient not found.' end
    local result = DPN_MED.PredictV9Trajectory(state, horizonMinutes)
    trajectories[tonumber(target)] = trajectories[tonumber(target)] or {}
    table.insert(trajectories[tonumber(target)], 1, result)
    while #trajectories[tonumber(target)] > 30 do table.remove(trajectories[tonumber(target)]) end
    persist('INSERT INTO dpn_medical_v9_trajectories (trajectory_id,patient_cid,horizon_minutes,trajectory_data) VALUES (?,?,?,?)', { uid('TRJ', target), cid(target), result.horizonMinutes, encode(result) })
    return true, result
end)

exports('CreateAdaptiveCarePathway', function(target, author)
    target = tonumber(target); local state = stateFor(target); if not state then return false, 'Patient not found.' end
    local pathway = DPN_MED.BuildV9CarePathway(state); pathway.id = uid('PATH', target); pathway.target = target; pathway.patientCid = cid(target); pathway.author = tostring(author or 'system')
    pathways[target] = pathways[target] or {}; pathways[target][pathway.id] = pathway
    state.adaptivePathways[pathway.id] = pathway
    commit(target, state, 'v9_adaptive_pathway_created', { pathwayId = pathway.id, author = pathway.author, steps = #pathway.steps })
    persist('INSERT INTO dpn_medical_v9_care_pathways (pathway_id,patient_cid,status,pathway_data,created_by) VALUES (?,?,?,?,?)', { pathway.id, pathway.patientCid, pathway.status, encode(pathway), pathway.author })
    return pathway.id, pathway
end)

exports('CompleteAdaptivePathwayStep', function(target, pathwayId, stepCode, author)
    target = tonumber(target); local pathway = pathways[target] and pathways[target][tostring(pathwayId)]
    if not pathway then return false, 'Adaptive pathway not found.' end
    local selected
    for _, step in ipairs(pathway.steps or {}) do if step.code == stepCode then selected = step break end end
    if not selected then return false, 'Pathway step not found.' end
    selected.status = 'completed'; selected.completedAt = now(); selected.completedBy = tostring(author or 'system')
    local remaining = 0; for _, step in ipairs(pathway.steps or {}) do if step.status ~= 'completed' then remaining = remaining + 1 end end
    if remaining == 0 then pathway.status = 'completed'; pathway.completedAt = now() end
    CreateThread(function() pcall(function() MySQL.update.await('UPDATE dpn_medical_v9_care_pathways SET status=?,pathway_data=?,updated_at=NOW() WHERE pathway_id=?', { pathway.status, encode(pathway), pathway.id }) end) end)
    return true, selected, pathway
end)

exports('GetAdaptiveCarePathways', function(target)
    local rows = {}; for _, item in pairs(pathways[tonumber(target)] or {}) do rows[#rows + 1] = item end
    table.sort(rows, function(a,b) return (a.createdAt or 0) > (b.createdAt or 0) end); return rows
end)

exports('RecordDeviceTelemetry', function(target, deviceType, observations, sourceModule)
    target = tonumber(target); local state = stateFor(target); if not state then return false, 'Patient not found.' end
    local item = { id = uid('TEL', target), target = target, patientCid = cid(target), deviceType = tostring(deviceType or 'monitor'), observations = type(observations) == 'table' and observations or {}, sourceModule = tostring(sourceModule or 'unknown'), recordedAt = now() }
    telemetry[target] = telemetry[target] or {}; table.insert(telemetry[target], 1, item); while #telemetry[target] > 120 do table.remove(telemetry[target]) end
    state.deviceTelemetry[item.deviceType] = item
    commit(target, state, 'v9_device_telemetry', { deviceType = item.deviceType, sourceModule = item.sourceModule })
    persist('INSERT INTO dpn_medical_v9_device_telemetry (telemetry_id,patient_cid,device_type,source_module,telemetry_data) VALUES (?,?,?,?,?)', { item.id, item.patientCid, item.deviceType, item.sourceModule, encode(item) })
    return true, item
end)

exports('GetDeviceTelemetry', function(target, limit)
    local source = telemetry[tonumber(target)] or {}; local out = {}; limit = math.max(1, math.min(120, tonumber(limit) or 30))
    for i = 1, math.min(limit, #source) do out[i] = source[i] end; return out
end)

exports('ReconcilePatientSafetyV9', function(target, author)
    target = tonumber(target); local state = stateFor(target); if not state then return false, 'Patient not found.' end
    local report = DPN_MED.ReconcileV9Safety(state); report.id = uid('SAFE', target); report.target = target; report.patientCid = cid(target); report.author = tostring(author or 'system')
    reconciliations[target] = report; state.safetyReconciliation = report
    commit(target, state, 'v9_safety_reconciled', { reconciliationId = report.id, findings = #report.findings, author = report.author })
    persist('INSERT INTO dpn_medical_v9_safety_reconciliations (reconciliation_id,patient_cid,safety_score,findings,reconciled_by) VALUES (?,?,?,?,?)', { report.id, report.patientCid, report.score, encode(report.findings), report.author })
    return true, report
end)

exports('GetV9OperationalDashboard', function()
    local patients, critical, declining, medicationRisk, queueDepth = {}, 0, 0, 0, 0
    for _, sid in ipairs(GetPlayers() or {}) do
        local target = tonumber(sid); local state = stateFor(target)
        if state then
            local twin = DPN_MED.BuildV9Twin(state)
            if twin.v9.adaptiveRisk >= 80 then critical = critical + 1 end
            if twin.v9.trajectory == 'rapid_decline' or twin.v9.trajectory == 'critical_decline' then declining = declining + 1 end
            if twin.v9.medicationAccumulationRisk >= 25 then medicationRisk = medicationRisk + 1 end
            patients[#patients + 1] = { id = target, citizenid = cid(target), adaptive = twin, pathways = pathways[target], telemetry = telemetry[target] and #telemetry[target] or 0 }
        end
    end
    for _, item in pairs(resilienceQueue) do if item.status == 'queued' then queueDepth = queueDepth + 1 end end
    table.sort(patients, function(a,b) return (a.adaptive.v9.adaptiveRisk or 0) > (b.adaptive.v9.adaptiveRisk or 0) end)
    return { version = VERSION, generatedAt = now(), patients = patients, critical = critical, declining = declining, medicationRisk = medicationRisk, resilienceQueueDepth = queueDepth, replayStats = replayStats }
end)

exports('QueueResilientIntegration', queueIntegration)
exports('GetResilienceQueue', function() local out = {}; for _, item in pairs(resilienceQueue) do out[#out + 1] = item end; table.sort(out, function(a,b) return (a.createdAt or 0) > (b.createdAt or 0) end); return out end)
exports('ReplayResilienceQueue', function(limit)
    limit = math.max(1, math.min(100, tonumber(limit) or 20)); local attempted, succeeded = 0, 0
    for _, item in pairs(resilienceQueue) do
        if attempted >= limit then break end
        if item.status == 'queued' then attempted = attempted + 1; local ok = deliver(item); if ok then succeeded = succeeded + 1 end end
    end
    replayStats.lastReplayAt = now(); return true, { attempted = attempted, succeeded = succeeded, failed = attempted - succeeded }
end)

exports('RunV9SelfTest', function()
    local state = DPN_MED.NewBodyState(); state.vitals.blood = 2600; state.vitals.spo2 = 82; state.vitals.hr = 145; state.vitals.rr = 34; state.vitals.glucose = 420
    state.labs = state.labs or {}; state.labs.sodium = 128; state.labs.potassium = 6.2; state.labs.chloride = 94; state.labs.hco3 = 12; state.labs.creatinine = 3.2; state.labs.bilirubin = 5.0; state.labs.inr = 2.1; state.labs.albumin = 2.4
    state = DPN_MED.Recalculate(state); local twin = DPN_MED.BuildV9Twin(state); local trajectory = DPN_MED.PredictV9Trajectory(state, 30); local safety = DPN_MED.ReconcileV9Safety(state)
    local passed = twin.v9.adaptiveRisk >= 50 and twin.v9.electrolyteRisk >= 30 and trajectory.projectedRisk >= trajectory.currentRisk and #safety.findings > 0
    return { passed = passed, adaptiveRisk = twin.v9.adaptiveRisk, electrolyteRisk = twin.v9.electrolyteRisk, projectedRisk = trajectory.projectedRisk, findings = #safety.findings, disposition = twin.v9.disposition }
end)

AddEventHandler(DPN_MED.Events.StateChanged, function(target)
    target = tonumber(target); local state = stateFor(target); if not state then return end
    DPN_MED.CalculateV9Metrics(state)
    if state.v9.adaptiveRisk >= 85 then
        pcall(function() exports['dpn-medical-core']:RaiseSafetyAlert(target, 'v9_predicted_deterioration', 'critical', 'Adaptive network predicts imminent critical deterioration.', { adaptiveRisk = state.v9.adaptiveRisk, minutes = state.v9.predictedMinutesToCritical, disposition = state.v9.disposition }, 'dpn-medical-core-v9') end)
    end
end)

CreateThread(function()
    Wait(4200)
    print('[dpn-medical-core] v9.0.0 adaptive trajectory, medication kinetics, safety reconciliation and resilient network active')
    while true do
        Wait(30000)
        pcall(function() exports['dpn-medical-core']:ReplayResilienceQueue(10) end)
    end
end)

RegisterCommand('medadaptive', function(src, args)
    local target = tonumber(args[1] or src); local twin = exports['dpn-medical-core']:GetV9Twin(target)
    local msg = twin and ('Adaptive risk %s%% | Recovery %s%% | %s | Critical in %s min | Disposition %s'):format(twin.v9.adaptiveRisk, twin.v9.recoveryProbability, twin.v9.trajectory, twin.v9.predictedMinutesToCritical, twin.v9.disposition) or 'Patient unavailable.'
    if src == 0 then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { 'DPN Adaptive', msg } }) end
end, false)

RegisterCommand('medresilience', function(src)
    local report = exports['dpn-medical-core']:ReplayResilienceQueue(50)
    local msg = ('Resilience replay requested: %s'):format(encode(report))
    if src == 0 then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { 'DPN Medical', msg } }) end
end, true)
