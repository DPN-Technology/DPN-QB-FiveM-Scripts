DPN_MED = DPN_MED or {}

local function now()
    return os and os.time and os.time() or 0
end

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function blankPart(part)
    local data = {
        damage = 0,
        pain = 0,
        bleeding = 'none',
        bleedStacks = 0,
        internalBleeding = false,
        fracture = 'none',
        burn = 0,
        infection = 0,
        nerve = 0,
        mobility = 100,
        wounds = {},
        organs = {},
        bones = {}
    }

    for _, organ in ipairs(Config.OrganMap[part] or {}) do data.organs[organ] = 0 end
    for _, bone in ipairs(Config.BoneMap[part] or {}) do data.bones[bone] = 'none' end
    return data
end

function DPN_MED.NewBodyState()
    local body = {}
    for part in pairs(Config.BodyParts) do body[part] = blankPart(part) end

    return {
        version = Config.Version or 4,
        body = body,
        vitals = {
            blood = 5000,
            systolic = 120,
            diastolic = 80,
            hr = 74,
            rr = 16,
            spo2 = 99,
            temp = 98.6,
            glucose = 92,
            etco2 = 38
        },
        status = {
            pain = 0,
            shock = 0,
            unconscious = false,
            cardiacArrest = false,
            stabilized = false,
            triage = 'green',
            lastDamage = nil,
            lifeState = 'alive',
            incapacitatedAt = 0,
            diedAt = 0,
            causeOfDeath = nil,
            admitted = false
        },
        treatments = {},
        conditions = {},
        medications = {},
        diagnostics = {},
        flags = {},
        updatedAt = now()
    }
end

function DPN_MED.NormalizeState(state)
    if type(state) ~= 'table' then return DPN_MED.NewBodyState() end
    local fresh = DPN_MED.NewBodyState()

    state.version = Config.Version or 4
    state.body = type(state.body) == 'table' and state.body or {}
    for part in pairs(Config.BodyParts) do
        local current = type(state.body[part]) == 'table' and state.body[part] or {}
        local base = fresh.body[part]
        for key, value in pairs(base) do
            if current[key] == nil then current[key] = value end
        end
        current.wounds = type(current.wounds) == 'table' and current.wounds or {}
        current.organs = type(current.organs) == 'table' and current.organs or base.organs
        current.bones = type(current.bones) == 'table' and current.bones or base.bones
        state.body[part] = current
    end

    state.vitals = type(state.vitals) == 'table' and state.vitals or fresh.vitals
    for key, value in pairs(fresh.vitals) do
        if state.vitals[key] == nil then state.vitals[key] = value end
    end

    state.status = type(state.status) == 'table' and state.status or fresh.status
    for key, value in pairs(fresh.status) do
        if state.status[key] == nil then state.status[key] = value end
    end

    state.treatments = type(state.treatments) == 'table' and state.treatments or {}
    state.conditions = type(state.conditions) == 'table' and state.conditions or {}
    state.medications = type(state.medications) == 'table' and state.medications or {}
    state.diagnostics = type(state.diagnostics) == 'table' and state.diagnostics or {}
    state.flags = type(state.flags) == 'table' and state.flags or {}
    state.updatedAt = tonumber(state.updatedAt) or now()
    return DPN_MED.Recalculate(state)
end

function DPN_MED.ClampVitals(state)
    local v = state.vitals
    v.blood = math.floor(clamp(v.blood, 0, 5000))
    v.systolic = math.floor(clamp(v.systolic, 0, 240))
    v.diastolic = math.floor(clamp(v.diastolic, 0, 160))
    v.hr = math.floor(clamp(v.hr, 0, 240))
    v.rr = math.floor(clamp(v.rr, 0, 45))
    v.spo2 = math.floor(clamp(v.spo2, 0, 100))
    v.temp = clamp(v.temp, 80, 110)
    v.glucose = math.floor(clamp(v.glucose, 0, 600))
    v.etco2 = math.floor(clamp(v.etco2, 0, 100))
    return state
end

