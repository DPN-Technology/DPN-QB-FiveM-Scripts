DPN_MED = DPN_MED or {}

-- v9 adaptive clinical network: longitudinal physiology, pharmacokinetics,
-- safety reconciliation and recovery forecasting. All recommendations are
-- advisory unless a server explicitly invokes an existing treatment export.

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

local drugKinetics = {
    morphine = { halfLifeMin = 120, renal = 0.65, hepatic = 0.35, qt = 0, respiratory = 12, pressure = 5 },
    fentanyl = { halfLifeMin = 210, renal = 0.10, hepatic = 0.90, qt = 1, respiratory = 15, pressure = 4 },
    midazolam = { halfLifeMin = 150, renal = 0.30, hepatic = 0.70, qt = 1, respiratory = 13, pressure = 5 },
    ketamine = { halfLifeMin = 160, renal = 0.15, hepatic = 0.85, qt = 1, respiratory = 3, pressure = -3 },
    epinephrine = { halfLifeMin = 4, renal = 0.10, hepatic = 0.90, qt = 4, respiratory = 0, pressure = -12 },
    norepinephrine = { halfLifeMin = 3, renal = 0.05, hepatic = 0.95, qt = 2, respiratory = 0, pressure = -18 },
    amiodarone = { halfLifeMin = 2400, renal = 0.05, hepatic = 0.95, qt = 12, respiratory = 0, pressure = 4 },
    naloxone = { halfLifeMin = 60, renal = 0.55, hepatic = 0.45, qt = 0, respiratory = -10, pressure = 0 },
    ceftriaxone = { halfLifeMin = 480, renal = 0.55, hepatic = 0.45, qt = 0, respiratory = 0, pressure = 0 },
    tranexamic_acid = { halfLifeMin = 120, renal = 0.95, hepatic = 0.05, qt = 0, respiratory = 0, pressure = 0 }
}

function DPN_MED.EnsureV9Schema(state)
    state = type(state) == 'table' and state or DPN_MED.NewBodyState()
    if DPN_MED.EnsureV8Schema then state = DPN_MED.EnsureV8Schema(state) end
    ensure(state, 'electrolytes', {
        sodium = 140, potassium = 4.0, chloride = 103, bicarbonate = 24,
        calcium = 9.2, magnesium = 2.0, phosphate = 3.5
    })
    ensure(state, 'endocrine', {
        insulinEffect = 1.0, cortisolStress = 0, thyroidReserve = 100,
        ketones = 0, osmoticStress = 0
    })
    ensure(state, 'hepatic', {
        clearance = 100, syntheticFunction = 100, encephalopathy = 0,
        injuryScore = 0
    })
    ensure(state, 'immune', {
        inflammatoryLoad = 0, immuneReserve = 100, antimicrobialCoverage = 0,
        sourceControl = false
    })
    ensure(state, 'recovery', {
        mobilityPotential = 100, nutritionReserve = 100, sleepDebt = 0,
        rehabilitationBurden = 0, socialBarrierScore = 0
    })
    ensure(state, 'v9', {
        adaptiveRisk = 0, recoveryProbability = 100, electrolyteRisk = 0,
        medicationAccumulationRisk = 0, qtRisk = 0, hepaticRisk = 0,
        anionGap = 12, correctedSodium = 140, calculatedOsmolality = 290,
        predictedMinutesToCritical = -1, trajectory = 'stable',
        disposition = 'routine', confidence = 90, safetyIntegrity = 100,
        networkPriority = 5, lastCalculated = 0
    })
    state.activeDrugLevels = type(state.activeDrugLevels) == 'table' and state.activeDrugLevels or {}
    state.deviceTelemetry = type(state.deviceTelemetry) == 'table' and state.deviceTelemetry or {}
    state.adaptivePathways = type(state.adaptivePathways) == 'table' and state.adaptivePathways or {}
    state.safetyReconciliation = type(state.safetyReconciliation) == 'table' and state.safetyReconciliation or {}
    state.longitudinalTrajectory = type(state.longitudinalTrajectory) == 'table' and state.longitudinalTrajectory or {}
    return state
end

local function lab(state, key, fallback)
    local value = state.labs and tonumber(state.labs[key])
    if value ~= nil then return value end
    if state.electrolytes and state.electrolytes[key] ~= nil then return tonumber(state.electrolytes[key]) or fallback end
    return fallback
end

