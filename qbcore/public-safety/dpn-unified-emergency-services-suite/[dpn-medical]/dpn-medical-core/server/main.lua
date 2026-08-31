local QBCore = exports['qb-core']:GetCoreObject()

MedicalStates = MedicalStates or {}
DPNMedicalServer = DPNMedicalServer or {}
local loaded, dirty, sourceCitizen = {}, {}, {}
local damageCooldowns, treatmentCooldowns = {}, {}
local moduleRegistry = {}

local function nowMs() return GetGameTimer() end
local function getPlayer(src) return QBCore.Functions.GetPlayer(tonumber(src)) end
local function notify(src, message, kind) TriggerClientEvent('QBCore:Notify', src, message, kind or 'primary', 5000) end
local function citizenId(src)
    local player = getPlayer(src)
    if not player then return sourceCitizen[tonumber(src)] end
    local id = player.PlayerData.citizenid
    sourceCitizen[tonumber(src)] = id
    return id
end

local function hasAdminPermission(src)
    return src == 0 or QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
end

local levelOrder = { basic = 1, ems = 2, doctor = 3, surgeon = 4 }
local function isMedicalJob(player, minimum)
    if not player or not player.PlayerData or not player.PlayerData.job then return false end
    local job = player.PlayerData.job
    if Config.Security.requireOnDutyForAdvancedTreatment and minimum ~= 'basic' and job.onduty == false then return false end
    local required = levelOrder[minimum or 'ems'] or 2
    local best = 0
    for level, jobs in pairs(Config.Jobs) do
        if jobs[job.name] then best = math.max(best, levelOrder[level] or 0) end
    end
    return best >= required
end

local function distanceAllowed(a, b, maximum)
    if a == b then return true end
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if pedA <= 0 or pedB <= 0 then return false end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) <= maximum
end

local function ensureState(src)
    src = tonumber(src)
    local id = citizenId(src)
    if not id then return nil end
    if not loaded[id] then
        MedicalStates[id] = DPNMedicalStorage.Load(id)
        loaded[id] = true
    end
    MedicalStates[id] = DPN_MED.NormalizeState(MedicalStates[id])
    return MedicalStates[id], id
end

local function setMetadata(src, state)
    local player = getPlayer(src)
    if not player then return end
    local lifeState = state.status.lifeState or 'alive'
    player.Functions.SetMetaData('isdead', lifeState == 'dead')
    player.Functions.SetMetaData('inlaststand', lifeState == 'incapacitated')
    player.Functions.SetMetaData('dpnmedical', {
        triage = state.status.triage,
        lifeState = lifeState,
        blood = state.vitals.blood,
        admitted = state.status.admitted == true
    })
end

local function sync(src)
    local state = ensureState(src)
    if not state then return false end
    if DPN_MED.GetProtocolRecommendations and state.advanced then state.advanced.protocols = DPN_MED.GetProtocolRecommendations(state) end
    setMetadata(src, state)
    local player = Player(src)
    if player and player.state then
        player.state:set('dpnMedicalLifeState', state.status.lifeState or 'alive', true)
        player.state:set('dpnMedicalTriage', state.status.triage or 'green', true)
    end
    TriggerClientEvent(DPN_MED.Events.SyncState, src, state)
    return true
end

local function commit(src, id, state, eventType, data)
    state = DPN_MED.NormalizeState(state)
    MedicalStates[id] = state
    dirty[id] = true
    sync(src)
    if eventType then DPNMedicalStorage.Log(id, eventType, data or {}) end
    TriggerEvent(DPN_MED.Events.StateChanged, src, id, state, eventType, data or {})
end

