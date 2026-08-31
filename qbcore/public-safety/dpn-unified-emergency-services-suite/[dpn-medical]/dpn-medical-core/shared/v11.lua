DPN_MED = DPN_MED or {}

-- v11 autonomous-care network. This layer is advisory and deterministic.
-- It forecasts intervention effects, identifies conflicts, and builds plans,
-- but all high-risk clinical actions still require an authorized human actor.

local previousRecalculate = DPN_MED.Recalculate

local function now()
    return os and os.time and os.time() or 0
end

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function round(value, places)
    local power = 10 ^ (places or 0)
    return math.floor((tonumber(value) or 0) * power + 0.5) / power
end

local function ensure(parent, key, defaults)
    parent[key] = type(parent[key]) == 'table' and parent[key] or {}
    for name, value in pairs(defaults or {}) do
        if parent[key][name] == nil then parent[key][name] = value end
    end
    return parent[key]
end

local function copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, item in pairs(value) do out[copy(key, seen)] = copy(item, seen) end
    return out
end

local function lab(state, key, fallback)
    if state.labs and tonumber(state.labs[key]) ~= nil then return tonumber(state.labs[key]) end
    if state.electrolytes and tonumber(state.electrolytes[key]) ~= nil then return tonumber(state.electrolytes[key]) end
    return tonumber(fallback) or 0
end

local function countTable(value)
    local total = 0
    for _ in pairs(type(value) == 'table' and value or {}) do total = total + 1 end
    return total
end

local function hasCondition(state, pattern)
    pattern = tostring(pattern or ''):lower()
    for name in pairs(state.conditions or {}) do
        if tostring(name):lower():find(pattern, 1, true) then return true end
    end
    return false
end

local function activeDeviceCount(state)
    local count, invasive = 0, 0
    for _, device in pairs(state.devices or {}) do
        if type(device) == 'table' and device.status ~= 'removed' then
            count = count + 1
            if device.invasive == true or device.type == 'central_line' or device.type == 'arterial_line'
                or device.type == 'foley' or device.type == 'ventilator' or device.type == 'ecmo'
                or device.type == 'dialysis' then
                invasive = invasive + 1
            end
        end
    end
    return count, invasive
end

function DPN_MED.EnsureV11Schema(state)
    state = type(state) == 'table' and state or DPN_MED.NewBodyState()
    if DPN_MED.EnsureV10Schema then state = DPN_MED.EnsureV10Schema(state) end

    ensure(state, 'demographics', {
        age = 35, weightKg = 80, heightCm = 178, sex = 'unspecified', pregnancy = false,
        baselineMobility = 100, baselineCognition = 100, baselineOxygen = 99
    })
    ensure(state, 'microcirculation', {
        tissueOxygenation = 95, capillaryRefillSeconds = 2.0, mottlingScore = 0,
        endothelialIntegrity = 100, perfusionHeterogeneity = 0, cellularStress = 0
    })
    ensure(state, 'endocrineModel', {
        glucose = 95, ketones = 0, cortisolReserve = 100, thyroidReserve = 100,
        insulinNeed = 0, endocrineRisk = 0, crisis = 'none'
    })
    ensure(state, 'infectionModel', {
        probability = 0, sourceControlNeeded = false, source = 'unknown',
        antimicrobialDelayMinutes = 0, immuneFailure = 0, isolationPriority = 0
    })
    ensure(state, 'nutritionModel', {
        bmi = 25.2, idealBodyWeightKg = 73, calorieTarget = 2000, proteinTargetGrams = 95,
        calorieDeficit = 0, proteinDeficit = 0, aspirationRisk = 0, nutritionRisk = 0
    })
    ensure(state, 'deviceSafety', {
        activeDevices = 0, invasiveDevices = 0, infectionRisk = 0,
        removalCandidates = {}, overdueChecks = {}, lineDays = 0
    })
    ensure(state, 'recoveryModelV11', {
        physiologicReserve = 100, frailty = 0, deliriumRisk = 0,
        rehabilitationNeed = 0, dischargeBarrierScore = 0, predictedRecoveryHours = 0
    })
    ensure(state, 'v11', {
        autonomousRisk = 0, interventionDelayRisk = 0, resourceIntensity = 0,
        homeostasisScore = 100, clinicalPriority = 'routine', predictedLevelOfCare = 'self_care',
        predictedMortality = 0, dataReliability = 100, networkReadiness = 100,
        unresolvedConflicts = 0, autonomousPlanStatus = 'none', reassessmentIntervalSeconds = 60,
        lastCalculated = 0
    })

    state.autonomousCarePlans = type(state.autonomousCarePlans) == 'table' and state.autonomousCarePlans or {}
    state.decisionCheckpoints = type(state.decisionCheckpoints) == 'table' and state.decisionCheckpoints or {}
    state.waveformSnapshots = type(state.waveformSnapshots) == 'table' and state.waveformSnapshots or {}
    state.v11Recommendations = type(state.v11Recommendations) == 'table' and state.v11Recommendations or {}
    return state