local function medicationAccumulation(state)
    local renal = state.renal or {}
    local hepatic = state.hepatic or {}
    local egfr = clamp(renal.estimatedGfr or 100, 5, 130)
    local hepaticClearance = clamp(hepatic.clearance or 100, 5, 100)
    local total, qt, respiratory, pressure = 0, 0, 0, 0
    local levels = {}
    local current = now()
    for _, item in ipairs(state.medicationAdministration or {}) do
        if item.status ~= 'reversed' and item.status ~= 'stopped' then
            local name = tostring(item.medication or ''):lower()
            local profile = drugKinetics[name]
            if profile then
                local ageMin = math.max(0, (current - (tonumber(item.administeredAt) or current)) / 60)
                local renalFactor = 1 + profile.renal * math.max(0, (90 - egfr) / 45)
                local hepaticFactor = 1 + profile.hepatic * math.max(0, (80 - hepaticClearance) / 40)
                local effectiveHalfLife = profile.halfLifeMin * renalFactor * hepaticFactor
                local remaining = 0.5 ^ (ageMin / math.max(1, effectiveHalfLife))
                local dose = tonumber(item.dose) or 0
                local burden = dose * remaining
                levels[name] = (levels[name] or 0) + burden
                total = total + math.min(25, burden / math.max(1, dose) * 8)
                qt = qt + profile.qt * remaining
                respiratory = respiratory + profile.respiratory * remaining
                pressure = pressure + profile.pressure * remaining
            end
        end
    end
    state.activeDrugLevels = levels
    return clamp(total, 0, 100), clamp(qt, 0, 100), clamp(respiratory, -30, 100), clamp(pressure, -30, 100)
end

