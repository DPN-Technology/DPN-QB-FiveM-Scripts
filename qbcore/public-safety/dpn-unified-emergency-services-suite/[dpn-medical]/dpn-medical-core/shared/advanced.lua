DPN_MED = DPN_MED or {}

local baseRecalculate = DPN_MED.Recalculate
local baseApplyTreatment = DPN_MED.ApplyTreatment
local baseDecayState = DPN_MED.DecayState
local baseGetSummary = DPN_MED.GetSummary

local function now()
    return os and os.time and os.time() or 0
end

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function ensureTable(parent, key, defaults)
    parent[key] = type(parent[key]) == 'table' and parent[key] or {}
    for k, v in pairs(defaults or {}) do
        if parent[key][k] == nil then parent[key][k] = v end
    end
    return parent[key]
end

function DPN_MED.EnsureAdvancedSchema(state)
    state = type(state) == 'table' and state or DPN_MED.NewBodyState()
    ensureTable(state, 'profile', {
        bloodType = (Config.Advanced and Config.Advanced.defaultBloodType) or 'unknown',
        codeStatus = 'full_code', consent = 'implied', weightKg = 80, heightCm = 175
    })
    state.profile.allergies = type(state.profile.allergies) == 'table' and state.profile.allergies or {}
    state.profile.alerts = type(state.profile.alerts) == 'table' and state.profile.alerts or {}
    state.profile.history = type(state.profile.history) == 'table' and state.profile.history or {}

    ensureTable(state, 'airway', { patent = true, obstruction = 0, secured = false, device = nil, suctionRequired = false })
    ensureTable(state, 'respiration', { effort = 'normal', leftSounds = 'clear', rightSounds = 'clear', oxygenLpm = 0, ventilated = false, pneumothorax = false })
    ensureTable(state, 'circulation', { perfusion = 'normal', rhythm = 'sinus', pulses = 'strong', capillaryRefill = 2, ivAccess = 0, ioAccess = 0 })
    ensureTable(state, 'neuro', { gcs = 15, pupils = 'PERRL', orientation = 4, seizure = false })
    ensureTable(state, 'renal', { urineOutput = 35, renalRisk = 0 })
    ensureTable(state, 'exposure', { contamination = nil, isolation = nil, hypothermiaRisk = 0 })
    ensureTable(state, 'advanced', { map = 93, shockIndex = 0.62, qsofa = 0, news = 0, lactate = 1.0, deterioration = 0, risk = 'low', recommendedCare = 'routine' })

    state.devices = type(state.devices) == 'table' and state.devices or {}
    state.procedures = type(state.procedures) == 'table' and state.procedures or {}
    state.carePlan = type(state.carePlan) == 'table' and state.carePlan or { tasks = {}, goals = {}, status = 'none' }
    state.carePlan.tasks = type(state.carePlan.tasks) == 'table' and state.carePlan.tasks or {}
    state.carePlan.goals = type(state.carePlan.goals) == 'table' and state.carePlan.goals or {}
    state.timeline = type(state.timeline) == 'table' and state.timeline or {}
    state.episodes = type(state.episodes) == 'table' and state.episodes or {}
    return state
end

