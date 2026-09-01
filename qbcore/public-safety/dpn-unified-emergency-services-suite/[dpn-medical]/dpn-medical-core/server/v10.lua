local VERSION = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'unknown'
local bundles, blackBox, commandIncidents, reconciliationHistory = {}, {}, {}, {}

local function now() return os.time() end
local function uid(prefix, target) return ('%s-%s-%s-%04d'):format(prefix, now(), tostring(target or 0), math.random(0, 9999)) end
local function encode(value) local ok, data = pcall(json.encode, value); return ok and data or '{}' end
local function player(target) local ok, p = pcall(function() return exports['qb-core']:GetCoreObject().Functions.GetPlayer(tonumber(target)) end); return ok and p or nil end
local function cid(target) local p = player(target); return p and p.PlayerData and p.PlayerData.citizenid or ('source:%s'):format(tostring(target)) end
local function stateFor(target) if not DPNMedicalServer or not DPNMedicalServer.EnsureState then return nil end; return DPNMedicalServer.EnsureState(tonumber(target)) end
local function commit(target, state, eventType, data)
    local _, patientCid = DPNMedicalServer.EnsureState(tonumber(target))
    if not patientCid then return false end
    DPNMedicalServer.Commit(tonumber(target), patientCid, state, eventType, data or {})
    return true
end
local function persist(sql, params)
    CreateThread(function() pcall(function() MySQL.insert.await(sql, params) end) end)
end

local function record(target, eventType, payload, sourceModule)
    target = tonumber(target)
    local item = {
        id = uid('BBX', target), target = target, patientCid = cid(target), eventType = tostring(eventType or 'event'),
        payload = type(payload) == 'table' and payload or {}, sourceModule = tostring(sourceModule or 'dpn-medical-core'), recordedAt = now()
    }
    blackBox[target] = blackBox[target] or {}
    table.insert(blackBox[target], 1, item)
    while #blackBox[target] > 250 do table.remove(blackBox[target]) end
    persist('INSERT INTO dpn_medical_v10_black_box (event_id,patient_cid,event_type,source_module,event_data) VALUES (?,?,?,?,?)', { item.id, item.patientCid, item.eventType, item.sourceModule, encode(item.payload) })
    return item
end

exports('GetV10Twin', function(target)
    local state = stateFor(target)
    return state and DPN_MED.BuildV10Twin(state) or nil
end)

exports('PredictCriticalTransitionV10', function(target, horizonMinutes)
    local state = stateFor(target)
    if not state then return false, 'Patient not found.' end
    local prediction = DPN_MED.PredictV10Transition(state, horizonMinutes)
    record(target, 'v10_transition_prediction', prediction, 'dpn-medical-core')
    return true, prediction
end)

