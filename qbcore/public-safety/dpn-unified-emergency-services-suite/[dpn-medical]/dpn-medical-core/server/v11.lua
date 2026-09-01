local VERSION = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'unknown'
local plans, reassessments, checkpoints, networkEvents = {}, {}, {}, {}

local function now() return os.time() end
local function uid(prefix, target) return ('%s-%s-%s-%04d'):format(prefix, now(), tostring(target or 0), math.random(0, 9999)) end
local function encode(value) local ok, data = pcall(json.encode, value); return ok and data or '{}' end
local function player(target)
    local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if not ok or not core or not core.Functions then return nil end
    local got, value = pcall(function() return core.Functions.GetPlayer(tonumber(target)) end)
    return got and value or nil
end
local function cid(target)
    local p = player(target)
    return p and p.PlayerData and p.PlayerData.citizenid or ('source:%s'):format(tostring(target))
end
local function stateFor(target)
    if not DPNMedicalServer or not DPNMedicalServer.EnsureState then return nil end
    return DPNMedicalServer.EnsureState(tonumber(target))
end
local function commit(target, state, eventType, data)
    local _, patientCid = DPNMedicalServer.EnsureState(tonumber(target))
    if not patientCid then return false end
    DPNMedicalServer.Commit(tonumber(target), patientCid, state, eventType, data or {})
    return true
end
local function persist(sql, params, update)
    CreateThread(function()
        pcall(function()
            if update then MySQL.update.await(sql, params) else MySQL.insert.await(sql, params) end
        end)
    end)
end
local function record(target, eventType, payload, sourceModule)
    local item = {
        id = uid('NET11', target), target = tonumber(target), patientCid = cid(target),
        eventType = tostring(eventType or 'event'), sourceModule = tostring(sourceModule or 'dpn-medical-core'),
        payload = type(payload) == 'table' and payload or {}, recordedAt = now()
    }
    networkEvents[tonumber(target)] = networkEvents[tonumber(target)] or {}
    table.insert(networkEvents[tonumber(target)], 1, item)
    while #networkEvents[tonumber(target)] > 300 do table.remove(networkEvents[tonumber(target)]) end
    persist('INSERT INTO dpn_medical_v11_network_events (event_id,patient_cid,event_type,source_module,event_data) VALUES (?,?,?,?,?)', {
        item.id, item.patientCid, item.eventType, item.sourceModule, encode(item.payload)
    })
    return item
end

exports('GetV11Twin', function(target)
    local state = stateFor(target)
    return state and DPN_MED.BuildV11Twin(state) or nil
end)

exports('ForecastInterventionV11', function(target, intervention, horizonMinutes, actor)
    target = tonumber(target)
    local state = stateFor(target)
    if not state then return false, 'Patient not found.' end
    local result = DPN_MED.ForecastInterventionV11(state, intervention, horizonMinutes)
    result.actor = tostring(actor or 'system')
    record(target, 'intervention_forecast', result, 'dpn-medical-core-v11')
    return true, result
end)

