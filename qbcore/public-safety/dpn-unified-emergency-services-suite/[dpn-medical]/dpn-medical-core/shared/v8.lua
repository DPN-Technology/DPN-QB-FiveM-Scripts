DPN_MED = DPN_MED or {}

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

local medicationRules = {
    morphine = { minDose = 1, maxDose = 10, routes = { iv=true, im=true }, respiratoryDepression = true, hypotension = true },
    fentanyl = { minDose = 25, maxDose = 200, routes = { iv=true, im=true, intranasal=true }, respiratoryDepression = true, hypotension = true },
    epinephrine = { minDose = 0.1, maxDose = 1, routes = { iv=true, io=true, im=true }, tachycardia = true },
    norepinephrine = { minDose = 0.01, maxDose = 3, routes = { iv=true, io=true }, vasopressor = true },
    naloxone = { minDose = 0.04, maxDose = 4, routes = { iv=true, im=true, intranasal=true } },
    ketamine = { minDose = 10, maxDose = 500, routes = { iv=true, im=true }, dissociative = true },
    midazolam = { minDose = 0.5, maxDose = 10, routes = { iv=true, im=true, intranasal=true }, respiratoryDepression = true },
    amiodarone = { minDose = 150, maxDose = 300, routes = { iv=true, io=true }, antiarrhythmic = true },
    tranexamic_acid = { minDose = 500, maxDose = 2000, routes = { iv=true, io=true }, clotSupport = true },
    ceftriaxone = { minDose = 500, maxDose = 2000, routes = { iv=true, im=true }, antibiotic = true },
    dextrose = { minDose = 5, maxDose = 50, routes = { iv=true, io=true, oral=true }, glucoseSupport = true }
}

function DPN_MED.EnsureV8Schema(state)
    state = type(state) == 'table' and state or DPN_MED.NewBodyState()
    if DPN_MED.EnsureV6Schema then state = DPN_MED.EnsureV6Schema(state) end
    ensure(state, 'demographics', { age = 35, weightKg = 80, heightCm = 175, sex = 'unknown', pregnancy = false })
    ensure(state, 'hemodynamics', {
        strokeVolumeMl = 70, cardiacOutputLpm = 5.2, systemicVascularResistance = 1100,
        oxygenDeliveryMlMin = 950, oxygenConsumptionMlMin = 250, oxygenExtractionRatio = 0.26,
        cerebralPerfusionPressure = 75, intracranialPressure = 12
    })
    ensure(state, 'pulmonary', {
        tidalVolumeMl = 500, minuteVentilationLpm = 8.0, compliance = 100,
        fio2 = 0.21, pfRatio = 450, deadSpaceFraction = 0.30, workOfBreathing = 10
    })
    ensure(state, 'renal', { akiStage = 0, perfusion = 'normal', estimatedGfr = 100 })
    ensure(state, 'coagulation', { score = 0, phenotype = 'normal', lethalTriad = false })
    ensure(state, 'metabolism', { demand = 1.0, oxygenDebt = 0, reserve = 100 })
    ensure(state, 'v8', {
        precisionRisk = 0, predictedSurvival = 99, medicationRisk = 0,
        guidelineCompliance = 100, careComplexity = 0, recommendedDestination = 'routine',
        lastCalculated = 0
    })
    state.medicationAdministration = type(state.medicationAdministration) == 'table' and state.medicationAdministration or {}
    state.careBundles = type(state.careBundles) == 'table' and state.careBundles or {}
    state.eventJournal = type(state.eventJournal) == 'table' and state.eventJournal or {}
    state.simulation = type(state.simulation) == 'table' and state.simulation or { active = false, rate = 1.0, paused = false }
    return state
end

local function chestBurden(state)
    local chest = state.body and state.body.chest or {}
    local damage = tonumber(chest.damage) or 0
    local burn = tonumber(chest.burn) or 0
    local internal = chest.internalBleeding == true and 20 or 0
    local lung = 0
    for organ, value in pairs(chest.organs or {}) do
        if tostring(organ):find('lung', 1, true) then lung = lung + (tonumber(value) or 0) end
    end
    return clamp(damage * 0.45 + burn * 8 + internal + lung * 0.35, 0, 100)
end

local function headBurden(state)
    local head = state.body and state.body.head or {}
    local burden = (tonumber(head.damage) or 0) + (head.internalBleeding and 30 or 0)
    for _, value in pairs(head.organs or {}) do burden = burden + (tonumber(value) or 0) * 0.4 end
    return clamp(burden, 0, 100)
end