function DPN_MED.CalculatePain(state)
    local total = 0
    for part, data in pairs(state.body) do
        local meta = Config.BodyParts[part] or { painMultiplier = 1.0 }
        total = total + ((tonumber(data.pain) or 0) * meta.painMultiplier)
        if data.fracture and data.fracture ~= 'none' then total = total + 7 end
        if (tonumber(data.burn) or 0) > 0 then total = total + ((tonumber(data.burn) or 0) * 5) end
        if data.internalBleeding then total = total + 4 end
    end
    state.status.pain = math.floor(clamp(total / 4, 0, 100))
    return state.status.pain
end

function DPN_MED.CalculateTriage(state)
    local v, s = state.vitals, state.status
    if s.cardiacArrest or v.blood <= Config.Thresholds.deathBloodMl or v.spo2 <= Config.Thresholds.cardiacSpO2 then return 'black' end
    if s.unconscious or v.blood < 2800 or v.spo2 < 86 or s.shock > 65 then return 'red' end
    if v.blood < 3900 or s.pain > 45 or s.shock > 30 then return 'yellow' end
    return 'green'
end

function DPN_MED.Recalculate(state)
    state = DPN_MED.ClampVitals(state)
    DPN_MED.CalculatePain(state)

    local v, s = state.vitals, state.status
    local bloodLoss = math.max(0, 5000 - v.blood)
    local shockFromBlood = bloodLoss / 35
    local shockFromPain = (s.pain or 0) * 0.25
    s.shock = math.floor(clamp(math.max(tonumber(s.shock) or 0, shockFromBlood + shockFromPain), 0, 100))

    v.systolic = math.floor(clamp(120 - (bloodLoss / 50) - (s.shock / 4), 45, 220))
    v.diastolic = math.floor(clamp(80 - (bloodLoss / 75), 25, 150))
    v.hr = math.floor(clamp(74 + (bloodLoss / 45) + (s.shock / 3), 0, 220))
    v.spo2 = math.floor(clamp(99 - (s.shock / 5), 35, 100))
    v.rr = math.floor(clamp(16 + (s.shock / 12), 0, 45))

    s.unconscious = s.cardiacArrest
        or v.blood <= Config.Thresholds.unconsciousBloodMl
        or v.spo2 <= Config.Thresholds.unconsciousSpO2
        or s.pain >= Config.Thresholds.unconsciousPain

    s.cardiacArrest = s.cardiacArrest
        or v.blood <= Config.Thresholds.deathBloodMl
        or v.spo2 <= Config.Thresholds.cardiacSpO2
        or s.shock >= Config.Thresholds.criticalShock

    s.triage = DPN_MED.CalculateTriage(state)
    state.updatedAt = now()
    return DPN_MED.ClampVitals(state)
end

function DPN_MED.SanitizeInjury(injury)
    injury = type(injury) == 'table' and injury or {}
    local bleeding = tostring(injury.bleeding or 'none')
    if Config.BleedingPriority[bleeding] == nil then bleeding = 'none' end

    local fracture = injury.fracture
    if fracture ~= 'closed' and fracture ~= 'compound' then fracture = nil end

    return {
        type = tostring(injury.type or 'trauma'):sub(1, 32),
        damage = clamp(injury.damage, 0, Config.Security.maxDamagePerHit),
        pain = clamp(injury.pain or injury.damage or 0, 0, Config.Security.maxPainPerHit),
        bleeding = bleeding,
        internalBleeding = injury.internalBleeding == true,
        fracture = fracture,
        burn = math.floor(clamp(injury.burn, 0, 4)),
        nerve = clamp(injury.nerve, 0, 100),
        organ = type(injury.organ) == 'string' and injury.organ:sub(1, 32) or nil,
        organDamage = clamp(injury.organDamage or injury.damage or 0, 0, 100),
        weapon = type(injury.weapon) == 'string' and injury.weapon:sub(1, 64) or nil,
        source = type(injury.source) == 'string' and injury.source:sub(1, 32) or nil
    }
end