function DPN_MED.CalculateV9Metrics(state)
    state = DPN_MED.EnsureV9Schema(state)
    local v = state.vitals or {}
    local sodium = lab(state, 'sodium', 140)
    local potassium = lab(state, 'potassium', 4.0)
    local chloride = lab(state, 'chloride', 103)
    local hco3 = lab(state, 'hco3', lab(state, 'bicarbonate', 24))
    local calcium = lab(state, 'calcium', 9.2)
    local magnesium = lab(state, 'magnesium', 2.0)
    local glucose = tonumber(v.glucose) or lab(state, 'glucose', 92)
    local bun = lab(state, 'bun', 14)
    local bilirubin = lab(state, 'bilirubin', 0.8)
    local inr = lab(state, 'inr', 1.0)
    local albumin = lab(state, 'albumin', 4.0)
    local ast = lab(state, 'ast', 25)
    local alt = lab(state, 'alt', 25)

    state.electrolytes.sodium = sodium
    state.electrolytes.potassium = potassium
    state.electrolytes.chloride = chloride
    state.electrolytes.bicarbonate = hco3
    state.electrolytes.calcium = calcium
    state.electrolytes.magnesium = magnesium

    local anionGap = sodium - chloride - hco3
    local correctedSodium = sodium + math.max(0, glucose - 100) / 100 * 1.6
    local osmolality = 2 * sodium + glucose / 18 + bun / 2.8
    local electrolyteRisk = 0
    if potassium < 3.0 or potassium > 6.0 then electrolyteRisk = electrolyteRisk + 35 elseif potassium < 3.5 or potassium > 5.3 then electrolyteRisk = electrolyteRisk + 15 end
    if sodium < 125 or sodium > 155 then electrolyteRisk = electrolyteRisk + 30 elseif sodium < 132 or sodium > 148 then electrolyteRisk = electrolyteRisk + 12 end
    if calcium < 7.5 or calcium > 11.5 then electrolyteRisk = electrolyteRisk + 18 end
    if magnesium < 1.2 then electrolyteRisk = electrolyteRisk + 20 end
    if anionGap > 20 then electrolyteRisk = electrolyteRisk + 15 end
    if osmolality > 320 or osmolality < 270 then electrolyteRisk = electrolyteRisk + 18 end

    local accumulation, medicationQt, respiratoryBurden, pressureBurden = medicationAccumulation(state)
    local qtRisk = medicationQt
    if potassium < 3.4 then qtRisk = qtRisk + 22 end
    if magnesium < 1.6 then qtRisk = qtRisk + 20 end
    if calcium < 8.0 then qtRisk = qtRisk + 10 end
    local hepaticRisk = clamp((bilirubin - 1) * 9 + math.max(0, inr - 1.2) * 18 + math.max(0, 3.5 - albumin) * 12 + math.max(0, ast + alt - 120) / 15, 0, 100)
    state.hepatic.injuryScore = math.floor(hepaticRisk)
    state.hepatic.clearance = math.floor(clamp(100 - hepaticRisk * 0.85, 5, 100))
    state.hepatic.syntheticFunction = math.floor(clamp(100 - math.max(0, inr - 1) * 35 - math.max(0, 4 - albumin) * 15, 5, 100))

    local baseRisk = tonumber(state.v8 and state.v8.precisionRisk) or tonumber(state.advanced and state.advanced.deterioration) or 0
    local organRisk = tonumber(state.v6 and state.v6.sofa) or 0
    local oxygenDebt = tonumber(state.metabolism and state.metabolism.oxygenDebt) or 0
    local airway = state.airway and state.airway.risk == 'critical' and 25 or 0
    local drugRespiratory = math.max(0, respiratoryBurden)
    local hypotensionBurden = math.max(0, pressureBurden)
    local adaptiveRisk = clamp(baseRisk * 0.52 + organRisk * 2.1 + electrolyteRisk * 0.32 + accumulation * 0.20 + hepaticRisk * 0.15 + qtRisk * 0.18 + oxygenDebt * 0.08 + airway + drugRespiratory * 0.25 + hypotensionBurden * 0.18, 0, 100)

    local reserve = tonumber(state.metabolism and state.metabolism.reserve) or 100
    local rehab = tonumber(state.recovery and state.recovery.rehabilitationBurden) or 0
    local social = tonumber(state.recovery and state.recovery.socialBarrierScore) or 0
    local recovery = clamp(100 - adaptiveRisk * 0.72 + reserve * 0.18 - rehab * 0.12 - social * 0.08, 0, 100)
    local trend = 'stable'
    local minutes = -1
    if adaptiveRisk >= 85 then trend, minutes = 'critical_decline', 5
    elseif adaptiveRisk >= 70 then trend, minutes = 'rapid_decline', 15
    elseif adaptiveRisk >= 50 then trend, minutes = 'at_risk', 30
    elseif adaptiveRisk <= 20 and recovery >= 75 then trend = 'recovering' end

    local disposition = 'routine'
    if adaptiveRisk >= 85 or (state.v6 and state.v6.sofa or 0) >= 12 then disposition = 'resuscitation_icu'
    elseif adaptiveRisk >= 70 then disposition = 'icu'
    elseif adaptiveRisk >= 50 then disposition = 'monitored_stepdown'
    elseif recovery < 55 then disposition = 'inpatient_recovery'
    elseif recovery < 75 then disposition = 'observation' end

    local integrity = 100
    local missing = 0
    for _, key in ipairs({ 'hr','rr','spo2','systolic','diastolic','blood','temp','glucose' }) do if v[key] == nil then missing = missing + 1 end end
    integrity = integrity - missing * 8
    if state.profile and state.profile.allergies == nil then integrity = integrity - 6 end
    if state.demographics and not tonumber(state.demographics.weightKg) then integrity = integrity - 8 end
    if state.updatedAt and now() - tonumber(state.updatedAt) > 120 then integrity = integrity - 10 end

    state.v9.anionGap = math.floor(anionGap * 10 + 0.5) / 10
    state.v9.correctedSodium = math.floor(correctedSodium * 10 + 0.5) / 10
    state.v9.calculatedOsmolality = math.floor(osmolality * 10 + 0.5) / 10
    state.v9.electrolyteRisk = math.floor(clamp(electrolyteRisk, 0, 100))
    state.v9.medicationAccumulationRisk = math.floor(accumulation)
    state.v9.qtRisk = math.floor(clamp(qtRisk, 0, 100))
    state.v9.hepaticRisk = math.floor(hepaticRisk)
    state.v9.adaptiveRisk = math.floor(adaptiveRisk)
    state.v9.recoveryProbability = math.floor(recovery)
    state.v9.predictedMinutesToCritical = minutes
    state.v9.trajectory = trend
    state.v9.disposition = disposition
    state.v9.confidence = math.floor(clamp(55 + integrity * 0.4 - missing * 3, 25, 98))
    state.v9.safetyIntegrity = math.floor(clamp(integrity, 0, 100))
    state.v9.networkPriority = adaptiveRisk >= 85 and 1 or adaptiveRisk >= 70 and 2 or adaptiveRisk >= 50 and 3 or adaptiveRisk >= 30 and 4 or 5
    state.v9.lastCalculated = now()
    state.v9.respiratoryMedicationBurden = math.floor(drugRespiratory)
    state.v9.pressureMedicationBurden = math.floor(hypotensionBurden)
    return state
end

