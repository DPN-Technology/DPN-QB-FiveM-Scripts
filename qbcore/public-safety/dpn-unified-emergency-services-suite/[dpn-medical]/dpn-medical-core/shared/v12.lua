DPN_MED = DPN_MED or {}

-- v12 integrated critical-care network.
-- Adds special-population physiology, cardiopulmonary support modeling,
-- organ-support candidacy, data-confidence scoring, and protocol orchestration.
-- All invasive/high-risk interventions remain advisory until approved by an
-- authorized human through the server-side protocol workflow.

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
    local output = {}
    seen[value] = output
    for key, item in pairs(value) do output[copy(key, seen)] = copy(item, seen) end
    return output
end

local function count(value)
    local total = 0
    for _ in pairs(type(value) == 'table' and value or {}) do total = total + 1 end
    return total
end

local function lab(state, key, fallback)
    if type(state.labs) == 'table' and tonumber(state.labs[key]) ~= nil then return tonumber(state.labs[key]) end
    if type(state.electrolytes) == 'table' and tonumber(state.electrolytes[key]) ~= nil then return tonumber(state.electrolytes[key]) end
    return tonumber(fallback) or 0
end

local function condition(state, fragment)
    fragment = tostring(fragment or ''):lower()
    for name in pairs(type(state.conditions) == 'table' and state.conditions or {}) do
        if tostring(name):lower():find(fragment, 1, true) then return true end
    end
    return false
end

local populationRanges = {
    neonate = { hrMin = 100, hrMax = 180, rrMin = 30, rrMax = 60, sbpCritical = 60, mapTarget = 45, bloodMlKg = 85 },
    infant = { hrMin = 100, hrMax = 160, rrMin = 25, rrMax = 50, sbpCritical = 70, mapTarget = 50, bloodMlKg = 80 },
    child = { hrMin = 75, hrMax = 140, rrMin = 18, rrMax = 35, sbpCritical = 70, mapTarget = 55, bloodMlKg = 75 },
    adolescent = { hrMin = 60, hrMax = 120, rrMin = 12, rrMax = 25, sbpCritical = 90, mapTarget = 60, bloodMlKg = 70 },
    adult = { hrMin = 55, hrMax = 105, rrMin = 10, rrMax = 24, sbpCritical = 90, mapTarget = 65, bloodMlKg = 70 },
    geriatric = { hrMin = 55, hrMax = 100, rrMin = 10, rrMax = 24, sbpCritical = 100, mapTarget = 70, bloodMlKg = 65 }
}

