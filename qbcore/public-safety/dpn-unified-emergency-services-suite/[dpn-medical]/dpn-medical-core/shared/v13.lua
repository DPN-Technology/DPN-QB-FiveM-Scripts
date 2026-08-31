DPN_MED = DPN_MED or {}

-- v13 continuum-command physiology and deterministic clinical simulation.
-- This layer is additive: all v12 calculations remain available and v13 builds
-- on top of the existing authoritative patient state.

local previousRecalculate = DPN_MED.Recalculate

local function now() return os and os.time and os.time() or 0 end
local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end
local function round(value, places)
    local p = 10 ^ (places or 0)
    return math.floor((tonumber(value) or 0) * p + 0.5) / p
end
local function ensure(parent, key, defaults)
    parent[key] = type(parent[key]) == 'table' and parent[key] or {}
    for k, v in pairs(defaults or {}) do if parent[key][k] == nil then parent[key][k] = v end end
    return parent[key]
end
local function copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}; if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for k, v in pairs(value) do out[copy(k, seen)] = copy(v, seen) end
    return out
end
local function lab(state, key, fallback)
    for _, bucket in ipairs({ state.labs, state.electrolytes, state.bloodGas }) do
        if type(bucket) == 'table' and tonumber(bucket[key]) ~= nil then return tonumber(bucket[key]) end
    end
    return tonumber(fallback) or 0
end
local function hasCondition(state, fragment)
    fragment = tostring(fragment or ''):lower()
    for key, value in pairs(type(state.conditions) == 'table' and state.conditions or {}) do
        local name = tostring(key):lower()
        if name:find(fragment, 1, true) and (type(value) ~= 'table' or value.active ~= false) then return true end
    end
    return false