function DPN_MED.PredictV9Trajectory(state, horizonMinutes)
    state = DPN_MED.CalculateV9Metrics(state)
    horizonMinutes = clamp(horizonMinutes or 30, 5, 240)
    local currentRisk = state.v9.adaptiveRisk
    local untreatedBleeding = 0
    for _, part in pairs(state.body or {}) do
        if part.internalBleeding then untreatedBleeding = untreatedBleeding + 8 end
        local bleed = tostring(part.bleeding or 'none')
        if bleed == 'arterial' then untreatedBleeding = untreatedBleeding + 10 elseif bleed == 'venous' then untreatedBleeding = untreatedBleeding + 5 end
    end
    local infection = state.infection and state.infection.suspected and 8 or 0
    local support = 0
    if state.organSupport then
        if state.organSupport.ventilator then support = support + 8 end
        if state.organSupport.vasopressor then support = support + 7 end
        if state.organSupport.transfusion then support = support + 8 end
        if state.organSupport.dialysis then support = support + 5 end
    end
    local slopePerHour = untreatedBleeding + infection + state.v9.electrolyteRisk * 0.08 + state.v9.medicationAccumulationRisk * 0.05 - support
    if state.status and state.status.stabilized then slopePerHour = slopePerHour - 10 end
    local projectedRisk = clamp(currentRisk + slopePerHour * (horizonMinutes / 60), 0, 100)
    local projectedRecovery = clamp(state.v9.recoveryProbability - math.max(0, projectedRisk - currentRisk) * 0.8 + math.max(0, currentRisk - projectedRisk) * 0.5, 0, 100)
    return {
        generatedAt = now(), horizonMinutes = horizonMinutes,
        currentRisk = currentRisk, projectedRisk = math.floor(projectedRisk),
        currentRecovery = state.v9.recoveryProbability, projectedRecovery = math.floor(projectedRecovery),
        slopePerHour = math.floor(slopePerHour * 10 + 0.5) / 10,
        direction = projectedRisk > currentRisk + 5 and 'worsening' or projectedRisk < currentRisk - 5 and 'improving' or 'stable',
        confidence = state.v9.confidence,
        limitingFactors = {
            untreatedBleeding = untreatedBleeding, infection = infection,
            electrolyteRisk = state.v9.electrolyteRisk,
            medicationAccumulation = state.v9.medicationAccumulationRisk,
            organSupportBenefit = support
        }
    }
end