local function setLifeState(target, lifeState, details, actor)
    target = tonumber(target)
    local state, id = ensureState(target)
    if not state then return false, 'Patient not found' end
    local previous = state.status.lifeState or 'alive'
    if previous == lifeState then return true, state end
    local changed
    state, changed = DPN_MED.SetLifeState(state, lifeState, details)
    if not changed then return false, 'Invalid life state' end
    commit(target, id, state, 'life_state', { from = previous, to = lifeState, actor = actor, details = details })
    TriggerEvent(DPN_MED.Events.LifeStateChanged, target, id, previous, lifeState, state, details or {})
    TriggerClientEvent('dpn-medical-core:client:lifeState', target, lifeState, details or {})
    return true, state
end

local function resetPatient(target, reason, preserveHistory)
    target = tonumber(target)
    local oldState, id = ensureState(target)
    if not oldState then return false end
    local fresh = DPN_MED.NewBodyState()
    if preserveHistory then
        fresh.treatments = oldState.treatments or {}
        fresh.medications = oldState.medications or {}
    end
    MedicalStates[id] = fresh
    commit(target, id, fresh, 'reset', { reason = reason or 'unknown' })
    return true
end

local function revivePatient(target, options)
    target = tonumber(target)
    options = type(options) == 'table' and options or {}
    local state, id = ensureState(target)
    if not state then return false end
    if options.fullHeal == true then
        state = DPN_MED.NewBodyState()
    else
        state.status.cardiacArrest = false
        state.status.unconscious = false
        state.vitals.hr = math.max(60, tonumber(state.vitals.hr) or 0)
        state.vitals.rr = math.max(10, tonumber(state.vitals.rr) or 0)
        state.vitals.spo2 = math.max(88, tonumber(state.vitals.spo2) or 0)
        state.vitals.systolic = math.max(85, tonumber(state.vitals.systolic) or 0)
        state.vitals.diastolic = math.max(50, tonumber(state.vitals.diastolic) or 0)
        state.vitals.blood = math.max(1800, tonumber(state.vitals.blood) or 0)
        state, _ = DPN_MED.SetLifeState(state, 'alive', { clearArrest = true })
    end
    commit(target, id, state, 'revive', { by = options.by or 'system', fullHeal = options.fullHeal == true })
    TriggerClientEvent(DPN_MED.Events.ReviveClient, target, options)
    TriggerEvent(DPN_MED.Events.LifeStateChanged, target, id, 'dead_or_incapacitated', 'alive', state, options)
    return true
end

DPNMedicalServer.EnsureState = ensureState
DPNMedicalServer.Sync = sync
DPNMedicalServer.Commit = commit
DPNMedicalServer.SetLifeState = setLifeState
DPNMedicalServer.ResetPatient = resetPatient
DPNMedicalServer.RevivePatient = revivePatient
DPNMedicalServer.CitizenId = citizenId
DPNMedicalServer.IsMedicalJob = isMedicalJob
DPNMedicalServer.HasAdminPermission = hasAdminPermission

RegisterNetEvent(DPN_MED.Events.RequestState, function() sync(source) end)

local function processDamage(src, part, injury)
    local current = nowMs()
    if current - (damageCooldowns[src] or 0) < Config.Timing.damageReportCooldownMs then return false end
    damageCooldowns[src] = current
    if not Config.BodyParts[part] or type(injury) ~= 'table' then return false end
    local state, id = ensureState(src)
    if not state or (state.status.lifeState or 'alive') ~= 'alive' then return false end
    local changed
    state, changed = DPN_MED.ApplyInjury(state, part, injury)
    if not changed then return false end
    commit(src, id, state, 'injury', { part = part, injury = DPN_MED.SanitizeInjury(injury) })
    if state.status.cardiacArrest then setLifeState(src, 'incapacitated', { cause = injury.type or 'critical trauma' }, 'medical-core') end
    return true
end

RegisterNetEvent(DPN_MED.Events.ReportDamage, function(part, injury) processDamage(source, part, injury) end)

local function playerHasItem(player, itemName)
    if not itemName then return true end
    return player and player.Functions and player.Functions.GetItemByName and player.Functions.GetItemByName(itemName) ~= nil
