local VERSION = '8.0.0'
local QBCore = exports['qb-core']:GetCoreObject()
local plans, simulations, journal, circuit = {}, {}, {}, {}
local sequence = 0

local function uid(prefix, target)
    sequence = sequence + 1
    return ('%s-%s-%s-%04d'):format(prefix, os.time(), tostring(target or 0), sequence % 10000)
end

local function player(target) return QBCore.Functions.GetPlayer(tonumber(target)) end
local function cid(target)
    local p = player(target)
    return p and p.PlayerData and p.PlayerData.citizenid or ('source:' .. tostring(target))
end
local function actor(value)
    if type(value) == 'number' then return cid(value) end
    return tostring(value or 'dpn-medical-core')
end
local function encode(value)
    local ok, result = pcall(json.encode, value or {})
    return ok and result or '{}'
end
local function persist(query, params)
    CreateThread(function() pcall(function() MySQL.insert.await(query, params) end) end)
end
local function coreState(target)
    target = tonumber(target)
    if not target or not DPNMedicalServer or not DPNMedicalServer.EnsureState then return nil end
    local state = DPNMedicalServer.EnsureState(target)
    if type(state) ~= 'table' then return nil end
    return DPN_MED.CalculatePrecisionMetrics(state)
end
local function commit(target, state, eventType, data)
    target = tonumber(target)
    if not target or not DPNMedicalServer or not DPNMedicalServer.EnsureState or not DPNMedicalServer.Commit then return false end
    local _, patientCid = DPNMedicalServer.EnsureState(target)
    if not patientCid then return false end
    DPNMedicalServer.Commit(target, patientCid, state, eventType or 'v8_update', data or {})
    return true