function DPN_MED.BuildV9CarePathway(state)
    state = DPN_MED.CalculateV9Metrics(state)
    local steps = {}
    local function add(code, department, priority, reason, targetMinutes)
        steps[#steps + 1] = { code = code, department = department, priority = priority, reason = reason, targetMinutes = targetMinutes, status = 'pending' }
    end
    if state.v9.adaptiveRisk >= 85 then add('immediate_resuscitation', 'emergency', 1, 'Adaptive risk is critical.', 0) end
    if state.v9.electrolyteRisk >= 35 then add('electrolyte_correction', 'pharmacy', 1, 'Dangerous electrolyte instability.', 15) end
    if state.v9.qtRisk >= 35 then add('continuous_ecg_qt', 'lifepak', 1, 'Elevated dysrhythmia and QT risk.', 5) end
    if state.v9.medicationAccumulationRisk >= 25 then add('medication_reconciliation', 'pharmacy', 1, 'Medication accumulation or clearance risk.', 15) end
    if state.v9.hepaticRisk >= 40 then add('hepatic_dose_adjustment', 'pharmacy', 2, 'Reduced hepatic clearance.', 30) end
    if state.renal and tonumber(state.renal.akiStage or 0) >= 2 then add('renal_protection_bundle', 'icu', 1, 'Stage 2 or 3 acute kidney injury.', 15) end
    if state.pulmonary and tonumber(state.pulmonary.pfRatio or 500) < 200 then add('lung_protective_strategy', 'icu', 1, 'Severe oxygenation failure.', 10) end
    if state.coagulation and state.coagulation.lethalTriad then add('damage_control_resuscitation', 'surgery', 1, 'Lethal trauma triad detected.', 0) end
    if state.v9.recoveryProbability < 60 then add('early_rehabilitation_screen', 'rehab', 3, 'Low predicted recovery probability.', 240) end
    if #steps == 0 then add('routine_monitoring', 'medical', 4, 'No critical adaptive pathway trigger.', 60) end
    return {
        createdAt = now(), status = 'active', risk = state.v9.adaptiveRisk,
        disposition = state.v9.disposition, confidence = state.v9.confidence,
        steps = steps
    }
end

function DPN_MED.ReconcileV9Safety(state)
    state = DPN_MED.CalculateV9Metrics(state)
    local findings = {}
    local function add(code, severity, message)
        findings[#findings + 1] = { code = code, severity = severity, message = message }
    end
    if state.v9.safetyIntegrity < 70 then add('incomplete_clinical_data', 'warning', 'Clinical data integrity is below 70%.') end
    if state.v9.qtRisk >= 35 then add('qt_dysrhythmia_risk', state.v9.qtRisk >= 60 and 'critical' or 'warning', 'QT and electrolyte risk requires ECG review.') end
    if state.v9.medicationAccumulationRisk >= 30 then add('drug_accumulation', 'warning', 'Active medication burden may exceed patient clearance.') end
    if state.v9.electrolyteRisk >= 40 then add('electrolyte_instability', 'critical', 'Electrolyte values create immediate physiologic risk.') end
    if state.v9.hepaticRisk >= 55 then add('hepatic_clearance_failure', 'warning', 'Reduced hepatic clearance requires medication adjustment.') end
    if state.v9.predictedMinutesToCritical > 0 and state.v9.predictedMinutesToCritical <= 15 then add('predicted_critical_deterioration', 'critical', 'Patient is predicted to become critical within 15 minutes.') end
    return { generatedAt = now(), score = state.v9.safetyIntegrity, findings = findings, passed = #findings == 0 }
end

function DPN_MED.BuildV9Twin(state)
    state = DPN_MED.CalculateV9Metrics(state)
    return {
        generatedAt = now(), v9 = state.v9, v8 = state.v8, v6 = state.v6,
        vitals = state.vitals, electrolytes = state.electrolytes,
        hemodynamics = state.hemodynamics, pulmonary = state.pulmonary,
        renal = state.renal, hepatic = state.hepatic, endocrine = state.endocrine,
        immune = state.immune, recovery = state.recovery,
        activeDrugLevels = state.activeDrugLevels,
        safety = DPN_MED.ReconcileV9Safety(state),
        trajectory15 = DPN_MED.PredictV9Trajectory(state, 15),
        trajectory30 = DPN_MED.PredictV9Trajectory(state, 30),
        pathway = DPN_MED.BuildV9CarePathway(state)
    }
end

local priorRecalculate = DPN_MED.Recalculate
function DPN_MED.Recalculate(state)
    state = priorRecalculate(state)
    return DPN_MED.CalculateV9Metrics(state)
end

-- Add v9 scenarios to the existing native-mouse MedAdmin test laboratory.
local v9Scenarios = {
    { id='adaptive_electrolyte_storm', label='Adaptive Electrolyte Storm', category='ADAPTIVE V9', description='Severe hyperkalemia, hypomagnesemia, acidosis and QT risk for pharmacy, LIFEPAK and ICU testing.', dangerous=true, confirm=true },
    { id='adaptive_polypharmacy', label='Adaptive Polypharmacy Accumulation', category='ADAPTIVE V9', description='Renal and hepatic clearance failure with sedative and opioid accumulation.', dangerous=true, confirm=true },
    { id='adaptive_hepatic_failure', label='Adaptive Acute Hepatic Failure', category='ADAPTIVE V9', description='Synthetic failure, coagulopathy, hyperbilirubinemia and medication-clearance impairment.', dangerous=true, confirm=true },
    { id='adaptive_endocrine_crisis', label='Adaptive Endocrine Crisis', category='ADAPTIVE V9', description='Hyperosmolar metabolic emergency with severe dehydration and electrolyte shifts.', dangerous=true, confirm=true },
    { id='adaptive_post_rosc', label='Adaptive Post-ROSC Instability', category='ADAPTIVE V9', description='Post-cardiac-arrest shock, hypoxia, acidosis and recurrent dysrhythmia risk.', dangerous=true, confirm=true },
    { id='adaptive_multi_organ_failure', label='Adaptive Multi-Organ Failure', category='ADAPTIVE V9', description='Combined respiratory, circulatory, renal, hepatic and neurologic failure for full-system validation.', dangerous=true, confirm=true }
}
for _, scenario in ipairs(v9Scenarios) do
    local exists = false
    for _, current in ipairs(DPN_MED.TestScenarios or {}) do if current.id == scenario.id then exists = true break end end
    if not exists then DPN_MED.TestScenarios[#DPN_MED.TestScenarios + 1] = scenario end
end
