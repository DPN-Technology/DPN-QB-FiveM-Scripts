DPN_MED = DPN_MED or {}

-- v10 critical-care command engine. This layer is deterministic and server
-- authoritative; it produces recommendations and closed-loop care gaps but
-- never performs a treatment unless an authorized server export is invoked.

local function now()
    return os and os.time and os.time() or 0
end

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function ensure(parent, key, defaults)
    parent[key] = type(parent[key]) == 'table' and parent[key] or {}
    for name, value in pairs(defaults or {}) do
        if parent[key][name] == nil then parent[key][name] = value end
    end
    return parent[key]
end

local bleedRates = { none = 0, capillary = 2, venous = 12, arterial = 32 }

function DPN_MED.EnsureV10Schema(state)
    state = type(state) == 'table' and state or DPN_MED.NewBodyState()
    if DPN_MED.EnsureV9Schema then state = DPN_MED.EnsureV9Schema(state) end
    ensure(state, 'circulationModel', {
        effectiveVolumeMl = 5000, hemorrhageRateMlMin = 0, internalHemorrhageRateMlMin = 0,
        capillaryLeak = 0, interstitialOverloadMl = 0, clotStability = 100,
        transfusionBalance = 100, fluidResponsiveness = 100
    })
    ensure(state, 'bloodGas', {
        ph = 7.40, paO2 = 95, paCO2 = 40, hco3 = 24, baseExcess = 0,
        lactate = 1.0, acidBase = 'normal', compensation = 'none',
        oxygenationFailure = false, ventilationFailure = false
    })
    ensure(state, 'toxicity', {
        opioid = 0, sedative = 0, sympathomimetic = 0, anticholinergic = 0,
        cholinergic = 0, cardiotoxic = 0, totalBurden = 0,
        dominantToxidrome = 'none', antidotes = {}
    })
    ensure(state, 'neuroCritical', {
        deliriumRisk = 0, seizureRisk = 0, herniationRisk = 0,
        sedationDepth = 0, cerebralOxygenRisk = 0
    })
    ensure(state, 'v10', {
        commandRisk = 0, instabilityIndex = 0, organCouplingFailure = 0,
        predictedArrestMinutes = -1, predictedICUNeed = 0, careGapCount = 0,
        closedLoopCompliance = 100, dataConfidence = 100, autonomyLevel = 'advisory',
        trajectoryClass = 'stable', recommendedCommand = 'routine_monitoring',
        lastCalculated = 0
    })
    state.closedLoopBundles = type(state.closedLoopBundles) == 'table' and state.closedLoopBundles or {}
    state.blackBoxEvents = type(state.blackBoxEvents) == 'table' and state.blackBoxEvents or {}
    state.commandIncidents = type(state.commandIncidents) == 'table' and state.commandIncidents or {}
    state.v10Recommendations = type(state.v10Recommendations) == 'table' and state.v10Recommendations or {}
    return state
end

local function lab(state, key, fallback)
    local value = state.labs and tonumber(state.labs[key])
    if value ~= nil then return value end
    if state.electrolytes and state.electrolytes[key] ~= nil then
        return tonumber(state.electrolytes[key]) or fallback
    end
    return fallback
end

local function calculateBleeding(state)
    local external, internal, wounds = 0, 0, 0
    for _, part in pairs(state.body or {}) do
        local rate = bleedRates[tostring(part.bleeding or 'none')] or 0
        local stacks = math.max(1, tonumber(part.bleedStacks) or 1)
        external = external + rate * math.min(stacks, 4)
        if part.internalBleeding == true then
            internal = internal + 18 + (tonumber(part.damage) or 0) * 0.22
        end
        for _, wound in ipairs(part.wounds or {}) do
            if wound.treated ~= true then wounds = wounds + 1 end
        end
    end
    return clamp(external, 0, 400), clamp(internal, 0, 400), wounds
end