end

local function calculateFrailty(state, age, bmi)
    local mobility = tonumber(state.demographics.baselineMobility) or 100
    local cognition = tonumber(state.demographics.baselineCognition) or 100
    local comorbidityCount = countTable(state.conditions)
    local frailty = math.max(0, age - 60) * 0.9
        + math.max(0, 70 - mobility) * 0.6
        + math.max(0, 75 - cognition) * 0.45
        + comorbidityCount * 3
        + ((bmi < 18.5 or bmi > 40) and 10 or 0)
    return clamp(frailty, 0, 100)
end

local function calculateEndocrine(state)
    local glucose = lab(state, 'glucose', state.endocrineModel.glucose or 95)
    local ketones = lab(state, 'ketones', state.endocrineModel.ketones or 0)
    local sodium = lab(state, 'sodium', 140)
    local potassium = lab(state, 'potassium', 4.0)
    local cortisol = lab(state, 'cortisol', 18)
    local risk = 0
    local crisis = 'none'

    if glucose >= 450 and ketones >= 3 then risk = risk + 65; crisis = 'diabetic_ketoacidosis' end
    if glucose >= 650 and ketones < 3 then risk = risk + 70; crisis = 'hyperosmolar_crisis' end
    if glucose < 55 then risk = risk + 80; crisis = 'severe_hypoglycemia' end
    if sodium < 120 or sodium > 160 then risk = risk + 45; if crisis == 'none' then crisis = 'sodium_crisis' end end
    if potassium < 2.8 or potassium > 6.2 then risk = risk + 55; if crisis == 'none' then crisis = 'potassium_crisis' end end
    if cortisol < 5 or hasCondition(state, 'adrenal') then risk = risk + 45; if crisis == 'none' then crisis = 'adrenal_crisis' end end

    return {
        glucose = round(glucose, 1), ketones = round(ketones, 1), cortisolReserve = math.floor(clamp(cortisol * 5, 0, 100)),
        thyroidReserve = math.floor(clamp(100 - (hasCondition(state, 'thyroid') and 35 or 0), 0, 100)),
        insulinNeed = math.floor(clamp((glucose - 140) * 0.16, 0, 100)), endocrineRisk = math.floor(clamp(risk, 0, 100)), crisis = crisis
    }
end

local function calculateInfection(state, vitals, lactate)
    local temperature = tonumber(vitals.temp) or 98.6
    local wbc = lab(state, 'wbc', 8.0)
    local crp = lab(state, 'crp', 0.5)
    local procalcitonin = lab(state, 'procalcitonin', 0.05)
    local probability = 0
    if temperature >= 101.5 or temperature <= 95.0 then probability = probability + 22 end
    if wbc >= 15 or wbc <= 3 then probability = probability + 18 end
    if crp >= 10 then probability = probability + 18 end
    if procalcitonin >= 2 then probability = probability + 28 end
    if lactate >= 4 then probability = probability + 18 end
    if hasCondition(state, 'sepsis') or hasCondition(state, 'infection') then probability = probability + 35 end
    local source = state.flags and state.flags.infectionSource or 'unknown'
    local delay = tonumber(state.flags and state.flags.antimicrobialDelayMinutes) or 0
    return {
        probability = math.floor(clamp(probability, 0, 100)), sourceControlNeeded = probability >= 55,
        source = source, antimicrobialDelayMinutes = delay,
        immuneFailure = math.floor(clamp(probability * 0.6 + math.max(0, lactate - 2) * 6, 0, 100)),
        isolationPriority = math.floor(clamp((hasCondition(state, 'contagious') and 70 or 0) + probability * 0.3, 0, 100))
    }