function DPN_MED.ApplyInjury(state, part, rawInjury)
    state = DPN_MED.NormalizeState(state)
    if not Config.BodyParts[part] or not state.body[part] then return state, false end

    local injury = DPN_MED.SanitizeInjury(rawInjury)
    local p = state.body[part]
    p.damage = clamp((p.damage or 0) + injury.damage, 0, 100)
    p.pain = clamp((p.pain or 0) + injury.pain, 0, 100)

    if Config.BleedingPriority[injury.bleeding] > Config.BleedingPriority[p.bleeding or 'none'] then
        p.bleeding = injury.bleeding
    end
    if injury.bleeding ~= 'none' then p.bleedStacks = math.floor(clamp((p.bleedStacks or 0) + 1, 0, 5)) end
    if injury.internalBleeding then p.internalBleeding = true end
    if injury.fracture then p.fracture = injury.fracture end
    if injury.burn > 0 then p.burn = math.max(p.burn or 0, injury.burn) end
    if injury.nerve > 0 then p.nerve = clamp((p.nerve or 0) + injury.nerve, 0, 100) end

    if injury.organ and p.organs[injury.organ] ~= nil then
        p.organs[injury.organ] = clamp((p.organs[injury.organ] or 0) + injury.organDamage, 0, 100)
    end

    p.mobility = math.floor(clamp(100 - (p.damage * 0.55) - ((p.fracture ~= 'none') and 25 or 0) - ((p.nerve or 0) * 0.25), 0, 100))
    p.wounds[#p.wounds + 1] = {
        type = injury.type,
        severity = math.floor(injury.damage),
        bleeding = injury.bleeding,
        weapon = injury.weapon,
        source = injury.source,
        time = now(),
        treated = false
    }
    while #p.wounds > 20 do table.remove(p.wounds, 1) end

    state.status.lastDamage = { part = part, type = injury.type, weapon = injury.weapon, time = now() }
    state.status.stabilized = false
    return DPN_MED.Recalculate(state), true
end