end
local function removeItem(player, itemName)
    if not itemName then return true end
    return player and player.Functions and player.Functions.RemoveItem and player.Functions.RemoveItem(itemName, 1)
end

RegisterNetEvent(DPN_MED.Events.TreatPart, function(target, part, treatment)
    local src = source
    target = tonumber(target)
    treatment = type(treatment) == 'table' and treatment or { type = treatment }
    local treatmentType = tostring(treatment.type or '')
    local definition = Config.Treatments[treatmentType]
    if not target or not getPlayer(target) or not definition then return end
    local current = nowMs()
    if current - (treatmentCooldowns[src] or 0) < Config.Timing.treatmentCooldownMs then return end
    treatmentCooldowns[src] = current
    local practitioner = getPlayer(src)
    local selfTreatment = src == target
    local authorized = isMedicalJob(practitioner, definition.level) or hasAdminPermission(src)
        or (selfTreatment and Config.Security.allowSelfBasicTreatment and definition.self == true)
    if not authorized then return notify(src, 'You are not authorized to perform that treatment.', 'error') end
    if not distanceAllowed(src, target, Config.Security.maxTreatmentDistance) then return notify(src, 'Patient is too far away.', 'error') end
    if Config.Security.requireTreatmentItems and definition.item and not playerHasItem(practitioner, definition.item) then
        return notify(src, ('Required item missing: %s'):format(definition.item), 'error')
    end
    local state, id = ensureState(target)
    local practitionerId = citizenId(src) or ('source:%s'):format(src)
    local updated, success, errorMessage = DPN_MED.ApplyTreatment(state, part, treatmentType, practitionerId)
    if not success then return notify(src, errorMessage or 'Treatment failed.', 'error') end
    if Config.Security.requireTreatmentItems and definition.item and not removeItem(practitioner, definition.item) then
        return notify(src, 'Treatment item could not be removed.', 'error')
    end
    commit(target, id, updated, 'treatment', { practitioner = practitionerId, treatment = treatmentType, part = part })
    notify(src, ('%s applied.'):format(definition.label), 'success')
    if src ~= target then notify(target, ('Medical treatment received: %s'):format(definition.label), 'success') end
end)

RegisterNetEvent(DPN_MED.Events.EnterIncapacitated, function(details)
    local src = source
    local state = ensureState(src)
    if not state or (state.status.lifeState or 'alive') ~= 'alive' then return end
    details = type(details) == 'table' and details or {}
    setLifeState(src, 'incapacitated', { cause = tostring(details.cause or 'Traumatic injury'):sub(1, 128), time = os.time() }, src)
end)

RegisterNetEvent(DPN_MED.Events.RequestDeath, function(details)
    local src = source
    local state = ensureState(src)
    if not state or state.status.lifeState ~= 'incapacitated' then return end
    setLifeState(src, 'dead', { cause = tostring((details and details.cause) or state.status.causeOfDeath or 'Injuries sustained'):sub(1, 128), time = os.time() }, src)
end)

RegisterNetEvent(DPN_MED.Events.RequestRespawn, function()
    local src = source
    local state = ensureState(src)
    if not state or state.status.lifeState ~= 'dead' then return end
    local diedAt = tonumber(state.status.diedAt) or os.time()
    if os.time() - diedAt < Config.Lifecycle.deadRespawnDelaySeconds then return end
    local handled = false
    if GetResourceState('dpn-medical-hospital') == 'started' then
        local ok, result = pcall(function()
            return exports['dpn-medical-hospital']:EmergencyRespawn(src, 'Medical respawn')
        end)
        handled = ok and result == true
    end
    if not handled then
        if Config.Lifecycle.clearInjuriesOnHospitalRespawn then resetPatient(src, 'default-respawn', true) end
        local c = Config.Lifecycle.defaultRespawn
        TriggerClientEvent(DPN_MED.Events.RespawnClient, src, { x = c.x, y = c.y, z = c.z, w = c.w })
        setLifeState(src, 'alive', { clearArrest = true }, 'default-respawn')
    end
end)