end

local function calculateDeviceSafety(state, infectionProbability)
    local active, invasive = activeDeviceCount(state)
    local lineDays = 0
    local overdue, removal = {}, {}
    for id, device in pairs(state.devices or {}) do
        if type(device) == 'table' and device.status ~= 'removed' then
            local inserted = tonumber(device.insertedAt) or now()
            local days = math.max(0, (now() - inserted) / 86400)
            lineDays = lineDays + days
            if days >= (tonumber(device.reviewAfterDays) or 3) then overdue[#overdue + 1] = tostring(id) end
            if device.indication == nil or device.indication == '' then removal[#removal + 1] = tostring(id) end
        end
    end
    return {
        activeDevices = active, invasiveDevices = invasive, lineDays = round(lineDays, 1),
        infectionRisk = math.floor(clamp(invasive * 8 + lineDays * 1.8 + infectionProbability * 0.35, 0, 100)),
        removalCandidates = removal, overdueChecks = overdue
    }
end

local function calculateNutrition(state, weightKg, heightCm, frailty)
    local heightM = math.max(1.2, heightCm / 100)
    local bmi = weightKg / (heightM * heightM)
    local ideal = 50 + 0.9 * math.max(0, heightCm - 152.4)
    local stress = tonumber(state.v10 and state.v10.commandRisk) or 0
    local calorieTarget = weightKg * (stress >= 60 and 30 or 25)
    local proteinTarget = weightKg * (stress >= 60 and 1.8 or 1.2)
    local deliveredCalories = tonumber(state.nutrition and state.nutrition.caloriesDelivered) or 0
    local deliveredProtein = tonumber(state.nutrition and state.nutrition.proteinDelivered) or 0
    local aspiration = clamp(
        (((tonumber(state.neuro and state.neuro.gcs) or 15) < 9) and 55 or 0)
        + ((state.status and state.status.unconscious) and 35 or 0)
        + ((state.organSupport and state.organSupport.ventilator) and 10 or 0),
        0, 100
    )
    local risk = clamp(math.max(0, calorieTarget - deliveredCalories) / math.max(1, calorieTarget) * 45
        + math.max(0, proteinTarget - deliveredProtein) / math.max(1, proteinTarget) * 35
        + frailty * 0.25 + ((bmi < 18.5) and 25 or 0), 0, 100)
    return {
        bmi = round(bmi, 1), idealBodyWeightKg = round(ideal, 1), calorieTarget = math.floor(calorieTarget),
        proteinTargetGrams = math.floor(proteinTarget), calorieDeficit = math.floor(math.max(0, calorieTarget - deliveredCalories)),
        proteinDeficit = math.floor(math.max(0, proteinTarget - deliveredProtein)), aspirationRisk = math.floor(aspiration),
        nutritionRisk = math.floor(risk)
    }
end

function DPN_MED.CalculateV11Metrics(state)
    state = DPN_MED.EnsureV11Schema(state)
    if DPN_MED.CalculateV10Metrics then state = DPN_MED.CalculateV10Metrics(state) end

    local v = state.vitals or {}
    local age = clamp(state.demographics.age, 0, 110)
    local weight = clamp(state.demographics.weightKg, 25, 300)
    local height = clamp(state.demographics.heightCm, 120, 230)
    local map = tonumber(state.advanced and state.advanced.map)
        or (((tonumber(v.systolic) or 120) + 2 * (tonumber(v.diastolic) or 80)) / 3)
    local lactate = tonumber(state.bloodGas and state.bloodGas.lactate) or lab(state, 'lactate', 1.0)
    local spo2 = tonumber(v.spo2) or 99
    local temperature = tonumber(v.temp) or 98.6
    local commandRisk = tonumber(state.v10 and state.v10.commandRisk) or 0
    local careGaps = tonumber(state.v10 and state.v10.careGapCount) or 0

    local heightM = height / 100
    local bmi = weight / math.max(1.0, heightM * heightM)
    local frailty = calculateFrailty(state, age, bmi)
    local tissueO2 = clamp(spo2 - math.max(0, 65 - map) * 0.7 - math.max(0, lactate - 2) * 3.5, 0, 100)
    local refill = clamp(1.5 + math.max(0, 70 - map) * 0.045 + math.max(0, lactate - 2) * 0.22, 1, 8)
    local mottling = clamp(math.max(0, 65 - map) * 0.08 + math.max(0, lactate - 2) * 0.4, 0, 5)
    local endothelial = clamp(100 - (tonumber(state.circulationModel and state.circulationModel.capillaryLeak) or 0)
        - math.max(0, temperature - 101) * 6 - commandRisk * 0.18, 0, 100)
    local heterogeneity = clamp(math.max(0, 75 - tissueO2) * 1.3 + mottling * 8, 0, 100)
    local cellularStress = clamp(math.max(0, lactate - 2) * 9 + math.max(0, 65 - map) * 1.1
        + math.max(0, 90 - spo2) * 2, 0, 100)

    local endocrine = calculateEndocrine(state)
    local infection = calculateInfection(state, v, lactate)
    local deviceSafety = calculateDeviceSafety(state, infection.probability)
    local nutrition = calculateNutrition(state, weight, height, frailty)

    local physiologicReserve = clamp(100 - commandRisk * 0.55 - frailty * 0.35
        - endocrine.endocrineRisk * 0.22 - infection.immuneFailure * 0.2 - cellularStress * 0.3, 0, 100)
    local deliriumRisk = clamp(frailty * 0.35 + (tonumber(state.neuroCritical and state.neuroCritical.deliriumRisk) or 0) * 0.65
        + deviceSafety.activeDevices * 2 + infection.probability * 0.18, 0, 100)
    local rehabNeed = clamp((100 - physiologicReserve) * 0.5 + frailty * 0.45
        + math.max(0, 100 - (tonumber(state.status and state.status.mobility) or 100)) * 0.35, 0, 100)
    local dischargeBarriers = clamp(frailty * 0.35 + rehabNeed * 0.45 + deviceSafety.activeDevices * 6
        + nutrition.nutritionRisk * 0.25 + infection.isolationPriority * 0.2, 0, 100)

    local interventionDelay = clamp(commandRisk * 0.55 + careGaps * 8 + math.max(0, lactate - 2) * 5
        + infection.antimicrobialDelayMinutes * 0.4, 0, 100)
    local resourceIntensity = clamp(commandRisk * 0.45 + deviceSafety.invasiveDevices * 8
        + endocrine.endocrineRisk * 0.22 + infection.probability * 0.25 + rehabNeed * 0.15, 0, 100)
    local homeostasis = clamp(100 - commandRisk * 0.5 - cellularStress * 0.28 - endocrine.endocrineRisk * 0.2
        - infection.immuneFailure * 0.18 - deviceSafety.infectionRisk * 0.12, 0, 100)
    local mortality = clamp(commandRisk * 0.52 + (100 - physiologicReserve) * 0.32 + cellularStress * 0.22
        + endocrine.endocrineRisk * 0.12 + infection.immuneFailure * 0.16, 0, 99)

    local dataPoints = 0
    for _, key in ipairs({ 'hr', 'rr', 'spo2', 'systolic', 'diastolic', 'blood', 'temp' }) do
        if tonumber(v[key]) ~= nil then dataPoints = dataPoints + 1 end
    end
    local reliability = clamp(45 + dataPoints * 6 + (state.labs and countTable(state.labs) or 0) * 1.8
        - (state.flags and state.flags.staleData and 30 or 0), 0, 100)

    local level = 'self_care'
    local priority = 'routine'
    local interval = 120
    if mortality >= 70 or commandRisk >= 88 then level, priority, interval = 'resuscitation', 'immediate', 10
    elseif commandRisk >= 72 or resourceIntensity >= 75 then level, priority, interval = 'intensive_care', 'critical', 15
    elseif commandRisk >= 50 or endocrine.endocrineRisk >= 55 or infection.probability >= 65 then level, priority, interval = 'monitored_acute', 'urgent', 30
    elseif commandRisk >= 25 or rehabNeed >= 45 then level, priority, interval = 'inpatient', 'high', 60 end

    state.microcirculation.tissueOxygenation = math.floor(tissueO2)
    state.microcirculation.capillaryRefillSeconds = round(refill, 1)
    state.microcirculation.mottlingScore = round(mottling, 1)
    state.microcirculation.endothelialIntegrity = math.floor(endothelial)
    state.microcirculation.perfusionHeterogeneity = math.floor(heterogeneity)
    state.microcirculation.cellularStress = math.floor(cellularStress)
    state.endocrineModel = endocrine
    state.infectionModel = infection
    state.deviceSafety = deviceSafety
    state.nutritionModel = nutrition
    state.recoveryModelV11.physiologicReserve = math.floor(physiologicReserve)
    state.recoveryModelV11.frailty = math.floor(frailty)
    state.recoveryModelV11.deliriumRisk = math.floor(deliriumRisk)
    state.recoveryModelV11.rehabilitationNeed = math.floor(rehabNeed)
    state.recoveryModelV11.dischargeBarrierScore = math.floor(dischargeBarriers)
    state.recoveryModelV11.predictedRecoveryHours = math.floor(clamp((100 - physiologicReserve) * 2.4 + rehabNeed * 1.6, 0, 720))
    state.v11.autonomousRisk = math.floor(clamp(commandRisk * 0.55 + interventionDelay * 0.25 + cellularStress * 0.25
        + endocrine.endocrineRisk * 0.15 + infection.immuneFailure * 0.2, 0, 100))
    state.v11.interventionDelayRisk = math.floor(interventionDelay)
    state.v11.resourceIntensity = math.floor(resourceIntensity)
    state.v11.homeostasisScore = math.floor(homeostasis)
    state.v11.clinicalPriority = priority
    state.v11.predictedLevelOfCare = level
    state.v11.predictedMortality = math.floor(mortality)
    state.v11.dataReliability = math.floor(reliability)
    state.v11.reassessmentIntervalSeconds = interval
    state.v11.lastCalculated = now()
    state.v11Recommendations = DPN_MED.GetV11Recommendations and DPN_MED.GetV11Recommendations(state, true) or {}
    return state
end

function DPN_MED.GetV11Recommendations(state, alreadyCalculated)
    state = DPN_MED.EnsureV11Schema(state)
    if not alreadyCalculated then state = DPN_MED.CalculateV11Metrics(state) end
    local recommendations = {}
    local function add(code, priority, department, reason, targetMinutes, humanApproval)
        recommendations[#recommendations + 1] = {
            code = code, priority = priority, department = department, reason = reason,
            targetMinutes = targetMinutes, requiresHumanApproval = humanApproval ~= false
        }
    end

    if state.microcirculation.tissueOxygenation < 70 then
        add('restore_tissue_oxygen_delivery', 1, 'critical_care', 'Modeled tissue oxygenation is critically reduced.', 3)
    end
    if state.v11.interventionDelayRisk >= 65 then
        add('activate_time_critical_pathway', 1, 'command', 'Delay risk is high with unresolved care gaps.', 2)
    end
    if state.endocrineModel.endocrineRisk >= 50 then
        add('endocrine_emergency_bundle', 1, 'emergency', 'A severe metabolic or endocrine crisis is predicted.', 5)
    end
    if state.infectionModel.probability >= 65 then
        add('sepsis_source_control_bundle', 1, 'infectious_disease', 'Infection probability and organ-stress signals are high.', 15)
    end
    if state.deviceSafety.infectionRisk >= 45 or #state.deviceSafety.overdueChecks > 0 then
        add('device_necessity_and_line_review', 2, 'nursing', 'Invasive-device risk or overdue safety checks were detected.', 30)
    end
    if state.nutritionModel.nutritionRisk >= 50 then
        add('early_nutrition_support', 3, 'nutrition', 'Nutrition deficit may impair recovery.', 120)
    end
    if state.recoveryModelV11.deliriumRisk >= 50 then
        add('delirium_prevention_bundle', 2, 'critical_care', 'Predicted delirium risk is elevated.', 60)
    end
    if state.recoveryModelV11.rehabilitationNeed >= 55 then
        add('early_mobility_and_rehab', 3, 'rehabilitation', 'Functional decline risk requires early rehabilitation.', 240)
    end
    if state.v11.dataReliability < 65 then
        add('acquire_missing_clinical_data', 2, 'diagnostics', 'Decision confidence is limited by missing or stale data.', 15, false)
    end
    if #recommendations == 0 then
        add('continue_adaptive_monitoring', 4, 'primary_team', 'Current physiology is stable under the v11 model.', state.v11.reassessmentIntervalSeconds / 60, false)
    end
    table.sort(recommendations, function(a, b)
        if a.priority == b.priority then return (a.targetMinutes or 9999) < (b.targetMinutes or 9999) end
        return a.priority < b.priority
    end)
    return recommendations
end

function DPN_MED.BuildV11Twin(state)
    state = DPN_MED.CalculateV11Metrics(state)
    return {
        generatedAt = now(), demographics = copy(state.demographics), vitals = copy(state.vitals),
        v8 = copy(state.v8), v9 = copy(state.v9), v10 = copy(state.v10), v11 = copy(state.v11),
        hemodynamics = copy(state.hemodynamics), pulmonary = copy(state.pulmonary), renal = copy(state.renal),
        circulation = copy(state.circulationModel),
        bloodGas = copy(state.bloodGas), microcirculation = copy(state.microcirculation),
        endocrine = copy(state.endocrineModel), infection = copy(state.infectionModel),
        nutrition = copy(state.nutritionModel), deviceSafety = copy(state.deviceSafety),
        recovery = copy(state.recoveryModelV11), toxicity = copy(state.toxicity),
        recommendations = copy(state.v11Recommendations), status = copy(state.status)
    }
end

local function applyForecastIntervention(state, intervention)
    intervention = tostring(intervention or ''):lower()
    state.flags = type(state.flags) == 'table' and state.flags or {}
    state.labs = type(state.labs) == 'table' and state.labs or {}
    state.conditions = type(state.conditions) == 'table' and state.conditions or {}
    if intervention == 'oxygen' then
        state.vitals.spo2 = clamp((tonumber(state.vitals.spo2) or 80) + 10, 0, 100)
        state.flags.oxygenSupport = true
    elseif intervention == 'advanced_airway' then
        state.vitals.spo2 = clamp((tonumber(state.vitals.spo2) or 75) + 18, 0, 100)
        state.vitals.rr = 16
        state.labs.paco2 = clamp(lab(state, 'paco2', 55) - 12, 25, 50)
        state.flags.airwaySecured = true
    elseif intervention == 'blood' or intervention == 'massive_transfusion' then
        state.vitals.blood = clamp((tonumber(state.vitals.blood) or 2500) + (intervention == 'massive_transfusion' and 1500 or 500), 0, 6000)
        state.flags.transfusionStarted = true
        state.labs.fibrinogen = clamp(lab(state, 'fibrinogen', 150) + 50, 50, 500)
    elseif intervention == 'fluids' then
        state.vitals.systolic = clamp((tonumber(state.vitals.systolic) or 80) + 10, 0, 220)
        state.vitals.diastolic = clamp((tonumber(state.vitals.diastolic) or 45) + 6, 0, 140)
        state.flags.fluidResuscitation = true
    elseif intervention == 'hemorrhage_control' then
        for _, part in pairs(state.body or {}) do
            part.bleeding = 'none'
            part.internalBleeding = false
            part.bleedStacks = 0
        end
        state.flags.hemorrhageControlled = true
    elseif intervention == 'vasopressor' then
        state.vitals.systolic = clamp((tonumber(state.vitals.systolic) or 75) + 18, 0, 220)
        state.vitals.diastolic = clamp((tonumber(state.vitals.diastolic) or 40) + 12, 0, 140)
        state.flags.vasopressorStarted = true
    elseif intervention == 'antibiotics' then
        state.flags.antimicrobialDelayMinutes = 0
        state.flags.antibioticsStarted = true
        state.labs.procalcitonin = math.max(0, lab(state, 'procalcitonin', 2.5) - 0.5)
    elseif intervention == 'source_control' then
        state.flags.sourceControlCompleted = true
        state.conditions.sepsis = nil
        state.labs.lactate = math.max(1.0, lab(state, 'lactate', 5.0) - 1.2)
    elseif intervention == 'insulin' then
        state.labs.glucose = math.max(90, lab(state, 'glucose', 450) - 120)
        state.labs.ketones = math.max(0, lab(state, 'ketones', 4) - 1.0)
    elseif intervention == 'dialysis' then
        state.labs.potassium = clamp(lab(state, 'potassium', 6.5) - 1.4, 3.5, 5.0)
        state.labs.creatinine = math.max(1.0, lab(state, 'creatinine', 4.0) - 1.0)
        state.flags.renalReplacementStarted = true
    elseif intervention == 'warming' then
        state.vitals.temp = clamp((tonumber(state.vitals.temp) or 94) + 2.0, 90, 102)
    elseif intervention == 'cooling' then
        state.vitals.temp = clamp((tonumber(state.vitals.temp) or 105) - 2.5, 95, 106)
    elseif intervention == 'antidote' then
        state.conditions.opioid_toxicity = nil
        state.flags.antidoteGiven = true
    end
    return state
end

function DPN_MED.ForecastInterventionV11(state, intervention, horizonMinutes)
    state = DPN_MED.CalculateV11Metrics(state)
    local before = DPN_MED.BuildV11Twin(state)
    local projected = copy(state)
    projected = applyForecastIntervention(projected, intervention)
    projected = DPN_MED.CalculateV11Metrics(projected)
    local after = DPN_MED.BuildV11Twin(projected)
    return {
        intervention = tostring(intervention or 'none'), horizonMinutes = clamp(horizonMinutes or 15, 1, 240),
        before = { risk = before.v11.autonomousRisk, mortality = before.v11.predictedMortality, homeostasis = before.v11.homeostasisScore,
            levelOfCare = before.v11.predictedLevelOfCare, tissueOxygenation = before.microcirculation.tissueOxygenation },
        after = { risk = after.v11.autonomousRisk, mortality = after.v11.predictedMortality, homeostasis = after.v11.homeostasisScore,
            levelOfCare = after.v11.predictedLevelOfCare, tissueOxygenation = after.microcirculation.tissueOxygenation },
        estimatedBenefit = math.floor(clamp(before.v11.autonomousRisk - after.v11.autonomousRisk, -100, 100)),
        estimatedMortalityReduction = math.floor(clamp(before.v11.predictedMortality - after.v11.predictedMortality, -100, 100)),
        warnings = after.v11.autonomousRisk > before.v11.autonomousRisk and { 'The modeled intervention may worsen this patient.' } or {},
        requiresHumanApproval = true, generatedAt = now()
    }
end

function DPN_MED.ReconcileDevicesAndMedicationsV11(state)
    state = DPN_MED.CalculateV11Metrics(state)
    local findings = {}
    local function add(code, severity, message, recommendation)
        findings[#findings + 1] = { code = code, severity = severity, message = message, recommendation = recommendation }
    end
    if state.deviceSafety.infectionRisk >= 45 then add('device_infection_risk', 'high', 'Invasive-device infection risk is elevated.', 'Review every device indication and aseptic-care interval.') end
    for _, id in ipairs(state.deviceSafety.removalCandidates or {}) do add('device_without_indication', 'medium', 'Device ' .. tostring(id) .. ' has no documented indication.', 'Remove or document continued need.') end
    if state.toxicity and state.toxicity.totalBurden >= 35 then add('medication_burden', 'high', 'Medication/toxicology burden is clinically significant.', 'Pharmacist review and continuous respiratory monitoring.') end
    if state.endocrineModel.glucose < 70 and state.flags and state.flags.insulinInfusion then add('insulin_hypoglycemia', 'critical', 'Insulin is active during hypoglycemia.', 'Stop insulin and initiate hypoglycemia rescue protocol.') end
    if state.bloodGas and state.bloodGas.ventilationFailure and state.toxicity and state.toxicity.sedative >= 25 then add('sedative_ventilation_conflict', 'critical', 'Sedative burden is worsening ventilation failure.', 'Hold sedatives and secure ventilation.') end
    if #findings == 0 then add('reconciliation_clear', 'info', 'No major device or medication conflicts were detected.', 'Continue scheduled review.') end
    return { score = math.floor(clamp(100 - (#findings - 1) * 18 - state.deviceSafety.infectionRisk * 0.2, 0, 100)), findings = findings, generatedAt = now() }
end

function DPN_MED.BuildAutonomousCarePlanV11(state)
    state = DPN_MED.CalculateV11Metrics(state)
    local steps = {}
    for index, item in ipairs(state.v11Recommendations or {}) do
        steps[#steps + 1] = {
            id = ('STEP-%02d'):format(index), code = item.code, department = item.department,
            priority = item.priority, reason = item.reason, targetMinutes = item.targetMinutes,
            status = item.requiresHumanApproval and 'awaiting_approval' or 'planned',
            requiresHumanApproval = item.requiresHumanApproval, createdAt = now()
        }
    end
    return {
        status = 'draft', risk = state.v11.autonomousRisk, mortality = state.v11.predictedMortality,
        levelOfCare = state.v11.predictedLevelOfCare, reassessmentIntervalSeconds = state.v11.reassessmentIntervalSeconds,
        steps = steps, createdAt = now(), advisoryOnly = true
    }
end

function DPN_MED.BuildWaveformSnapshotV11(state, sampleCount)
    state = DPN_MED.CalculateV11Metrics(state)
    sampleCount = math.max(12, math.min(120, tonumber(sampleCount) or 36))
    local hr = tonumber(state.vitals.hr) or 74
    local rr = tonumber(state.vitals.rr) or 16
    local spo2 = tonumber(state.vitals.spo2) or 99
    local etco2 = tonumber(state.vitals.etco2) or math.max(10, 40 - math.max(0, rr - 16) * 0.8)
    local rhythm = state.advanced and state.advanced.rhythm or (hr == 0 and 'asystole' or 'sinus')
    local ecg, pleth, capno = {}, {}, {}
    for index = 1, sampleCount do
        local phase = (index - 1) / sampleCount
        local qrs = math.sin(phase * math.pi * 2 * math.max(1, hr / 60))
        local pulse = math.max(0, math.sin(phase * math.pi * 2 * math.max(1, hr / 60)))
        local breath = math.max(0, math.sin(phase * math.pi * 2 * math.max(0.2, rr / 60)))
        ecg[index] = round(qrs * (rhythm == 'asystole' and 0.01 or 1.0), 3)
        pleth[index] = round(pulse * (spo2 / 100), 3)
        capno[index] = round(breath * etco2, 2)
    end
    return { generatedAt = now(), rhythm = rhythm, hr = hr, rr = rr, spo2 = spo2, etco2 = round(etco2, 1), ecg = ecg, pleth = pleth, capnography = capno }
end

function DPN_MED.RunV11SharedSelfTest()
    local state = DPN_MED.NewBodyState()
    state.vitals.hr = 154; state.vitals.rr = 38; state.vitals.spo2 = 78; state.vitals.systolic = 62; state.vitals.diastolic = 32; state.vitals.temp = 102.8; state.vitals.blood = 2300
    state.labs = { lactate = 8.4, glucose = 520, ketones = 4.2, sodium = 126, potassium = 6.4, wbc = 19, procalcitonin = 4.5, ph = 7.08, hco3 = 12, paco2 = 54 }
    state.conditions = { sepsis = { severity = 90 }, diabetic_ketoacidosis = { severity = 85 } }
    state.body.abdomen.internalBleeding = true; state.body.abdomen.damage = 80
    state = DPN_MED.CalculateV11Metrics(state)
    local twin = DPN_MED.BuildV11Twin(state)
    local forecast = DPN_MED.ForecastInterventionV11(state, 'blood', 15)
    local plan = DPN_MED.BuildAutonomousCarePlanV11(state)
    local reconciliation = DPN_MED.ReconcileDevicesAndMedicationsV11(state)
    return {
        passed = twin.v11.autonomousRisk >= 60 and twin.endocrine.endocrineRisk >= 50
            and twin.infection.probability >= 50 and #plan.steps >= 2 and forecast.before.risk >= forecast.after.risk,
        risk = twin.v11.autonomousRisk, endocrineRisk = twin.endocrine.endocrineRisk,
        infectionProbability = twin.infection.probability, planSteps = #plan.steps,
        forecastBenefit = forecast.estimatedBenefit, reconciliationFindings = #reconciliation.findings
    }
end

function DPN_MED.Recalculate(state)
    if previousRecalculate then state = previousRecalculate(state) end
    return DPN_MED.CalculateV11Metrics(state)
end