local function classifyPopulation(age, pregnancy, postpartum)
    age = clamp(age, 0, 120)
    local group
    if age < 0.08 then group = 'neonate'
    elseif age < 2 then group = 'infant'
    elseif age < 12 then group = 'child'
    elseif age < 18 then group = 'adolescent'
    elseif age >= 70 then group = 'geriatric'
    else group = 'adult' end

    local special = {}
    if pregnancy then special[#special + 1] = 'pregnant' end
    if postpartum then special[#special + 1] = 'postpartum' end
    if age < 18 then special[#special + 1] = 'pediatric' end
    if age >= 70 then special[#special + 1] = 'geriatric' end
    return group, special
end

local function predictedBodyWeight(sex, heightCm)
    heightCm = clamp(heightCm, 80, 230)
    local inchesOverFiveFeet = math.max(0, (heightCm / 2.54) - 60)
    local base = tostring(sex or ''):lower() == 'female' and 45.5 or 50.0
    return clamp(base + 2.3 * inchesOverFiveFeet, 8, 160)
end

local function getVentilator(state)
    local support = type(state.organSupport) == 'table' and state.organSupport or {}
    local ventilator = type(support.ventilator) == 'table' and support.ventilator or {}
    local settings = type(state.ventilator) == 'table' and state.ventilator or ventilator
    return settings
end

function DPN_MED.EnsureV12Schema(state)
    state = type(state) == 'table' and state or DPN_MED.NewBodyState()
    if DPN_MED.EnsureV11Schema then state = DPN_MED.EnsureV11Schema(state) end

    ensure(state, 'populationModelV12', {
        group = 'adult', specialPopulations = {}, pregnancyWeeks = 0,
        postpartumHours = 0, referenceRanges = {}, adjustedShockIndex = 0,
        ageAdjustedHypotension = false, estimatedBloodVolumeMl = 5600
    })
    ensure(state, 'cardiovascularModelV12', {
        preload = 100, afterload = 100, contractility = 100, cardiacReserve = 100,
        leftVentricularFailureRisk = 0, rightVentricularFailureRisk = 0,
        pulmonaryVascularResistance = 100, fluidResponsiveness = 50,
        cardiogenicShockRisk = 0, obstructiveShockRisk = 0, distributiveShockRisk = 0
    })
    ensure(state, 'ventilationModelV12', {
        predictedBodyWeightKg = 70, tidalVolumeMlKg = 6, plateauPressure = 20,
        drivingPressure = 12, autoPeep = 0, mechanicalPower = 8,
        ventilatorInjuryRisk = 0, recruitmentPotential = 0,
        ecmoCandidacy = 0, respiratorySupportLevel = 'none'
    })
    ensure(state, 'organSupportModelV12', {
        crrtNeed = 0, ecmoNeed = 0, mechanicalCirculatorySupportNeed = 0,
        damageControlResuscitationNeed = 0, massiveTransfusionNeed = 0,
        neurocriticalNeed = 0, obstetricEmergencyNeed = 0,
        pediatricCriticalCareNeed = 0, recommendedSupports = {}
    })
    ensure(state, 'dataQualityV12', {
        completeness = 0, freshness = 100, consistency = 100,
        confidence = 0, staleSignals = {}, missingSignals = {}, conflicts = {}
    })
    ensure(state, 'v12', {
        integratedRisk = 0, decompensationMinutes = 0, commandLevel = 'routine',
        networkPriority = 5, recommendedTeam = 'primary_care',
        recommendedDestination = 'self_care', resourceDemand = 0,
        approvalRequired = false, protocolCompliance = 100,
        specialPopulationRisk = 0, lastCalculated = 0
    })

    state.v12Recommendations = type(state.v12Recommendations) == 'table' and state.v12Recommendations or {}
    state.protocolPlansV12 = type(state.protocolPlansV12) == 'table' and state.protocolPlansV12 or {}
    state.trendsV12 = type(state.trendsV12) == 'table' and state.trendsV12 or {}
    state.networkTransactionsV12 = type(state.networkTransactionsV12) == 'table' and state.networkTransactionsV12 or {}
    return state
end

local function calculatePopulation(state)
    local demographics = state.demographics or {}
    local age = clamp(demographics.age, 0, 120)
    local weight = clamp(demographics.weightKg, 1.5, 350)
    local pregnancy = demographics.pregnancy == true or condition(state, 'pregnan')
    local postpartum = state.flags and state.flags.postpartum == true or condition(state, 'postpartum')
    local group, special = classifyPopulation(age, pregnancy, postpartum)
    local ranges = copy(populationRanges[group] or populationRanges.adult)
    local vitals = state.vitals or {}
    local hr = tonumber(vitals.hr) or 75
    local sbp = tonumber(vitals.systolic) or 120
    local shockIndex = hr / math.max(1, sbp)
    local pregnancyWeeks = clamp(demographics.pregnancyWeeks or (state.flags and state.flags.pregnancyWeeks) or 0, 0, 42)
    local bloodPerKg = ranges.bloodMlKg
    if pregnancy then bloodPerKg = bloodPerKg * 1.25 end
    local ageAdjustedHypotension = sbp < ranges.sbpCritical
    local specialRisk = 0
    if age < 2 then specialRisk = specialRisk + 18 end
    if age >= 70 then specialRisk = specialRisk + math.min(30, (age - 70) * 1.2 + 10) end
    if pregnancy then specialRisk = specialRisk + 15 end
    if postpartum then specialRisk = specialRisk + 25 end
    if pregnancy and pregnancyWeeks >= 20 and sbp >= 160 then specialRisk = specialRisk + 35 end

    return {
        group = group, specialPopulations = special, pregnancyWeeks = pregnancyWeeks,
        postpartumHours = clamp(state.flags and state.flags.postpartumHours or 0, 0, 720),
        referenceRanges = ranges, adjustedShockIndex = round(shockIndex, 2),
        ageAdjustedHypotension = ageAdjustedHypotension,
        estimatedBloodVolumeMl = math.floor(weight * bloodPerKg),
        specialPopulationRisk = math.floor(clamp(specialRisk, 0, 100))
    }
end

local function calculateCardiovascular(state, population)
    local vitals = state.vitals or {}
    local map = tonumber(state.advanced and state.advanced.map)
        or (((tonumber(vitals.systolic) or 120) + 2 * (tonumber(vitals.diastolic) or 80)) / 3)
    local hr = tonumber(vitals.hr) or 75
    local blood = tonumber(vitals.blood) or population.estimatedBloodVolumeMl
    local expectedBlood = math.max(250, population.estimatedBloodVolumeMl)
    local bloodFraction = clamp(blood / expectedBlood, 0, 1.4)
    local lactate = tonumber(state.bloodGas and state.bloodGas.lactate) or lab(state, 'lactate', 1)
    local spo2 = tonumber(vitals.spo2) or 99
    local existing = state.hemodynamics or {}
    local cardiacOutput = tonumber(existing.cardiacOutput) or clamp((hr / 75) * 5.0 * bloodFraction, 0.2, 15)
    local preload = clamp(bloodFraction * 100 - math.max(0, lactate - 2) * 3, 0, 140)
    local afterload = clamp((map / math.max(35, population.referenceRanges.mapTarget)) * 100, 20, 220)
    local contractility = clamp(100 - math.max(0, lactate - 2) * 5 - math.max(0, 75 - spo2) * 1.5
        - (condition(state, 'cardiomyopathy') and 35 or 0), 0, 140)
    local pvr = clamp(100 + math.max(0, 92 - spo2) * 5 + math.max(0, lab(state, 'paco2', 40) - 45) * 2
        + (condition(state, 'pulmonary embol') and 80 or 0), 40, 300)
    local leftFailure = clamp(math.max(0, 70 - contractility) * 1.1 + math.max(0, afterload - 150) * 0.4
        + (condition(state, 'heart failure') and 35 or 0), 0, 100)
    local rightFailure = clamp(math.max(0, pvr - 130) * 0.45 + math.max(0, 65 - preload) * 0.4
        + (condition(state, 'right heart') and 30 or 0), 0, 100)
    local fluidResponsiveness = clamp((100 - preload) * 0.8 + (population.ageAdjustedHypotension and 20 or 0)
        - leftFailure * 0.45 - rightFailure * 0.25, 0, 100)
    local cardiogenic = clamp(leftFailure * 0.65 + rightFailure * 0.25 + math.max(0, 2.2 - cardiacOutput) * 25, 0, 100)
    local obstructive = clamp(rightFailure * 0.55 + (condition(state, 'pneumothorax') and 45 or 0)
        + (condition(state, 'tamponade') and 55 or 0) + (condition(state, 'pulmonary embol') and 45 or 0), 0, 100)
    local infection = tonumber(state.infectionModel and state.infectionModel.probability) or 0
    local distributive = clamp(infection * 0.65 + math.max(0, 70 - afterload) * 0.7
        + (condition(state, 'anaphyl') and 55 or 0), 0, 100)
    local reserve = clamp(contractility * 0.45 + preload * 0.25 + (200 - afterload) * 0.15
        - math.max(cardiogenic, obstructive, distributive) * 0.3, 0, 100)

    return {
        preload = math.floor(preload), afterload = math.floor(afterload), contractility = math.floor(contractility),
        cardiacReserve = math.floor(reserve), leftVentricularFailureRisk = math.floor(leftFailure),
        rightVentricularFailureRisk = math.floor(rightFailure), pulmonaryVascularResistance = math.floor(pvr),
        fluidResponsiveness = math.floor(fluidResponsiveness), cardiogenicShockRisk = math.floor(cardiogenic),
        obstructiveShockRisk = math.floor(obstructive), distributiveShockRisk = math.floor(distributive),
        cardiacOutput = round(cardiacOutput, 2), map = round(map, 1)
    }
end

local function calculateVentilation(state)
    local demographics = state.demographics or {}
    local vitals = state.vitals or {}
    local bloodGas = state.bloodGas or {}
    local ventilator = getVentilator(state)
    local pbw = predictedBodyWeight(demographics.sex, demographics.heightCm or 178)
    local tidal = tonumber(ventilator.tidalVolumeMl or ventilator.tidalVolume or state.pulmonary and state.pulmonary.tidalVolume)
        or math.floor(pbw * 6)
    local peep = tonumber(ventilator.peep) or 5
    local peak = tonumber(ventilator.peakPressure or ventilator.pip) or clamp(18 + peep + math.max(0, 92 - (tonumber(vitals.spo2) or 99)) * 0.8, 12, 55)
    local plateau = tonumber(ventilator.plateauPressure) or clamp(peak - 3, 10, 50)
    local driving = math.max(0, plateau - peep)
    local rate = tonumber(ventilator.rate) or tonumber(vitals.rr) or 16
    local fio2 = tonumber(ventilator.fio2 or ventilator.fiO2) or (state.flags and state.flags.oxygenSupport and 0.5 or 0.21)
    if fio2 > 1 then fio2 = fio2 / 100 end
    local paco2 = tonumber(bloodGas.paco2) or lab(state, 'paco2', 40)
    local pao2 = tonumber(bloodGas.pao2) or lab(state, 'pao2', math.max(45, (tonumber(vitals.spo2) or 99) - 15))
    local pf = pao2 / math.max(0.21, fio2)
    local autoPeep = clamp(math.max(0, rate - 24) * 0.25 + math.max(0, paco2 - 50) * 0.08
        + (condition(state, 'asthma') and 4 or 0) + (condition(state, 'copd') and 3 or 0), 0, 20)
    local mechanicalPower = 0.098 * rate * (tidal / 1000) * (peak - (driving / 2))
    local vili = clamp(math.max(0, driving - 14) * 5 + math.max(0, plateau - 30) * 5
        + math.max(0, tidal / math.max(1, pbw) - 8) * 10 + math.max(0, mechanicalPower - 17) * 3, 0, 100)
    local recruitment = clamp(math.max(0, 200 - pf) * 0.35 + math.max(0, 8 - peep) * 4, 0, 100)
    local ecmo = clamp(math.max(0, 100 - pf) * 0.8 + math.max(0, paco2 - 70) * 1.5
        + (condition(state, 'ards') and 20 or 0) - (condition(state, 'terminal') and 40 or 0), 0, 100)
    local support = 'none'
    if ecmo >= 70 then support = 'ecmo_evaluation'
    elseif pf < 100 or paco2 > 70 then support = 'invasive_ventilation'
    elseif pf < 200 or tonumber(vitals.spo2) and tonumber(vitals.spo2) < 88 then support = 'advanced_oxygen_support'
    elseif tonumber(vitals.spo2) and tonumber(vitals.spo2) < 94 then support = 'supplemental_oxygen' end

    return {
        predictedBodyWeightKg = round(pbw, 1), tidalVolumeMlKg = round(tidal / math.max(1, pbw), 1),
        tidalVolumeMl = math.floor(tidal), plateauPressure = round(plateau, 1), drivingPressure = round(driving, 1),
        autoPeep = round(autoPeep, 1), mechanicalPower = round(mechanicalPower, 1),
        ventilatorInjuryRisk = math.floor(vili), recruitmentPotential = math.floor(recruitment),
        ecmoCandidacy = math.floor(ecmo), respiratorySupportLevel = support,
        fio2 = round(fio2, 2), peep = round(peep, 1), pfRatio = math.floor(pf), rate = math.floor(rate)
    }
end

local function calculateOrganSupport(state, population, cardiovascular, ventilation)
    local vitals = state.vitals or {}
    local lactate = tonumber(state.bloodGas and state.bloodGas.lactate) or lab(state, 'lactate', 1)
    local potassium = lab(state, 'potassium', 4)
    local creatinine = lab(state, 'creatinine', 1)
    local ph = lab(state, 'ph', tonumber(state.bloodGas and state.bloodGas.ph) or 7.4)
    local urine = tonumber(state.fluids and state.fluids.urineMlHr) or 60
    local blood = tonumber(vitals.blood) or population.estimatedBloodVolumeMl
    local bloodDeficit = clamp(100 - (blood / math.max(250, population.estimatedBloodVolumeMl) * 100), 0, 100)
    local inr = lab(state, 'inr', 1.0)
    local fibrinogen = lab(state, 'fibrinogen', 300)
    local gcs = tonumber(state.neuro and state.neuro.gcs) or tonumber(state.advanced and state.advanced.gcs) or 15
    local crrt = clamp(math.max(0, creatinine - 2) * 16 + math.max(0, potassium - 5.5) * 28
        + math.max(0, 20 - urine) * 1.8 + math.max(0, 7.2 - ph) * 180, 0, 100)
    local ecmo = ventilation.ecmoCandidacy
    local mcs = clamp(cardiovascular.cardiogenicShockRisk * 0.75 + math.max(0, lactate - 6) * 5
        + math.max(0, 60 - cardiovascular.map) * 2, 0, 100)
    local damageControl = clamp(bloodDeficit * 0.7 + math.max(0, inr - 1.5) * 20
        + math.max(0, 150 - fibrinogen) * 0.2 + math.max(0, 96 - (tonumber(vitals.temp) or 98.6)) * 8, 0, 100)
    local mtp = clamp(bloodDeficit * 0.85 + math.max(0, lactate - 4) * 7
        + (state.flags and state.flags.massiveHemorrhage and 35 or 0), 0, 100)
    local neuro = clamp(math.max(0, 12 - gcs) * 9 + (state.flags and state.flags.herniationRisk and 40 or 0), 0, 100)
    local obstetric = clamp((population.specialPopulationRisk or 0)
        + (state.flags and state.flags.postpartumHemorrhage and 65 or 0)
        + (condition(state, 'eclamps') and 70 or 0), 0, 100)
    local pediatric = population.group == 'neonate' or population.group == 'infant' or population.group == 'child'
    local pediatricNeed = pediatric and clamp((state.v11 and state.v11.autonomousRisk or 0) + (population.ageAdjustedHypotension and 25 or 0), 0, 100) or 0
    local supports = {}
    if crrt >= 55 then supports[#supports + 1] = 'renal_replacement_therapy' end
    if ecmo >= 65 then supports[#supports + 1] = 'ecmo_evaluation' end
    if mcs >= 65 then supports[#supports + 1] = 'mechanical_circulatory_support' end
    if damageControl >= 55 then supports[#supports + 1] = 'damage_control_resuscitation' end
    if mtp >= 55 then supports[#supports + 1] = 'massive_transfusion_protocol' end
    if neuro >= 55 then supports[#supports + 1] = 'neurocritical_care' end
    if obstetric >= 55 then supports[#supports + 1] = 'obstetric_emergency_team' end
    if pediatricNeed >= 55 then supports[#supports + 1] = 'pediatric_critical_care' end

    return {
        crrtNeed = math.floor(crrt), ecmoNeed = math.floor(ecmo),
        mechanicalCirculatorySupportNeed = math.floor(mcs),
        damageControlResuscitationNeed = math.floor(damageControl),
        massiveTransfusionNeed = math.floor(mtp), neurocriticalNeed = math.floor(neuro),
        obstetricEmergencyNeed = math.floor(obstetric), pediatricCriticalCareNeed = math.floor(pediatricNeed),
        recommendedSupports = supports
    }
end

local function calculateDataQuality(state)
    local requiredVitals = { 'hr', 'rr', 'spo2', 'systolic', 'diastolic', 'temp', 'blood' }
    local requiredLabs = { 'ph', 'lactate', 'paco2', 'pao2', 'creatinine', 'potassium', 'glucose' }
    local missing, stale, conflicts = {}, {}, {}
    local points = 0
    local vitals = state.vitals or {}
    for _, key in ipairs(requiredVitals) do
        if tonumber(vitals[key]) == nil then missing[#missing + 1] = 'vital:' .. key else points = points + 1 end
    end
    for _, key in ipairs(requiredLabs) do
        if tonumber(state.labs and state.labs[key]) == nil and tonumber(state.bloodGas and state.bloodGas[key]) == nil then
            missing[#missing + 1] = 'lab:' .. key
        else
            points = points + 1
        end
    end
    local lastObservation = tonumber(state.lastObservationAt or state.updatedAt or state.v11 and state.v11.lastCalculated) or now()
    local ageSeconds = math.max(0, now() - lastObservation)
    if ageSeconds > 300 then stale[#stale + 1] = 'patient_observations' end
    if tonumber(vitals.systolic) and tonumber(vitals.diastolic) and tonumber(vitals.diastolic) > tonumber(vitals.systolic) then
        conflicts[#conflicts + 1] = 'diastolic_exceeds_systolic'
    end
    if tonumber(vitals.spo2) and (tonumber(vitals.spo2) < 0 or tonumber(vitals.spo2) > 100) then
        conflicts[#conflicts + 1] = 'spo2_out_of_range'
    end
    local completeness = clamp(points / (#requiredVitals + #requiredLabs) * 100, 0, 100)
    local freshness = clamp(100 - ageSeconds / 12, 0, 100)
    local consistency = clamp(100 - #conflicts * 30, 0, 100)
    local confidence = clamp(completeness * 0.5 + freshness * 0.25 + consistency * 0.25, 0, 100)
    return {
        completeness = math.floor(completeness), freshness = math.floor(freshness), consistency = math.floor(consistency),
        confidence = math.floor(confidence), staleSignals = stale, missingSignals = missing, conflicts = conflicts
    }
end

function DPN_MED.GetV12Recommendations(state, alreadyCalculated)
    state = DPN_MED.EnsureV12Schema(state)
    if not alreadyCalculated then state = DPN_MED.CalculateV12Metrics(state) end
    local recommendations = {}
    local function add(code, priority, department, reason, targetMinutes, approval, dependencies)
        recommendations[#recommendations + 1] = {
            code = code, priority = priority, department = department, reason = reason,
            targetMinutes = targetMinutes, requiresHumanApproval = approval ~= false,
            dependencies = type(dependencies) == 'table' and dependencies or {}
        }
    end

    local support = state.organSupportModelV12
    local cardio = state.cardiovascularModelV12
    local ventilation = state.ventilationModelV12
    local population = state.populationModelV12

    if support.massiveTransfusionNeed >= 55 then add('activate_massive_transfusion', 1, 'blood_bank', 'Modeled blood-volume deficit and coagulopathy require immediate blood-product coordination.', 2) end
    if support.damageControlResuscitationNeed >= 55 then add('damage_control_resuscitation', 1, 'trauma_surgery', 'Lethal-triad and hemorrhage risk favor abbreviated damage-control care.', 5) end
    if support.ecmoNeed >= 65 then add('ecmo_team_evaluation', 1, 'ecmo', 'Refractory oxygenation/ventilation failure meets modeled ECMO-evaluation threshold.', 10) end
    if support.crrtNeed >= 55 then add('renal_replacement_evaluation', 1, 'nephrology', 'Acidosis, hyperkalemia, oliguria, or renal failure indicate renal-replacement evaluation.', 15) end
    if support.mechanicalCirculatorySupportNeed >= 65 then add('mechanical_circulatory_support_evaluation', 1, 'cardiology', 'Cardiogenic shock and perfusion failure may require mechanical support.', 10) end
    if support.neurocriticalNeed >= 55 then add('neurocritical_pathway', 1, 'neurosurgery', 'Neurologic deterioration requires neurocritical evaluation and cerebral-perfusion protection.', 5) end
    if support.obstetricEmergencyNeed >= 55 then add('obstetric_emergency_pathway', 1, 'obstetrics', 'Pregnancy/postpartum physiology indicates an obstetric emergency response.', 3) end
    if support.pediatricCriticalCareNeed >= 55 then add('pediatric_critical_care_pathway', 1, 'pediatrics', 'Age-adjusted physiology requires pediatric critical-care resources.', 5) end
    if ventilation.ventilatorInjuryRisk >= 45 then add('lung_protective_ventilation_review', 2, 'respiratory_therapy', 'Driving pressure, plateau pressure, or mechanical power is unsafe.', 10) end
    if cardio.cardiogenicShockRisk >= 50 then add('cardiogenic_shock_bundle', 1, 'cardiology', 'Contractility and perfusion indicate cardiogenic shock.', 5) end
    if cardio.obstructiveShockRisk >= 50 then add('obstructive_shock_reversal', 1, 'emergency', 'Right-heart strain or obstructive physiology requires immediate reversible-cause treatment.', 3) end
    if cardio.distributiveShockRisk >= 50 then add('distributive_shock_bundle', 1, 'critical_care', 'Low vascular tone and infection/allergy signals indicate distributive shock.', 5) end
    if state.dataQualityV12.confidence < 60 then add('restore_data_confidence', 2, 'diagnostics', 'Clinical confidence is limited by missing, stale, or conflicting data.', 10, false) end
    if #recommendations == 0 then add('continue_integrated_monitoring', 4, 'primary_team', 'No immediate v12 escalation criteria are present.', 30, false) end

    table.sort(recommendations, function(a, b)
        if a.priority == b.priority then return (a.targetMinutes or 9999) < (b.targetMinutes or 9999) end
        return a.priority < b.priority
    end)
    return recommendations
end

function DPN_MED.CalculateV12Metrics(state)
    state = DPN_MED.EnsureV12Schema(state)
    if DPN_MED.CalculateV11Metrics then state = DPN_MED.CalculateV11Metrics(state) end

    local population = calculatePopulation(state)
    local cardiovascular = calculateCardiovascular(state, population)
    local ventilation = calculateVentilation(state)
    local support = calculateOrganSupport(state, population, cardiovascular, ventilation)
    local quality = calculateDataQuality(state)
    local baseRisk = tonumber(state.v11 and state.v11.autonomousRisk) or 0
    local supportPeak = math.max(support.crrtNeed, support.ecmoNeed, support.mechanicalCirculatorySupportNeed,
        support.damageControlResuscitationNeed, support.massiveTransfusionNeed, support.neurocriticalNeed,
        support.obstetricEmergencyNeed, support.pediatricCriticalCareNeed)
    local shockPeak = math.max(cardiovascular.cardiogenicShockRisk, cardiovascular.obstructiveShockRisk, cardiovascular.distributiveShockRisk)
    local integratedRisk = clamp(baseRisk * 0.46 + supportPeak * 0.28 + shockPeak * 0.18
        + ventilation.ventilatorInjuryRisk * 0.12 + population.specialPopulationRisk * 0.12
        + math.max(0, 70 - quality.confidence) * 0.22, 0, 100)
    local decompensation = integratedRisk >= 90 and 3 or integratedRisk >= 80 and 8 or integratedRisk >= 70 and 15
        or integratedRisk >= 55 and 30 or integratedRisk >= 35 and 60 or 0
    local commandLevel, priority, team, destination = 'routine', 5, 'primary_care', 'self_care'
    if integratedRisk >= 90 then commandLevel, priority, team, destination = 'system_critical', 1, 'multidisciplinary_resuscitation', 'regional_critical_care_center'
    elseif integratedRisk >= 75 then commandLevel, priority, team, destination = 'critical', 1, 'critical_care_team', 'intensive_care'
    elseif integratedRisk >= 60 then commandLevel, priority, team, destination = 'urgent', 2, 'specialty_response_team', 'monitored_acute_care'
    elseif integratedRisk >= 40 then commandLevel, priority, team, destination = 'heightened', 3, 'acute_care_team', 'hospital_observation' end

    local resourceDemand = clamp((tonumber(state.v11 and state.v11.resourceIntensity) or 0) * 0.5
        + #support.recommendedSupports * 10 + integratedRisk * 0.25, 0, 100)
    local compliance = clamp(100 - (tonumber(state.v10 and state.v10.careGapCount) or 0) * 12
        - math.max(0, 70 - quality.confidence) * 0.25, 0, 100)

    state.populationModelV12 = population
    state.cardiovascularModelV12 = cardiovascular
    state.ventilationModelV12 = ventilation
    state.organSupportModelV12 = support
    state.dataQualityV12 = quality
    state.v12.integratedRisk = math.floor(integratedRisk)
    state.v12.decompensationMinutes = decompensation
    state.v12.commandLevel = commandLevel
    state.v12.networkPriority = priority
    state.v12.recommendedTeam = team
    state.v12.recommendedDestination = destination
    state.v12.resourceDemand = math.floor(resourceDemand)
    state.v12.approvalRequired = supportPeak >= 55 or integratedRisk >= 65
    state.v12.protocolCompliance = math.floor(compliance)
    state.v12.specialPopulationRisk = population.specialPopulationRisk
    state.v12.lastCalculated = now()
    state.v12Recommendations = DPN_MED.GetV12Recommendations(state, true)
    return state
end

function DPN_MED.BuildV12Twin(state)
    state = DPN_MED.CalculateV12Metrics(state)
    local previous = DPN_MED.BuildV11Twin and DPN_MED.BuildV11Twin(state) or {}
    previous.generatedAt = now()
    previous.populationV12 = copy(state.populationModelV12)
    previous.cardiovascularV12 = copy(state.cardiovascularModelV12)
    previous.ventilationV12 = copy(state.ventilationModelV12)
    previous.organSupportV12 = copy(state.organSupportModelV12)
    previous.dataQualityV12 = copy(state.dataQualityV12)
    previous.v12 = copy(state.v12)
    previous.v12Recommendations = copy(state.v12Recommendations)
    return previous
end

function DPN_MED.BuildIntegratedProtocolV12(state, requestedProtocol)
    state = DPN_MED.CalculateV12Metrics(state)
    requestedProtocol = tostring(requestedProtocol or 'auto')
    local steps = {}
    local seen = {}
    local function add(item)
        if not seen[item.code] then
            seen[item.code] = true
            steps[#steps + 1] = {
                id = ('V12STEP-%02d'):format(#steps + 1), code = item.code,
                department = item.department, priority = item.priority,
                reason = item.reason, targetMinutes = item.targetMinutes,
                requiresHumanApproval = item.requiresHumanApproval,
                status = item.requiresHumanApproval and 'awaiting_approval' or 'planned',
                dependencies = copy(item.dependencies), createdAt = now()
            }
        end
    end
    for _, recommendation in ipairs(state.v12Recommendations or {}) do add(recommendation) end
    if requestedProtocol ~= 'auto' then
        add({ code = requestedProtocol, department = 'command', priority = 2,
            reason = 'Explicitly requested v12 protocol.', targetMinutes = 10, requiresHumanApproval = true })
    end
    return {
        protocol = requestedProtocol, status = 'draft', integratedRisk = state.v12.integratedRisk,
        commandLevel = state.v12.commandLevel, population = state.populationModelV12.group,
        specialPopulations = copy(state.populationModelV12.specialPopulations),
        recommendedDestination = state.v12.recommendedDestination,
        recommendedSupports = copy(state.organSupportModelV12.recommendedSupports),
        dataConfidence = state.dataQualityV12.confidence, steps = steps,
        advisoryOnly = true, createdAt = now()
    }
end

function DPN_MED.BuildV12TrendPoint(state)
    state = DPN_MED.CalculateV12Metrics(state)
    return {
        at = now(), risk = state.v12.integratedRisk, commandLevel = state.v12.commandLevel,
        decompensationMinutes = state.v12.decompensationMinutes,
        map = state.cardiovascularModelV12.map, cardiacReserve = state.cardiovascularModelV12.cardiacReserve,
        tissueOxygenation = state.microcirculation and state.microcirculation.tissueOxygenation or 100,
        pfRatio = state.ventilationModelV12.pfRatio, ventilatorInjuryRisk = state.ventilationModelV12.ventilatorInjuryRisk,
        crrtNeed = state.organSupportModelV12.crrtNeed, ecmoNeed = state.organSupportModelV12.ecmoNeed,
        dataConfidence = state.dataQualityV12.confidence
    }
end

function DPN_MED.RunV12SharedSelfTest()
    local adult = DPN_MED.NewBodyState()
    adult.demographics = adult.demographics or {}
    adult.demographics.age = 46; adult.demographics.weightKg = 82; adult.demographics.heightCm = 178
    adult.vitals.hr = 152; adult.vitals.rr = 38; adult.vitals.spo2 = 74
    adult.vitals.systolic = 58; adult.vitals.diastolic = 30; adult.vitals.blood = 2100; adult.vitals.temp = 94.0
    adult.labs = { ph = 7.08, lactate = 9.6, paco2 = 64, pao2 = 48, creatinine = 3.8,
        potassium = 6.3, glucose = 180, inr = 2.7, fibrinogen = 95 }
    adult.conditions = { ards = { severity = 90 }, cardiogenic_shock = { severity = 80 } }
    adult.ventilator = { fio2 = 1.0, peep = 12, plateauPressure = 32, tidalVolumeMl = 420, rate = 30 }
    adult = DPN_MED.CalculateV12Metrics(adult)

    local pediatric = DPN_MED.NewBodyState()
    pediatric.demographics = pediatric.demographics or {}
    pediatric.demographics.age = 6; pediatric.demographics.weightKg = 22; pediatric.demographics.heightCm = 118
    pediatric.vitals.hr = 165; pediatric.vitals.rr = 42; pediatric.vitals.spo2 = 83
    pediatric.vitals.systolic = 62; pediatric.vitals.diastolic = 34; pediatric.vitals.blood = 1050
    pediatric.labs = { ph = 7.18, lactate = 6.2, paco2 = 50, pao2 = 58, creatinine = 1.6,
        potassium = 5.5, glucose = 70 }
    pediatric.conditions = { sepsis = { severity = 85 } }
    pediatric = DPN_MED.CalculateV12Metrics(pediatric)

    local plan = DPN_MED.BuildIntegratedProtocolV12(adult, 'auto')
    return {
        passed = adult.v12.integratedRisk >= 65 and adult.organSupportModelV12.ecmoNeed >= 40
            and adult.organSupportModelV12.crrtNeed >= 40 and pediatric.populationModelV12.group == 'child'
            and pediatric.populationModelV12.ageAdjustedHypotension == true and #plan.steps >= 2,
        adultRisk = adult.v12.integratedRisk, pediatricRisk = pediatric.v12.integratedRisk,
        adultECMONeed = adult.organSupportModelV12.ecmoNeed, adultCRRTNeed = adult.organSupportModelV12.crrtNeed,
        pediatricGroup = pediatric.populationModelV12.group, protocolSteps = #plan.steps
    }
end

function DPN_MED.Recalculate(state)
    if previousRecalculate then state = previousRecalculate(state) end
    return DPN_MED.CalculateV12Metrics(state)
end