local function newsBand(value, bands)
    for _, row in ipairs(bands) do
        if value <= row[1] then return row[2] end
    end
    return bands[#bands][2]
end

function DPN_MED.CalculateAdvancedMetrics(state)
    state = DPN_MED.EnsureAdvancedSchema(state)
    local v, s = state.vitals, state.status
    local sys = math.max(1, tonumber(v.systolic) or 1)
    local dia = math.max(0, tonumber(v.diastolic) or 0)
    local hr = math.max(0, tonumber(v.hr) or 0)
    local rr = math.max(0, tonumber(v.rr) or 0)
    local spo2 = math.max(0, tonumber(v.spo2) or 0)
    local temp = tonumber(v.temp) or 98.6

    state.advanced.map = math.floor((sys + (2 * dia)) / 3)
    state.advanced.shockIndex = math.floor((hr / sys) * 100) / 100

    local gcs = 15
    if s.cardiacArrest or (s.lifeState or 'alive') == 'dead' then gcs = 3
    elseif s.unconscious then gcs = 7
    elseif spo2 < 88 or (s.shock or 0) > 70 then gcs = 10
    elseif (s.pain or 0) > 80 then gcs = 13 end
    state.neuro.gcs = gcs

    local qsofa = 0
    if sys <= 100 then qsofa = qsofa + 1 end
    if rr >= 22 then qsofa = qsofa + 1 end
    if state.neuro.gcs < 15 then qsofa = qsofa + 1 end
    state.advanced.qsofa = qsofa

    local news = 0
    news = news + newsBand(rr, {{8,3},{11,1},{20,0},{24,2},{99,3}})
    news = news + newsBand(spo2, {{91,3},{93,2},{95,1},{100,0}})
    news = news + newsBand(sys, {{90,3},{100,2},{110,1},{219,0},{999,3}})
    news = news + newsBand(hr, {{40,3},{50,1},{90,0},{110,1},{130,2},{999,3}})
    news = news + newsBand(temp, {{95.0,3},{96.8,1},{100.4,0},{102.2,1},{999,2}})
    if s.unconscious then news = news + 3 end
    state.advanced.news = math.floor(news)

    local lactate = 0.8 + math.max(0, state.advanced.shockIndex - 0.7) * 3.2 + math.max(0, 94 - spo2) * 0.08 + math.max(0, (s.shock or 0) - 30) * 0.025
    state.advanced.lactate = math.floor(clamp(lactate, 0.5, 15) * 10) / 10

    local hemorrhageBurden, internalBurden, organBurden, fractureBurden = 0, 0, 0, 0
    for _, part in pairs(state.body or {}) do
        if part.bleeding == 'arterial' then hemorrhageBurden = hemorrhageBurden + 12
        elseif part.bleeding == 'venous' then hemorrhageBurden = hemorrhageBurden + 5 end
        if part.internalBleeding then internalBurden = internalBurden + 12 end
        if part.fracture == 'compound' then fractureBurden = fractureBurden + 6 elseif part.fracture == 'closed' then fractureBurden = fractureBurden + 2 end
        for _, damage in pairs(part.organs or {}) do if (tonumber(damage) or 0) >= 35 then organBurden = organBurden + 5 end end
    end
    local deterioration = news * 6 + qsofa * 12 + math.max(0, state.advanced.shockIndex - 0.8) * 30 + hemorrhageBurden + internalBurden + organBurden + fractureBurden
    if s.cardiacArrest then deterioration = 100 end
    if v.blood < 3800 then deterioration = deterioration + 12 end
    if v.blood < 3000 then deterioration = deterioration + 20 end
    if state.neuro.gcs <= 8 then deterioration = deterioration + 18 end
    state.advanced.deterioration = math.floor(clamp(deterioration, 0, 100))

    if state.advanced.deterioration >= 80 or s.cardiacArrest then
        state.advanced.risk, state.advanced.recommendedCare = 'critical', 'resuscitation'
    elseif state.advanced.deterioration >= 55 then
        state.advanced.risk, state.advanced.recommendedCare = 'high', 'icu'
    elseif state.advanced.deterioration >= 30 then
        state.advanced.risk, state.advanced.recommendedCare = 'moderate', 'monitored_bed'
    else
        state.advanced.risk, state.advanced.recommendedCare = 'low', 'routine'
    end

    if state.advanced.map < 55 then state.circulation.perfusion = 'critical'
    elseif state.advanced.map < 65 then state.circulation.perfusion = 'poor'
    elseif state.advanced.map < 75 then state.circulation.perfusion = 'reduced'
    else state.circulation.perfusion = 'normal' end

    if s.cardiacArrest then state.circulation.rhythm = 'arrest'
    elseif hr == 0 then state.circulation.rhythm = 'asystole'
    elseif hr < 50 then state.circulation.rhythm = 'bradycardia'
    elseif hr > 140 then state.circulation.rhythm = 'severe_tachycardia'
    elseif hr > 100 then state.circulation.rhythm = 'tachycardia'
    else state.circulation.rhythm = 'sinus' end
    return state
end

function DPN_MED.Recalculate(state)
    state = DPN_MED.EnsureAdvancedSchema(state)
    local observed = {
        spo2 = tonumber(state.vitals.spo2), rr = tonumber(state.vitals.rr),
        systolic = tonumber(state.vitals.systolic), diastolic = tonumber(state.vitals.diastolic),
        hr = tonumber(state.vitals.hr), etco2 = tonumber(state.vitals.etco2)
    }
    state = baseRecalculate(state)
    local current = now()
    if observed.spo2 then
        if state.flags.oxygenUntil and current <= state.flags.oxygenUntil then
            state.vitals.spo2 = math.max(state.vitals.spo2, observed.spo2)
        else
            state.vitals.spo2 = math.min(state.vitals.spo2, observed.spo2)
        end
    end
    if observed.rr and (observed.rr < 12 or observed.rr > 20) then state.vitals.rr = observed.rr end
    if observed.etco2 and (observed.etco2 < 30 or observed.etco2 > 45) then state.vitals.etco2 = observed.etco2 end
    if observed.systolic then
        if (state.flags.ivBolusUntil and current <= state.flags.ivBolusUntil) or (state.flags.epinephrineUntil and current <= state.flags.epinephrineUntil) then
            state.vitals.systolic = math.max(state.vitals.systolic, observed.systolic)
        else
            state.vitals.systolic = math.min(state.vitals.systolic, observed.systolic)
        end
    end
    if observed.diastolic and not (state.flags.ivBolusUntil and current <= state.flags.ivBolusUntil) then state.vitals.diastolic = math.min(state.vitals.diastolic, observed.diastolic) end
    if observed.hr and (observed.hr < 50 or observed.hr > 100) then state.vitals.hr = observed.hr end
    DPN_MED.ClampVitals(state)
    return DPN_MED.CalculateAdvancedMetrics(state)
end

function DPN_MED.CheckTreatmentSafety(state, treatmentType, part, context)
    state = DPN_MED.EnsureAdvancedSchema(state)
    context = type(context) == 'table' and context or {}
    local warnings = {}
    local hardStop = nil
    local v = state.vitals

    if treatmentType == 'morphine' then
        if (v.rr or 0) < 10 or (v.spo2 or 0) < 90 then hardStop = 'Morphine withheld: respiratory depression risk.' end
        if (v.systolic or 0) < 90 then warnings[#warnings + 1] = 'Hypotension may worsen after morphine.' end
    elseif treatmentType == 'iv_fluids' then
        if state.flags and state.flags.heartFailure then warnings[#warnings + 1] = 'Fluid overload risk due to heart failure.' end
    elseif treatmentType == 'blood' then
        local ordered = tostring(context.bloodType or state.flags.pendingBloodType or 'unknown')
        local actual = tostring(state.profile.bloodType or 'unknown')
        if ordered ~= 'unknown' and actual ~= 'unknown' and ordered ~= actual and ordered ~= 'O-' then
            hardStop = ('Blood type mismatch: patient %s, product %s.'):format(actual, ordered)
        end
    elseif treatmentType == 'aed' then
        if not state.status.cardiacArrest then hardStop = 'Defibrillation denied: patient is not in cardiac arrest.' end
        if state.circulation.rhythm == 'asystole' then hardStop = 'Asystole is not a shockable rhythm.' end
    elseif treatmentType == 'tourniquet' and part and not (part:find('_arm',1,true) or part:find('_leg',1,true)) then
        hardStop = 'Tourniquets can only be applied to extremities.'
    end

    for allergy, enabled in pairs(state.profile.allergies or {}) do
        if enabled and tostring(allergy):lower() == tostring(treatmentType):lower() then
            hardStop = ('Allergy alert: %s.'):format(allergy)
        end
    end
    return hardStop == nil, hardStop, warnings
end

function DPN_MED.ApplyTreatment(state, part, treatmentType, practitioner, context)
    local safe, reason, warnings = DPN_MED.CheckTreatmentSafety(state, treatmentType, part, context)
    if not safe then return state, false, reason end
    local updated, ok, message = baseApplyTreatment(state, part, treatmentType, practitioner)
    if not ok then return updated, ok, message end
    updated = DPN_MED.EnsureAdvancedSchema(updated)
    local t = now()
    if treatmentType == 'oxygen' then
        updated.respiration.oxygenLpm = math.max(updated.respiration.oxygenLpm or 0, tonumber(context and context.lpm) or 10)
        updated.flags.oxygenUntil = t + 900
    elseif treatmentType == 'iv_fluids' then
        updated.circulation.ivAccess = math.max(1, updated.circulation.ivAccess or 0)
        updated.flags.ivBolusUntil = t + 300
    elseif treatmentType == 'epinephrine' then
        updated.flags.epinephrineUntil = t + 180
    elseif treatmentType == 'blood' then
        updated.flags.lastBloodProduct = tostring(context and context.bloodType or 'O-')
    elseif treatmentType == 'tourniquet' and part and updated.body[part] then
        updated.body[part].tourniquetAppliedAt = updated.body[part].tourniquetAppliedAt or t
    elseif treatmentType == 'chest_seal' and part == 'chest' then
        updated.respiration.pneumothorax = false
    elseif treatmentType == 'surgical_repair' then
        updated.flags.postOpUntil = t + 1800
    end
    if warnings and #warnings > 0 then updated.flags.lastTreatmentWarnings = warnings end
    return DPN_MED.Recalculate(updated), true
end

function DPN_MED.DecayState(state)
    state = baseDecayState(state)
    state = DPN_MED.EnsureAdvancedSchema(state)
    local tick = math.max(1, tonumber(Config.Advanced and Config.Advanced.physiologyTickSeconds) or 5)
    local current = now()

    if not state.airway.patent or (state.airway.obstruction or 0) > 0 then
        state.vitals.spo2 = math.max(0, state.vitals.spo2 - (0.4 + (state.airway.obstruction or 0) / 100) * tick / 5)
        state.vitals.etco2 = math.min(100, state.vitals.etco2 + 1)
    end
    if state.respiration.pneumothorax then
        state.vitals.spo2 = math.max(0, state.vitals.spo2 - 0.8)
        state.vitals.rr = math.min(45, state.vitals.rr + 0.4)
    end
    if state.flags.oxygenUntil and current <= state.flags.oxygenUntil then
        state.vitals.spo2 = math.min(100, state.vitals.spo2 + math.max(0.2, (state.respiration.oxygenLpm or 0) / 20))
    elseif state.flags.oxygenUntil and current > state.flags.oxygenUntil then
        state.flags.oxygenUntil = nil
        state.respiration.oxygenLpm = 0
    end

    local infectionBurden = 0
    for _, part in pairs(state.body) do
        infectionBurden = infectionBurden + (tonumber(part.infection) or 0)
        if Config.Advanced.enableTourniquetIschemia and part.tourniquet and part.tourniquetAppliedAt then
            local minutes = (current - part.tourniquetAppliedAt) / 60
            if minutes >= (Config.AdvancedThresholds.tourniquetWarningMinutes or 90) then
                part.nerve = math.min(100, (part.nerve or 0) + 0.25)
                part.mobility = math.max(0, (part.mobility or 100) - 0.2)
                state.flags.tourniquetWarning = true
            end
            if minutes >= (Config.AdvancedThresholds.tourniquetCriticalMinutes or 120) then
                part.damage = math.min(100, (part.damage or 0) + 0.2)
                state.flags.tourniquetCritical = true
            end
        end
    end
    if Config.Advanced.enableSepsisProgression and infectionBurden >= 80 then
        state.vitals.temp = math.min(106, state.vitals.temp + 0.02)
        state.vitals.hr = math.min(220, state.vitals.hr + 0.15)
        state.vitals.systolic = math.max(0, state.vitals.systolic - 0.08)
        state.flags.sepsisRisk = true
    end

    for i = #state.medications, 1, -1 do
        local med = state.medications[i]
        if tonumber(med.expiresAt or 0) > 0 and current > tonumber(med.expiresAt) then
            table.remove(state.medications, i)
        end
    end
    return DPN_MED.Recalculate(state)
end

function DPN_MED.AddTimelineEvent(state, eventType, data, actor)
    state = DPN_MED.EnsureAdvancedSchema(state)
    state.timeline[#state.timeline + 1] = { type = tostring(eventType or 'event'), data = data or {}, actor = actor or 'system', time = now() }
    local max = tonumber(Config.Advanced and Config.Advanced.maxTimelineEntries) or 150
    while #state.timeline > max do table.remove(state.timeline, 1) end
    return state
end

function DPN_MED.AddCarePlanTask(state, task)
    state = DPN_MED.EnsureAdvancedSchema(state)
    task = type(task) == 'table' and task or {}
    local id = tostring(task.id or ('task_%s_%s'):format(now(), #state.carePlan.tasks + 1))
    state.carePlan.status = 'active'
    state.carePlan.tasks[#state.carePlan.tasks + 1] = {
        id = id, label = tostring(task.label or 'Clinical task'):sub(1,160),
        status = tostring(task.status or 'pending'), priority = tonumber(task.priority) or 3,
        dueAt = tonumber(task.dueAt) or 0, assignedTo = task.assignedTo,
        createdAt = now(), completedAt = 0, metadata = type(task.metadata) == 'table' and task.metadata or {}
    }
    while #state.carePlan.tasks > (tonumber(Config.Advanced.maxCarePlanTasks) or 40) do table.remove(state.carePlan.tasks, 1) end
    return state, id
end

function DPN_MED.CompleteCarePlanTask(state, taskId, actor)
    state = DPN_MED.EnsureAdvancedSchema(state)
    for _, task in ipairs(state.carePlan.tasks) do
        if task.id == taskId then
            task.status, task.completedAt, task.completedBy = 'completed', now(), actor or 'system'
            return state, true
        end
    end
    return state, false
end

function DPN_MED.AddProcedure(state, procedure)
    state = DPN_MED.EnsureAdvancedSchema(state)
    procedure = type(procedure) == 'table' and procedure or {}
    state.procedures[#state.procedures + 1] = {
        id = tostring(procedure.id or ('procedure_%s'):format(now())),
        type = tostring(procedure.type or 'procedure'), bodyPart = procedure.bodyPart,
        provider = procedure.provider or 'system', outcome = procedure.outcome or 'completed',
        time = tonumber(procedure.time) or now(), metadata = procedure.metadata or {}
    }
    while #state.procedures > 100 do table.remove(state.procedures, 1) end
    return state
end

function DPN_MED.GetProtocolRecommendations(state)
    state = DPN_MED.CalculateAdvancedMetrics(state)
    local rec = {}
    local summary = baseGetSummary(state)
    if state.status.cardiacArrest then rec[#rec+1] = { id='cardiac_arrest', priority=0, actions=Config.Protocols.cardiac_arrest.actions } end
    local majorHemorrhage = false
    for _, part in pairs(state.body or {}) do if part.bleeding == 'arterial' or part.internalBleeding then majorHemorrhage = true break end end
    if summary.bleeding and (majorHemorrhage or state.vitals.blood < 4200) then rec[#rec+1] = { id='massive_hemorrhage', priority=1, actions=Config.Protocols.massive_hemorrhage.actions } end
    if state.vitals.spo2 < 90 or not state.airway.patent then rec[#rec+1] = { id='airway_compromise', priority=1, actions=Config.Protocols.airway_compromise.actions } end
    if state.advanced.map < 65 or state.advanced.shockIndex >= 1.0 then rec[#rec+1] = { id='shock', priority=1, actions=Config.Protocols.shock.actions } end
    if state.neuro.gcs < 14 then rec[#rec+1] = { id='traumatic_brain_injury', priority=2, actions=Config.Protocols.traumatic_brain_injury.actions } end
    if state.advanced.qsofa >= 2 then rec[#rec+1] = { id='sepsis', priority=1, actions=Config.Protocols.sepsis.actions } end
    table.sort(rec, function(a,b) return a.priority < b.priority end)
    return rec
end

function DPN_MED.GetClinicalSnapshot(state)
    state = DPN_MED.CalculateAdvancedMetrics(state)
    local summary = baseGetSummary(state)
    summary.map = state.advanced.map
    summary.shockIndex = state.advanced.shockIndex
    summary.qsofa = state.advanced.qsofa
    summary.news = state.advanced.news
    summary.lactate = state.advanced.lactate
    summary.deterioration = state.advanced.deterioration
    summary.risk = state.advanced.risk
    summary.recommendedCare = state.advanced.recommendedCare
    summary.gcs = state.neuro.gcs
    summary.rhythm = state.circulation.rhythm
    summary.perfusion = state.circulation.perfusion
    summary.airwayPatent = state.airway.patent
    summary.oxygenLpm = state.respiration.oxygenLpm
    summary.protocols = DPN_MED.GetProtocolRecommendations(state)
    return summary
end

function DPN_MED.GetSummary(state)
    return DPN_MED.GetClinicalSnapshot(state)
end