function DPN_MED.ValidateMedicationDose(state, medication, dose, route)
    state = DPN_MED.EnsureV8Schema(state)
    medication = tostring(medication or ''):lower()
    route = tostring(route or 'iv'):lower()
    dose = tonumber(dose)
    local rule = medicationRules[medication]
    if not rule then return false, 'Medication is not in the DPN precision formulary.', { severity = 'hard_stop' } end
    if not dose or dose < rule.minDose or dose > rule.maxDose then
        return false, ('Dose %.2f is outside the allowed %.2f-%.2f range.'):format(dose or 0, rule.minDose, rule.maxDose), { severity = 'hard_stop' }
    end
    if not rule.routes[route] then return false, ('Route %s is not approved for %s.'):format(route, medication), { severity = 'hard_stop' } end
    local warnings = {}
    local v = state.vitals or {}
    if rule.respiratoryDepression and ((tonumber(v.rr) or 0) < 10 or (tonumber(v.spo2) or 0) < 92) then
        warnings[#warnings + 1] = 'Respiratory depression risk is elevated.'
    end
    if rule.hypotension and ((tonumber(v.systolic) or 0) < 95 or (state.advanced and state.advanced.map or 0) < 65) then
        warnings[#warnings + 1] = 'Medication may worsen hypotension.'
    end
    if rule.tachycardia and (tonumber(v.hr) or 0) > 145 then warnings[#warnings + 1] = 'Existing severe tachycardia.' end
    if medication == 'tranexamic_acid' and state.status and state.status.lastDamage and state.status.lastDamage.time then
        local elapsed = ((os and os.time and os.time() or 0) - tonumber(state.status.lastDamage.time)) / 60
        if elapsed > 180 then warnings[#warnings + 1] = 'TXA benefit is reduced after three hours.' end
    end
    for allergy, enabled in pairs(state.profile and state.profile.allergies or {}) do
        if enabled and tostring(allergy):lower() == medication then
            return false, ('Documented allergy to %s.'):format(medication), { severity = 'hard_stop' }
        end
    end
    local weight = math.max(1, tonumber(state.demographics.weightKg) or 80)
    local perKg = dose / weight
    return true, #warnings > 0 and table.concat(warnings, ' ') or 'Dose passed precision safety checks.', {
        severity = #warnings > 0 and 'warning' or 'clear', warnings = warnings, dosePerKg = perKg, rule = rule
    }
end

function DPN_MED.CalculatePrecisionMetrics(state)
    state = DPN_MED.EnsureV8Schema(state)
    local v = state.vitals or {}
    local labs = state.labs or {}
    local bloodFraction = clamp((tonumber(v.blood) or 5000) / 5000, 0, 1)
    local contractility = state.organSupport and state.organSupport.vasopressor and 1.15 or 1.0
    if state.status and state.status.cardiacArrest then contractility = 0 end
    local strokeVolume = 70 * bloodFraction * contractility
    local hr = tonumber(v.hr) or 74
    local cardiacOutput = strokeVolume * hr / 1000
    local map = tonumber(state.advanced and state.advanced.map) or (((tonumber(v.systolic) or 120) + 2 * (tonumber(v.diastolic) or 80)) / 3)
    local svr = cardiacOutput > 0.1 and (map - 5) * 80 / cardiacOutput or 3000
    local hemoglobin = tonumber(labs.hemoglobin) or (14 * bloodFraction)
    local saturation = clamp((tonumber(v.spo2) or 99) / 100, 0, 1)
    local oxygenDelivery = cardiacOutput * (1.34 * hemoglobin * saturation + 0.003 * 90) * 10
    local temp = tonumber(v.temp) or 98.6
    local pain = tonumber(state.status and state.status.pain) or 0
    local demand = clamp(1 + math.max(0, temp - 100.4) * 0.08 + pain / 250 + (state.infection and state.infection.suspected and 0.25 or 0), 0.65, 2.0)
    local oxygenConsumption = 250 * demand
    local extraction = oxygenDelivery > 1 and oxygenConsumption / oxygenDelivery or 1

    local chest = chestBurden(state)
    local compliance = clamp(100 - chest * 0.75 - (state.respiration and state.respiration.pneumothorax and 30 or 0), 10, 100)
    local tidal = clamp(500 * compliance / 100, 150, 800)
    local rr = tonumber(v.rr) or 16
    local minuteVentilation = tidal * rr / 1000
    local fio2 = 0.21
    if state.respiration and (tonumber(state.respiration.oxygenLpm) or 0) > 0 then fio2 = clamp(0.21 + state.respiration.oxygenLpm * 0.04, 0.21, 1.0) end
    if state.organSupport and state.organSupport.ventilator then fio2 = math.max(fio2, 0.5) end
    local pfRatio = clamp((tonumber(v.spo2) or 99) * 5 / fio2, 50, 500)
    local work = clamp(10 + chest * 0.55 + math.max(0, rr - 20) * 2, 0, 100)

    local head = headBurden(state)
    local icp = clamp(10 + head * 0.35 + (state.neuro and (15 - (tonumber(state.neuro.gcs) or 15)) * 2 or 0), 5, 60)
    local cpp = clamp(map - icp, 0, 120)

    local creatinine = tonumber(labs.creatinine) or 1.0
    local urine = tonumber(state.fluids and state.fluids.urineMlHr) or 35
    local aki = 0
    if creatinine >= 4 or urine < 5 then aki = 3 elseif creatinine >= 2 or urine < 15 then aki = 2 elseif creatinine >= 1.3 or urine < 30 then aki = 1 end
    local egfr = clamp(110 / math.max(0.6, creatinine), 5, 130)

    local ph = tonumber(labs.ph) or 7.40
    local inr = tonumber(labs.inr) or 1.0
    local platelets = tonumber(labs.platelets) or 250
    local coag = 0
    if temp < 95 then coag = coag + 2 elseif temp < 96.8 then coag = coag + 1 end
    if ph < 7.2 then coag = coag + 3 elseif ph < 7.3 then coag = coag + 1 end
    if inr >= 2.5 then coag = coag + 3 elseif inr >= 1.5 then coag = coag + 1 end
    if platelets < 50 then coag = coag + 3 elseif platelets < 100 then coag = coag + 1 end

    local medRisk = 0
    for _, administration in ipairs(state.medicationAdministration or {}) do
        if administration.status ~= 'reversed' then medRisk = medRisk + (administration.riskWeight or 2) end
    end
    medRisk = clamp(medRisk, 0, 100)

    local oxygenDebt = clamp((oxygenConsumption - oxygenDelivery) / math.max(1, oxygenConsumption) * 100, 0, 100)
    local precisionRisk = clamp(
        (tonumber(state.advanced and state.advanced.deterioration) or 0) * 0.35 +
        (tonumber(state.v6 and state.v6.sofa) or 0) * 3 + oxygenDebt * 0.35 +
        math.max(0, 60 - cpp) * 0.6 + aki * 7 + coag * 3 + medRisk * 0.15,
        0, 100
    )
    local survival = clamp(100 - precisionRisk * 0.82 - (state.status and state.status.cardiacArrest and 18 or 0), 1, 99.9)

    state.hemodynamics.strokeVolumeMl = math.floor(strokeVolume * 10) / 10
    state.hemodynamics.cardiacOutputLpm = math.floor(cardiacOutput * 100) / 100
    state.hemodynamics.systemicVascularResistance = math.floor(svr)
    state.hemodynamics.oxygenDeliveryMlMin = math.floor(oxygenDelivery)
    state.hemodynamics.oxygenConsumptionMlMin = math.floor(oxygenConsumption)
    state.hemodynamics.oxygenExtractionRatio = math.floor(extraction * 100) / 100
    state.hemodynamics.intracranialPressure = math.floor(icp)
    state.hemodynamics.cerebralPerfusionPressure = math.floor(cpp)
    state.pulmonary.tidalVolumeMl = math.floor(tidal)
    state.pulmonary.minuteVentilationLpm = math.floor(minuteVentilation * 10) / 10
    state.pulmonary.compliance = math.floor(compliance)
    state.pulmonary.fio2 = math.floor(fio2 * 100) / 100
    state.pulmonary.pfRatio = math.floor(pfRatio)
    state.pulmonary.workOfBreathing = math.floor(work)
    state.renal.akiStage = aki
    state.renal.perfusion = map < 55 and 'critical' or (map < 65 and 'poor' or 'adequate')
    state.renal.estimatedGfr = math.floor(egfr)
    state.coagulation.score = coag
    state.coagulation.phenotype = coag >= 7 and 'critical' or (coag >= 4 and 'high_risk' or (coag >= 2 and 'abnormal' or 'normal'))
    state.coagulation.lethalTriad = temp < 95 and ph < 7.25 and coag >= 4
    state.metabolism.demand = math.floor(demand * 100) / 100
    state.metabolism.oxygenDebt = math.floor(oxygenDebt)
    state.metabolism.reserve = math.floor(clamp(100 - oxygenDebt - precisionRisk * 0.25, 0, 100))
    state.v8.precisionRisk = math.floor(precisionRisk)
    state.v8.predictedSurvival = math.floor(survival * 10) / 10
    state.v8.medicationRisk = math.floor(medRisk)
    state.v8.careComplexity = math.floor(clamp(precisionRisk + medRisk * 0.25 + #state.activeOrders * 2, 0, 100))
    if precisionRisk >= 80 then state.v8.recommendedDestination = 'resuscitation_icu'
    elseif precisionRisk >= 60 then state.v8.recommendedDestination = 'icu'
    elseif precisionRisk >= 35 then state.v8.recommendedDestination = 'monitored_acute_care'
    elseif precisionRisk >= 15 then state.v8.recommendedDestination = 'emergency_department'
    else state.v8.recommendedDestination = 'routine' end
    state.v8.lastCalculated = os and os.time and os.time() or 0
    return state
end

function DPN_MED.GetPrecisionRecommendations(state)
    state = DPN_MED.CalculatePrecisionMetrics(state)
    local recommendations = {}
    local function add(code, priority, reason, department)
        recommendations[#recommendations + 1] = { code = code, priority = priority, reason = reason, department = department }
    end
    if state.metabolism.oxygenDebt >= 30 then add('restore_oxygen_delivery', 1, 'Oxygen delivery is below estimated metabolic demand.', 'resuscitation') end
    if state.hemodynamics.cerebralPerfusionPressure < 60 then add('neuro_perfusion_bundle', 1, 'Cerebral perfusion pressure is below target.', 'trauma') end
    if state.coagulation.lethalTriad then add('damage_control_resuscitation', 1, 'Hypothermia, acidosis, and coagulopathy are present.', 'trauma') end
    if state.renal.akiStage >= 2 then add('renal_protection_bundle', 2, 'Acute kidney injury risk is elevated.', 'icu') end
    if state.pulmonary.pfRatio < 200 then add('lung_protective_support', 1, 'Severe oxygenation impairment detected.', 'respiratory') end
    if state.pulmonary.workOfBreathing > 70 then add('airway_escalation', 1, 'Work of breathing is unsustainable.', 'respiratory') end
    if state.v8.medicationRisk >= 20 then add('pharmacy_reconciliation', 2, 'Cumulative medication risk is elevated.', 'pharmacy') end
    if state.v8.precisionRisk >= 60 then add('critical_care_consult', 1, 'Precision deterioration score indicates high risk.', 'icu') end
    return recommendations
end

function DPN_MED.BuildPrecisionTwin(state)
    state = DPN_MED.CalculatePrecisionMetrics(state)
    return {
        version = '8.0.0',
        generatedAt = os and os.time and os.time() or 0,
        lifeState = state.status and state.status.lifeState,
        triage = state.status and state.status.triage,
        demographics = state.demographics,
        hemodynamics = state.hemodynamics,
        pulmonary = state.pulmonary,
        renal = state.renal,
        coagulation = state.coagulation,
        metabolism = state.metabolism,
        v8 = state.v8,
        v6 = state.v6,
        advanced = state.advanced,
        recommendations = DPN_MED.GetPrecisionRecommendations(state)
    }
end

function DPN_MED.ApplyPrecisionIntervention(state, code, data)
    state = DPN_MED.CalculatePrecisionMetrics(state)
    code = tostring(code or '')
    data = type(data) == 'table' and data or {}
    if code == 'damage_control_resuscitation' then
        state.vitals.blood = clamp((state.vitals.blood or 0) + (tonumber(data.bloodMl) or 500), 0, 5000)
        state.vitals.temp = clamp((state.vitals.temp or 98.6) + 1.2, 80, 110)
        state.labs.ph = clamp((state.labs.ph or 7.4) + 0.05, 6.8, 7.7)
        state.labs.inr = clamp((state.labs.inr or 1.0) - 0.2, 0.7, 8)
    elseif code == 'lung_protective_support' then
        state.organSupport.ventilator = true
        state.pulmonary.fio2 = clamp(tonumber(data.fio2) or 0.6, 0.21, 1.0)
        state.vitals.spo2 = clamp((state.vitals.spo2 or 0) + 6, 0, 100)
        state.vitals.etco2 = clamp(state.vitals.etco2 or 38, 20, 55)
    elseif code == 'renal_protection_bundle' then
        state.fluids.intakeMl = (state.fluids.intakeMl or 0) + (tonumber(data.fluidMl) or 250)
        state.fluids.urineMlHr = math.max(state.fluids.urineMlHr or 0, 25)
        state.labs.creatinine = math.max(0.7, (state.labs.creatinine or 1.0) - 0.1)
    elseif code == 'neuro_perfusion_bundle' then
        state.vitals.systolic = math.max(state.vitals.systolic or 0, 110)
        state.hemodynamics.intracranialPressure = math.max(5, (state.hemodynamics.intracranialPressure or 12) - 4)
    elseif code == 'restore_oxygen_delivery' then
        state.vitals.spo2 = clamp((state.vitals.spo2 or 0) + 5, 0, 100)
        state.vitals.blood = clamp((state.vitals.blood or 0) + (tonumber(data.bloodMl) or 250), 0, 5000)
    else
        return state, false, 'Unknown precision intervention.'
    end
    return DPN_MED.CalculatePrecisionMetrics(state), true, 'Precision intervention applied.'
end

local priorRecalculate = DPN_MED.Recalculate
function DPN_MED.Recalculate(state)
    state = priorRecalculate(state)
    return DPN_MED.CalculatePrecisionMetrics(state)
end
