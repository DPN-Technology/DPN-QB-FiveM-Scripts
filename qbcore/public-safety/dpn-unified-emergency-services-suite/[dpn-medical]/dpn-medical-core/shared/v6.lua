DPN_MED = DPN_MED or {}

local v5Recalculate = DPN_MED.Recalculate

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

function DPN_MED.EnsureV6Schema(state)
    state = type(state) == 'table' and state or DPN_MED.NewBodyState()
    if DPN_MED.EnsureAdvancedSchema then state = DPN_MED.EnsureAdvancedSchema(state) end
    ensure(state, 'labs', {
        hemoglobin = 14.0, hematocrit = 42.0, platelets = 250, inr = 1.0,
        sodium = 140, potassium = 4.0, glucose = 100, creatinine = 1.0,
        bilirubin = 0.8, wbc = 7.5, ph = 7.40, pco2 = 40, hco3 = 24
    })
    ensure(state, 'fluids', { intakeMl = 0, outputMl = 0, urineMlHr = 35, bloodProductsMl = 0, lastUpdated = 0 })
    ensure(state, 'sedation', { score = 0, target = 0, paralytic = false, analgesia = 0 })
    ensure(state, 'nutrition', { route = 'oral', status = 'normal', caloriesToday = 0, aspirationRisk = false })
    ensure(state, 'infection', { suspected = false, confirmed = false, source = nil, culturesPending = false, antibioticsAt = nil })
    ensure(state, 'organSupport', { ventilator = false, vasopressor = false, dialysis = false, ecmo = false, transfusion = false })
    ensure(state, 'v6', {
        sofa = 0, acidBase = 'normal', fluidBalance = 0, clottingRisk = 'normal',
        organFailureRisk = 'low', massiveTransfusion = false, sepsisBundleDue = false,
        safetyScore = 100, complexity = 0, disposition = 'routine', lastCalculated = 0
    })
    state.activeOrders = type(state.activeOrders) == 'table' and state.activeOrders or {}
    state.safetyAlerts = type(state.safetyAlerts) == 'table' and state.safetyAlerts or {}
    state.observationTrends = type(state.observationTrends) == 'table' and state.observationTrends or {}
    state.directives = type(state.directives) == 'table' and state.directives or {}
    return state
end

function DPN_MED.ClassifyAcidBase(labs)
    labs = type(labs) == 'table' and labs or {}
    local ph = tonumber(labs.ph) or 7.40
    local pco2 = tonumber(labs.pco2) or 40
    local hco3 = tonumber(labs.hco3) or 24
    if ph < 7.35 then
        if hco3 < 22 and pco2 > 45 then return 'mixed_acidosis' end
        if hco3 < 22 then return 'metabolic_acidosis' end
        if pco2 > 45 then return 'respiratory_acidosis' end
        return 'acidemia'
    elseif ph > 7.45 then
        if hco3 > 26 and pco2 < 35 then return 'mixed_alkalosis' end
        if hco3 > 26 then return 'metabolic_alkalosis' end
        if pco2 < 35 then return 'respiratory_alkalosis' end
        return 'alkalemia'
    end
    if hco3 < 22 and pco2 < 35 then return 'compensated_metabolic_acidosis' end
    if hco3 > 26 and pco2 > 45 then return 'compensated_metabolic_alkalosis' end
    return 'normal'
end