exports('CreateAutonomousCarePlanV11', function(target, author)
    target = tonumber(target)
    local state = stateFor(target)
    if not state then return false, 'Patient not found.' end
    local plan = DPN_MED.BuildAutonomousCarePlanV11(state)
    plan.id = uid('ACP11', target)
    plan.target = target
    plan.patientCid = cid(target)
    plan.author = tostring(author or 'system')
    plans[target] = plans[target] or {}
    plans[target][plan.id] = plan
    state.autonomousCarePlans[plan.id] = plan
    state.v11.autonomousPlanStatus = 'draft'
    commit(target, state, 'v11_autonomous_plan_created', { planId = plan.id, steps = #plan.steps, author = plan.author })
    persist('INSERT INTO dpn_medical_v11_autonomous_plans (plan_id,patient_cid,status,risk_score,plan_data,created_by) VALUES (?,?,?,?,?,?)', {
        plan.id, plan.patientCid, plan.status, plan.risk, encode(plan), plan.author
    })
    record(target, 'autonomous_plan_created', { planId = plan.id, steps = #plan.steps }, 'dpn-medical-core-v11')
    TriggerEvent('dpn-medical:server:v11PlanCreated', plan)
    return plan.id, plan
end)

exports('ApproveAutonomousCarePlanV11', function(target, planId, approver)
    target = tonumber(target)
    local plan = plans[target] and plans[target][tostring(planId)]
    if not plan then return false, 'Autonomous care plan not found.' end
    plan.status = 'approved'
    plan.approvedBy = tostring(approver or 'unknown')
    plan.approvedAt = now()
    for _, step in ipairs(plan.steps or {}) do
        if step.status == 'awaiting_approval' then step.status = 'approved' end
    end
    local state = stateFor(target)
    if state then
        state.v11.autonomousPlanStatus = 'approved'
        commit(target, state, 'v11_autonomous_plan_approved', { planId = plan.id, approver = plan.approvedBy })
    end
    persist('UPDATE dpn_medical_v11_autonomous_plans SET status=?,plan_data=?,approved_by=?,updated_at=NOW() WHERE plan_id=?', {
        plan.status, encode(plan), plan.approvedBy, plan.id
    }, true)
    record(target, 'autonomous_plan_approved', { planId = plan.id, approver = plan.approvedBy }, 'dpn-medical-core-v11')
    return true, plan
end)

exports('CompleteAutonomousStepV11', function(target, planId, stepId, actor, evidence)
    target = tonumber(target)
    local plan = plans[target] and plans[target][tostring(planId)]
    if not plan then return false, 'Autonomous care plan not found.' end
    local selected
    for _, step in ipairs(plan.steps or {}) do
        if tostring(step.id) == tostring(stepId) or tostring(step.code) == tostring(stepId) then selected = step break end
    end
    if not selected then return false, 'Care-plan step not found.' end
    if selected.requiresHumanApproval and plan.status ~= 'approved' then return false, 'Plan requires human approval before execution.' end
    selected.status = 'completed'
    selected.completedAt = now()
    selected.completedBy = tostring(actor or 'system')
    selected.evidence = evidence
    local remaining = 0
    for _, step in ipairs(plan.steps or {}) do if step.status ~= 'completed' then remaining = remaining + 1 end end
    if remaining == 0 then plan.status = 'complete'; plan.completedAt = now() end
    persist('UPDATE dpn_medical_v11_autonomous_plans SET status=?,plan_data=?,updated_at=NOW() WHERE plan_id=?', {
        plan.status, encode(plan), plan.id
    }, true)
    record(target, 'autonomous_step_completed', { planId = plan.id, step = selected.code, remaining = remaining }, 'dpn-medical-core-v11')
    return true, selected, plan
end)

exports('GetAutonomousCarePlansV11', function(target)
    local out = {}
    for _, plan in pairs(plans[tonumber(target)] or {}) do out[#out + 1] = plan end
    table.sort(out, function(a, b) return (a.createdAt or 0) > (b.createdAt or 0) end)
    return out
end)

exports('StartContinuousReassessmentV11', function(target, intervalSeconds, actor)
    target = tonumber(target)
    if not stateFor(target) then return false, 'Patient not found.' end
    intervalSeconds = math.max(10, math.min(300, tonumber(intervalSeconds) or 30))
    reassessments[target] = {
        target = target, intervalSeconds = intervalSeconds, actor = tostring(actor or 'system'),
        status = 'active', nextRunAt = now(), startedAt = now(), runs = 0, alerts = 0
    }
    persist('INSERT INTO dpn_medical_v11_reassessments (patient_cid,status,interval_seconds,reassessment_data,started_by) VALUES (?,?,?,?,?)', {
        cid(target), 'active', intervalSeconds, encode(reassessments[target]), reassessments[target].actor
    })
    record(target, 'continuous_reassessment_started', reassessments[target], 'dpn-medical-core-v11')
    return true, reassessments[target]
end)

exports('StopContinuousReassessmentV11', function(target, actor)
    target = tonumber(target)
    local item = reassessments[target]
    if not item then return false, 'No active continuous reassessment.' end
    item.status = 'stopped'; item.stoppedAt = now(); item.stoppedBy = tostring(actor or 'system')
    reassessments[target] = nil
    record(target, 'continuous_reassessment_stopped', item, 'dpn-medical-core-v11')
    return true, item
end)

exports('ReconcileDevicesAndMedicationsV11', function(target, actor)
    target = tonumber(target)
    local state = stateFor(target)
    if not state then return false, 'Patient not found.' end
    local report = DPN_MED.ReconcileDevicesAndMedicationsV11(state)
    report.id = uid('REC11', target)
    report.target = target
    report.patientCid = cid(target)
    report.actor = tostring(actor or 'system')
    persist('INSERT INTO dpn_medical_v11_decision_checkpoints (checkpoint_id,patient_cid,checkpoint_type,status,checkpoint_data,created_by) VALUES (?,?,?,?,?,?)', {
        report.id, report.patientCid, 'device_medication_reconciliation', report.score >= 80 and 'clear' or 'attention_required', encode(report), report.actor
    })
    record(target, 'device_medication_reconciliation', report, 'dpn-medical-core-v11')
    return true, report
end)

exports('GenerateWaveformSnapshotV11', function(target, sampleCount, actor)
    target = tonumber(target)
    local state = stateFor(target)
    if not state then return false, 'Patient not found.' end
    local snapshot = DPN_MED.BuildWaveformSnapshotV11(state, sampleCount)
    snapshot.id = uid('WAVE11', target)
    snapshot.target = target
    snapshot.patientCid = cid(target)
    snapshot.actor = tostring(actor or 'system')
    state.waveformSnapshots[snapshot.id] = snapshot
    commit(target, state, 'v11_waveform_snapshot', { snapshotId = snapshot.id, rhythm = snapshot.rhythm })
    record(target, 'waveform_snapshot', { id = snapshot.id, rhythm = snapshot.rhythm, hr = snapshot.hr, spo2 = snapshot.spo2 }, 'dpn-medical-core-v11')
    return true, snapshot
end)

exports('CreateDecisionCheckpointV11', function(target, checkpointType, context, actor)
    target = tonumber(target)
    local twin = exports['dpn-medical-core']:GetV11Twin(target)
    if type(twin) ~= 'table' then return false, 'Patient not found.' end
    local item = {
        id = uid('CHK11', target), target = target, patientCid = cid(target),
        checkpointType = tostring(checkpointType or 'clinical_review'), context = type(context) == 'table' and context or {},
        risk = twin.v11.autonomousRisk, mortality = twin.v11.predictedMortality,
        priority = twin.v11.clinicalPriority, status = 'open', actor = tostring(actor or 'system'), createdAt = now()
    }
    checkpoints[item.id] = item
    persist('INSERT INTO dpn_medical_v11_decision_checkpoints (checkpoint_id,patient_cid,checkpoint_type,status,checkpoint_data,created_by) VALUES (?,?,?,?,?,?)', {
        item.id, item.patientCid, item.checkpointType, item.status, encode(item), item.actor
    })
    record(target, 'decision_checkpoint_created', item, 'dpn-medical-core-v11')
    return item.id, item
end)

exports('ResolveDecisionCheckpointV11', function(checkpointId, decision, actor, notes)
    local item = checkpoints[tostring(checkpointId)]
    if not item then return false, 'Decision checkpoint not found.' end
    item.status = 'resolved'; item.decision = decision; item.resolvedBy = tostring(actor or 'system'); item.notes = notes; item.resolvedAt = now()
    persist('UPDATE dpn_medical_v11_decision_checkpoints SET status=?,checkpoint_data=?,updated_at=NOW() WHERE checkpoint_id=?', {
        item.status, encode(item), item.id
    }, true)
    record(item.target, 'decision_checkpoint_resolved', item, 'dpn-medical-core-v11')
    return true, item
end)

exports('GetV11NetworkDashboard', function()
    local patients, immediate, critical, highIntensity, activeReassessments, openPlans = {}, 0, 0, 0, 0, 0
    for _, sid in ipairs(GetPlayers() or {}) do
        local target = tonumber(sid)
        local state = stateFor(target)
        if state then
            local twin = DPN_MED.BuildV11Twin(state)
            if twin.v11.clinicalPriority == 'immediate' then immediate = immediate + 1 end
            if twin.v11.autonomousRisk >= 70 then critical = critical + 1 end
            if twin.v11.resourceIntensity >= 70 then highIntensity = highIntensity + 1 end
            local planCount = 0
            for _, plan in pairs(plans[target] or {}) do if plan.status ~= 'complete' then planCount = planCount + 1 end end
            openPlans = openPlans + planCount
            patients[#patients + 1] = {
                id = target, citizenid = cid(target), twin = twin, activePlanCount = planCount,
                continuousReassessment = reassessments[target] ~= nil
            }
        end
    end
    for _ in pairs(reassessments) do activeReassessments = activeReassessments + 1 end
    table.sort(patients, function(a, b) return (a.twin.v11.autonomousRisk or 0) > (b.twin.v11.autonomousRisk or 0) end)
    return {
        version = VERSION, generatedAt = now(), patients = patients, immediate = immediate,
        critical = critical, highIntensity = highIntensity, activeReassessments = activeReassessments,
        openPlans = openPlans, networkEventCount = (function() local n = 0; for _, rows in pairs(networkEvents) do n = n + #rows end; return n end)()
    }
end)

exports('GetV11NetworkEvents', function(target, limit)
    local rows, source = {}, networkEvents[tonumber(target)] or {}
    limit = math.max(1, math.min(300, tonumber(limit) or 50))
    for index = 1, math.min(limit, #source) do rows[index] = source[index] end
    return rows
end)

exports('RunV11SelfTest', function()
    local shared = DPN_MED.RunV11SharedSelfTest()
    local passed = shared and shared.passed == true
    return {
        passed = passed, shared = shared, version = VERSION,
        exports = { 'GetV11Twin', 'ForecastInterventionV11', 'CreateAutonomousCarePlanV11',
            'StartContinuousReassessmentV11', 'ReconcileDevicesAndMedicationsV11', 'GenerateWaveformSnapshotV11' }
    }
end)

AddEventHandler(DPN_MED.Events.StateChanged, function(target, patientCid, changedState, eventType, data)
    target = tonumber(target)
    local state = type(changedState) == 'table' and changedState or stateFor(target)
    if not state then return end
    DPN_MED.CalculateV11Metrics(state)
    record(target, eventType or 'state_changed', data or { risk = state.v11.autonomousRisk, patientCid = patientCid }, 'dpn-medical-core-v11')
    if state.v11.autonomousRisk >= 88 then
        pcall(function()
            exports['dpn-medical-core']:RaiseSafetyAlert(target, 'v11_autonomous_critical', 'critical',
                'Autonomous-care model predicts immediate multi-system deterioration.', {
                    risk = state.v11.autonomousRisk, mortality = state.v11.predictedMortality,
                    levelOfCare = state.v11.predictedLevelOfCare, interventionDelayRisk = state.v11.interventionDelayRisk
                }, 'dpn-medical-core-v11')
        end)
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        local stamp = now()
        for target, item in pairs(reassessments) do
            if item.status == 'active' and stamp >= (item.nextRunAt or 0) then
                local state = stateFor(target)
                if not state then
                    reassessments[target] = nil
                else
                    local before = tonumber(state.v11 and state.v11.autonomousRisk) or 0
                    DPN_MED.CalculateV11Metrics(state)
                    local after = state.v11.autonomousRisk
                    item.runs = (item.runs or 0) + 1
                    item.lastRisk = after
                    item.nextRunAt = stamp + item.intervalSeconds
                    if after >= 85 and before < 85 then
                        item.alerts = (item.alerts or 0) + 1
                        pcall(function()
                            exports['dpn-medical-core']:RaiseSafetyAlert(target, 'v11_reassessment_escalation', 'critical',
                                'Continuous reassessment detected escalation to immediate risk.', { before = before, after = after }, 'dpn-medical-core-v11')
                        end)
                    end
                    commit(target, state, 'v11_continuous_reassessment', { before = before, after = after, run = item.runs })
                end
            end
        end
    end
end)

CreateThread(function()
    Wait(4800)
    print('[dpn-medical-core] v11.0.0 autonomous-care network, intervention forecasting and continuous reassessment active')
end)

RegisterCommand('medv11', function(src, args)
    local target = tonumber(args[1] or src)
    local twin = exports['dpn-medical-core']:GetV11Twin(target)
    local message = twin and ('V11 risk %s%% | mortality %s%% | homeostasis %s%% | priority %s | care %s | tissue O2 %s%%'):format(
        twin.v11.autonomousRisk, twin.v11.predictedMortality, twin.v11.homeostasisScore,
        twin.v11.clinicalPriority, twin.v11.predictedLevelOfCare, twin.microcirculation.tissueOxygenation
    ) or 'Patient unavailable.'
    if src == 0 then print(message) else TriggerClientEvent('chat:addMessage', src, { args = { 'DPN Medical v11', message } }) end
end, false)

RegisterCommand('medv11test', function(src)
    local report = exports['dpn-medical-core']:RunV11SelfTest()
    local message = ('V11 self-test passed=%s risk=%s endocrine=%s infection=%s planSteps=%s'):format(
        tostring(report.passed), tostring(report.shared and report.shared.risk), tostring(report.shared and report.shared.endocrineRisk),
        tostring(report.shared and report.shared.infectionProbability), tostring(report.shared and report.shared.planSteps)
    )
    if src == 0 then print(message) else TriggerClientEvent('chat:addMessage', src, { args = { 'DPN Medical v11', message } }) end
end, false)

RegisterNetEvent('dpn-medical-core:server:requestV11Snapshot', function()
    local src = source
    local twin = exports['dpn-medical-core']:GetV11Twin(src)
    TriggerClientEvent('dpn-medical-core:client:v11Snapshot', src, twin)
    TriggerClientEvent('dpn-medical-core:client:v11Summary', src, twin and ('Risk %s%% | %s | Homeostasis %s%%'):format(
        twin.v11.autonomousRisk, twin.v11.predictedLevelOfCare, twin.v11.homeostasisScore
    ) or 'No medical state available.')
end)