function DPN_MED.ApplyTreatment(state, part, treatmentType, practitioner)
    state = DPN_MED.NormalizeState(state)
    local definition = Config.Treatments[treatmentType]
    if not definition then return state, false, 'Unknown treatment' end

    local p = part and state.body[part] or nil
    if not definition.global and not p then return state, false, 'Invalid body part' end
    if definition.limbOnly and not (part and (part:find('_arm', 1, true) or part:find('_leg', 1, true))) then
        return state, false, 'This treatment is limited to limbs'
    end
    if definition.parts and not definition.parts[part] then return state, false, 'Treatment cannot be used on that body part' end

    if treatmentType == 'pressure_bandage' then
        if p.bleeding == 'arterial' then p.bleeding = 'venous' else p.bleeding = 'none' end
        p.bleedStacks = math.max(0, (p.bleedStacks or 0) - 1)
        p.pain = math.max(0, p.pain - 5)
    elseif treatmentType == 'hemostatic_gauze' then
        p.bleeding = 'none'
        p.bleedStacks = 0
        p.pain = math.max(0, p.pain - 7)
    elseif treatmentType == 'tourniquet' then
        p.bleeding = 'none'
        p.bleedStacks = 0
        p.pain = math.min(100, p.pain + 5)
        p.mobility = math.min(p.mobility or 100, 35)
        p.tourniquet = true
    elseif treatmentType == 'chest_seal' then
        p.bleeding = 'none'
        p.bleedStacks = 0
        p.pain = math.max(0, p.pain - 8)
        state.vitals.spo2 = math.min(99, state.vitals.spo2 + 8)
    elseif treatmentType == 'splint' then
        if p.fracture == 'none' then return state, false, 'No fracture detected' end
        p.splinted = true
        p.mobility = math.max(p.mobility or 0, 60)
        p.pain = math.max(0, p.pain - 12)
    elseif treatmentType == 'oxygen' then
        state.vitals.spo2 = math.min(100, state.vitals.spo2 + 12)
        state.vitals.rr = math.max(8, state.vitals.rr - 2)
    elseif treatmentType == 'iv_fluids' then
        state.vitals.systolic = math.min(135, state.vitals.systolic + 10)
        state.status.shock = math.max(0, state.status.shock - 10)
    elseif treatmentType == 'blood' then
        state.vitals.blood = math.min(5000, state.vitals.blood + 650)
        state.status.shock = math.max(0, state.status.shock - 18)
    elseif treatmentType == 'morphine' then
        for _, bodyPart in pairs(state.body) do bodyPart.pain = math.max(0, (bodyPart.pain or 0) - 10) end
        state.vitals.rr = math.max(7, state.vitals.rr - 2)
        state.flags.morphineUntil = now() + 600
    elseif treatmentType == 'epinephrine' then
        state.vitals.hr = math.max(65, state.vitals.hr)
        state.vitals.systolic = math.max(90, state.vitals.systolic)
        state.status.shock = math.max(0, state.status.shock - 8)
    elseif treatmentType == 'narcan' then
        state.flags.opioidOverdose = false
        state.vitals.rr = math.max(12, state.vitals.rr)
        state.vitals.spo2 = math.max(92, state.vitals.spo2)
    elseif treatmentType == 'aed' then
        if not state.status.cardiacArrest then return state, false, 'No shockable arrest is present' end
        state.status.cardiacArrest = false
        state.status.unconscious = true
        state.vitals.hr = 72
        state.vitals.spo2 = math.max(82, state.vitals.spo2)
        state.vitals.systolic = math.max(85, state.vitals.systolic)
    elseif treatmentType == 'surgical_repair' then
        p.internalBleeding = false
        p.bleeding = 'none'
        p.bleedStacks = 0
        p.fracture = 'none'
        p.damage = math.max(0, p.damage - 45)
        p.pain = math.max(0, p.pain - 35)
        p.mobility = math.max(p.mobility or 0, 75)
        for organ in pairs(p.organs) do p.organs[organ] = math.max(0, (p.organs[organ] or 0) - 45) end
    elseif treatmentType == 'antibiotics' then
        for _, bodyPart in pairs(state.body) do bodyPart.infection = math.max(0, (bodyPart.infection or 0) - 35) end
        state.flags.antibioticsUntil = now() + 1800
    elseif treatmentType == 'rehab_session' then
        for _, bodyPart in pairs(state.body) do
            if bodyPart.splinted or (bodyPart.fracture or 'none') == 'none' then
                bodyPart.mobility = math.min(100, (bodyPart.mobility or 100) + 12)
                bodyPart.nerve = math.max(0, (bodyPart.nerve or 0) - 5)
                bodyPart.pain = math.max(0, (bodyPart.pain or 0) - 5)
            end
        end
    elseif treatmentType == 'full_heal' then
        local healed = DPN_MED.NewBodyState()
        healed.treatments = state.treatments
        state = healed
    end

    state.treatments[#state.treatments + 1] = {
        by = practitioner or 'unknown',
        type = treatmentType,
        part = part,
        time = now()
    }
    while #state.treatments > 50 do table.remove(state.treatments, 1) end

    state.status.stabilized = treatmentType == 'aed' or treatmentType == 'blood' or treatmentType == 'surgical_repair' or treatmentType == 'full_heal'
    return DPN_MED.Recalculate(state), true
end

function DPN_MED.DecayState(state)
    state = DPN_MED.NormalizeState(state)
    local bloodLoss = 0

    for _, p in pairs(state.body) do
        local external = Config.BleedRatesMlPerTick[p.bleeding or 'none'] or 0
        if external > 0 then bloodLoss = bloodLoss + (external * math.max(1, p.bleedStacks or 1)) end
        if p.internalBleeding then bloodLoss = bloodLoss + (Config.BleedRatesMlPerTick.internal or 12) end
        if (p.infection or 0) > 0 then p.pain = math.min(100, p.pain + 0.15) end
    end

    state.vitals.blood = math.max(0, (state.vitals.blood or 5000) - bloodLoss)
    return DPN_MED.Recalculate(state)
end

function DPN_MED.GetSummary(state)
    state = DPN_MED.NormalizeState(state)
    local active = 0
    local severe = 0
    local bleeding = false
    for _, p in pairs(state.body) do
        if (p.damage or 0) > 0 or p.internalBleeding or (p.bleeding or 'none') ~= 'none' or (p.fracture or 'none') ~= 'none' then active = active + 1 end
        if (p.damage or 0) >= 55 or p.internalBleeding or p.bleeding == 'arterial' or p.fracture == 'compound' then severe = severe + 1 end
        if p.internalBleeding or (p.bleeding or 'none') ~= 'none' then bleeding = true end
    end

    return {
        triage = state.status.triage,
        pain = state.status.pain,
        shock = state.status.shock,
        unconscious = state.status.unconscious,
        cardiacArrest = state.status.cardiacArrest,
        blood = state.vitals.blood,
        spo2 = state.vitals.spo2,
        activeInjuries = active,
        severeInjuries = severe,
        bleeding = bleeding
    }
