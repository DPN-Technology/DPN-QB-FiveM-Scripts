local VERSION = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'unknown'
local protocols, sessions, trends, transactions, circuitBreakers = {}, {}, {}, {}, {}

local function now() return os.time() end
local function uid(prefix, target) return ('%s-%s-%s-%04d'):format(prefix, now(), tostring(target or 0), math.random(0, 9999)) end
local function encode(value) local ok, data = pcall(json.encode, value); return ok and data or '{}' end
local function player(target)
    local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if not ok or not core or not core.Functions then return nil end
    local got, value = pcall(function() return core.Functions.GetPlayer(tonumber(target)) end)
    return got and value or nil
end
local function cid(target)
    local p = player(target)
    return p and p.PlayerData and p.PlayerData.citizenid or ('source:%s'):format(tostring(target))
end
local function stateFor(target)
    if not DPNMedicalServer or not DPNMedicalServer.EnsureState then return nil end
    return DPNMedicalServer.EnsureState(tonumber(target))
end
local function commit(target, state, eventType, data)
    if not DPNMedicalServer or not DPNMedicalServer.EnsureState or not DPNMedicalServer.Commit then return false end
    local _, patientCid = DPNMedicalServer.EnsureState(tonumber(target))
    if not patientCid then return false end
    DPNMedicalServer.Commit(tonumber(target), patientCid, state, eventType, data or {})
    return true
end
local function persist(sql, params, update)
    CreateThread(function()
        pcall(function()
            if update then MySQL.update.await(sql, params) else MySQL.insert.await(sql, params) end
        end)
    end)
end
local function countRows(value)
    local n = 0
    for _ in pairs(type(value) == 'table' and value or {}) do n = n + 1 end
    return n
end
local function recordTrend(target, state, source)
    target = tonumber(target)
    if not target or not state then return nil end
    local point = DPN_MED.BuildV12TrendPoint(state)
    point.id = uid('TREND12', target)
    point.target = target
    point.patientCid = cid(target)
    point.source = tostring(source or 'state_change')
    trends[target] = trends[target] or {}
    table.insert(trends[target], 1, point)
    while #trends[target] > 240 do table.remove(trends[target]) end
    persist('INSERT INTO dpn_medical_v12_trends (trend_id,patient_cid,source_module,trend_data) VALUES (?,?,?,?)', {
        point.id, point.patientCid, point.source, encode(point)
    })
    return point
end
local function moduleState(resource)
    local state = GetResourceState(resource)
    local breaker = circuitBreakers[resource]
    return {
        resource = resource, state = state, available = state == 'started' and not (breaker and breaker.open),
        breakerOpen = breaker and breaker.open == true or false,
        failures = breaker and breaker.failures or 0,
        lastFailure = breaker and breaker.lastFailure or nil,
        retryAt = breaker and breaker.retryAt or nil,
        version = GetResourceMetadata(resource, 'version', 0)
    }
end
local function noteModuleResult(resource, ok, detail)
    circuitBreakers[resource] = circuitBreakers[resource] or { failures = 0, open = false }
    local breaker = circuitBreakers[resource]
    if ok then
        breaker.failures = math.max(0, (breaker.failures or 0) - 1)
        if breaker.failures == 0 then breaker.open = false; breaker.retryAt = nil end
    else
        breaker.failures = (breaker.failures or 0) + 1
        breaker.lastFailure = tostring(detail or 'unknown failure')
        breaker.lastFailureAt = now()
        if breaker.failures >= 3 then
            breaker.open = true
            breaker.retryAt = now() + math.min(300, breaker.failures * 30)
        end
    end
    return breaker
end

exports('GetV12Twin', function(target)
    local state = stateFor(target)
    return state and DPN_MED.BuildV12Twin(state) or nil
end)

exports('GetV12ReferenceRanges', function(target)
    local state = stateFor(target)
    if not state then return false, 'Patient not found.' end
    state = DPN_MED.CalculateV12Metrics(state)
    return true, state.populationModelV12
end)