QBCore.Functions.CreateCallback('dpn-medical-core:server:getPatientState', function(src, cb, target)
    target = tonumber(target) or src
    if target ~= src then
        if not isMedicalJob(getPlayer(src), 'ems') and not hasAdminPermission(src) then return cb(nil, 'Not authorized') end
        if not distanceAllowed(src, target, Config.Security.maxInspectDistance) then return cb(nil, 'Patient is too far away') end
    end
    local state = ensureState(target)
    if state and DPN_MED.GetProtocolRecommendations and state.advanced then state.advanced.protocols = DPN_MED.GetProtocolRecommendations(state) end
    cb(state, state and nil or 'Patient not found')
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player and player.PlayerData and player.PlayerData.source
    if src then ensureState(src); sync(src) end
end)

local function saveAndReleaseSource(src)
    src = tonumber(src)
    local id = sourceCitizen[src] or citizenId(src)
    if id and MedicalStates[id] then DPNMedicalStorage.Save(id, MedicalStates[id]) end
    sourceCitizen[src], damageCooldowns[src], treatmentCooldowns[src] = nil, nil, nil
end
AddEventHandler('playerDropped', function() saveAndReleaseSource(source) end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) saveAndReleaseSource(src or source) end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id, state in pairs(MedicalStates) do DPNMedicalStorage.Save(id, state) end
end)

CreateThread(function()
    Wait(1000)
    moduleRegistry['dpn-medical-core'] = { name='dpn-medical-core', version='6.0.0', capabilities={'injuries','vitals','lifecycle','death','revive','persistence','module_registry'}, registeredAt=os.time() }
    print('[dpn-medical-core] v6.0.0 advanced medical platform base active')
    pcall(function()
        MySQL.insert('INSERT INTO dpn_medical_modules (resource_name, version, capabilities, last_seen) VALUES (?, ?, ?, NOW()) ON DUPLICATE KEY UPDATE version=VALUES(version), capabilities=VALUES(capabilities), last_seen=NOW()', {'dpn-medical-core','5.0.0',json.encode(moduleRegistry['dpn-medical-core'].capabilities)})
    end)
    Wait(500)
    for _, sourceId in ipairs(GetPlayers()) do ensureState(tonumber(sourceId)); sync(tonumber(sourceId)) end
end)

CreateThread(function()
    while true do
        Wait(Config.Timing.decayTickMs)
        for _, sourceId in ipairs(GetPlayers()) do
            local src = tonumber(sourceId)
            local state, id = ensureState(src)
            if state and (state.status.lifeState or 'alive') ~= 'dead' then
                local before = DPN_MED.GetSummary(state)
                state = DPN_MED.DecayState(state)
                local after = DPN_MED.GetSummary(state)
                MedicalStates[id] = state
                if before.blood ~= after.blood or before.triage ~= after.triage or before.cardiacArrest ~= after.cardiacArrest then
                    commit(src, id, state, 'decay', { before = before, after = after })
                end
                if state.status.cardiacArrest and state.status.lifeState == 'alive' then
                    setLifeState(src, 'incapacitated', { cause = 'Cardiac arrest' }, 'medical-core')
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait((Config.Persistence.saveIntervalMinutes or 3) * 60000)
        for id in pairs(dirty) do
            if MedicalStates[id] and DPNMedicalStorage.Save(id, MedicalStates[id]) then dirty[id] = nil end
        end
    end
end)