end



function DPN_MED.SetLifeState(state, lifeState, details)
    state = DPN_MED.NormalizeState(state)
    if lifeState ~= 'alive' and lifeState ~= 'incapacitated' and lifeState ~= 'dead' then
        return state, false
    end
    details = type(details) == 'table' and details or {}
    state.status.lifeState = lifeState
    if lifeState == 'alive' then
        state.status.incapacitatedAt = 0
        state.status.diedAt = 0
        state.status.unconscious = false
        if details.clearArrest ~= false then state.status.cardiacArrest = false end
        state.status.causeOfDeath = nil
    elseif lifeState == 'incapacitated' then
        state.status.incapacitatedAt = tonumber(details.time) or now()
        state.status.unconscious = details.unconscious ~= false
        state.status.causeOfDeath = details.cause or state.status.causeOfDeath
    elseif lifeState == 'dead' then
        state.status.diedAt = tonumber(details.time) or now()
        state.status.unconscious = true
        state.status.cardiacArrest = true
        state.status.causeOfDeath = details.cause or state.status.causeOfDeath or 'Unknown'
        state.vitals.hr = 0
        state.vitals.rr = 0
        state.vitals.spo2 = 0
        state.vitals.systolic = 0
        state.vitals.diastolic = 0
    end
    state.updatedAt = now()
    return state, true
end

function DPN_MED.AddCondition(state, conditionId, data)
    state = DPN_MED.NormalizeState(state)
    conditionId = tostring(conditionId or ''):sub(1, 64)
    if conditionId == '' then return state, false end
    data = type(data) == 'table' and data or {}
    state.conditions[conditionId] = {
        id = conditionId,
        label = tostring(data.label or conditionId):sub(1, 100),
        severity = math.max(0, math.min(100, tonumber(data.severity) or 1)),
        stage = tostring(data.stage or 'active'):sub(1, 32),
        contagious = data.contagious == true,
        startedAt = tonumber(data.startedAt) or now(),
        expiresAt = tonumber(data.expiresAt) or 0,
        metadata = type(data.metadata) == 'table' and data.metadata or {}
    }
    return DPN_MED.Recalculate(state), true
end

function DPN_MED.RemoveCondition(state, conditionId)
    state = DPN_MED.NormalizeState(state)
    if state.conditions[conditionId] == nil then return state, false end
    state.conditions[conditionId] = nil
    return DPN_MED.Recalculate(state), true
end

function DPN_MED.AddMedication(state, medicationId, data)
    state = DPN_MED.NormalizeState(state)
    medicationId = tostring(medicationId or ''):sub(1, 64)
    if medicationId == '' then return state, false end
    data = type(data) == 'table' and data or {}
    state.medications[#state.medications + 1] = {
        id = medicationId,
        dose = tostring(data.dose or ''):sub(1, 64),
        route = tostring(data.route or 'unknown'):sub(1, 32),
        by = tostring(data.by or 'system'):sub(1, 64),
        time = tonumber(data.time) or now(),
        expiresAt = tonumber(data.expiresAt) or 0,
        metadata = type(data.metadata) == 'table' and data.metadata or {}
    }
    while #state.medications > 100 do table.remove(state.medications, 1) end
    return state, true
end

function DPN_MED.SetDiagnostic(state, diagnosticId, data)
    state = DPN_MED.NormalizeState(state)
    diagnosticId = tostring(diagnosticId or ''):sub(1, 64)
    if diagnosticId == '' then return state, false end
    data = type(data) == 'table' and data or {}
    state.diagnostics[diagnosticId] = {
        type = tostring(data.type or diagnosticId):sub(1, 64),
        findings = tostring(data.findings or ''):sub(1, 2000),
        result = tostring(data.result or 'pending'):sub(1, 64),
        orderedBy = tostring(data.orderedBy or 'system'):sub(1, 64),
        time = tonumber(data.time) or now(),
        metadata = type(data.metadata) == 'table' and data.metadata or {}
    }
    return state, true
end