exports('CreateIntegratedProtocolV12', function(target, requestedProtocol, author)
    target = tonumber(target)
    local state = stateFor(target)
    if not state then return false, 'Patient not found.' end
    local plan = DPN_MED.BuildIntegratedProtocolV12(state, requestedProtocol)
    plan.id = uid('PROTO12', target)
    plan.target = target
    plan.patientCid = cid(target)
    plan.author = tostring(author or 'system')
    protocols[target] = protocols[target] or {}
    protocols[target][plan.id] = plan
    state.protocolPlansV12[plan.id] = plan
    commit(target, state, 'v12_protocol_created', { planId = plan.id, steps = #plan.steps, protocol = plan.protocol })
    persist('INSERT INTO dpn_medical_v12_protocols (protocol_id,patient_cid,protocol_type,status,risk_score,protocol_data,created_by) VALUES (?,?,?,?,?,?,?)', {
        plan.id, plan.patientCid, plan.protocol, plan.status, plan.integratedRisk, encode(plan), plan.author
    })
    TriggerEvent('dpn-medical:server:v12ProtocolCreated', plan)
    return plan.id, plan
end)

exports('ApproveIntegratedProtocolV12', function(target, planId, approver)
    target = tonumber(target)
    local plan = protocols[target] and protocols[target][tostring(planId)]
    if not plan then return false, 'V12 protocol not found.' end
    plan.status = 'approved'
    plan.approvedBy = tostring(approver or 'system')
    plan.approvedAt = now()
    for _, step in ipairs(plan.steps or {}) do
        if step.status == 'awaiting_approval' then step.status = 'planned'; step.approvedBy = plan.approvedBy end
    end
    persist('UPDATE dpn_medical_v12_protocols SET status=?,protocol_data=?,approved_by=?,updated_at=NOW() WHERE protocol_id=?', {
        plan.status, encode(plan), plan.approvedBy, plan.id
    }, true)
    return true, plan
end)

exports('CompleteIntegratedProtocolStepV12', function(target, planId, stepId, actor, evidence)
    target = tonumber(target)
    local plan = protocols[target] and protocols[target][tostring(planId)]
    if not plan then return false, 'V12 protocol not found.' end
    local selected
    for _, step in ipairs(plan.steps or {}) do if step.id == tostring(stepId) then selected = step break end end
    if not selected then return false, 'V12 protocol step not found.' end
    if selected.requiresHumanApproval and plan.status ~= 'approved' then return false, 'Protocol requires human approval.' end
    selected.status = 'complete'
    selected.completedBy = tostring(actor or 'system')
    selected.completedAt = now()
    selected.evidence = evidence
    local complete = true
    for _, step in ipairs(plan.steps or {}) do if step.status ~= 'complete' then complete = false break end end
    if complete then plan.status = 'complete'; plan.completedAt = now() else plan.status = 'active' end
    persist('UPDATE dpn_medical_v12_protocols SET status=?,protocol_data=?,updated_at=NOW() WHERE protocol_id=?', {
        plan.status, encode(plan), plan.id
    }, true)
    return true, plan
end)

exports('GetIntegratedProtocolsV12', function(target)
    return protocols[tonumber(target)] or {}
end)

exports('StartCriticalCareSessionV12', function(target, intervalSeconds, actor)
    target = tonumber(target)
    local state = stateFor(target)
    if not state then return false, 'Patient not found.' end
    intervalSeconds = math.max(5, math.min(300, tonumber(intervalSeconds) or 15))
    local item = {
        id = uid('CCS12', target), target = target, patientCid = cid(target), intervalSeconds = intervalSeconds,
        actor = tostring(actor or 'system'), status = 'active', runs = 0, alerts = 0,
        startedAt = now(), nextRunAt = now(), lastRisk = state.v12 and state.v12.integratedRisk or 0
    }
    sessions[target] = item
    persist('INSERT INTO dpn_medical_v12_sessions (session_id,patient_cid,status,interval_seconds,session_data,started_by) VALUES (?,?,?,?,?,?)', {
        item.id, item.patientCid, item.status, item.intervalSeconds, encode(item), item.actor
    })
    recordTrend(target, state, 'critical_care_session_start')
    return true, item
end)

exports('StopCriticalCareSessionV12', function(target, actor)
    target = tonumber(target)
    local item = sessions[target]
    if not item then return false, 'No active v12 critical-care session.' end
    item.status = 'stopped'; item.stoppedBy = tostring(actor or 'system'); item.stoppedAt = now()
    persist('UPDATE dpn_medical_v12_sessions SET status=?,session_data=?,updated_at=NOW() WHERE session_id=?', {
        item.status, encode(item), item.id
    }, true)
    sessions[target] = nil
    return true, item
end)

exports('RecordV12Observation', function(target, observationType, value, unit, actor, metadata)
    target = tonumber(target)
    local state = stateFor(target)
    if not state then return false, 'Patient not found.' end
    state.observationsV12 = type(state.observationsV12) == 'table' and state.observationsV12 or {}
    local item = {
        id = uid('OBS12', target), type = tostring(observationType or 'observation'), value = value,
        unit = unit, actor = tostring(actor or 'system'), metadata = type(metadata) == 'table' and metadata or {}, at = now()
    }
    table.insert(state.observationsV12, 1, item)
    while #state.observationsV12 > 300 do table.remove(state.observationsV12) end
    state.lastObservationAt = item.at
    DPN_MED.CalculateV12Metrics(state)
    commit(target, state, 'v12_observation', item)
    persist('INSERT INTO dpn_medical_v12_observations (observation_id,patient_cid,observation_type,observation_value,observation_unit,observation_data,recorded_by) VALUES (?,?,?,?,?,?,?)', {
        item.id, cid(target), item.type, tostring(item.value or ''), tostring(item.unit or ''), encode(item), item.actor
    })
    return true, item
end)

exports('GetV12Trend', function(target, limit)
    local rows, output = trends[tonumber(target)] or {}, {}
    limit = math.max(1, math.min(240, tonumber(limit) or 60))
    for index = 1, math.min(limit, #rows) do output[index] = rows[index] end
    return output
end)

exports('EvaluateOrganSupportV12', function(target)
    local state = stateFor(target)
    if not state then return false, 'Patient not found.' end
    state = DPN_MED.CalculateV12Metrics(state)
    return true, {
        target = tonumber(target), patientCid = cid(target), population = state.populationModelV12,
        cardiovascular = state.cardiovascularModelV12, ventilation = state.ventilationModelV12,
        organSupport = state.organSupportModelV12, risk = state.v12.integratedRisk,
        destination = state.v12.recommendedDestination, recommendations = state.v12Recommendations,
        generatedAt = now()
    }
end)

exports('CreateNetworkTransactionV12', function(target, transactionType, sourceResource, destinationResource, payload, actor)
    target = tonumber(target)
    local item = {
        id = uid('NET12', target), target = target, patientCid = cid(target), type = tostring(transactionType or 'clinical_event'),
        sourceResource = tostring(sourceResource or 'unknown'), destinationResource = tostring(destinationResource or 'broadcast'),
        payload = type(payload) == 'table' and payload or {}, actor = tostring(actor or 'system'),
        status = 'pending', attempts = 0, createdAt = now()
    }
    transactions[item.id] = item
    persist('INSERT INTO dpn_medical_v12_network_transactions (transaction_id,patient_cid,transaction_type,source_resource,destination_resource,status,transaction_data) VALUES (?,?,?,?,?,?,?)', {
        item.id, item.patientCid, item.type, item.sourceResource, item.destinationResource, item.status, encode(item)
    })
    TriggerEvent('dpn-medical:server:v12NetworkTransaction', item)
    return item.id, item
end)

exports('AcknowledgeNetworkTransactionV12', function(transactionId, resource, success, detail)
    local item = transactions[tostring(transactionId)]
    if not item then return false, 'V12 network transaction not found.' end
    item.attempts = (item.attempts or 0) + 1
    item.status = success == true and 'acknowledged' or 'failed'
    item.acknowledgedBy = tostring(resource or 'unknown')
    item.detail = detail
    item.updatedAt = now()
    noteModuleResult(item.acknowledgedBy, success == true, detail)
    persist('UPDATE dpn_medical_v12_network_transactions SET status=?,attempts=?,transaction_data=?,updated_at=NOW() WHERE transaction_id=?', {
        item.status, item.attempts, encode(item), item.id
    }, true)
    return true, item
end)

exports('ReconcileMedicalNetworkV12', function(target, actor)
    target = tonumber(target)
    local required = {
        'dpn-medical-core','dpn-medical-ems','dpn-medical-hospital','dpn-medical-surgery','dpn-medical-radiology',
        'dpn-medical-pharmacy','dpn-medical-records','dpn-medical-coroner','dpn-medical-insurance','dpn-medical-training',
        'dpn-medical-disease','dpn-medical-ambulance','dpn-medical-ai','dpn-medical-dispatch','dpn-medical-icu',
        'dpn-medical-rehab','dpn-medical-lifepak','dpn-medical-inventory','dpn-medical-billing-plus','dpn-medical-admin-tools'
    }
    local modules, unavailable = {}, {}
    for _, resource in ipairs(required) do
        local row = moduleState(resource)
        modules[#modules + 1] = row
        if not row.available then unavailable[#unavailable + 1] = resource end
    end
    local state = target and stateFor(target) or nil
    local report = {
        id = uid('RECON12', target), target = target, patientCid = target and cid(target) or nil,
        actor = tostring(actor or 'system'), modules = modules, unavailable = unavailable,
        activeSessions = countRows(sessions), pendingTransactions = 0, failedTransactions = 0,
        dataConfidence = state and DPN_MED.CalculateV12Metrics(state).dataQualityV12.confidence or nil,
        createdAt = now()
    }
    for _, item in pairs(transactions) do
        if item.status == 'pending' then report.pendingTransactions = report.pendingTransactions + 1 end
        if item.status == 'failed' then report.failedTransactions = report.failedTransactions + 1 end
    end
    persist('INSERT INTO dpn_medical_v12_reconciliations (reconciliation_id,patient_cid,status,reconciliation_data,created_by) VALUES (?,?,?,?,?)', {
        report.id, report.patientCid, #unavailable == 0 and 'healthy' or 'degraded', encode(report), report.actor
    })
    return #unavailable == 0, report
end)

exports('GetV12OperationalDashboard', function()
    local patients, critical, special, supportCandidates, lowConfidence = {}, 0, 0, 0, 0
    for _, sid in ipairs(GetPlayers() or {}) do
        local target = tonumber(sid)
        local state = stateFor(target)
        if state then
            local twin = DPN_MED.BuildV12Twin(state)
            if twin.v12.integratedRisk >= 70 then critical = critical + 1 end
            if #(twin.populationV12.specialPopulations or {}) > 0 then special = special + 1 end
            if #(twin.organSupportV12.recommendedSupports or {}) > 0 then supportCandidates = supportCandidates + 1 end
            if twin.dataQualityV12.confidence < 60 then lowConfidence = lowConfidence + 1 end
            patients[#patients + 1] = {
                id = target, citizenid = cid(target), twin = twin,
                activeSession = sessions[target] ~= nil,
                protocolCount = countRows(protocols[target] or {}), trendPoints = #(trends[target] or {})
            }
        end
    end
    table.sort(patients, function(a, b) return (a.twin.v12.integratedRisk or 0) > (b.twin.v12.integratedRisk or 0) end)
    local pending, failed = 0, 0
    for _, item in pairs(transactions) do
        if item.status == 'pending' then pending = pending + 1 elseif item.status == 'failed' then failed = failed + 1 end
    end
    return {
        version = VERSION, generatedAt = now(), patients = patients, critical = critical,
        specialPopulationPatients = special, organSupportCandidates = supportCandidates,
        lowConfidencePatients = lowConfidence, activeSessions = countRows(sessions),
        pendingTransactions = pending, failedTransactions = failed, circuitBreakers = circuitBreakers
    }
end)

exports('RunV12SelfTest', function()
    local shared = DPN_MED.RunV12SharedSelfTest()
    local passed = shared and shared.passed == true
    return {
        passed = passed, shared = shared, version = VERSION,
        exports = {
            'GetV12Twin','CreateIntegratedProtocolV12','StartCriticalCareSessionV12','RecordV12Observation',
            'EvaluateOrganSupportV12','CreateNetworkTransactionV12','ReconcileMedicalNetworkV12','GetV12OperationalDashboard'
        }
    }
end)

AddEventHandler(DPN_MED.Events.StateChanged, function(target, patientCid, changedState, eventType, data)
    target = tonumber(target)
    local state = type(changedState) == 'table' and changedState or stateFor(target)
    if not state then return end
    DPN_MED.CalculateV12Metrics(state)
    recordTrend(target, state, eventType or 'state_changed')
    if state.v12.integratedRisk >= 88 then
        pcall(function()
            exports['dpn-medical-core']:RaiseSafetyAlert(target, 'v12_integrated_critical', 'critical',
                'V12 integrated model predicts immediate critical-care escalation.', {
                    risk = state.v12.integratedRisk, commandLevel = state.v12.commandLevel,
                    destination = state.v12.recommendedDestination,
                    supports = state.organSupportModelV12.recommendedSupports
                }, 'dpn-medical-core-v12')
        end)
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        local stamp = now()
        for target, item in pairs(sessions) do
            if item.status == 'active' and stamp >= (item.nextRunAt or 0) then
                local state = stateFor(target)
                if not state then
                    sessions[target] = nil
                else
                    local before = tonumber(state.v12 and state.v12.integratedRisk) or 0
                    DPN_MED.CalculateV12Metrics(state)
                    local after = state.v12.integratedRisk
                    item.runs = (item.runs or 0) + 1
                    item.lastRisk = after
                    item.nextRunAt = stamp + item.intervalSeconds
                    recordTrend(target, state, 'critical_care_session')
                    if after >= 85 and before < 85 then
                        item.alerts = (item.alerts or 0) + 1
                        pcall(function()
                            exports['dpn-medical-core']:RaiseSafetyAlert(target, 'v12_session_escalation', 'critical',
                                'V12 critical-care session detected escalation.', { before = before, after = after }, 'dpn-medical-core-v12')
                        end)
                    end
                    persist('UPDATE dpn_medical_v12_sessions SET session_data=?,updated_at=NOW() WHERE session_id=?', { encode(item), item.id }, true)
                end
            end
        end
        for resource, breaker in pairs(circuitBreakers) do
            if breaker.open and breaker.retryAt and stamp >= breaker.retryAt and GetResourceState(resource) == 'started' then
                breaker.open = false; breaker.failures = math.max(0, (breaker.failures or 0) - 1); breaker.retryAt = nil
            end
        end
    end
end)

CreateThread(function()
    Wait(5200)
    print('[dpn-medical-core] v12.0.0 integrated critical-care, special populations and network resilience active')
end)

RegisterCommand('medv12', function(src, args)
    local target = tonumber(args[1] or src)
    local twin = exports['dpn-medical-core']:GetV12Twin(target)
    local message = twin and ('V12 risk %s%% | %s | %s | population %s | confidence %s%% | supports %s'):format(
        twin.v12.integratedRisk, twin.v12.commandLevel, twin.v12.recommendedDestination,
        twin.populationV12.group, twin.dataQualityV12.confidence,
        table.concat(twin.organSupportV12.recommendedSupports or {}, ', ')
    ) or 'Patient unavailable.'
    if src == 0 then print(message) else TriggerClientEvent('chat:addMessage', src, { args = { 'DPN Medical v12', message } }) end
end, false)

RegisterCommand('medv12test', function(src)
    local report = exports['dpn-medical-core']:RunV12SelfTest()
    local shared = report.shared or {}
    local message = ('V12 self-test passed=%s adultRisk=%s pediatricRisk=%s ECMO=%s CRRT=%s steps=%s'):format(
        tostring(report.passed), tostring(shared.adultRisk), tostring(shared.pediatricRisk),
        tostring(shared.adultECMONeed), tostring(shared.adultCRRTNeed), tostring(shared.protocolSteps)
    )
    if src == 0 then print(message) else TriggerClientEvent('chat:addMessage', src, { args = { 'DPN Medical v12', message } }) end
end, false)

RegisterNetEvent('dpn-medical-core:server:requestV12Snapshot', function()
    local src = source
    local twin = exports['dpn-medical-core']:GetV12Twin(src)
    TriggerClientEvent('dpn-medical-core:client:v12Snapshot', src, twin)
    TriggerClientEvent('dpn-medical-core:client:v12Summary', src, twin and ('Risk %s%% | %s | %s | Confidence %s%%'):format(
        twin.v12.integratedRisk, twin.v12.commandLevel, twin.v12.recommendedDestination, twin.dataQualityV12.confidence
    ) or 'No medical state available.')
end)