end
local function medicationRows(state)
    local rows = {}
    for key, value in pairs(type(state.medications) == 'table' and state.medications or {}) do
        if type(value) == 'table' then
            local row = copy(value); row.name = row.name or tostring(key); rows[#rows + 1] = row
        elseif value then rows[#rows + 1] = { name = tostring(key), active = true } end
    end
    return rows
end

function DPN_MED.EnsureV13Schema(state)
    state = type(state) == 'table' and state or DPN_MED.NewBodyState()
    if DPN_MED.EnsureV12Schema then state = DPN_MED.EnsureV12Schema(state) end
    ensure(state, 'hemostasisV13', {
        clotStrength = 100, fibrinolysisRisk = 0, hemorrhageRisk = 0,
        bleedingControlProbability = 100, calciumRisk = 0, lethalTriadScore = 0
    })
    ensure(state, 'pharmacologyV13', {
        activeMedicationCount = 0, opioidBurden = 0, sedativeBurden = 0,
        qtBurden = 0, renalAccumulationRisk = 0, hepaticAccumulationRisk = 0,
        interactionRisk = 0, toxicityRisk = 0, clearanceIndex = 100
    })
    ensure(state, 'immuneV13', {
        infectionProbability = 0, cytokineBurden = 0, immunosuppressionRisk = 0,
        sourceControlUrgency = 0, deviceInfectionRisk = 0, isolationNeed = 0
    })
    ensure(state, 'recoveryV13', {
        recoveryReserve = 100, dischargeReadiness = 100, expectedLengthOfStayHours = 0,
        rehabilitationNeed = 0, deliriumRisk = 0, nutritionRisk = 0,
        socialBarrierRisk = 0, prolongedCareRisk = 0
    })
    ensure(state, 'uncertaintyV13', {
        confidence = 100, completeness = 100, freshness = 100, contradictionRisk = 0,
        missingSignals = {}, staleSignals = {}
    })
    ensure(state, 'v13', {
        continuumRisk = 0, commandLevel = 'routine', networkPriority = 5,
        predictedICUHours = 0, predictedHospitalHours = 0, transferRisk = 0,
        careComplexity = 0, resilienceScore = 100, recommendedDestination = 'self_care',
        recommendedTeam = 'primary_care', approvalRequired = false, lastCalculated = 0
    })
    state.v13CausalGraph = type(state.v13CausalGraph) == 'table' and state.v13CausalGraph or { nodes = {}, edges = {} }
    state.v13ContinuumPlans = type(state.v13ContinuumPlans) == 'table' and state.v13ContinuumPlans or {}
    state.v13Snapshots = type(state.v13Snapshots) == 'table' and state.v13Snapshots or {}
    return state
end

local function calculateHemostasis(state)
    local platelets = clamp(lab(state, 'platelets', 250), 1, 1200)
    local fibrinogen = clamp(lab(state, 'fibrinogen', 300), 20, 1000)
    local inr = clamp(lab(state, 'inr', 1.0), 0.7, 8)
    local calcium = clamp(lab(state, 'ionizedCalcium', lab(state, 'calcium', 1.15)), 0.3, 3)
    local ph = clamp(lab(state, 'ph', 7.4), 6.6, 7.8)
    local temp = clamp((state.vitals and (state.vitals.temperature or state.vitals.temp)) or state.temperature or 37, 24, 44)
    local bleeding = tonumber(state.bleeding and state.bleeding.rate) or tonumber(state.advanced and state.advanced.bleedingRate) or 0
    local blood = tonumber(state.vitals and state.vitals.blood) or 5000
    local plateletScore = clamp((platelets / 150) * 100, 0, 120)
    local fibrinScore = clamp((fibrinogen / 200) * 100, 0, 120)
    local inrScore = clamp(100 - math.max(0, inr - 1) * 45, 0, 100)
    local tempScore = clamp(100 - math.max(0, 35 - temp) * 20, 0, 100)
    local phScore = clamp(100 - math.max(0, 7.25 - ph) * 240, 0, 100)
    local calciumScore = clamp(100 - math.max(0, 1.0 - calcium) * 130, 0, 100)
    local clot = clamp(plateletScore * .22 + fibrinScore * .22 + inrScore * .20 + tempScore * .12 + phScore * .14 + calciumScore * .10, 0, 100)
    local lysis = clamp(math.max(0, 100 - fibrinScore) * .45 + math.max(0, inr - 1.2) * 20 + math.max(0, 35 - temp) * 8, 0, 100)
    local hemorrhage = clamp((bleeding * 1.8) + math.max(0, 4200 - blood) / 35 + (100 - clot) * .55, 0, 100)
    local triad = clamp(math.max(0, 35 - temp) * 20 + math.max(0, 7.25 - ph) * 200 + math.max(0, inr - 1.2) * 30, 0, 100)
    return {
        platelets = platelets, fibrinogen = fibrinogen, inr = round(inr, 2), ionizedCalcium = round(calcium, 2),
        ph = round(ph, 2), temperature = round(temp, 1), clotStrength = round(clot, 1),
        fibrinolysisRisk = round(lysis, 1), hemorrhageRisk = round(hemorrhage, 1),
        bleedingControlProbability = round(clamp(clot - bleeding * 1.2, 0, 100), 1),
        calciumRisk = round(clamp(math.max(0, 1.0 - calcium) * 120, 0, 100), 1), lethalTriadScore = round(triad, 1)
    }
end

local function calculatePharmacology(state)
    local rows = medicationRows(state)
    local opioid, sedative, qt, renal, hepatic, interactions = 0, 0, 0, 0, 0, 0
    local active = 0
    for _, med in ipairs(rows) do
        if med.active ~= false then
            active = active + 1
            local name = tostring(med.name or ''):lower(); local class = tostring(med.class or ''):lower()
            local dose = clamp(med.dose or med.amount or 1, 0, 1000)
            if class:find('opioid', 1, true) or name:find('morph', 1, true) or name:find('fent', 1, true) then opioid = opioid + math.min(40, 10 + dose * .5) end
            if class:find('sedat', 1, true) or name:find('midazol', 1, true) or name:find('propof', 1, true) then sedative = sedative + math.min(40, 12 + dose * .35) end
            if med.qtRisk == true or name:find('amiod', 1, true) or name:find('haloper', 1, true) then qt = qt + 22 end
            if med.renalClearance == true then renal = renal + 15 end
            if med.hepaticClearance == true then hepatic = hepatic + 15 end
            if med.interactionRisk then interactions = interactions + tonumber(med.interactionRisk) end
        end
    end
    local renalModel = state.renalModelV11 or state.renal or {}
    local hepaticModel = state.hepaticModelV9 or state.hepatic or {}
    local egfr = tonumber(renalModel.egfr) or tonumber(renalModel.eGFR) or lab(state, 'egfr', 90)
    local hepaticFunction = tonumber(hepaticModel['function']) or 100
    local renalRisk = clamp(renal * math.max(0, 1 - egfr / 90), 0, 100)
    local hepaticRisk = clamp(hepatic * math.max(0, 1 - hepaticFunction / 100), 0, 100)
    local rr = tonumber(state.vitals and state.vitals.rr) or 16
    local spo2 = tonumber(state.vitals and state.vitals.spo2) or 99
    local toxicity = clamp(opioid * .45 + sedative * .45 + qt * .25 + renalRisk * .45 + hepaticRisk * .45 + interactions + math.max(0, 10 - rr) * 5 + math.max(0, 92 - spo2) * 2, 0, 100)
    return {
        activeMedicationCount = active, opioidBurden = round(clamp(opioid, 0, 100), 1),
        sedativeBurden = round(clamp(sedative, 0, 100), 1), qtBurden = round(clamp(qt, 0, 100), 1),
        renalAccumulationRisk = round(renalRisk, 1), hepaticAccumulationRisk = round(hepaticRisk, 1),
        interactionRisk = round(clamp(interactions, 0, 100), 1), toxicityRisk = round(toxicity, 1),
        clearanceIndex = round(clamp(100 - renalRisk * .45 - hepaticRisk * .45, 0, 100), 1)
    }
end

local function calculateImmune(state)
    local temp = tonumber(state.vitals and (state.vitals.temperature or state.vitals.temp)) or 37
    local wbc = lab(state, 'wbc', 8)
    local lactate = lab(state, 'lactate', 1.2)
    local crp = lab(state, 'crp', 3)
    local infection = 0
    if hasCondition(state, 'sepsis') or hasCondition(state, 'infection') then infection = infection + 50 end
    infection = infection + math.max(0, math.abs(temp - 37.0) - .7) * 12 + math.max(0, math.abs(wbc - 8) - 4) * 3 + math.max(0, lactate - 2) * 8 + math.min(20, crp / 10)
    local devices = type(state.devicesV11) == 'table' and state.devicesV11 or type(state.devices) == 'table' and state.devices or {}
    local deviceCount, overdue = 0, 0
    for _, device in pairs(devices) do
        if type(device) == 'table' and device.active ~= false then
            deviceCount = deviceCount + 1
            if device.reviewDue == true or (device.reviewAt and tonumber(device.reviewAt) and tonumber(device.reviewAt) < now()) then overdue = overdue + 1 end
        end
    end
    local deviceRisk = clamp(deviceCount * 8 + overdue * 18, 0, 100)
    local immunosuppression = clamp((hasCondition(state, 'immunosupp') and 45 or 0) + (hasCondition(state, 'cancer') and 25 or 0) + math.max(0, 4 - wbc) * 10, 0, 100)
    local cytokine = clamp(infection * .7 + math.max(0, lactate - 2) * 8, 0, 100)
    return {
        infectionProbability = round(clamp(infection, 0, 100), 1), cytokineBurden = round(cytokine, 1),
        immunosuppressionRisk = round(immunosuppression, 1), sourceControlUrgency = round(clamp(infection * .75 + lactate * 5, 0, 100), 1),
        deviceInfectionRisk = round(deviceRisk, 1), isolationNeed = round(clamp(infection * .4 + (hasCondition(state, 'contagious') and 50 or 0), 0, 100), 1)
    }
end

local function calculateRecovery(state)
    local demographics = state.demographics or {}; local age = tonumber(demographics.age) or 35
    local pain = tonumber(state.status and state.status.pain) or 0
    local mobility = tonumber(state.mobility) or tonumber(state.rehabV11 and state.rehabV11.mobility) or 100
    local albumin = lab(state, 'albumin', 4.0)
    local frailty = tonumber(state.recoveryV11 and state.recoveryV11.frailty) or math.max(0, age - 65) * 1.2
    local delirium = clamp((age >= 70 and 25 or 0) + math.max(0, 90 - (tonumber(state.neurological and state.neurological.gcs) or tonumber(state.advanced and state.advanced.gcs) or 15) * 6) + (state.status and state.status.unconscious and 30 or 0), 0, 100)
    local nutrition = clamp(math.max(0, 3.5 - albumin) * 35 + (hasCondition(state, 'malnutrition') and 40 or 0), 0, 100)
    local social = clamp(tonumber(state.socialBarriers and state.socialBarriers.score) or 0, 0, 100)
    local reserve = clamp(100 - frailty * .5 - pain * .2 - nutrition * .25 - delirium * .25 - math.max(0, 50 - mobility) * .5, 0, 100)
    local v12risk = tonumber(state.v12 and state.v12.integratedRisk) or 0
    local los = clamp(v12risk * 1.2 + frailty * .8 + nutrition * .7 + delirium * .5, 0, 720)
    local readiness = clamp(reserve - v12risk * .6 - social * .35, 0, 100)
    return {
        recoveryReserve = round(reserve, 1), dischargeReadiness = round(readiness, 1),
        expectedLengthOfStayHours = math.floor(los), rehabilitationNeed = round(clamp(100 - mobility + frailty * .5, 0, 100), 1),
        deliriumRisk = round(delirium, 1), nutritionRisk = round(nutrition, 1), socialBarrierRisk = round(social, 1),
        prolongedCareRisk = round(clamp(100 - reserve + social * .35, 0, 100), 1)
    }
end

local function calculateUncertainty(state)
    local expected = {
        { 'hr', state.vitals and state.vitals.hr }, { 'rr', state.vitals and state.vitals.rr },
        { 'spo2', state.vitals and state.vitals.spo2 }, { 'systolic', state.vitals and state.vitals.systolic },
        { 'diastolic', state.vitals and state.vitals.diastolic }, { 'blood', state.vitals and state.vitals.blood },
        { 'temperature', state.vitals and (state.vitals.temperature or state.vitals.temp) },
        { 'gcs', (state.neurological and state.neurological.gcs) or (state.advanced and state.advanced.gcs) },
        { 'lactate', lab(state, 'lactate', nil) }, { 'ph', lab(state, 'ph', nil) },
        { 'creatinine', lab(state, 'creatinine', nil) }, { 'platelets', lab(state, 'platelets', nil) }
    }
    local missing = {}; local present = 0
    for _, row in ipairs(expected) do if row[2] == nil or row[2] == 0 then missing[#missing + 1] = row[1] else present = present + 1 end end
    local base = (present / #expected) * 100
    local previous = state.dataQualityV12 or {}; local freshness = tonumber(previous.freshness) or 100
    local contradictions = 0
    local hr = tonumber(state.vitals and state.vitals.hr) or 0; local sbp = tonumber(state.vitals and state.vitals.systolic) or 0
    if hr == 0 and sbp > 0 then contradictions = contradictions + 35 end
    if sbp == 0 and hr > 0 then contradictions = contradictions + 35 end
    if tonumber(state.vitals and state.vitals.spo2) and state.vitals.spo2 > 100 then contradictions = contradictions + 20 end
    return {
        confidence = round(clamp(base * .65 + freshness * .35 - contradictions, 0, 100), 1),
        completeness = round(base, 1), freshness = round(clamp(freshness, 0, 100), 1),
        contradictionRisk = round(clamp(contradictions, 0, 100), 1), missingSignals = missing, staleSignals = previous.staleSignals or {}
    }
end

function DPN_MED.CalculateV13Metrics(state)
    state = DPN_MED.EnsureV13Schema(state)
    state.hemostasisV13 = calculateHemostasis(state)
    state.pharmacologyV13 = calculatePharmacology(state)
    state.immuneV13 = calculateImmune(state)
    state.recoveryV13 = calculateRecovery(state)
    state.uncertaintyV13 = calculateUncertainty(state)
    local base = tonumber(state.v12 and state.v12.integratedRisk) or 0
    local shock = tonumber(state.status and state.status.shock) or 0
    local spo2 = tonumber(state.vitals and state.vitals.spo2) or 99
    local sbp = tonumber(state.vitals and state.vitals.systolic) or 120
    local blood = tonumber(state.vitals and state.vitals.blood) or 5000
    local hr = tonumber(state.vitals and state.vitals.hr) or 80
    local rr = tonumber(state.vitals and state.vitals.rr) or 16
    local gcs = tonumber(state.neurological and state.neurological.gcs)
        or tonumber(state.advanced and state.advanced.gcs) or 15
    local physiologicRisk = clamp(
        shock * .55
        + math.max(0, 92 - spo2) * 2.6
        + math.max(0, 90 - sbp) * 1.35
        + math.max(0, 3500 - blood) / 30
        + math.max(0, hr - 120) * .35
        + math.max(0, 10 - rr) * 3
        + math.max(0, 15 - gcs) * 4,
        0, 100
    )
    local baseSignal = base > 0 and base or math.max(physiologicRisk, state.hemostasisV13.hemorrhageRisk, state.immuneV13.infectionProbability)
    local risk = clamp(baseSignal * .20 + physiologicRisk * .28
        + state.hemostasisV13.hemorrhageRisk * .20
        + state.pharmacologyV13.toxicityRisk * .08
        + state.immuneV13.infectionProbability * .10
        + state.recoveryV13.prolongedCareRisk * .06
        + (100 - state.uncertaintyV13.confidence) * .08, 0, 100)
    local complexity = clamp((state.pharmacologyV13.activeMedicationCount * 4) + #(state.organSupportModelV12 and state.organSupportModelV12.recommendedSupports or {}) * 14
        + state.immuneV13.sourceControlUrgency * .25 + state.recoveryV13.rehabilitationNeed * .2, 0, 100)
    local resilience = clamp(state.recoveryV13.recoveryReserve * .5 + state.uncertaintyV13.confidence * .25 + (100 - state.hemostasisV13.lethalTriadScore) * .25, 0, 100)
    local command = risk >= 90 and 'catastrophic' or risk >= 75 and 'critical' or risk >= 55 and 'high' or risk >= 30 and 'elevated' or 'routine'
    local destination = risk >= 88 and 'tertiary_critical_care' or risk >= 70 and 'icu' or risk >= 48 and 'monitored_inpatient' or risk >= 25 and 'emergency_department' or 'outpatient'
    local team = risk >= 88 and 'multidisciplinary_command' or risk >= 70 and 'critical_care' or risk >= 48 and 'hospitalist_specialist' or risk >= 25 and 'emergency_medicine' or 'primary_care'
    state.v13 = {
        continuumRisk = round(risk, 1), commandLevel = command,
        networkPriority = risk >= 85 and 1 or risk >= 65 and 2 or risk >= 45 and 3 or risk >= 25 and 4 or 5,
        predictedICUHours = math.floor(clamp(risk * 1.8 + complexity * .7, 0, 720)),
        predictedHospitalHours = math.floor(clamp(state.recoveryV13.expectedLengthOfStayHours + risk * .8, 0, 1440)),
        transferRisk = round(clamp(risk * .55 + state.hemostasisV13.hemorrhageRisk * .25 + state.uncertaintyV13.contradictionRisk * .2, 0, 100), 1),
        careComplexity = round(complexity, 1), resilienceScore = round(resilience, 1),
        recommendedDestination = destination, recommendedTeam = team,
        approvalRequired = risk >= 55 or complexity >= 65, lastCalculated = now()
    }
    state.v13CausalGraph = DPN_MED.BuildCausalGraphV13(state)
    return state
end

function DPN_MED.BuildCausalGraphV13(state)
    state = DPN_MED.EnsureV13Schema(state)
    local nodes = {
        { id = 'hemorrhage', value = state.hemostasisV13.hemorrhageRisk, type = 'risk' },
        { id = 'coagulation', value = 100 - state.hemostasisV13.clotStrength, type = 'risk' },
        { id = 'toxicity', value = state.pharmacologyV13.toxicityRisk, type = 'risk' },
        { id = 'infection', value = state.immuneV13.infectionProbability, type = 'risk' },
        { id = 'recovery', value = 100 - state.recoveryV13.recoveryReserve, type = 'risk' },
        { id = 'uncertainty', value = 100 - state.uncertaintyV13.confidence, type = 'quality' },
        { id = 'continuum_risk', value = state.v13.continuumRisk, type = 'outcome' }
    }
    local edges = {
        { from = 'hemorrhage', to = 'continuum_risk', weight = .18 }, { from = 'coagulation', to = 'hemorrhage', weight = .55 },
        { from = 'toxicity', to = 'continuum_risk', weight = .11 }, { from = 'infection', to = 'continuum_risk', weight = .12 },
        { from = 'recovery', to = 'continuum_risk', weight = .08 }, { from = 'uncertainty', to = 'continuum_risk', weight = .09 }
    }
    return { nodes = nodes, edges = edges, generatedAt = now() }
end

function DPN_MED.BuildContinuumPlanV13(state, requested)
    state = DPN_MED.CalculateV13Metrics(state)
    local steps = {}
    local function add(id, department, priority, reason, approval)
        steps[#steps + 1] = { id = id, department = department, priority = priority, reason = reason,
            requiresHumanApproval = approval == true, status = approval and 'awaiting_approval' or 'planned' }
    end
    if state.hemostasisV13.hemorrhageRisk >= 50 then add('control_hemorrhage', 'ems_surgery', 1, 'High modeled hemorrhage risk.', true) end
    if state.hemostasisV13.clotStrength < 55 then add('correct_coagulopathy', 'blood_bank_pharmacy', 1, 'Low modeled clot strength.', true) end
    if state.pharmacologyV13.toxicityRisk >= 45 then add('medication_safety_review', 'pharmacy', 1, 'Medication toxicity or accumulation risk.', true) end
    if state.immuneV13.sourceControlUrgency >= 45 then add('source_control', 'hospital_surgery', 1, 'Infection source-control urgency.', true) end
    if state.uncertaintyV13.confidence < 65 then add('close_data_gaps', 'diagnostics_records', 2, 'Low clinical-data confidence.', false) end
    if state.recoveryV13.rehabilitationNeed >= 45 then add('early_rehabilitation', 'rehab', 3, 'Functional recovery risk.', false) end
    if #steps == 0 then add('routine_monitoring', 'primary_care', 4, 'No major continuum care gap detected.', false) end
    return {
        protocol = requested or 'continuum_care', status = 'draft', risk = state.v13.continuumRisk,
        destination = state.v13.recommendedDestination, team = state.v13.recommendedTeam,
        approvalRequired = state.v13.approvalRequired, steps = steps, createdAt = now()
    }
end

function DPN_MED.SimulateInterventionV13(state, intervention)
    local work = copy(DPN_MED.CalculateV13Metrics(state)); intervention = tostring(intervention or 'observation')
    local before = work.v13.continuumRisk
    if intervention == 'hemorrhage_control' then work.hemostasisV13.hemorrhageRisk = clamp(work.hemostasisV13.hemorrhageRisk - 35, 0, 100)
    elseif intervention == 'blood_products' then work.hemostasisV13.clotStrength = clamp(work.hemostasisV13.clotStrength + 22, 0, 100)
    elseif intervention == 'antidote' then work.pharmacologyV13.toxicityRisk = clamp(work.pharmacologyV13.toxicityRisk - 40, 0, 100)
    elseif intervention == 'source_control' then work.immuneV13.sourceControlUrgency = clamp(work.immuneV13.sourceControlUrgency - 40, 0, 100)
    elseif intervention == 'rehabilitation' then work.recoveryV13.recoveryReserve = clamp(work.recoveryV13.recoveryReserve + 18, 0, 100) end
    local projected = clamp(before - (before * .15) - (intervention ~= 'observation' and 10 or 0), 0, 100)
    return { intervention = intervention, currentRisk = before, projectedRisk = round(projected, 1),
        expectedBenefit = round(clamp(before - projected, 0, 100), 1), confidence = work.uncertaintyV13.confidence,
        requiresHumanApproval = intervention ~= 'observation', generatedAt = now() }
end

function DPN_MED.BuildV13Twin(state)
    state = DPN_MED.CalculateV13Metrics(state)
    return {
        version = '13.0.0', demographics = copy(state.demographics or {}), vitals = copy(state.vitals or {}),
        v13 = copy(state.v13), hemostasisV13 = copy(state.hemostasisV13), pharmacologyV13 = copy(state.pharmacologyV13),
        immuneV13 = copy(state.immuneV13), recoveryV13 = copy(state.recoveryV13), uncertaintyV13 = copy(state.uncertaintyV13),
        causalGraphV13 = copy(state.v13CausalGraph), v12 = copy(state.v12 or {}), organSupportV12 = copy(state.organSupportModelV12 or {})
    }
end

function DPN_MED.BuildV13TrendPoint(state)
    state = DPN_MED.CalculateV13Metrics(state)
    return { at = now(), risk = state.v13.continuumRisk, resilience = state.v13.resilienceScore,
        clotStrength = state.hemostasisV13.clotStrength, toxicity = state.pharmacologyV13.toxicityRisk,
        infection = state.immuneV13.infectionProbability, recoveryReserve = state.recoveryV13.recoveryReserve,
        confidence = state.uncertaintyV13.confidence }
end

function DPN_MED.RunV13SharedSelfTest()
    local state = DPN_MED.NewBodyState()
    state.vitals.blood = 2200; state.vitals.systolic = 72; state.vitals.diastolic = 38; state.vitals.hr = 148; state.vitals.spo2 = 84
    state.labs = { platelets = 58, fibrinogen = 90, inr = 2.3, ionizedCalcium = .78, ph = 7.08, lactate = 8.5, creatinine = 2.8, wbc = 19 }
    state.vitals.temperature = 33.4; state.status.shock = 92
    state.medications = { morphine = { name = 'morphine', class = 'opioid', dose = 12, renalClearance = true, active = true } }
    state.conditions = { sepsis = { active = true } }
    state = DPN_MED.CalculateV13Metrics(state)
    local plan = DPN_MED.BuildContinuumPlanV13(state)
    local simulation = DPN_MED.SimulateInterventionV13(state, 'hemorrhage_control')
    return { passed = state.v13.continuumRisk >= 60 and state.hemostasisV13.clotStrength < 70 and #plan.steps >= 3 and simulation.projectedRisk < simulation.currentRisk,
        risk = state.v13.continuumRisk, clotStrength = state.hemostasisV13.clotStrength, toxicity = state.pharmacologyV13.toxicityRisk,
        infection = state.immuneV13.infectionProbability, planSteps = #plan.steps, projectedRisk = simulation.projectedRisk }
end

DPN_MED.Recalculate = function(state, ...)
    if previousRecalculate then state = previousRecalculate(state, ...) end
    return DPN_MED.CalculateV13Metrics(state)
end