local function acidBase(ph, paCO2, hco3)
    if ph < 7.35 then
        if hco3 < 22 and paCO2 > 45 then return 'mixed_acidosis', 'inadequate' end
        if hco3 < 22 then
            local expected = 1.5 * hco3 + 8
            return 'metabolic_acidosis', math.abs(paCO2 - expected) <= 4 and 'appropriate' or 'mixed'
        end
        return 'respiratory_acidosis', hco3 >= 24 and 'partial' or 'acute'
    elseif ph > 7.45 then
        if hco3 > 26 and paCO2 < 35 then return 'mixed_alkalosis', 'inadequate' end
        if hco3 > 26 then return 'metabolic_alkalosis', 'evaluate_respiration' end
        return 'respiratory_alkalosis', hco3 <= 22 and 'partial' or 'acute'
    end
    if hco3 < 20 and paCO2 < 32 then return 'compensated_metabolic_acidosis', 'compensated' end
    if hco3 > 28 and paCO2 > 46 then return 'compensated_respiratory_acidosis', 'compensated' end
    return 'normal', 'none'
end

local function toxicityBurden(state)
    local profile = { opioid = 0, sedative = 0, sympathomimetic = 0, anticholinergic = 0, cholinergic = 0, cardiotoxic = 0 }
    local mappings = {
        morphine = { opioid = 18, sedative = 8 }, fentanyl = { opioid = 22, sedative = 9 },
        midazolam = { sedative = 20 }, ketamine = { sedative = 8, sympathomimetic = 5 },
        epinephrine = { sympathomimetic = 14, cardiotoxic = 4 }, norepinephrine = { sympathomimetic = 10 },
        amiodarone = { cardiotoxic = 10 }, naloxone = { opioid = -20 }
    }
    for _, administration in ipairs(state.medicationAdministration or {}) do
        if administration.status ~= 'stopped' and administration.status ~= 'reversed' then
            local medication = tostring(administration.medication or ''):lower()
            local burden = mappings[medication]
            if burden then
                for key, value in pairs(burden) do profile[key] = clamp((profile[key] or 0) + value, 0, 100) end
            end
        end
    end
    for name, condition in pairs(state.conditions or {}) do
        local severity = type(condition) == 'table' and tonumber(condition.severity) or 50
        if tostring(name):find('opioid', 1, true) then profile.opioid = clamp(profile.opioid + severity * 0.8, 0, 100) end
        if tostring(name):find('stimulant', 1, true) then profile.sympathomimetic = clamp(profile.sympathomimetic + severity * 0.7, 0, 100) end
        if tostring(name):find('cholinergic', 1, true) then profile.cholinergic = clamp(profile.cholinergic + severity * 0.7, 0, 100) end
    end
    local dominant, maximum = 'none', 0
    for key, value in pairs(profile) do if value > maximum then dominant, maximum = key, value end end
    local antidotes = {}
    if profile.opioid >= 30 then antidotes[#antidotes + 1] = 'naloxone' end
    if profile.cholinergic >= 30 then antidotes[#antidotes + 1] = 'atropine_pralidoxime' end
    if profile.cardiotoxic >= 35 then antidotes[#antidotes + 1] = 'toxicology_cardiac_bundle' end
    profile.totalBurden = clamp(profile.opioid * 0.4 + profile.sedative * 0.35 + profile.sympathomimetic * 0.2 + profile.cardiotoxic * 0.3 + profile.anticholinergic * 0.15 + profile.cholinergic * 0.25, 0, 100)
    profile.dominantToxidrome = dominant
    profile.antidotes = antidotes
    return profile
end

function DPN_MED.CalculateV10Metrics(state)
    state = DPN_MED.EnsureV10Schema(state)
    local v = state.vitals or {}
    local externalRate, internalRate, openWounds = calculateBleeding(state)
    local ph = lab(state, 'ph', 7.40)
    local paCO2 = lab(state, 'paco2', tonumber(v.etco2) and (tonumber(v.etco2) + 4) or 40)
    local hco3 = lab(state, 'hco3', lab(state, 'bicarbonate', 24))
    local paO2 = lab(state, 'pao2', clamp((tonumber(v.spo2) or 99) * 1.05, 30, 110))
    local lactate = lab(state, 'lactate', tonumber(state.advanced and state.advanced.lactate) or 1.0)
    local baseExcess = 0.93 * (hco3 - 24.4 + 14.8 * (ph - 7.4))
    local acidClass, compensation = acidBase(ph, paCO2, hco3)
    local platelets = lab(state, 'platelets', 250)
    local inr = lab(state, 'inr', 1.0)
    local fibrinogen = lab(state, 'fibrinogen', 300)
    local temperature = tonumber(v.temp) or 98.6
    local clot = clamp(100 - math.max(0, inr - 1) * 24 - math.max(0, 150 - platelets) * 0.22 - math.max(0, 180 - fibrinogen) * 0.18 - math.max(0, 96.8 - temperature) * 7 - math.max(0, 7.30 - ph) * 150, 0, 100)
    local blood = tonumber(v.blood) or 5000
    local capillaryLeak = clamp((tonumber(state.immune and state.immune.inflammatoryLoad) or 0) * 0.45 + (temperature > 102 and 15 or 0), 0, 100)
    local interstitial = clamp((tonumber(state.fluids and state.fluids.intakeMl) or 0) - (tonumber(state.fluids and state.fluids.outputMl) or 0) - 1000, 0, 8000)
    local effectiveVolume = clamp(blood - interstitial * 0.08 - capillaryLeak * 6, 0, 5000)
    local tox = toxicityBurden(state)

    local map = tonumber(state.advanced and state.advanced.map) or (((tonumber(v.systolic) or 120) + 2 * (tonumber(v.diastolic) or 80)) / 3)
    local oxygenDelivery = tonumber(state.hemodynamics and state.hemodynamics.oxygenDeliveryMlMin) or 900
    local cpp = tonumber(state.hemodynamics and state.hemodynamics.cerebralPerfusionPressure) or map - 10
    local egfr = tonumber(state.renal and state.renal.estimatedGfr) or 100
    local adaptiveRisk = tonumber(state.v9 and state.v9.adaptiveRisk) or 0
    local organCoupling = clamp(math.max(0, 65 - map) * 1.2 + math.max(0, 650 - oxygenDelivery) * 0.06 + math.max(0, 60 - cpp) * 0.9 + math.max(0, 60 - egfr) * 0.25 + math.max(0, lactate - 2) * 8, 0, 100)
    local instability = clamp(adaptiveRisk * 0.45 + (externalRate + internalRate) * 0.12 + math.max(0, 80 - clot) * 0.28 + math.max(0, lactate - 2) * 6 + tox.totalBurden * 0.25 + organCoupling * 0.4, 0, 100)

    local dataPoints = 0
    for _, key in ipairs({ 'hr', 'rr', 'spo2', 'systolic', 'diastolic', 'blood', 'temp', 'etco2' }) do if tonumber(v[key]) ~= nil then dataPoints = dataPoints + 1 end end
    local labPoints = 0
    for _, key in ipairs({ 'ph', 'hco3', 'lactate', 'inr', 'platelets', 'creatinine', 'potassium' }) do if state.labs and tonumber(state.labs[key]) ~= nil then labPoints = labPoints + 1 end end
    local confidence = clamp(45 + dataPoints * 4 + labPoints * 3, 0, 100)

    local careGaps = {}
    if externalRate + internalRate >= 30 and not (state.flags and state.flags.hemorrhageControlled) then careGaps[#careGaps + 1] = 'hemorrhage_control' end
    if clot < 55 and not (state.flags and state.flags.coagulopathyAddressed) then careGaps[#careGaps + 1] = 'coagulopathy_correction' end
    if tonumber(v.spo2) and v.spo2 < 90 and not (state.organSupport and state.organSupport.ventilator) and (tonumber(state.respiration and state.respiration.oxygenLpm) or 0) <= 0 then careGaps[#careGaps + 1] = 'oxygenation_support' end
    if lactate >= 4 and not (state.flags and state.flags.perfusionBundleStarted) then careGaps[#careGaps + 1] = 'perfusion_resuscitation' end
    if tox.totalBurden >= 35 and #tox.antidotes > 0 then careGaps[#careGaps + 1] = 'toxicology_antidote_review' end
    if organCoupling >= 50 and not (state.flags and state.flags.criticalCareConsulted) then careGaps[#careGaps + 1] = 'critical_care_escalation' end

    local arrestMinutes = -1
    if instability >= 90 then arrestMinutes = 3 elseif instability >= 80 then arrestMinutes = 8 elseif instability >= 68 then arrestMinutes = 15 elseif instability >= 55 then arrestMinutes = 30 end
    local icuNeed = clamp(instability * 0.7 + organCoupling * 0.35 + math.max(0, 65 - map) * 0.8, 0, 100)
    local trajectory = instability >= 85 and 'imminent_failure' or instability >= 70 and 'critical_deterioration' or instability >= 50 and 'unstable' or instability <= 20 and 'recovering' or 'stable'
    local command = 'routine_monitoring'
    if instability >= 85 then command = 'activate_resuscitation_command'
    elseif instability >= 70 then command = 'critical_care_escalation'
    elseif instability >= 50 then command = 'monitored_high_acuity_care'
    elseif #careGaps > 0 then command = 'close_care_gaps' end

    state.circulationModel.effectiveVolumeMl = math.floor(effectiveVolume)
    state.circulationModel.hemorrhageRateMlMin = math.floor(externalRate)
    state.circulationModel.internalHemorrhageRateMlMin = math.floor(internalRate)
    state.circulationModel.capillaryLeak = math.floor(capillaryLeak)
    state.circulationModel.interstitialOverloadMl = math.floor(interstitial)
    state.circulationModel.clotStability = math.floor(clot)
    state.circulationModel.fluidResponsiveness = math.floor(clamp(100 - interstitial / 80 - capillaryLeak * 0.4, 0, 100))
    state.bloodGas.ph = math.floor(ph * 100) / 100
    state.bloodGas.paO2 = math.floor(paO2)
    state.bloodGas.paCO2 = math.floor(paCO2)
    state.bloodGas.hco3 = math.floor(hco3 * 10) / 10
    state.bloodGas.baseExcess = math.floor(baseExcess * 10) / 10
    state.bloodGas.lactate = math.floor(lactate * 10) / 10
    state.bloodGas.acidBase = acidClass
    state.bloodGas.compensation = compensation
    state.bloodGas.oxygenationFailure = paO2 < 60 or (tonumber(v.spo2) or 99) < 88
    state.bloodGas.ventilationFailure = paCO2 > 55 or paCO2 < 25
    state.toxicity = tox
    state.neuroCritical.sedationDepth = math.floor(clamp(tox.opioid * 0.5 + tox.sedative * 0.7, 0, 100))
    state.neuroCritical.deliriumRisk = math.floor(clamp((tonumber(state.recovery and state.recovery.sleepDebt) or 0) * 0.4 + tox.totalBurden * 0.3 + math.max(0, 92 - (tonumber(v.spo2) or 99)) * 2 + math.max(0, lactate - 2) * 5, 0, 100))
    state.neuroCritical.cerebralOxygenRisk = math.floor(clamp(math.max(0, 60 - cpp) * 1.5 + math.max(0, 90 - (tonumber(v.spo2) or 99)) * 2, 0, 100))
    state.v10.commandRisk = math.floor(instability)
    state.v10.instabilityIndex = math.floor(instability)
    state.v10.organCouplingFailure = math.floor(organCoupling)
    state.v10.predictedArrestMinutes = arrestMinutes
    state.v10.predictedICUNeed = math.floor(icuNeed)
    state.v10.careGapCount = #careGaps
    state.v10.closedLoopCompliance = math.floor(clamp(100 - #careGaps * 14, 0, 100))
    state.v10.dataConfidence = math.floor(confidence)
    state.v10.trajectoryClass = trajectory
    state.v10.recommendedCommand = command
    state.v10.lastCalculated = now()
    state.v10Recommendations = careGaps
    return state
end

function DPN_MED.GetV10Recommendations(state)
    state = DPN_MED.CalculateV10Metrics(state)
    local out = {}
    local function add(code, priority, department, reason, targetMinutes)
        out[#out + 1] = { code = code, priority = priority, department = department, reason = reason, targetMinutes = targetMinutes }
    end
    if state.circulationModel.hemorrhageRateMlMin + state.circulationModel.internalHemorrhageRateMlMin >= 30 then add('hemorrhage_command_bundle', 1, 'trauma', 'Ongoing modeled blood loss is clinically significant.', 3) end
    if state.circulationModel.clotStability < 55 then add('coagulation_restoration', 1, 'blood_bank', 'Clot stability is below the safe threshold.', 8) end
    if state.bloodGas.oxygenationFailure then add('oxygenation_rescue', 1, 'respiratory', 'Arterial oxygenation failure is present.', 2) end
    if state.bloodGas.ventilationFailure then add('ventilation_rescue', 1, 'respiratory', 'Ventilation failure is present.', 2) end
    if state.bloodGas.lactate >= 4 then add('shock_source_control', 1, 'critical_care', 'Lactate suggests inadequate perfusion or severe stress.', 5) end
    if state.toxicity.totalBurden >= 35 then add('toxicology_review', 1, 'pharmacy', 'Medication or toxin burden is elevated.', 5) end
    if state.v10.organCouplingFailure >= 50 then add('multi_organ_support', 1, 'icu', 'Organ perfusion systems are failing together.', 5) end
    if state.neuroCritical.cerebralOxygenRisk >= 45 then add('neuro_oxygen_delivery', 1, 'neurocritical', 'Cerebral oxygen delivery is threatened.', 3) end
    if state.v10.dataConfidence < 70 then add('complete_critical_data', 2, 'clinical_operations', 'Critical decision data is incomplete.', 10) end
    return out
end

function DPN_MED.BuildV10Twin(state)
    state = DPN_MED.CalculateV10Metrics(state)
    return {
        version = '10.0.0', generatedAt = now(), lifeState = state.status and state.status.lifeState,
        triage = state.status and state.status.triage, vitals = state.vitals,
        circulation = state.circulationModel, bloodGas = state.bloodGas,
        toxicity = state.toxicity, neuroCritical = state.neuroCritical,
        v10 = state.v10, v9 = state.v9, v8 = state.v8, v6 = state.v6,
        recommendations = DPN_MED.GetV10Recommendations(state), careGaps = state.v10Recommendations
    }
end

function DPN_MED.PredictV10Transition(state, horizonMinutes)
    state = DPN_MED.CalculateV10Metrics(state)
    horizonMinutes = clamp(horizonMinutes or 15, 1, 240)
    local activeBleed = state.circulationModel.hemorrhageRateMlMin + state.circulationModel.internalHemorrhageRateMlMin
    local projectedBlood = clamp((tonumber(state.vitals.blood) or 5000) - activeBleed * horizonMinutes, 0, 5000)
    local untreatedGrowth = (#state.v10Recommendations or 0) * 0.9 * math.sqrt(horizonMinutes)
    local projectedRisk = clamp(state.v10.commandRisk + untreatedGrowth + math.max(0, 3000 - projectedBlood) / 90, 0, 100)
    return {
        horizonMinutes = horizonMinutes, currentRisk = state.v10.commandRisk,
        projectedRisk = math.floor(projectedRisk), projectedBloodMl = math.floor(projectedBlood),
        projectedClass = projectedRisk >= 85 and 'imminent_failure' or projectedRisk >= 70 and 'critical_deterioration' or projectedRisk >= 50 and 'unstable' or 'stable',
        predictedArrestMinutes = state.v10.predictedArrestMinutes, assumptions = { no_new_treatment = true, hemorrhage_rate_constant = true }
    }
end

function DPN_MED.BuildClosedLoopBundle(state)
    state = DPN_MED.CalculateV10Metrics(state)
    local steps = {}
    for _, rec in ipairs(DPN_MED.GetV10Recommendations(state)) do
        steps[#steps + 1] = {
            code = rec.code, department = rec.department, priority = rec.priority,
            reason = rec.reason, targetMinutes = rec.targetMinutes,
            status = 'pending', createdAt = now()
        }
    end
    return {
        version = '10.0.0', status = #steps > 0 and 'active' or 'complete',
        commandRisk = state.v10.commandRisk, compliance = state.v10.closedLoopCompliance,
        recommendedCommand = state.v10.recommendedCommand, steps = steps, createdAt = now()
    }
end

local previousRecalculate = DPN_MED.Recalculate
function DPN_MED.Recalculate(state)
    state = previousRecalculate(state)
    return DPN_MED.CalculateV10Metrics(state)
end