exports('CreateClosedLoopBundleV10', function(target, author)
    target = tonumber(target)
    local state = stateFor(target)
    if not state then return false, 'Patient not found.' end
    local bundle = DPN_MED.BuildClosedLoopBundle(state)
    bundle.id = uid('CLB', target)
    bundle.target = target
    bundle.patientCid = cid(target)
    bundle.author = tostring(author or 'system')
    bundles[target] = bundles[target] or {}
    bundles[target][bundle.id] = bundle
    state.closedLoopBundles[bundle.id] = bundle
    commit(target, state, 'v10_closed_loop_bundle_created', { bundleId = bundle.id, steps = #bundle.steps, author = bundle.author })
    persist('INSERT INTO dpn_medical_v10_closed_loop_bundles (bundle_id,patient_cid,status,command_risk,bundle_data,created_by) VALUES (?,?,?,?,?,?)', { bundle.id, bundle.patientCid, bundle.status, bundle.commandRisk, encode(bundle), bundle.author })
    record(target, 'closed_loop_bundle_created', { bundleId = bundle.id, steps = #bundle.steps }, 'dpn-medical-core')
    return bundle.id, bundle
end)

exports('CompleteClosedLoopStepV10', function(target, bundleId, stepCode, author, evidence)
    target = tonumber(target)
    local bundle = bundles[target] and bundles[target][tostring(bundleId)]
    if not bundle then return false, 'Closed-loop bundle not found.' end
    local selected
    for _, step in ipairs(bundle.steps or {}) do if step.code == stepCode then selected = step break end end
    if not selected then return false, 'Closed-loop step not found.' end
    selected.status = 'completed'; selected.completedAt = now(); selected.completedBy = tostring(author or 'system'); selected.evidence = evidence
    local remaining = 0
    for _, step in ipairs(bundle.steps or {}) do if step.status ~= 'completed' then remaining = remaining + 1 end end
    if remaining == 0 then bundle.status = 'complete'; bundle.completedAt = now() end
    CreateThread(function() pcall(function() MySQL.update.await('UPDATE dpn_medical_v10_closed_loop_bundles SET status=?,bundle_data=?,updated_at=NOW() WHERE bundle_id=?', { bundle.status, encode(bundle), bundle.id }) end) end)
    record(target, 'closed_loop_step_completed', { bundleId = bundle.id, step = stepCode, remaining = remaining }, 'dpn-medical-core')
    return true, selected, bundle
end)

exports('GetClosedLoopBundlesV10', function(target)
    local out = {}
    for _, bundle in pairs(bundles[tonumber(target)] or {}) do out[#out + 1] = bundle end
    table.sort(out, function(a,b) return (a.createdAt or 0) > (b.createdAt or 0) end)
    return out
end)

exports('RecordClinicalBlackBoxV10', function(target, eventType, payload, sourceModule)
    if not stateFor(target) then return false, 'Patient not found.' end
    return true, record(target, eventType, payload, sourceModule)
end)

exports('GetClinicalBlackBoxV10', function(target, limit)
    local rows, source = {}, blackBox[tonumber(target)] or {}
    limit = math.max(1, math.min(250, tonumber(limit) or 50))
    for index = 1, math.min(limit, #source) do rows[index] = source[index] end
    return rows
end)

exports('CreateClinicalCommandIncidentV10', function(target, incidentType, location, actor)
    target = tonumber(target)
    local twin = exports['dpn-medical-core']:GetV10Twin(target)
    if type(twin) ~= 'table' then return false, 'Patient not found.' end
    local incident = {
        id = uid('CMD', target), target = target, patientCid = cid(target), incidentType = tostring(incidentType or 'critical_care'),
        location = location, actor = tostring(actor or 'system'), status = 'active', commandRisk = twin.v10.commandRisk,
        recommendedCommand = twin.v10.recommendedCommand, assignments = {}, timeline = { { event = 'activated', at = now() } }, createdAt = now()
    }
    commandIncidents[incident.id] = incident
    persist('INSERT INTO dpn_medical_v10_command_incidents (incident_id,patient_cid,incident_type,status,command_risk,incident_data,created_by) VALUES (?,?,?,?,?,?,?)', { incident.id, incident.patientCid, incident.incidentType, incident.status, incident.commandRisk, encode(incident), incident.actor })
    record(target, 'clinical_command_activated', { incidentId = incident.id, type = incident.incidentType }, 'dpn-medical-core')
    TriggerEvent('dpn-medical:server:v10CommandActivated', incident)
    return incident.id, incident
end)

exports('UpdateClinicalCommandIncidentV10', function(incidentId, status, data, actor)
    local incident = commandIncidents[tostring(incidentId)]
    if not incident then return false, 'Command incident not found.' end
    incident.status = tostring(status or incident.status)
    incident.timeline[#incident.timeline + 1] = { event = incident.status, data = data, actor = actor, at = now() }
    incident.updatedAt = now()
    if incident.status == 'closed' or incident.status == 'resolved' then incident.closedAt = now() end
    CreateThread(function() pcall(function() MySQL.update.await('UPDATE dpn_medical_v10_command_incidents SET status=?,incident_data=?,updated_at=NOW() WHERE incident_id=?', { incident.status, encode(incident), incident.id }) end) end)
    return true, incident
end)

exports('ReconcileCrossModuleCareV10', function(target, author)
    target = tonumber(target)
    local state = stateFor(target)
    if not state then return false, 'Patient not found.' end
    local twin = DPN_MED.BuildV10Twin(state)
    local modules = {}
    local ok, registry = pcall(function() return exports['dpn-medical-core']:GetModules() end)
    if ok and type(registry) == 'table' then modules = registry end
    local missing = {}
    local required = { 'dpn-medical-ems', 'dpn-medical-hospital', 'dpn-medical-records', 'dpn-medical-pharmacy', 'dpn-medical-dispatch' }
    if twin.v10.commandRisk >= 65 then required[#required + 1] = 'dpn-medical-icu' end
    if twin.circulation.hemorrhageRateMlMin + twin.circulation.internalHemorrhageRateMlMin >= 30 then required[#required + 1] = 'dpn-medical-surgery' end
    for _, name in ipairs(required) do if GetResourceState(name) ~= 'started' then missing[#missing + 1] = name end end
    local report = {
        id = uid('REC', target), target = target, patientCid = cid(target), author = tostring(author or 'system'),
        commandRisk = twin.v10.commandRisk, careGaps = twin.careGaps, missingResources = missing,
        registeredModules = modules, status = (#missing == 0 and #twin.careGaps == 0) and 'reconciled' or 'attention_required', createdAt = now()
    }
    reconciliationHistory[target] = reconciliationHistory[target] or {}
    table.insert(reconciliationHistory[target], 1, report)
    persist('INSERT INTO dpn_medical_v10_reconciliations (reconciliation_id,patient_cid,status,reconciliation_data,reconciled_by) VALUES (?,?,?,?,?)', { report.id, report.patientCid, report.status, encode(report), report.author })
    record(target, 'cross_module_reconciliation', report, 'dpn-medical-core')
    return true, report
end)

exports('GetV10OperationalDashboard', function()
    local patients, imminent, critical, careGaps, activeCommands = {}, 0, 0, 0, 0
    for _, sid in ipairs(GetPlayers() or {}) do
        local target = tonumber(sid)
        local state = stateFor(target)
        if state then
            local twin = DPN_MED.BuildV10Twin(state)
            if twin.v10.predictedArrestMinutes > 0 and twin.v10.predictedArrestMinutes <= 10 then imminent = imminent + 1 end
            if twin.v10.commandRisk >= 70 then critical = critical + 1 end
            careGaps = careGaps + (twin.v10.careGapCount or 0)
            patients[#patients + 1] = { id = target, citizenid = cid(target), twin = twin, bundles = bundles[target], blackBoxEvents = blackBox[target] and #blackBox[target] or 0 }
        end
    end
    for _, incident in pairs(commandIncidents) do if incident.status == 'active' then activeCommands = activeCommands + 1 end end
    table.sort(patients, function(a,b) return (a.twin.v10.commandRisk or 0) > (b.twin.v10.commandRisk or 0) end)
    return { version = VERSION, generatedAt = now(), patients = patients, imminentArrest = imminent, critical = critical, careGaps = careGaps, activeCommands = activeCommands }
end)

exports('RunV10SelfTest', function()
    local state = DPN_MED.NewBodyState()
    state.vitals.blood = 2250; state.vitals.spo2 = 76; state.vitals.hr = 152; state.vitals.rr = 38; state.vitals.systolic = 64; state.vitals.diastolic = 34; state.vitals.temp = 94.0
    state.labs = { ph = 7.08, hco3 = 12, lactate = 9.2, inr = 3.0, platelets = 48, fibrinogen = 110, creatinine = 3.6, potassium = 6.1 }
    state.body.chest.bleeding = 'arterial'; state.body.chest.bleedStacks = 3; state.body.chest.internalBleeding = true; state.body.chest.damage = 85
    state.body.abdomen.internalBleeding = true; state.body.abdomen.damage = 80
    state = DPN_MED.Recalculate(state)
    local twin = DPN_MED.BuildV10Twin(state)
    local prediction = DPN_MED.PredictV10Transition(state, 15)
    local bundle = DPN_MED.BuildClosedLoopBundle(state)
    local passed = twin.v10.commandRisk >= 70 and twin.circulation.clotStability < 60 and twin.bloodGas.acidBase ~= 'normal' and prediction.projectedRisk >= prediction.currentRisk and #bundle.steps >= 3
    return { passed = passed, commandRisk = twin.v10.commandRisk, clotStability = twin.circulation.clotStability, acidBase = twin.bloodGas.acidBase, projectedRisk = prediction.projectedRisk, steps = #bundle.steps }
end)

AddEventHandler(DPN_MED.Events.StateChanged, function(target, eventType, data)
    target = tonumber(target)
    local state = stateFor(target)
    if not state then return end
    DPN_MED.CalculateV10Metrics(state)
    record(target, eventType or 'state_changed', data or { commandRisk = state.v10.commandRisk }, 'dpn-medical-core')
    if state.v10.commandRisk >= 88 then
        pcall(function() exports['dpn-medical-core']:RaiseSafetyAlert(target, 'v10_imminent_failure', 'critical', 'Critical-command engine predicts imminent physiologic failure.', { commandRisk = state.v10.commandRisk, arrestMinutes = state.v10.predictedArrestMinutes, careGaps = state.v10.careGapCount }, 'dpn-medical-core-v10') end)
    end
end)

CreateThread(function()
    Wait(4600)
    print('[dpn-medical-core] v10.0.0 critical-care command, closed-loop safety and clinical black box active')
end)

RegisterCommand('medv10', function(src, args)
    local target = tonumber(args[1] or src)
    local twin = exports['dpn-medical-core']:GetV10Twin(target)
    local message = twin and ('Command risk %s%% | Arrest %s min | ICU need %s%% | Clot %s%% | ABG %s | Gaps %s'):format(twin.v10.commandRisk, twin.v10.predictedArrestMinutes, twin.v10.predictedICUNeed, twin.circulation.clotStability, twin.bloodGas.acidBase, twin.v10.careGapCount) or 'Patient unavailable.'
    if src == 0 then print(message) else TriggerClientEvent('chat:addMessage', src, { args = { 'DPN Medical v10', message } }) end
end, false)

RegisterNetEvent('dpn-medical-core:server:requestV10Snapshot', function()
    local src = source
    local twin = exports['dpn-medical-core']:GetV10Twin(src)
    TriggerClientEvent('dpn-medical-core:client:v10Snapshot', src, twin)
    TriggerClientEvent('dpn-medical-core:client:v10Summary', src, twin and ('Risk %s%% | %s | Arrest %s min'):format(twin.v10.commandRisk, twin.v10.trajectoryClass, twin.v10.predictedArrestMinutes) or 'No medical state available.')
end)