function DPN_MED.CalculateSOFA(state)
    state = DPN_MED.EnsureV6Schema(state)
    local score = 0
    local spo2 = tonumber(state.vitals and state.vitals.spo2) or 99
    if spo2 < 85 then score = score + 4 elseif spo2 < 90 then score = score + 3 elseif spo2 < 94 then score = score + 2 elseif spo2 < 96 then score = score + 1 end
    local platelets = tonumber(state.labs.platelets) or 250
    if platelets < 20 then score = score + 4 elseif platelets < 50 then score = score + 3 elseif platelets < 100 then score = score + 2 elseif platelets < 150 then score = score + 1 end
    local bilirubin = tonumber(state.labs.bilirubin) or 0.8
    if bilirubin >= 12 then score = score + 4 elseif bilirubin >= 6 then score = score + 3 elseif bilirubin >= 2 then score = score + 2 elseif bilirubin >= 1.2 then score = score + 1 end
    local map = tonumber(state.advanced and state.advanced.map) or 93
    if state.organSupport.vasopressor then score = score + 3 elseif map < 55 then score = score + 4 elseif map < 65 then score = score + 2 elseif map < 70 then score = score + 1 end
    local gcs = tonumber(state.neuro and state.neuro.gcs) or 15
    if gcs < 6 then score = score + 4 elseif gcs < 10 then score = score + 3 elseif gcs < 13 then score = score + 2 elseif gcs < 15 then score = score + 1 end
    local creatinine = tonumber(state.labs.creatinine) or 1.0
    local urine = tonumber(state.fluids.urineMlHr) or 35
    if creatinine >= 5 or urine < 5 then score = score + 4 elseif creatinine >= 3.5 or urine < 10 then score = score + 3 elseif creatinine >= 2 or urine < 20 then score = score + 2 elseif creatinine >= 1.2 or urine < 30 then score = score + 1 end
    return math.floor(clamp(score, 0, 24))
end

local bloodCompatibility = {
    ['O-'] = { ['O-']=true },
    ['O+'] = { ['O-']=true, ['O+']=true },
    ['A-'] = { ['O-']=true, ['A-']=true },
    ['A+'] = { ['O-']=true, ['O+']=true, ['A-']=true, ['A+']=true },
    ['B-'] = { ['O-']=true, ['B-']=true },
    ['B+'] = { ['O-']=true, ['O+']=true, ['B-']=true, ['B+']=true },
    ['AB-'] = { ['O-']=true, ['A-']=true, ['B-']=true, ['AB-']=true },
    ['AB+'] = { ['O-']=true, ['O+']=true, ['A-']=true, ['A+']=true, ['B-']=true, ['B+']=true, ['AB-']=true, ['AB+']=true }
}

function DPN_MED.IsBloodCompatible(recipient, donor)
    recipient = tostring(recipient or 'UNKNOWN'):upper()
    donor = tostring(donor or 'UNKNOWN'):upper()
    if recipient == 'UNKNOWN' then return donor == 'O-' end
    return bloodCompatibility[recipient] and bloodCompatibility[recipient][donor] == true or false
end

function DPN_MED.CalculateV6Metrics(state)
    state = DPN_MED.EnsureV6Schema(state)
    state.v6.sofa = DPN_MED.CalculateSOFA(state)
    state.v6.acidBase = DPN_MED.ClassifyAcidBase(state.labs)
    state.v6.fluidBalance = (tonumber(state.fluids.intakeMl) or 0) + (tonumber(state.fluids.bloodProductsMl) or 0) - (tonumber(state.fluids.outputMl) or 0)
    local platelets = tonumber(state.labs.platelets) or 250
    local inr = tonumber(state.labs.inr) or 1.0
    if platelets < 50 or inr >= 2.5 then state.v6.clottingRisk = 'critical'
    elseif platelets < 100 or inr >= 1.8 then state.v6.clottingRisk = 'high'
    elseif platelets < 150 or inr >= 1.4 then state.v6.clottingRisk = 'moderate'
    else state.v6.clottingRisk = 'normal' end
    local blood = tonumber(state.vitals and state.vitals.blood) or 5000
    local shockIndex = tonumber(state.advanced and state.advanced.shockIndex) or 0.6
    state.v6.massiveTransfusion = blood < 3000 or shockIndex >= 1.2
    state.v6.sepsisBundleDue = state.infection.suspected == true and ((state.advanced and state.advanced.qsofa or 0) >= 2 or state.v6.sofa >= 4)
    local complexity = state.v6.sofa * 4
    complexity = complexity + math.max(0, 100 - (tonumber(state.advanced and state.advanced.deterioration) or 0)) * 0
    if state.organSupport.ventilator then complexity = complexity + 15 end
    if state.organSupport.vasopressor then complexity = complexity + 15 end
    if state.organSupport.dialysis then complexity = complexity + 12 end
    if state.v6.massiveTransfusion then complexity = complexity + 18 end
    if state.v6.sepsisBundleDue then complexity = complexity + 12 end
    state.v6.complexity = math.floor(clamp(complexity, 0, 100))
    local safety = 100
    if state.v6.clottingRisk == 'critical' then safety = safety - 25 elseif state.v6.clottingRisk == 'high' then safety = safety - 15 end
    if state.v6.sofa >= 10 then safety = safety - 30 elseif state.v6.sofa >= 6 then safety = safety - 18 end
    if state.v6.acidBase ~= 'normal' then safety = safety - 10 end
    if state.profile and state.profile.codeStatus == 'dnr' and state.status and state.status.cardiacArrest then safety = safety - 20 end
    state.v6.safetyScore = math.floor(clamp(safety, 0, 100))
    if state.v6.sofa >= 12 or (state.advanced and state.advanced.risk == 'critical') then state.v6.organFailureRisk, state.v6.disposition = 'critical', 'icu_resuscitation'
    elseif state.v6.sofa >= 7 then state.v6.organFailureRisk, state.v6.disposition = 'high', 'icu'
    elseif state.v6.sofa >= 3 then state.v6.organFailureRisk, state.v6.disposition = 'moderate', 'stepdown'
    else state.v6.organFailureRisk, state.v6.disposition = 'low', (state.advanced and state.advanced.recommendedCare) or 'routine' end
    state.v6.lastCalculated = os and os.time and os.time() or 0
    return state