exports('GetPatientState', function(sourceId) local state=ensureState(tonumber(sourceId)); if state and DPN_MED.GetProtocolRecommendations and state.advanced then state.advanced.protocols=DPN_MED.GetProtocolRecommendations(state) end; return state end)
exports('GetPatientStateByCitizenId', function(id)
    if not id then return nil end
    if not loaded[id] then MedicalStates[id] = DPNMedicalStorage.Load(id); loaded[id] = true end
    return MedicalStates[id]
end)
exports('GetPatientSummary', function(sourceId)
    local state = ensureState(tonumber(sourceId)); return state and DPN_MED.GetSummary(state) or nil
end)
exports('ApplyInjury', function(sourceId, part, injury) return processDamage(tonumber(sourceId), part, injury) end)
exports('TreatPatient', function(sourceId, part, treatmentType, practitioner)
    sourceId = tonumber(sourceId)
    local state, id = ensureState(sourceId)
    if not state then return false end
    local updated, success = DPN_MED.ApplyTreatment(state, part, treatmentType, practitioner or 'export')
    if success then commit(sourceId, id, updated, 'treatment_export', { part = part, treatment = treatmentType, practitioner = practitioner }) end
    return success
end)
exports('SetLifeState', function(sourceId, lifeState, details) return setLifeState(sourceId, lifeState, details, 'export') end)
exports('RevivePatient', function(sourceId, options) return revivePatient(sourceId, options) end)
exports('ResetPatient', function(sourceId, reason) return resetPatient(sourceId, reason or 'export', true) end)
exports('AddCondition', function(sourceId, conditionId, data)
    local state, id = ensureState(tonumber(sourceId)); if not state then return false end
    local updated, ok = DPN_MED.AddCondition(state, conditionId, data)
    if ok then commit(tonumber(sourceId), id, updated, 'condition_added', { condition = conditionId, data = data }) end
    return ok
end)
exports('RemoveCondition', function(sourceId, conditionId)
    local state, id = ensureState(tonumber(sourceId)); if not state then return false end
    local updated, ok = DPN_MED.RemoveCondition(state, conditionId)
    if ok then commit(tonumber(sourceId), id, updated, 'condition_removed', { condition = conditionId }) end
    return ok
end)
exports('AddMedication', function(sourceId, medicationId, data)
    local state, id = ensureState(tonumber(sourceId)); if not state then return false end
    local updated, ok = DPN_MED.AddMedication(state, medicationId, data)
    if ok then commit(tonumber(sourceId), id, updated, 'medication', { medication = medicationId, data = data }) end
    return ok
end)
exports('SetDiagnostic', function(sourceId, diagnosticId, data)
    local state, id = ensureState(tonumber(sourceId)); if not state then return false end
    local updated, ok = DPN_MED.SetDiagnostic(state, diagnosticId, data)
    if ok then commit(tonumber(sourceId), id, updated, 'diagnostic', { diagnostic = diagnosticId, data = data }) end
    return ok
end)
exports('SetFlag', function(sourceId, key, value)
    local state, id = ensureState(tonumber(sourceId)); if not state then return false end
    key = tostring(key or ''):sub(1, 64); if key == '' then return false end
    state.flags[key] = value; commit(tonumber(sourceId), id, state, 'flag', { key = key, value = value }); return true
end)
exports('RegisterModule', function(name, version, capabilities)
    name = tostring(name or ''):sub(1, 64); if name == '' then return false end
    moduleRegistry[name] = { name = name, version = tostring(version or 'unknown'), capabilities = capabilities or {}, registeredAt = os.time() }
    MySQL.insert('INSERT INTO dpn_medical_modules (resource_name, version, capabilities, last_seen) VALUES (?, ?, ?, NOW()) ON DUPLICATE KEY UPDATE version=VALUES(version), capabilities=VALUES(capabilities), last_seen=NOW()', { name, tostring(version or 'unknown'), json.encode(capabilities or {}) })
    print(('[dpn-medical-core] Registered module %s v%s'):format(name, tostring(version or 'unknown')))
    return true
end)
exports('GetModules', function() return moduleRegistry end)
exports('IsMedicalJob', function(sourceId, level) return isMedicalJob(getPlayer(sourceId), level or 'ems') end)
exports('EmitIntegration', function(name, payload)
    TriggerEvent(DPN_MED.Events.Integration, tostring(name or 'unknown'), payload or {})
    return true
end)