end
local function appendJournal(target, eventType, data, author)
    target = tonumber(target)
    if not target then return nil end
    local item = { id = uid('EVT', target), target = target, patientCid = cid(target), eventType = tostring(eventType), data = data or {}, author = actor(author), createdAt = os.time() }
    journal[target] = journal[target] or {}
    journal[target][#journal[target] + 1] = item
    while #journal[target] > 250 do table.remove(journal[target], 1) end
    persist('INSERT INTO dpn_medical_v8_event_journal (event_id, patient_cid, event_type, actor_cid, event_data) VALUES (?, ?, ?, ?, ?)', { item.id, item.patientCid, item.eventType, item.author, encode(item.data) })
    TriggerEvent('dpn-medical:v8:eventJournaled', target, item)
    return item
end

local function createPlan(target, name, steps, authorValue, metadata)
    target = tonumber(target)
    local state = coreState(target)
    if not state then return false, 'Patient not found.' end
    local id = uid('PLAN', target)
    local plan = {
        id = id, target = target, patientCid = cid(target), name = tostring(name or 'Precision Care Plan'),
        status = 'active', createdBy = actor(authorValue), createdAt = os.time(), updatedAt = os.time(),
        steps = type(steps) == 'table' and steps or {}, metadata = metadata or {}, currentStep = 1
    }
    for index, step in ipairs(plan.steps) do
        step.id = step.id or (id .. '-S' .. index)
        step.status = step.status or 'pending'
        step.priority = tonumber(step.priority) or 2
    end
    plans[target] = plans[target] or {}
    plans[target][id] = plan
    state.careBundles[id] = { name = plan.name, status = plan.status, steps = plan.steps, createdAt = plan.createdAt }
    commit(target, state, 'precision_plan_created', { planId = id, name = plan.name })
    appendJournal(target, 'precision_plan_created', plan, authorValue)
    persist('INSERT INTO dpn_medical_v8_care_plans (plan_id, patient_cid, plan_name, status, created_by, plan_data) VALUES (?, ?, ?, ?, ?, ?)', { id, plan.patientCid, plan.name, plan.status, plan.createdBy, encode(plan) })
    return id, plan
end

local function recommendedPlan(target, authorValue)
    local state = coreState(target)
    if not state then return false, 'Patient not found.' end
    local recommendations = DPN_MED.GetPrecisionRecommendations(state)
    local steps = {}
    for _, recommendation in ipairs(recommendations) do
        steps[#steps + 1] = { code = recommendation.code, priority = recommendation.priority, reason = recommendation.reason, department = recommendation.department, status = 'pending' }
    end
    if #steps == 0 then steps[1] = { code = 'continued_monitoring', priority = 3, reason = 'No high-risk precision intervention is currently indicated.', department = 'general', status = 'pending' } end
    return createPlan(target, 'Precision Recommended Care Bundle', steps, authorValue, { generated = true, precisionRisk = state.v8.precisionRisk })
end

local function executeStep(target, planId, stepId, data, authorValue)
    target = tonumber(target)
    local plan = plans[target] and plans[target][tostring(planId)]
    if not plan then return false, 'Care plan not found.' end
    local selected
    for _, step in ipairs(plan.steps) do if tostring(step.id) == tostring(stepId) then selected = step break end end
    if not selected then return false, 'Care-plan step not found.' end
    if selected.status == 'completed' then return true, 'Step already completed.', selected end
    local state = coreState(target)
    if not state then return false, 'Patient not found.' end
    if selected.code ~= 'continued_monitoring' then
        local updated, ok, message = DPN_MED.ApplyPrecisionIntervention(state, selected.code, data)
        if not ok then return false, message end
        state = updated
    end
    selected.status = 'completed'
    selected.completedAt = os.time()
    selected.completedBy = actor(authorValue)
    selected.result = data or {}
    plan.updatedAt = os.time()
    local complete = true
    for _, step in ipairs(plan.steps) do if step.status ~= 'completed' and step.status ~= 'cancelled' then complete = false break end end
    if complete then plan.status = 'completed'; plan.completedAt = os.time() end
    state.careBundles[plan.id] = { name = plan.name, status = plan.status, steps = plan.steps, updatedAt = plan.updatedAt }
    commit(target, state, 'precision_plan_step_completed', { planId = plan.id, stepId = selected.id, code = selected.code })
    appendJournal(target, 'precision_plan_step_completed', { planId = plan.id, step = selected }, authorValue)
    CreateThread(function() pcall(function() MySQL.update.await('UPDATE dpn_medical_v8_care_plans SET status=?, plan_data=?, updated_at=NOW() WHERE plan_id=?', { plan.status, encode(plan), plan.id }) end) end)
    return true, 'Care-plan step completed.', selected
end

local function recordMedication(target, medication, dose, route, authorValue, context)
    target = tonumber(target)
    local state = coreState(target)
    if not state then return false, 'Patient not found.' end
    local safe, message, assessment = DPN_MED.ValidateMedicationDose(state, medication, dose, route)
    if not safe then
        appendJournal(target, 'medication_blocked', { medication = medication, dose = dose, route = route, reason = message }, authorValue)
        return false, message, assessment
    end
    local item = {
        id = uid('MAR', target), medication = tostring(medication):lower(), dose = tonumber(dose), route = tostring(route or 'iv'):lower(),
        administeredBy = actor(authorValue), administeredAt = os.time(), context = context or {},
        warnings = assessment.warnings or {}, riskWeight = assessment.severity == 'warning' and 6 or 2, status = 'active'
    }
    state.medicationAdministration[#state.medicationAdministration + 1] = item
    while #state.medicationAdministration > 100 do table.remove(state.medicationAdministration, 1) end
    DPN_MED.CalculatePrecisionMetrics(state)
    commit(target, state, 'precision_medication_administered', item)
    appendJournal(target, 'precision_medication_administered', item, authorValue)
    persist('INSERT INTO dpn_medical_v8_medication_administration (administration_id, patient_cid, medication, dose, route, administered_by, administration_data) VALUES (?, ?, ?, ?, ?, ?, ?)', { item.id, cid(target), item.medication, item.dose, item.route, item.administeredBy, encode(item) })
    return true, message, item
end

local function simulationTick(target, session)
    local state = coreState(target)
    if not state then return false end
    local rate = math.max(0.1, math.min(20, tonumber(session.rate) or 1))
    local scenario = tostring(session.scenario or 'deterioration')
    if scenario == 'hemorrhage' then
        state.vitals.blood = math.max(0, (state.vitals.blood or 5000) - 12 * rate)
    elseif scenario == 'respiratory_failure' then
        state.vitals.spo2 = math.max(0, (state.vitals.spo2 or 99) - 0.3 * rate)
        state.vitals.etco2 = math.min(100, (state.vitals.etco2 or 38) + 0.2 * rate)
    elseif scenario == 'sepsis' then
        state.infection.suspected = true
        state.vitals.temp = math.min(106, (state.vitals.temp or 98.6) + 0.03 * rate)
        state.vitals.hr = math.min(220, (state.vitals.hr or 74) + 0.25 * rate)
        state.labs.lactate = (tonumber(state.labs.lactate) or tonumber(state.advanced and state.advanced.lactate) or 1) + 0.02 * rate
    elseif scenario == 'neuro_decline' then
        state.neuro.gcs = math.max(3, (tonumber(state.neuro.gcs) or 15) - 0.03 * rate)
    end
    DPN_MED.CalculatePrecisionMetrics(state)
    commit(target, state, 'simulation_tick', { sessionId = session.id, scenario = scenario, rate = rate })
    session.ticks = (session.ticks or 0) + 1
    session.updatedAt = os.time()
    return true
end

exports('GetPrecisionTwin', function(target) local state = coreState(target); return state and DPN_MED.BuildPrecisionTwin(state) or nil end)
exports('SetPatientDemographics', function(target, data, authorValue)
    local state = coreState(target); if not state then return false, 'Patient not found.' end
    data = type(data) == 'table' and data or {}
    for _, key in ipairs({ 'age', 'weightKg', 'heightCm', 'sex', 'pregnancy' }) do if data[key] ~= nil then state.demographics[key] = data[key] end end
    DPN_MED.CalculatePrecisionMetrics(state); commit(target, state, 'demographics_updated', { actor = actor(authorValue), demographics = state.demographics }); return true, state.demographics
end)
exports('ValidatePrecisionMedication', function(target, medication, dose, route) local state = coreState(target); if not state then return false, 'Patient not found.' end; return DPN_MED.ValidateMedicationDose(state, medication, dose, route) end)
exports('RecordPrecisionMedication', recordMedication)
exports('CreatePrecisionCarePlan', createPlan)
exports('CreateRecommendedPrecisionPlan', recommendedPlan)
exports('ExecutePrecisionPlanStep', executeStep)
exports('GetPrecisionCarePlans', function(target) local out = {}; for _, item in pairs(plans[tonumber(target)] or {}) do out[#out + 1] = item end; table.sort(out, function(a,b) return a.createdAt > b.createdAt end); return out end)
exports('GetPatientEventJournal', function(target, limit) local items = journal[tonumber(target)] or {}; local out = {}; for i = #items, math.max(1, #items - (tonumber(limit) or 50) + 1), -1 do out[#out + 1] = items[i] end; return out end)
exports('StartPrecisionSimulation', function(target, scenario, rate, authorValue)
    target = tonumber(target); if not coreState(target) then return false, 'Patient not found.' end
    local session = { id = uid('SIM', target), target = target, patientCid = cid(target), scenario = tostring(scenario or 'deterioration'), rate = math.max(0.1, math.min(20, tonumber(rate) or 1)), active = true, paused = false, startedBy = actor(authorValue), startedAt = os.time(), ticks = 0 }
    simulations[target] = session; appendJournal(target, 'precision_simulation_started', session, authorValue); return session.id, session
end)
exports('ControlPrecisionSimulation', function(target, operation, value, authorValue)
    target = tonumber(target); local session = simulations[target]; if not session then return false, 'No active simulation.' end
    operation = tostring(operation or '')
    if operation == 'pause' then session.paused = true elseif operation == 'resume' then session.paused = false elseif operation == 'rate' then session.rate = math.max(0.1, math.min(20, tonumber(value) or 1)) elseif operation == 'stop' then session.active = false; simulations[target] = nil else return false, 'Unknown simulation operation.' end
    appendJournal(target, 'precision_simulation_controlled', { operation = operation, value = value, sessionId = session.id }, authorValue); return true, session
end)
exports('GetPrecisionSimulation', function(target) return simulations[tonumber(target)] end)
exports('GetV8OperationalDashboard', function()
    local patients = {}; local highRisk = 0; local simulationsActive = 0
    for _, sid in ipairs(GetPlayers()) do
        local target = tonumber(sid); local state = coreState(target)
        if state then
            local twin = DPN_MED.BuildPrecisionTwin(state)
            if twin.v8.precisionRisk >= 60 then highRisk = highRisk + 1 end
            if simulations[target] then simulationsActive = simulationsActive + 1 end
            local planCount = 0; for _ in pairs(plans[target] or {}) do planCount = planCount + 1 end
            patients[#patients + 1] = { id = target, citizenid = cid(target), precision = twin, plans = planCount, simulation = simulations[target] }
        end
    end
    return { version = VERSION, generatedAt = os.time(), patients = patients, highRisk = highRisk, simulationsActive = simulationsActive, circuit = circuit }
end)
exports('RunV8SelfTest', function()
    local state = DPN_MED.EnsureV8Schema(DPN_MED.NewBodyState()); state.vitals.blood = 2800; state.vitals.spo2 = 82; state.vitals.hr = 142; state.vitals.rr = 34; state.labs.ph = 7.18; state.labs.inr = 2.1; state.labs.hemoglobin = 7.2; state = DPN_MED.Recalculate(state)
    local twin = DPN_MED.BuildPrecisionTwin(state); local recommendations = twin.recommendations or {}
    local passed = twin.v8.precisionRisk > 40 and twin.hemodynamics.oxygenDeliveryMlMin > 0 and #recommendations > 0
    return { passed = passed, precisionRisk = twin.v8.precisionRisk, oxygenDelivery = twin.hemodynamics.oxygenDeliveryMlMin, recommendations = #recommendations, destination = twin.v8.recommendedDestination }
end)

AddEventHandler(DPN_MED.Events.StateChanged, function(target)
    target = tonumber(target); local state = coreState(target); if not state then return end
    if state.v8.precisionRisk >= 80 then
        pcall(function() exports['dpn-medical-core']:RaiseSafetyAlert(target, 'v8_precision_critical', 'critical', 'Precision risk score is critical.', { precisionRisk = state.v8.precisionRisk, destination = state.v8.recommendedDestination }, 'dpn-medical-core') end)
    end
end)

CreateThread(function()
    Wait(2500)
    pcall(function() exports['dpn-medical-core']:RegisterModule('dpn-medical-core-v8', VERSION, { 'precision_digital_twin', 'hemodynamics', 'oxygen_delivery', 'dose_safety', 'care_bundles', 'simulation_control', 'event_journal', 'clinical_resilience' }) end)
    print('[dpn-medical-core] v8.0.0 precision physiology, care bundles, medication safety and simulation engine active')
    while true do
        Wait(1000)
        for target, session in pairs(simulations) do
            if session.active and not session.paused then
                local ok = pcall(simulationTick, target, session)
                if not ok then circuit.simulationErrors = (circuit.simulationErrors or 0) + 1 end
            end
        end
    end
end)

QBCore.Commands.Add('medprecision', 'Show precision physiology for a patient', { { name = 'id', help = 'Player ID' } }, true, function(src, args)
    local target = tonumber(args[1]); local twin = exports['dpn-medical-core']:GetPrecisionTwin(target); if not twin then return end
    TriggerClientEvent('chat:addMessage', src, { args = { 'DPN Precision', ('Risk %s%% | Survival %s%% | CO %.2f L/min | O2 delivery %s | Destination %s'):format(twin.v8.precisionRisk, twin.v8.predictedSurvival, twin.hemodynamics.cardiacOutputLpm, twin.hemodynamics.oxygenDeliveryMlMin, twin.v8.recommendedDestination) } })
end)