end

function DPN_MED.GetRecommendedOrders(state)
    state = DPN_MED.CalculateV6Metrics(state)
    local orders = {}
    local function add(orderType, code, priority, reason)
        orders[#orders + 1] = { type = orderType, code = code, priority = priority, reason = reason }
    end
    if state.v6.massiveTransfusion then add('protocol', 'massive_transfusion', 1, 'Blood volume and shock index meet massive hemorrhage criteria.') end
    if state.v6.sepsisBundleDue then
        add('lab', 'lactate_repeat', 1, 'Sepsis bundle criteria met.')
        add('medication', 'broad_spectrum_antibiotic', 1, 'Suspected infection with organ dysfunction.')
        add('procedure', 'blood_cultures', 1, 'Cultures should be obtained before antibiotics when feasible.')
    end
    if state.v6.sofa >= 7 then add('level_of_care', 'icu', 1, 'High organ dysfunction score.') end
    if state.vitals.spo2 < 92 then add('respiratory', 'oxygen_titration', 1, 'Hypoxemia detected.') end
    if state.advanced.map < 65 then add('circulation', 'hemodynamic_support', 1, 'MAP below perfusion target.') end
    if state.labs.potassium < 3.0 or state.labs.potassium > 5.8 then add('lab', 'potassium_recheck', 1, 'Critical potassium value.') end
    if state.labs.glucose < 60 or state.labs.glucose > 300 then add('lab', 'glucose_management', 2, 'Unsafe glucose value.') end
    if state.v6.clottingRisk ~= 'normal' then add('lab', 'coagulation_panel', 2, 'Coagulation abnormality detected.') end
    return orders
end

function DPN_MED.BuildDigitalTwin(state)
    state = DPN_MED.CalculateV6Metrics(state)
    local snapshot = DPN_MED.GetClinicalSnapshot and DPN_MED.GetClinicalSnapshot(state) or {}
    return {
        generatedAt = os and os.time and os.time() or 0,
        lifeState = state.status.lifeState,
        triage = state.status.triage,
        vitals = state.vitals,
        labs = state.labs,
        advanced = state.advanced,
        v6 = state.v6,
        airway = state.airway,
        respiration = state.respiration,
        circulation = state.circulation,
        neuro = state.neuro,
        fluids = state.fluids,
        organSupport = state.organSupport,
        infection = state.infection,
        profile = state.profile,
        recommendedOrders = DPN_MED.GetRecommendedOrders(state),
        protocols = snapshot.protocols or (DPN_MED.GetProtocolRecommendations and DPN_MED.GetProtocolRecommendations(state) or {})
    }
end

function DPN_MED.Recalculate(state)
    state = v5Recalculate(state)
    return DPN_MED.CalculateV6Metrics(state)
end
