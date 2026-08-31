local QBCore
local openMenus = {}
local actionCooldowns = {}
local memoryAudit = {}

local function log(message)
    print(('[dpn-medical-admin-tools] %s'):format(tostring(message)))
end

local function debugLog(message)
    if Config.Debug then log(message) end
end

local function getCore()
    if QBCore then return QBCore end
    local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok then QBCore = core end
    return QBCore
end

local function getPlayer(src)
    local core = getCore()
    if not core or not core.Functions or not core.Functions.GetPlayer then return nil end
    local ok, player = pcall(function() return core.Functions.GetPlayer(tonumber(src)) end)
    return ok and player or nil
end

local function contains(list, value)
    value = tostring(value or '')
    for key, item in pairs(list or {}) do
        if tostring(item) == value or (tostring(key) == value and item == true) then return true end
    end
    return false
end

local function getLicense(src)
    for _, identifier in ipairs(GetPlayerIdentifiers(src) or {}) do
        if identifier:sub(1, 8) == 'license:' then return identifier end
    end
    return nil
end

local function displayName(player, src)
    local pdata = player and player.PlayerData or {}
    local info = type(pdata.charinfo) == 'table' and pdata.charinfo or {}
    local name = (('%s %s'):format(info.firstname or '', info.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or GetPlayerName(tonumber(src)) or ('Player %s'):format(tostring(src))
end

local function hasPermission(src)
    src = tonumber(src) or 0
    if src == 0 then return true, 'console' end
    if Config.AllowEveryone == true then return true, 'config:allow_everyone' end

    for _, ace in ipairs(Config.AcePermissions or {}) do
        local ok, allowed = pcall(IsPlayerAceAllowed, src, ace)
        if ok and allowed then return true, 'ace:' .. tostring(ace) end
    end

    local player = getPlayer(src)
    local pdata = player and player.PlayerData or {}
    if contains(Config.AllowedCitizenIds, pdata.citizenid) then return true, 'citizenid' end
    if contains(Config.AllowedLicenses, getLicense(src)) then return true, 'license' end

    local core = getCore()
    if core and core.Functions then
        for _, permission in ipairs(Config.QBCorePermissions or {}) do
            if core.Functions.HasPermission then
                local ok, allowed = pcall(function() return core.Functions.HasPermission(src, permission) end)
                if ok and allowed then return true, 'qb:' .. permission end
            end
        end
        if core.Functions.GetPermission then
            local ok, permissions = pcall(function() return core.Functions.GetPermission(src) end)
            if ok then
                if type(permissions) == 'string' and contains(Config.QBCorePermissions, permissions) then
                    return true, 'qb:' .. permissions
                elseif type(permissions) == 'table' then
                    for _, permission in ipairs(Config.QBCorePermissions or {}) do
                        if permissions[permission] == true or contains(permissions, permission) then
                            return true, 'qb:' .. permission
                        end
                    end
                end
            end
        end
    end
    return false, 'none'
end

local function coreReady()
    return GetResourceState('dpn-medical-core') == 'started'
end

-- FiveM export proxies are method-style objects. Calling a dynamically looked-up
-- export as fn(...) silently discards the first real argument. That was causing
-- the selected patient server ID to be lost for every medical action.
local function callExport(resourceName, exportName, ...)
    if GetResourceState(resourceName) ~= 'started' then
        return false, nil, ('%s is not started'):format(resourceName)
    end

    local args = table.pack(...)
    local ok, result1, result2, result3 = pcall(function()
        local proxy = exports[resourceName]
        local fn = proxy and proxy[exportName]
        if type(fn) ~= 'function' then
            error(('missing export %s:%s'):format(resourceName, exportName))
        end
        -- Equivalent to exports[resourceName]:ExportName(...), while still
        -- allowing a dynamic export name.
        return fn(proxy, table.unpack(args, 1, args.n))
    end)

    if not ok then
        return false, nil, tostring(result1)
    end
    return true, result1, result2, result3
end

local function callCore(exportName, ...)
    return callExport('dpn-medical-core', exportName, ...)
end

local function callHospital(exportName, ...)
    return callExport((Config.Hospital and Config.Hospital.resource) or 'dpn-medical-hospital', exportName, ...)
end

local function getPatientState(src)
    local ok, state = callCore('GetPatientState', tonumber(src))
    return ok and type(state) == 'table' and state or {}
end

local function getModules()
    local ok, modules = callCore('GetModules')
    return ok and type(modules) == 'table' and modules or {}
end

local function getAdmission(citizenId)
    if not citizenId or GetResourceState((Config.Hospital and Config.Hospital.resource) or 'dpn-medical-hospital') ~= 'started' then
        return nil
    end
    local invoked, admission = callHospital('GetAdmissionByCitizenId', citizenId)
    return invoked and type(admission) == 'table' and admission or nil
end

local function addAudit(src, action, target, details)
    local player = getPlayer(src)
    local actor = player and player.PlayerData and player.PlayerData.citizenid or ('source:%s'):format(src)
    local entry = {
        actor_cid = actor,
        action = tostring(action or 'unknown'):sub(1, 64),
        target = target and tostring(target) or nil,
        details = details or {},
        created_at = os.date('%Y-%m-%d %H:%M:%S')
    }
    table.insert(memoryAudit, 1, entry)
    while #memoryAudit > (tonumber(Config.AuditLimit) or 40) do table.remove(memoryAudit) end

    if MySQL and MySQL.insert and json and json.encode then
        CreateThread(function()
            pcall(function()
                MySQL.insert.await('INSERT INTO dpn_medical_admin_audit (actor_cid, action, target, details) VALUES (?, ?, ?, ?)', {
                    actor, entry.action, entry.target, json.encode(details or {})
                })
            end)
        end)
    end
end

local function recentAudit()
    local rows = {}
    for index = 1, math.min(#memoryAudit, tonumber(Config.AuditLimit) or 40) do
        rows[#rows + 1] = memoryAudit[index]
    end
    return rows
end

local function patientRow(src)
    src = tonumber(src)
    if not src then return nil end
    local player = getPlayer(src)
    local pdata = player and player.PlayerData or {}
    local job = type(pdata.job) == 'table' and pdata.job or {}
    local grade = type(job.grade) == 'table' and job.grade or {}
    local state = getPatientState(src)
    local advancedSnapshot = {}
    do local ok, result = callCore('GetClinicalSnapshot', src); if ok and type(result) == 'table' then advancedSnapshot = result end end
    local v10Twin = {}
    do local ok, result = callCore('GetV10Twin', src); if ok and type(result) == 'table' then v10Twin = result end end
    local v11Twin = {}
    do local ok, result = callCore('GetV11Twin', src); if ok and type(result) == 'table' then v11Twin = result end end
    local v13Twin = {}
    do local ok, result = callCore('GetV13Twin', src); if ok and type(result) == 'table' then v13Twin = result end end
    local status = type(state.status) == 'table' and state.status or {}
    local vitals = type(state.vitals) == 'table' and state.vitals or {}
    local flags = type(state.flags) == 'table' and state.flags or {}
    local admission = getAdmission(pdata.citizenid)

    return {
        id = src,
        name = displayName(player, src),
        citizenid = pdata.citizenid or 'unavailable',
        job = job.label or job.name or 'Unknown',
        jobName = job.name or 'unknown',
        grade = grade.name or grade.level or 0,
        onDuty = job.onduty == true,
        lifeState = status.lifeState or 'alive',
        triage = status.triage or 'green',
        admitted = admission ~= nil or status.admitted == true or flags.admitted == true,
        ward = admission and (admission.ward or admission.bed_type or '') or status.ward or '',
        admissionState = admission and (admission.state or admission.status or 'admitted') or '',
        pain = tonumber(status.pain) or 0,
        shock = tonumber(status.shock) or 0,
        blood = tonumber(vitals.blood) or 5000,
        hr = tonumber(vitals.hr) or 74,
        rr = tonumber(vitals.rr) or 16,
        spo2 = tonumber(vitals.spo2) or 99,
        systolic = tonumber(vitals.systolic) or 120,
        diastolic = tonumber(vitals.diastolic) or 80,
        cardiacArrest = status.cardiacArrest == true,
        unconscious = status.unconscious == true,
        causeOfDeath = status.causeOfDeath or '',
        coreStateAvailable = next(state) ~= nil,
        deterioration = tonumber(advancedSnapshot.deterioration) or 0,
        risk = advancedSnapshot.risk or 'unknown',
        map = tonumber(advancedSnapshot.map) or 0,
        gcs = tonumber(advancedSnapshot.gcs) or 15,
        lactate = tonumber(advancedSnapshot.lactate) or 1.0,
        recommendedCare = advancedSnapshot.recommendedCare or 'routine',
        commandRisk = tonumber(v10Twin.v10 and v10Twin.v10.commandRisk) or 0,
        arrestMinutes = tonumber(v10Twin.v10 and v10Twin.v10.predictedArrestMinutes) or -1,
        icuNeed = tonumber(v10Twin.v10 and v10Twin.v10.predictedICUNeed) or 0,
        clotStability = tonumber(v10Twin.circulation and v10Twin.circulation.clotStability) or 100,
        acidBase = v10Twin.bloodGas and v10Twin.bloodGas.acidBase or 'normal',
        careGaps = tonumber(v10Twin.v10 and v10Twin.v10.careGapCount) or 0,
        autonomousRisk = tonumber(v11Twin.v11 and v11Twin.v11.autonomousRisk) or 0,
        predictedMortality = tonumber(v11Twin.v11 and v11Twin.v11.predictedMortality) or 0,
        homeostasis = tonumber(v11Twin.v11 and v11Twin.v11.homeostasisScore) or 100,
        clinicalPriority = v11Twin.v11 and v11Twin.v11.clinicalPriority or 'routine',
        predictedLevelOfCare = v11Twin.v11 and v11Twin.v11.predictedLevelOfCare or 'self_care',
        tissueOxygenation = tonumber(v11Twin.microcirculation and v11Twin.microcirculation.tissueOxygenation) or 100,
        endocrineRisk = tonumber(v11Twin.endocrine and v11Twin.endocrine.endocrineRisk) or 0,
        infectionProbability = tonumber(v11Twin.infection and v11Twin.infection.probability) or 0,
        resourceIntensity = tonumber(v11Twin.v11 and v11Twin.v11.resourceIntensity) or 0,
        continuumRisk = tonumber(v13Twin.v13 and v13Twin.v13.continuumRisk) or 0,
        continuumDestination = v13Twin.v13 and v13Twin.v13.recommendedDestination or 'unknown',
        resilienceScore = tonumber(v13Twin.v13 and v13Twin.v13.resilienceScore) or 100,
        clotStrengthV13 = tonumber(v13Twin.hemostasisV13 and v13Twin.hemostasisV13.clotStrength) or 100,
        toxicityRiskV13 = tonumber(v13Twin.pharmacologyV13 and v13Twin.pharmacologyV13.toxicityRisk) or 0,
        infectionRiskV13 = tonumber(v13Twin.immuneV13 and v13Twin.immuneV13.infectionProbability) or 0,
        recoveryReserveV13 = tonumber(v13Twin.recoveryV13 and v13Twin.recoveryV13.recoveryReserve) or 100,
        confidenceV13 = tonumber(v13Twin.uncertaintyV13 and v13Twin.uncertaintyV13.confidence) or 0
    }
end

local function patientRows()
    local rows = {}
    for _, value in ipairs(GetPlayers() or {}) do
        local ok, row = pcall(patientRow, tonumber(value))
        if ok and row then rows[#rows + 1] = row end
    end
    table.sort(rows, function(a, b) return (a.id or 0) < (b.id or 0) end)
    return rows
end

local function moduleRows()
    local registry = getModules()
    local rows = {}
    for _, name in ipairs(Config.RequiredModules or {}) do
        local registered = type(registry[name]) == 'table' and registry[name] or nil
        local state = GetResourceState(name) or 'missing'
        rows[#rows + 1] = {
            name = name,
            state = state,
            started = state == 'started',
            registered = registered ~= nil,
            version = registered and registered.version or GetResourceMetadata(name, 'version', 0) or 'unknown',
            capabilities = registered and type(registered.capabilities) == 'table' and registered.capabilities or {}
        }
    end
    return rows
end

local function testScenarioRows()
    local invoked, catalog, detail = callCore('GetTestScenarioCatalog')
    if not invoked or type(catalog) ~= 'table' then
        debugLog(('test catalog unavailable: %s'):format(tostring(detail or catalog)))
        catalog = {}
    end
    catalog[#catalog + 1] = {
        id = 'dispatch_bridge_health', label = 'Dispatch Bridge Health Check', category = 'DISPATCH',
        description = 'Verify DPN medical dispatch, responder routing, and dpn-dispatch-system bridge availability without creating a call.',
        nonDestructive = true
    }
    catalog[#catalog + 1] = {
        id = 'dispatch_pipeline_test', label = 'Create End-to-End EMS Test Call', category = 'DISPATCH',
        description = 'Create an audited priority-3 test call, alert on-duty EMS, generate map routing, and bridge the incident into dpn-dispatch-system.',
        confirm = true
    }
    return catalog
end


local function precisionPayload()
    local invoked, dashboard = callCore('GetV10OperationalDashboard')
    if not invoked or type(dashboard) ~= 'table' then return { version = 'unavailable', patients = {}, critical = 0, imminentArrest = 0, careGaps = 0, activeCommands = 0 }, {} end
    local rows = {}
    for _, item in ipairs(dashboard.patients or {}) do
        local twin = item.twin or {}
        local v10 = twin.v10 or {}
        local circulation = twin.circulation or {}
        rows[#rows + 1] = {
            id = item.id, citizenid = item.citizenid, name = GetPlayerName(tonumber(item.id)) or item.citizenid,
            risk = v10.commandRisk or 0, icuNeed = v10.predictedICUNeed or 0,
            destination = v10.recommendedCommand or 'routine_monitoring',
            minutesToCritical = v10.predictedArrestMinutes, clotStability = circulation.clotStability or 100,
            careGaps = v10.careGapCount or 0, blackBoxEvents = item.blackBoxEvents or 0
        }
    end
    table.sort(rows, function(a,b) return (a.risk or 0) > (b.risk or 0) end)
    return dashboard, rows
end

local function autonomousNetworkPayload()
    local invoked, dashboard = callCore('GetV11NetworkDashboard')
    if not invoked or type(dashboard) ~= 'table' then
        return { version = 'unavailable', patients = {}, immediate = 0, critical = 0, highIntensity = 0, activeReassessments = 0, openPlans = 0 }, {}
    end
    local rows = {}
    for _, item in ipairs(dashboard.patients or {}) do
        local twin = item.twin or {}
        local v11 = twin.v11 or {}
        local micro = twin.microcirculation or {}
        local recovery = twin.recovery or {}
        rows[#rows + 1] = {
            id = item.id, citizenid = item.citizenid, name = GetPlayerName(tonumber(item.id)) or item.citizenid,
            risk = v11.autonomousRisk or 0, mortality = v11.predictedMortality or 0,
            homeostasis = v11.homeostasisScore or 100, priority = v11.clinicalPriority or 'routine',
            levelOfCare = v11.predictedLevelOfCare or 'self_care', resourceIntensity = v11.resourceIntensity or 0,
            tissueOxygenation = micro.tissueOxygenation or 100, frailty = recovery.frailty or 0,
            activePlans = item.activePlanCount or 0, continuousReassessment = item.continuousReassessment == true
        }
    end
    table.sort(rows, function(a, b) return (a.risk or 0) > (b.risk or 0) end)
    return dashboard, rows
end

local function v12NetworkPayload()
    local invoked, dashboard = callCore('GetV12OperationalDashboard')
    if not invoked or type(dashboard) ~= 'table' then
        return { version = 'unavailable', patients = {}, critical = 0, specialPopulationPatients = 0,
            organSupportCandidates = 0, lowConfidencePatients = 0, activeSessions = 0,
            pendingTransactions = 0, failedTransactions = 0 }, {}
    end
    local rows = {}
    for _, item in ipairs(dashboard.patients or {}) do
        local twin = item.twin or {}
        local v12 = twin.v12 or {}
        local population = twin.populationV12 or {}
        local cardio = twin.cardiovascularV12 or {}
        local ventilation = twin.ventilationV12 or {}
        local support = twin.organSupportV12 or {}
        local quality = twin.dataQualityV12 or {}
        rows[#rows + 1] = {
            id = item.id, citizenid = item.citizenid, name = GetPlayerName(tonumber(item.id)) or item.citizenid,
            risk = v12.integratedRisk or 0, commandLevel = v12.commandLevel or 'routine',
            destination = v12.recommendedDestination or 'self_care', decompensationMinutes = v12.decompensationMinutes,
            population = population.group or 'adult', special = population.specialPopulations or {},
            confidence = quality.confidence or 0, cardiacReserve = cardio.cardiacReserve or 0,
            pfRatio = ventilation.pfRatio or 0, supportCount = #(support.recommendedSupports or {}),
            activeSession = item.activeSession == true, protocolCount = item.protocolCount or 0,
            trendPoints = item.trendPoints or 0
        }
    end
    table.sort(rows, function(a, b) return (a.risk or 0) > (b.risk or 0) end)
    return dashboard, rows
end


local function v13ContinuumPayload()
    local invoked, dashboard = callCore('GetV13OperationalDashboard')
    if not invoked or type(dashboard) ~= 'table' then
        return { version='unavailable', patients={}, critical=0, lowConfidence=0, coagulopathy=0, toxicity=0, infection=0, prolongedCare=0 }, {}
    end
    local rows = {}
    for _, item in ipairs(dashboard.patients or {}) do
        local twin=item.twin or{};local v13=twin.v13 or{}
        rows[#rows+1]={id=item.id,citizenid=item.citizenid,name=GetPlayerName(tonumber(item.id))or item.citizenid,risk=v13.continuumRisk or 0,destination=v13.recommendedDestination or'unknown',command=v13.commandLevel or'routine',resilience=v13.resilienceScore or 100,clot=twin.hemostasisV13 and twin.hemostasisV13.clotStrength or 100,toxicity=twin.pharmacologyV13 and twin.pharmacologyV13.toxicityRisk or 0,infection=twin.immuneV13 and twin.immuneV13.infectionProbability or 0,recovery=twin.recoveryV13 and twin.recoveryV13.recoveryReserve or 100,confidence=twin.uncertaintyV13 and twin.uncertaintyV13.confidence or 0,pathwayCount=item.pathwayCount or 0,snapshotCount=item.snapshotCount or 0}
    end
    table.sort(rows,function(a,b)return(a.risk or 0)>(b.risk or 0)end)
    return dashboard,rows
end

local function v14TraumaPayload()
    local invoked,dashboard=callCore('GetV14OperationalDashboard')
    if not invoked or type(dashboard)~='table'then return{version='unavailable',patients={},traumaOne=0,airwayThreat=0,occultBleed=0,compartmentRisk=0,activeMTP=0},{}end
    local rows={}
    for _,item in ipairs(dashboard.patients or{})do local twin=item.twin or{};local v14=twin.v14 or{};rows[#rows+1]={id=item.id,citizenid=item.citizenid,name=GetPlayerName(tonumber(item.id))or item.citizenid,risk=v14.traumaCommandRisk or 0,tier=v14.traumaTier or'none',goldenHour=v14.goldenHourRemaining or 0,destination=v14.recommendedDestination or'unknown',occult=twin.traumaV14 and twin.traumaV14.occultHemorrhageRisk or 0,compartment=twin.traumaV14 and twin.traumaV14.compartmentSyndromeRisk or 0,airway=twin.airwayV14 and twin.airwayV14.airwayProtection or 100,procedure=twin.procedureV14 and twin.procedureV14.readiness or 100,resourceDemand=v14.resourceDemand or 0,activeSession=item.activeSession==true,checklistCount=item.checklistCount or 0}end
    table.sort(rows,function(a,b)return(a.risk or 0)>(b.risk or 0)end);return dashboard,rows
end

local function buildPayload(src)
    local patients = patientRows()
    local modules = moduleRows()
    local stats = {
        players = #patients,
        alive = 0,
        incapacitated = 0,
        dead = 0,
        admitted = 0,
        modulesStarted = 0,
        modulesExpected = #(Config.RequiredModules or {})
    }

    for _, patient in ipairs(patients) do
        if patient.lifeState == 'dead' then
            stats.dead = stats.dead + 1
        elseif patient.lifeState == 'incapacitated' then
            stats.incapacitated = stats.incapacitated + 1
        else
            stats.alive = stats.alive + 1
        end
        if patient.admitted then stats.admitted = stats.admitted + 1 end
    end
    for _, module in ipairs(modules) do
        if module.started then stats.modulesStarted = stats.modulesStarted + 1 end
    end

    local precision, precisionRows = precisionPayload()
    local autonomousNetwork, autonomousRows = autonomousNetworkPayload()
    local v12Network, v12Rows = v12NetworkPayload()
    local v13Network, v13Rows = v13ContinuumPayload()
    local v14Network, v14Rows = v14TraumaPayload()

    return {
        generatedAt = os.time(),
        serverName = GetConvar('sv_projectName', GetConvar('sv_hostname', 'DPN Medical Server')),
        admin = { id = src, name = displayName(getPlayer(src), src) },
        stats = stats,
        patients = patients,
        modules = modules,
        tests = testScenarioRows(),
        precision = precision,
        precisionRows = precisionRows,
        autonomousNetwork = autonomousNetwork,
        autonomousRows = autonomousRows,
        v12Network = v12Network,
        v12Rows = v12Rows,
        v13Network = v13Network,
        v13Rows = v13Rows,
        v14Network = v14Network,
        v14Rows = v14Rows,
        audit = recentAudit(),
        coreOnline = coreReady(),
        notice = 'Native dashboard active. No NUI or browser focus is used.'
    }
end

local function safePayload(src)
    local ok, result = xpcall(function() return buildPayload(src) end, debug.traceback)
    if ok and type(result) == 'table' then return result end
    debugLog(('payload error src=%s: %s'):format(tostring(src), tostring(result)))
    return {
        serverName = GetConvar('sv_hostname', 'DPN Medical Server'),
        admin = { id = src, name = GetPlayerName(src) or ('Player ' .. tostring(src)) },
        stats = { players = 0, alive = 0, incapacitated = 0, dead = 0, admitted = 0, modulesStarted = 0, modulesExpected = #(Config.RequiredModules or {}) },
        patients = {}, modules = {}, tests = testScenarioRows(), precision = {}, precisionRows = {}, autonomousNetwork = {}, autonomousRows = {}, v12Network = {}, v12Rows = {}, v13Network = {}, v13Rows = {}, v14Network = {}, v14Rows = {}, audit = recentAudit(), coreOnline = coreReady(),
        notice = 'Dashboard opened in recovery mode because live medical data returned an error.'
    }
end

local function openFor(src, force)
    src = tonumber(src) or 0
    if src <= 0 or not GetPlayerName(src) then return false end
    local allowed, via
    if force == true then
        allowed, via = true, 'console-bypass'
    else
        allowed, via = hasPermission(src)
    end
    debugLog(('native open request src=%s allowed=%s via=%s'):format(src, tostring(allowed), tostring(via)))
    if not allowed then
        TriggerClientEvent('dpn-medical-admin-tools:client:deniedNative', src,
            'DPN Medical Admin permission denied. Add ACE dpn.medical.admin or QBCore admin/god permission.')
        addAudit(src, 'permission_denied', nil, { via = via })
        return false
    end
    local data = safePayload(src)
    openMenus[src] = true
    TriggerClientEvent('dpn-medical-admin-tools:client:openNative', src, data)
    debugLog(('native open event sent src=%s patients=%s modules=%s'):format(src, #data.patients, #data.modules))
    addAudit(src, 'menu_opened_native', nil, { via = via })
    return true
end

local function targetExists(target)
    target = tonumber(target)
    return target and GetPlayerName(target) ~= nil
end

local function coordsFor(src)
    local ped = GetPlayerPed(tonumber(src))
    if not ped or ped <= 0 then return nil end
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z, h = GetEntityHeading(ped) }
end

local allowedActions = {
    revive = true,
    stabilize = true,
    full_heal = true,
    reset_medical = true,
    heal_injuries = true,
    stop_bleeding = true,
    restore_vitals = true,
    resync = true,
    visual_reset = true,
    hospital_respawn = true,
    admit_er = true,
    admit_icu = true,
    discharge = true,
    digital_twin = true,
    recommended_orders = true,
    generate_handoff = true,
    ack_alerts = true,
    precision_twin = true,
    precision_plan = true,
    simulation_hemorrhage = true,
    simulation_stop = true,
    adaptive_twin = true,
    trajectory_30 = true,
    adaptive_pathway = true,
    safety_reconcile_v9 = true,
    resilience_replay_v9 = true,
    command_twin_v10 = true,
    transition_15_v10 = true,
    closed_loop_bundle_v10 = true,
    activate_command_v10 = true,
    reconcile_modules_v10 = true,
    black_box_v10 = true,
    care_twin_v11 = true,
    forecast_blood_v11 = true,
    autonomous_plan_v11 = true,
    reconcile_devices_v11 = true,
    start_reassessment_v11 = true,
    stop_reassessment_v11 = true,
    waveform_snapshot_v11 = true,
    system_test_v11 = true,
    integrated_twin_v12 = true,
    integrated_protocol_v12 = true,
    start_session_v12 = true,
    stop_session_v12 = true,
    organ_support_v12 = true,
    network_reconcile_v12 = true,
    system_test_v12 = true,
    trauma_twin_v14 = true,
    trauma_clock_v14 = true,
    trauma_activation_v14 = true,
    mtp_v14 = true,
    procedure_checklist_v14 = true,
    destination_compare_v14 = true,
    system_test_v14 = true,
    continuum_twin_v13 = true,
    snapshot_v13 = true,
    pathway_v13 = true,
    simulate_v13 = true,
    reserve_resource_v13 = true,
    incident_v13 = true,
    system_test_v13 = true,
    ['goto'] = true,
    bring = true,
    incapacitate = true,
    mark_dead = true
}

local function exportSucceeded(invoked, result, detail)
    if not invoked then return false, tostring(detail or 'export invocation failed') end
    if result ~= true then
        if type(detail) == 'string' and detail ~= '' then return false, detail end
        return false, 'Medical export returned false.'
    end
    return true
end

local function coreState(target)
    local invoked, state, detail = callCore('GetPatientState', target)
    if not invoked then return nil, detail end
    if type(state) ~= 'table' then return nil, 'Core returned no patient state.' end
    return state
end

local function applyTreatment(target, part, treatment, actor)
    local invoked, result, detail = callCore('TreatPatient', target, part, treatment, actor)
    local ok, err = exportSucceeded(invoked, result, detail)
    if not ok then
        debugLog(('treatment failed target=%s treatment=%s part=%s error=%s'):format(
            tostring(target), tostring(treatment), tostring(part), tostring(err)
        ))
    end
    return ok, err
end

local function restoreVitals(target, actor)
    local applied = 0
    -- Repeat bounded global treatments so critically depleted states are
    -- restored without replacing the patient's injury history.
    for _ = 1, 8 do if applyTreatment(target, nil, 'blood', actor) then applied = applied + 1 end end
    for _ = 1, 4 do if applyTreatment(target, nil, 'iv_fluids', actor) then applied = applied + 1 end end
    for _ = 1, 2 do if applyTreatment(target, nil, 'oxygen', actor) then applied = applied + 1 end end
    if applyTreatment(target, nil, 'epinephrine', actor) then applied = applied + 1 end
    return applied
end

local function stopAllBleeding(target, actor)
    local state, stateError = coreState(target)
    if not state then return false, stateError end
    local treated = 0
    for part, bodyPart in pairs(type(state.body) == 'table' and state.body or {}) do
        if bodyPart.internalBleeding == true then
            if applyTreatment(target, part, 'surgical_repair', actor) then treated = treated + 1 end
        elseif tostring(bodyPart.bleeding or 'none') ~= 'none' then
            if applyTreatment(target, part, part == 'chest' and 'chest_seal' or 'hemostatic_gauze', actor) then
                treated = treated + 1
            end
        end
    end
    restoreVitals(target, actor)
    return true, treated > 0 and ('Stopped bleeding in %s body region(s).'):format(treated) or 'No active bleeding found; vitals restored.'
end

local function healAllInjuries(target, actor)
    local state, stateError = coreState(target)
    if not state then return false, stateError end
    local treated = 0
    for part, bodyPart in pairs(type(state.body) == 'table' and state.body or {}) do
        local organDamage = false
        for _, value in pairs(type(bodyPart.organs) == 'table' and bodyPart.organs or {}) do
            if (tonumber(value) or 0) > 0 then organDamage = true break end
        end
        local damaged = (tonumber(bodyPart.damage) or 0) > 0
            or bodyPart.internalBleeding == true
            or tostring(bodyPart.bleeding or 'none') ~= 'none'
            or tostring(bodyPart.fracture or 'none') ~= 'none'
            or organDamage
        if damaged then
            if applyTreatment(target, part, 'surgical_repair', actor) then treated = treated + 1 end
            if (tonumber(bodyPart.damage) or 0) > 45 or organDamage then
                if applyTreatment(target, part, 'surgical_repair', actor) then treated = treated + 1 end
            end
        end
    end
    applyTreatment(target, nil, 'morphine', actor)
    applyTreatment(target, nil, 'rehab_session', actor)
    restoreVitals(target, actor)
    return true, treated > 0 and ('Advanced treatment completed (%s repairs).'):format(treated) or 'No active injuries found; vitals restored.'
end

local function actorIdentity(src)
    local player = getPlayer(src)
    local cid = player and player.PlayerData and player.PlayerData.citizenid
    return cid and ('medical-admin:%s'):format(cid) or ('medical-admin:source-%s'):format(src)
end

local function patientCitizenId(target)
    local player = getPlayer(target)
    return player and player.PlayerData and player.PlayerData.citizenid or nil
end

local function performAction(src, action, target)
    target = tonumber(target)
    action = tostring(action or '')
    if not allowedActions[action] then return false, 'Blocked unknown medical admin action.' end
    if not targetExists(target) then return false, 'Patient is no longer online.' end

    local actor = actorIdentity(src)
    debugLog(('action start src=%s target=%s action=%s'):format(src, target, action))

    if action == 'trauma_twin_v14' then
        local invoked,twin,detail=callCore('GetV14Twin',target);if not invoked or type(twin)~='table'then return false,'V14 trauma twin failed: '..tostring(detail or twin)end
        return true,('V14 trauma risk %s%%, tier %s, golden hour %s min, occult bleeding %s%%, airway protection %s%%, procedure readiness %s%%.'):format(tostring(twin.v14.traumaCommandRisk),tostring(twin.v14.traumaTier),tostring(twin.v14.goldenHourRemaining),tostring(twin.traumaV14.occultHemorrhageRisk),tostring(twin.airwayV14.airwayProtection),tostring(twin.procedureV14.readiness))
    elseif action == 'trauma_clock_v14' then
        local invoked,id,detail=callCore('StartTraumaEvolutionV14',target,'trauma',{speed=1,applyToLive=false},actor);if not invoked or not id then return false,'V14 trauma clock failed: '..tostring(detail or id)end;local stepped,okResult,stepDetail=callCore('AdvanceTraumaEvolutionV14',id,5);if not stepped or okResult~=true then return false,'V14 trauma clock advance failed: '..tostring(stepDetail or okResult)end;return true,('V14 trauma clock %s advanced five minutes; elapsed %s minutes.'):format(tostring(id),tostring(stepDetail.elapsedMinutes))
    elseif action == 'trauma_activation_v14' then
        local invoked,result,detail=callCore('CreateTraumaActivationV14',target,nil,actor);if not invoked or result~=true then return false,'V14 trauma activation failed: '..tostring(detail or result)end;return true,('V14 trauma activation %s created at tier %s.'):format(tostring(detail.id),tostring(detail.tier))
    elseif action == 'mtp_v14' then
        local invoked,result,detail=callCore('ActivateMassiveTransfusionV14',target,'main_blood_bank',actor);if not invoked or result~=true then return false,'V14 massive transfusion failed: '..tostring(detail or result)end;return true,'V14 massive-transfusion case activated: '..tostring(detail.id)
    elseif action == 'procedure_checklist_v14' then
        local invoked,id,detail=callCore('CreateProcedureChecklistV14',target,'damage_control_resuscitation',actor);if not invoked or not id then return false,'V14 procedure checklist failed: '..tostring(detail or id)end;return true,('V14 procedure checklist %s created with %s steps.'):format(tostring(id),tostring(#(detail.steps or{})))
    elseif action == 'destination_compare_v14' then
        local invoked,result,detail=callCore('CompareTraumaDestinationsV14',target,nil);if not invoked or result~=true or type(detail)~='table'then return false,'V14 destination comparison failed: '..tostring(detail or result)end;local best=detail[1]or{};return true,('V14 destination recommendation: %s score %s, travel %s min.'):format(tostring(best.id),tostring(best.score),tostring(best.travelMinutes))
    elseif action == 'system_test_v14' then
        local invoked,report,detail=callExport('dpn-medical-admin-tools','RunTraumaNetworkTestV14',actor);if not invoked or type(report)~='table'then return false,'V14 system test failed: '..tostring(detail or report)end;return report.success==true,('V14 system test: %s passed, %s failed.'):format(tostring(report.passed),tostring(report.failed))
    elseif action == 'continuum_twin_v13' then
        local invoked,twin,detail=callCore('GetV13Twin',target);if not invoked or type(twin)~='table'then return false,'V13 twin failed: '..tostring(detail or twin)end
        return true,('V13 continuum risk %s%%, destination %s, resilience %s%%, clot %s%%, toxicity %s%%, infection %s%%, confidence %s%%.'):format(tostring(twin.v13.continuumRisk),tostring(twin.v13.recommendedDestination),tostring(twin.v13.resilienceScore),tostring(twin.hemostasisV13.clotStrength),tostring(twin.pharmacologyV13.toxicityRisk),tostring(twin.immuneV13.infectionProbability),tostring(twin.uncertaintyV13.confidence))
    elseif action == 'snapshot_v13' then
        local invoked,id,detail=callCore('CreatePatientSnapshotV13',target,'medadmin_snapshot_v13',actor);if not invoked or not id then return false,'V13 snapshot failed: '..tostring(detail or id)end;return true,'V13 patient snapshot created: '..tostring(id)
    elseif action == 'pathway_v13' then
        local invoked,id,detail=callCore('CreateContinuumCarePathwayV13',target,'continuum_care',actor);if not invoked or not id then return false,'V13 pathway failed: '..tostring(detail or id)end;return true,'V13 continuum pathway created: '..tostring(id)
    elseif action == 'simulate_v13' then
        local invoked,id,detail=callCore('StartDeterministicSimulationV13',target,'hemorrhage',{seed=os.time(),applyToLive=false},actor);if not invoked or not id then return false,'V13 simulation failed: '..tostring(detail or id)end;local stepped,okResult,stepDetail=callCore('StepDeterministicSimulationV13',id,12);if not stepped or okResult~=true then return false,'V13 simulation step failed: '..tostring(stepDetail or okResult)end;return true,('V13 deterministic simulation %s advanced 12 steps; projected risk %s%%.'):format(tostring(id),tostring(stepDetail.model and stepDetail.model.v13 and stepDetail.model.v13.continuumRisk))
    elseif action == 'reserve_resource_v13' then
        local invoked,result,detail=callCore('ReserveCriticalResourceV13',target,'critical_care_kit',1,'main_hospital',actor);if not invoked or result~=true then return false,'V13 reservation failed: '..tostring(detail or result)end;return true,'V13 critical-care resource reserved: '..tostring(detail.id)
    elseif action == 'incident_v13' then
        local invoked,result,detail=callCore('CreateRegionalContinuumIncidentV13',target,nil,actor);if not invoked or result~=true then return false,'V13 command incident failed: '..tostring(detail or result)end;return true,'V13 regional continuum incident activated: '..tostring(detail.id)
    elseif action == 'system_test_v13' then
        local invoked,report,detail=callExport('dpn-medical-admin-tools','RunContinuumNetworkTestV13',actor);if not invoked or type(report)~='table'then return false,'V13 system test failed: '..tostring(detail or report)end;return report.success==true,('V13 system test: %s passed, %s failed.'):format(tostring(report.passed),tostring(report.failed))
    elseif action == 'integrated_twin_v12' then
        local invoked, twin, detail = callCore('GetV12Twin', target)
        if not invoked or type(twin) ~= 'table' then return false, 'V12 integrated twin failed: ' .. tostring(detail or twin) end
        return true, ('V12 twin: risk %s%%, command %s, destination %s, population %s, confidence %s%%, supports %s.'):format(
            tostring(twin.v12.integratedRisk), tostring(twin.v12.commandLevel), tostring(twin.v12.recommendedDestination),
            tostring(twin.populationV12.group), tostring(twin.dataQualityV12.confidence),
            table.concat(twin.organSupportV12.recommendedSupports or {}, ', '))
    elseif action == 'integrated_protocol_v12' then
        local invoked, id, plan = callCore('CreateIntegratedProtocolV12', target, 'auto', actor)
        if not invoked or not id or type(plan) ~= 'table' then return false, 'V12 protocol creation failed: ' .. tostring(plan or id) end
        return true, ('V12 integrated protocol %s created with %s step(s); human approval required=%s.'):format(
            tostring(id), tostring(#(plan.steps or {})), tostring(plan.advisoryOnly == true))
    elseif action == 'start_session_v12' then
        local invoked, okResult, detail = callCore('StartCriticalCareSessionV12', target, 15, actor)
        if not invoked or okResult ~= true or type(detail) ~= 'table' then return false, 'V12 critical-care session failed: ' .. tostring(detail or okResult) end
        return true, ('V12 critical-care session %s started every %s seconds.'):format(tostring(detail.id), tostring(detail.intervalSeconds))
    elseif action == 'stop_session_v12' then
        local invoked, okResult, detail = callCore('StopCriticalCareSessionV12', target, actor)
        if not invoked or okResult ~= true then return false, 'Unable to stop V12 session: ' .. tostring(detail or okResult) end
        return true, 'V12 critical-care session stopped.'
    elseif action == 'organ_support_v12' then
        local invoked, okResult, detail = callCore('EvaluateOrganSupportV12', target)
        if not invoked or okResult ~= true or type(detail) ~= 'table' then return false, 'V12 organ-support evaluation failed: ' .. tostring(detail or okResult) end
        local support = detail.organSupport or {}
        return true, ('V12 support: ECMO %s%%, CRRT %s%%, MCS %s%%, MTP %s%%, neuro %s%%, supports %s.'):format(
            tostring(support.ecmoNeed or 0), tostring(support.crrtNeed or 0),
            tostring(support.mechanicalCirculatorySupportNeed or 0), tostring(support.massiveTransfusionNeed or 0),
            tostring(support.neurocriticalNeed or 0), table.concat(support.recommendedSupports or {}, ', '))
    elseif action == 'network_reconcile_v12' then
        local invoked, healthy, report = callCore('ReconcileMedicalNetworkV12', target, actor)
        if not invoked or type(report) ~= 'table' then return false, 'V12 network reconciliation failed: ' .. tostring(report or healthy) end
        return true, ('V12 network %s: unavailable %s, pending transactions %s, failed %s, data confidence %s%%.'):format(
            healthy == true and 'healthy' or 'degraded', tostring(#(report.unavailable or {})),
            tostring(report.pendingTransactions or 0), tostring(report.failedTransactions or 0), tostring(report.dataConfidence or 'n/a'))
    elseif action == 'system_test_v12' then
        local invoked, report, detail = callExport('dpn-medical-admin-tools', 'RunIntegratedNetworkTestV12', actor)
        if not invoked or type(report) ~= 'table' then return false, 'V12 system test failed: ' .. tostring(detail or report) end
        return report.success == true, ('V12 system test: %s passed, %s failed.'):format(report.passed, report.failed)
    elseif action == 'care_twin_v11' then

        local invoked, twin, detail = callCore('GetV11Twin', target)
        if not invoked or type(twin) ~= 'table' then return false, 'V11 care twin failed: ' .. tostring(detail or twin) end
        return true, ('V11 twin: risk %s%%, mortality %s%%, homeostasis %s%%, priority %s, care %s, tissue O2 %s%%.'):format(
            twin.v11.autonomousRisk, twin.v11.predictedMortality, twin.v11.homeostasisScore, twin.v11.clinicalPriority, twin.v11.predictedLevelOfCare, twin.microcirculation.tissueOxygenation)
    elseif action == 'forecast_blood_v11' then
        local invoked, okResult, detail = callCore('ForecastInterventionV11', target, 'blood', 15, actor)
        if not invoked or okResult ~= true or type(detail) ~= 'table' then return false, 'V11 intervention forecast failed: ' .. tostring(detail or okResult) end
        return true, ('Blood forecast: risk %s%% -> %s%%, mortality %s%% -> %s%%, estimated benefit %s.'):format(
            detail.before.risk, detail.after.risk, detail.before.mortality, detail.after.mortality, detail.estimatedBenefit)
    elseif action == 'autonomous_plan_v11' then
        local invoked, id, detail = callCore('CreateAutonomousCarePlanV11', target, actor)
        if not invoked or not id then return false, 'Autonomous care plan failed: ' .. tostring(detail or id) end
        return true, 'Human-approval autonomous care plan created: ' .. tostring(id)
    elseif action == 'reconcile_devices_v11' then
        local invoked, okResult, detail = callCore('ReconcileDevicesAndMedicationsV11', target, actor)
        if not invoked or okResult ~= true or type(detail) ~= 'table' then return false, 'Device/medication reconciliation failed: ' .. tostring(detail or okResult) end
        return true, ('V11 reconciliation complete: safety score %s, findings %s.'):format(tostring(detail.score), tostring(#(detail.findings or {})))
    elseif action == 'start_reassessment_v11' then
        local invoked, okResult, detail = callCore('StartContinuousReassessmentV11', target, 30, actor)
        if not invoked or okResult ~= true then return false, 'Continuous reassessment failed: ' .. tostring(detail or okResult) end
        return true, 'Continuous v11 reassessment started every 30 seconds.'
    elseif action == 'stop_reassessment_v11' then
        local invoked, okResult, detail = callCore('StopContinuousReassessmentV11', target, actor)
        if not invoked or okResult ~= true then return false, 'Unable to stop reassessment: ' .. tostring(detail or okResult) end
        return true, 'Continuous v11 reassessment stopped.'
    elseif action == 'waveform_snapshot_v11' then
        local invoked, okResult, detail = callCore('GenerateWaveformSnapshotV11', target, 48, actor)
        if not invoked or okResult ~= true or type(detail) ~= 'table' then return false, 'Waveform snapshot failed: ' .. tostring(detail or okResult) end
        return true, ('Waveform captured: rhythm %s, HR %s, SpO2 %s, EtCO2 %s.'):format(detail.rhythm, detail.hr, detail.spo2, detail.etco2)
    elseif action == 'system_test_v11' then
        local invoked, report, detail = callExport('dpn-medical-admin-tools', 'RunAutonomousNetworkTestV11', actor)
        if not invoked or type(report) ~= 'table' then return false, 'V11 system test failed: ' .. tostring(detail or report) end
        return report.success == true, ('V11 system test: %s passed, %s failed.'):format(report.passed, report.failed)
    elseif action == 'command_twin_v10' then
        local invoked, twin, detail = callCore('GetV10Twin', target)
        if not invoked or type(twin) ~= 'table' then return false, 'V10 command twin failed: ' .. tostring(detail or twin) end
        return true, ('V10 twin: risk %s%%, arrest %s min, ICU %s%%, clot %s%%, ABG %s, gaps %s.'):format(twin.v10.commandRisk, twin.v10.predictedArrestMinutes, twin.v10.predictedICUNeed, twin.circulation.clotStability, twin.bloodGas.acidBase, twin.v10.careGapCount)
    elseif action == 'transition_15_v10' then
        local invoked, result, detail = callCore('PredictCriticalTransitionV10', target, 15)
        if not invoked or result ~= true or type(detail) ~= 'table' then return false, 'Transition prediction failed: ' .. tostring(detail or result) end
        return true, ('15-minute prediction: risk %s%% -> %s%%, blood %s mL, class %s.'):format(detail.currentRisk, detail.projectedRisk, detail.projectedBloodMl, detail.projectedClass)
    elseif action == 'closed_loop_bundle_v10' then
        local invoked, bundleId, bundle = callCore('CreateClosedLoopBundleV10', target, actorIdentity(src))
        if not invoked or type(bundle) ~= 'table' then return false, 'Closed-loop bundle failed: ' .. tostring(bundle or bundleId) end
        return true, ('Closed-loop bundle %s created with %s step(s).'):format(tostring(bundleId), #(bundle.steps or {}))
    elseif action == 'activate_command_v10' then
        local invoked, incidentId, incident = callCore('CreateClinicalCommandIncidentV10', target, 'medadmin_activation', coordsFor(target), actorIdentity(src))
        if not invoked or type(incident) ~= 'table' then return false, 'Command activation failed: ' .. tostring(incident or incidentId) end
        return true, ('Clinical command %s activated at risk %s%%.'):format(tostring(incidentId), tostring(incident.commandRisk))
    elseif action == 'reconcile_modules_v10' then
        local invoked, result, report = callCore('ReconcileCrossModuleCareV10', target, actorIdentity(src))
        if not invoked or result ~= true or type(report) ~= 'table' then return false, 'Reconciliation failed: ' .. tostring(report or result) end
        return true, ('Reconciliation %s: %s care gap(s), %s missing resource(s).'):format(report.status, #(report.careGaps or {}), #(report.missingResources or {}))
    elseif action == 'black_box_v10' then
        local invoked, events, detail = callCore('GetClinicalBlackBoxV10', target, 25)
        if not invoked or type(events) ~= 'table' then return false, 'Black-box review failed: ' .. tostring(detail or events) end
        return true, ('Clinical black box contains %s recent event(s). Latest: %s.'):format(#events, events[1] and tostring(events[1].eventType) or 'none')
    elseif action == 'goto' then
        local coords = coordsFor(target)
        if not coords then return false, 'Unable to locate patient.' end
        TriggerClientEvent('dpn-medical-admin-tools:client:teleportNative', src, coords)
        return true, 'Teleported to patient.'
    elseif action == 'bring' then
        local coords = coordsFor(src)
        if not coords then return false, 'Unable to locate administrator.' end
        TriggerClientEvent('dpn-medical-admin-tools:client:teleportNative', target, coords)
        return true, 'Patient brought to you.'
    elseif action == 'visual_reset' then
        TriggerClientEvent('dpn-medical-core:client:aggressiveVisualReset', target)
        TriggerClientEvent('dpn-medical-core:client:resetScreen', target)
        TriggerClientEvent('dpn-medical-core:client:forceCloseUI', target)
        return true, 'Medical visual state and interfaces reset.'
    elseif action == 'resync' then
        local state, err = coreState(target)
        if not state then return false, err end
        TriggerClientEvent('dpn-medical-core:client:syncState', target, state)
        TriggerClientEvent('dpn-medical-core:client:resetDamageTracker', target)
        return true, 'Patient medical state resynchronized.'
    end

    if not coreReady() then return false, 'dpn-medical-core is not started.' end

    if action == 'revive' then
        local invoked, result, detail = callCore('RevivePatient', target, { fullHeal = false, by = actor })
        local ok, err = exportSucceeded(invoked, result, detail)
        return ok, ok and 'Patient revived while preserving injuries.' or ('Revive failed: ' .. err)
    elseif action == 'full_heal' or action == 'reset_medical' then
        local invoked1, result1, detail1 = callCore('ResetPatient', target, 'medical admin full restore')
        local resetOk, resetError = exportSucceeded(invoked1, result1, detail1)
        if not resetOk then return false, 'Reset failed: ' .. resetError end
        local invoked2, result2, detail2 = callCore('RevivePatient', target, { fullHeal = true, by = actor })
        local reviveOk, reviveError = exportSucceeded(invoked2, result2, detail2)
        if not reviveOk then return false, 'Reset succeeded but revive failed: ' .. reviveError end
        TriggerClientEvent('dpn-medical-core:client:aggressiveVisualReset', target)
        return true, 'Patient fully restored and revived.'
    elseif action == 'stabilize' then
        local state, err = coreState(target)
        if not state then return false, err end
        local status = type(state.status) == 'table' and state.status or {}
        local count = 0
        if status.cardiacArrest == true then
            if applyTreatment(target, nil, 'aed', actor) then count = count + 1 end
        end
        count = count + restoreVitals(target, actor)
        if status.lifeState == 'dead' or status.lifeState == 'incapacitated' then
            local invoked, result = callCore('RevivePatient', target, { fullHeal = false, by = actor })
            if invoked and result == true then count = count + 1 end
        end
        return count > 0, count > 0 and ('Emergency stabilization completed (%s interventions).'):format(count) or 'Stabilization failed.'
    elseif action == 'heal_injuries' then
        return healAllInjuries(target, actor)
    elseif action == 'stop_bleeding' then
        return stopAllBleeding(target, actor)
    elseif action == 'restore_vitals' then
        local count = restoreVitals(target, actor)
        return count > 0, count > 0 and ('Vitals restored (%s interventions).'):format(count) or 'Unable to restore vitals.'
    elseif action == 'incapacitate' then
        local invoked, result, detail = callCore('SetLifeState', target, 'incapacitated', {
            cause = 'Medical administrator action', time = os.time(), unconscious = true
        })
        local ok, exportError = exportSucceeded(invoked, result, detail)
        return ok, ok and 'Patient incapacitated.' or ('Unable to incapacitate patient: ' .. exportError)
    elseif action == 'mark_dead' then
        local invoked, result, detail = callCore('SetLifeState', target, 'dead', {
            cause = 'Medical administrator action', time = os.time()
        })
        local ok, exportError = exportSucceeded(invoked, result, detail)
        return ok, ok and 'Patient marked deceased.' or ('Unable to mark patient deceased: ' .. exportError)
    elseif action == 'digital_twin' then
        local invoked, twin, detail = callCore('GetDigitalTwin', target)
        if not invoked or type(twin) ~= 'table' then return false, 'Digital twin failed: ' .. tostring(detail or twin) end
        local v6 = type(twin.v6) == 'table' and twin.v6 or {}
        return true, ('Digital twin: SOFA %s, %s organ-failure risk, %s acid-base status, disposition %s.'):format(
            tostring(v6.sofa or '?'), tostring(v6.organFailureRisk or 'unknown'), tostring(v6.acidBase or 'unknown'), tostring(v6.disposition or 'unknown'))
    elseif action == 'recommended_orders' then
        local invoked, ids, detail = callCore('CreateRecommendedOrderSet', target, actor)
        if not invoked or type(ids) ~= 'table' then return false, 'Order set failed: ' .. tostring(detail or ids) end
        return true, ('Created %s recommended clinical order(s).'):format(#ids)
    elseif action == 'generate_handoff' then
        local invoked, id, detail = callCore('CreateStructuredHandoff', target, 'Medical Administration Review', {
            situation = 'Administrative clinical handoff generated from the live digital twin.',
            metadata = { generatedBy = actor, source = 'medadmin' }
        }, actor)
        if not invoked or not id then return false, 'Handoff failed: ' .. tostring(detail or id) end
        return true, 'Structured SBAR handoff created: ' .. tostring(id)
    elseif action == 'ack_alerts' then
        local invoked, active, detail = callCore('GetActiveSafetyAlerts', target)
        if not invoked or type(active) ~= 'table' then return false, 'Unable to retrieve safety alerts: ' .. tostring(detail or active) end
        local acknowledged = 0
        for _, item in ipairs(active) do
            local called, ok = callCore('AcknowledgeSafetyAlert', target, item.id, actor, 'Acknowledged through MedAdmin')
            if called and ok == true then acknowledged = acknowledged + 1 end
        end
        return true, ('Acknowledged %s active safety alert(s).'):format(acknowledged)
    elseif action == 'precision_twin' then
        local invoked, twin, detail = callCore('GetPrecisionTwin', target)
        if not invoked or type(twin) ~= 'table' then return false, 'Precision twin failed: ' .. tostring(detail or twin) end
        local v8 = twin.v8 or {}; local h = twin.hemodynamics or {}; local p = twin.pulmonary or {}
        return true, ('Precision: risk %s%%, survival %s%%, CO %s L/min, O2 delivery %s, P/F %s, destination %s.'):format(tostring(v8.precisionRisk), tostring(v8.predictedSurvival), tostring(h.cardiacOutputLpm), tostring(h.oxygenDeliveryMlMin), tostring(p.pfRatio), tostring(v8.recommendedDestination))
    elseif action == 'precision_plan' then
        local invoked, id, detail = callCore('CreateRecommendedPrecisionPlan', target, actor)
        if not invoked or not id then return false, 'Precision care plan failed: ' .. tostring(detail or id) end
        return true, 'Precision care plan created: ' .. tostring(id)
    elseif action == 'simulation_hemorrhage' then
        local invoked, id, detail = callCore('StartPrecisionSimulation', target, 'hemorrhage', 1.0, actor)
        if not invoked or not id then return false, 'Simulation failed: ' .. tostring(detail or id) end
        return true, 'Controlled hemorrhage simulation started: ' .. tostring(id)
    elseif action == 'simulation_stop' then
        local invoked, result, detail = callCore('ControlPrecisionSimulation', target, 'stop', nil, actor)
        if not invoked or result ~= true then return false, 'Unable to stop simulation: ' .. tostring(detail or result) end
        return true, 'Precision simulation stopped.'
    elseif action == 'adaptive_twin' then
        local invoked, twin, detail = callCore('GetV9Twin', target)
        if not invoked or type(twin) ~= 'table' then return false, 'Adaptive twin failed: ' .. tostring(detail or twin) end
        local v9 = twin.v9 or {}
        return true, ('Adaptive v9: risk %s%%, recovery %s%%, trajectory %s, critical in %s min, electrolyte %s%%, medication accumulation %s%%, disposition %s.'):format(tostring(v9.adaptiveRisk), tostring(v9.recoveryProbability), tostring(v9.trajectory), tostring(v9.predictedMinutesToCritical), tostring(v9.electrolyteRisk), tostring(v9.medicationAccumulationRisk), tostring(v9.disposition))
    elseif action == 'trajectory_30' then
        local invoked, okResult, detail = callCore('PredictPatientTrajectory', target, 30)
        if not invoked or okResult ~= true or type(detail) ~= 'table' then return false, 'Trajectory prediction failed: ' .. tostring(detail or okResult) end
        return true, ('30-minute trajectory: %s, risk %s%% -> %s%%, recovery %s%% -> %s%%, confidence %s%%.'):format(tostring(detail.direction), tostring(detail.currentRisk), tostring(detail.projectedRisk), tostring(detail.currentRecovery), tostring(detail.projectedRecovery), tostring(detail.confidence))
    elseif action == 'adaptive_pathway' then
        local invoked, id, detail = callCore('CreateAdaptiveCarePathway', target, actor)
        if not invoked or not id then return false, 'Adaptive pathway failed: ' .. tostring(detail or id) end
        return true, 'Adaptive multidisciplinary pathway created: ' .. tostring(id)
    elseif action == 'safety_reconcile_v9' then
        local invoked, okResult, detail = callCore('ReconcilePatientSafetyV9', target, actor)
        if not invoked or okResult ~= true or type(detail) ~= 'table' then return false, 'Safety reconciliation failed: ' .. tostring(detail or okResult) end
        return true, ('Safety reconciliation complete: score %s, findings %s.'):format(tostring(detail.score), tostring(#(detail.findings or {})))
    elseif action == 'resilience_replay_v9' then
        local invoked, okResult, detail = callCore('ReplayResilienceQueue', 50)
        if not invoked or okResult ~= true then return false, 'Resilience replay failed: ' .. tostring(detail or okResult) end
        return true, ('Resilience queue replayed: %s attempted, %s succeeded, %s failed.'):format(tostring(detail.attempted), tostring(detail.succeeded), tostring(detail.failed))
    elseif action == 'hospital_respawn' then
        local invoked, result, detail = callHospital('EmergencyRespawn', target, 'Medical administrator hospital respawn')
        local ok, exportError = exportSucceeded(invoked, result, detail)
        return ok, ok and 'Patient respawned and admitted at the hospital.' or ('Hospital respawn failed: ' .. exportError)
    elseif action == 'admit_er' or action == 'admit_icu' then
        local ward = action == 'admit_icu' and 'icu' or 'er'
        local minutes = action == 'admit_icu' and ((Config.Hospital and Config.Hospital.icuMinutes) or 30) or ((Config.Hospital and Config.Hospital.erMinutes) or 15)
        local hospitalId = (Config.Hospital and Config.Hospital.defaultHospital) or 'pillbox'
        local invoked, result, detail = callHospital('AdmitPatient', target, hospitalId, actor, ward, minutes,
            action == 'admit_icu' and 'Administrative critical-care admission' or 'Administrative emergency admission')
        local ok, exportError = exportSucceeded(invoked, result, detail)
        return ok, ok and ('Patient admitted to %s.'):format(ward:upper()) or ('Admission failed: ' .. exportError)
    elseif action == 'discharge' then
        local cid = patientCitizenId(target)
        if not cid then return false, 'Patient citizen ID is unavailable.' end
        local invoked, result, detail = callHospital('DischargePatient', cid, actor, true, 'Medical administrator discharge')
        local ok, exportError = exportSucceeded(invoked, result, detail)
        return ok, ok and 'Patient discharged from hospital.' or ('Discharge failed: ' .. exportError)
    end

    return false, 'Unknown medical admin action.'
end

RegisterNetEvent('dpn-medical-admin-tools:server:requestOpenNative', function()
    openFor(source, false)
end)

RegisterNetEvent('dpn-medical-admin-tools:server:refreshNative', function()
    local src = source
    local allowed = hasPermission(src)
    if not openMenus[src] or not allowed then return end
    TriggerClientEvent('dpn-medical-admin-tools:client:updateNative', src, safePayload(src))
end)

RegisterNetEvent('dpn-medical-admin-tools:server:menuClosed', function()
    openMenus[source] = nil
end)

local function sendActionResult(src, ok, message, action, target)
    TriggerClientEvent('dpn-medical-admin-tools:client:actionResultNative', src, {
        ok = ok == true,
        message = tostring(message or (ok and 'Action completed.' or 'Action failed.')),
        action = tostring(action or ''),
        target = tonumber(target)
    })
end

local function executeSecuredAction(src, action, target, bypassOpenMenu)
    src = tonumber(src) or 0
    target = tonumber(target)
    action = tostring(action or ''):sub(1, 40)

    local allowed, via = hasPermission(src)
    if not allowed then
        debugLog(('action denied src=%s action=%s via=%s'):format(src, action, tostring(via)))
        if src > 0 then sendActionResult(src, false, 'Medical administrator permission denied.', action, target) end
        return false, 'permission denied'
    end
    if bypassOpenMenu ~= true and not openMenus[src] then
        sendActionResult(src, false, 'Open /medadmin before executing secured actions.', action, target)
        return false, 'menu is not open'
    end

    local now = GetGameTimer()
    local cooldown = tonumber(Config.ActionCooldownMs) or 650
    if src > 0 and now - (actionCooldowns[src] or 0) < cooldown then
        sendActionResult(src, false, 'Secured action cooldown is active. Try again.', action, target)
        return false, 'cooldown'
    end
    actionCooldowns[src] = now

    local ran, actionOk, actionMessage = xpcall(function()
        local success, resultMessage = performAction(src, action, target)
        return success == true, resultMessage
    end, debug.traceback)
    local ok, message
    if ran then
        ok, message = actionOk == true, actionMessage
    else
        ok = false
        message = 'Action handler error: ' .. tostring(actionOk)
        debugLog(('action exception src=%s target=%s action=%s error=%s'):format(src, tostring(target), action, tostring(actionOk)))
    end

    message = tostring(message or (ok and 'Action completed.' or 'Action failed.'))
    debugLog(('action result src=%s target=%s action=%s ok=%s message=%s'):format(src, tostring(target), action, tostring(ok), message))
    addAudit(src, action, target, { ok = ok == true, message = message, via = via })
    if src > 0 then sendActionResult(src, ok == true, message, action, target) end

    SetTimeout(350, function()
        if src > 0 and openMenus[src] and GetPlayerName(src) then
            TriggerClientEvent('dpn-medical-admin-tools:client:updateNative', src, safePayload(src))
        end
    end)
    return ok == true, message
end

RegisterNetEvent('dpn-medical-admin-tools:server:actionNative', function(action, target)
    executeSecuredAction(source, action, target, false)
end)

local function runAdminMedicalTest(src, target, scenarioId)
    if scenarioId == 'dispatch_bridge_health' then
        local invoked, health, detail = callExport('dpn-medical-dispatch', 'GetDispatchBridgeHealth')
        if not invoked or type(health) ~= 'table' then
            return false, { message = 'Dispatch bridge health check failed: ' .. tostring(detail or health) }
        end
        local started = {}
        for _, resource in ipairs(health.externalResources or {}) do
            started[#started + 1] = ('%s=%s'):format(resource.name, resource.state)
        end
        return true, { message = ('Dispatch healthy. Active calls: %s. External bridge: %s. %s'):format(
            tostring((function() local n=0 for _ in pairs(health.activeCalls or {}) do n=n+1 end return n end)()),
            health.externalEnabled and 'enabled' or 'disabled', table.concat(started, ', ')) }
    elseif scenarioId == 'dispatch_pipeline_test' then
        local invoked, call, detail = callExport('dpn-medical-dispatch', 'CreateMedicalCall', {
            source = target,
            type = 'admin_dispatch_test',
            priority = 3,
            code = 'MED-TEST',
            title = 'DPN Medical Dispatch Pipeline Test',
            message = 'Administrative end-to-end EMS dispatch test. No real emergency.',
            tags = { 'medical', 'admin-test', 'dispatch-validation' },
            riskFlags = { 'test-only' }
        })
        if not invoked or type(call) ~= 'table' then
            return false, { message = 'Dispatch pipeline test failed: ' .. tostring(detail or call) }
        end
        return true, { message = ('Dispatch test call #%s created; %s EMS unit(s) notified; external bridge %s.'):format(
            tostring(call.id), tostring(call.notifiedUnits or 0), call.externalBridge and 'attempted' or 'not configured'), call = call }
    end
    local invoked, success, result, detail = callCore('ApplyTestScenario', target, scenarioId, { resetBefore = true }, actorIdentity(src))
    if not invoked then return false, { message = tostring(detail or result or 'Medical core test invocation failed.') } end
    if type(result) ~= 'table' then result = { message = tostring(detail or result or (success and 'Medical test completed.' or 'Medical test failed.')) } end
    return success == true, result
end

RegisterNetEvent('dpn-medical-admin-tools:server:testScenarioNative', function(scenarioId, target)
    local src = tonumber(source) or 0
    target = tonumber(target)
    scenarioId = tostring(scenarioId or ''):sub(1, 64)

    local allowed, via = hasPermission(src)
    if not allowed or not openMenus[src] then
        sendActionResult(src, false, not allowed and 'Medical administrator permission denied.' or 'Open /medadmin before running tests.', 'test:' .. scenarioId, target)
        return
    end
    if not targetExists(target) then
        sendActionResult(src, false, 'Select an online patient before running a medical test.', 'test:' .. scenarioId, target)
        return
    end

    local now = GetGameTimer()
    local cooldown = tonumber(Config.TestLabCooldownMs) or 900
    if now - (actionCooldowns[src] or 0) < cooldown then
        sendActionResult(src, false, 'Medical test cooldown is active. Try again.', 'test:' .. scenarioId, target)
        return
    end
    actionCooldowns[src] = now

    local ok, result = runAdminMedicalTest(src, target, scenarioId)
    local message
    if ok then
        if type(result) == 'table' then
            message = result.message or (result.label and (result.label .. ' completed.')) or ('Medical test ' .. scenarioId .. ' completed.')
        else
            message = 'Medical test ' .. scenarioId .. ' completed.'
        end
    else
        if type(result) == 'table' then
            message = result.message or 'Medical test failed.'
        else
            message = tostring(result or 'Medical test failed.')
        end
    end

    debugLog(('test result src=%s target=%s scenario=%s ok=%s message=%s'):format(src, tostring(target), scenarioId, tostring(ok), tostring(message)))
    addAudit(src, 'medical_test:' .. scenarioId, target, { ok = ok, message = message, via = via })
    sendActionResult(src, ok, message, 'test:' .. scenarioId, target)

    SetTimeout(350, function()
        if openMenus[src] and GetPlayerName(src) then
            TriggerClientEvent('dpn-medical-admin-tools:client:updateNative', src, safePayload(src))
        end
    end)
end)

RegisterCommand('medtest', function(src, args)
    if src <= 0 then
        print('[dpn-medical-admin-tools] Usage in game: /medtest <player id> <scenario id>')
        return
    end
    local allowed = hasPermission(src)
    if not allowed then return end
    local target = tonumber(args and args[1])
    local scenarioId = tostring(args and args[2] or '')
    if not target or scenarioId == '' then
        TriggerClientEvent('QBCore:Notify', src, 'Usage: /medtest <player id> <scenario id>', 'error')
        return
    end
    openMenus[src] = true
    TriggerEvent('dpn-medical-admin-tools:server:runTestCommandInternal', src, target, scenarioId)
end, false)

AddEventHandler('dpn-medical-admin-tools:server:runTestCommandInternal', function(src, target, scenarioId)
    local ok, result = runAdminMedicalTest(src, target, tostring(scenarioId))
    local message = type(result) == 'table' and result.message or tostring(result or (ok and 'Medical test completed.' or 'Medical test failed.'))
    addAudit(src, 'medical_test_command:' .. tostring(scenarioId), target, { ok = ok, message = message })
    sendActionResult(src, ok, message, 'test:' .. tostring(scenarioId), target)
end)

RegisterCommand('medtestlist', function(src)
    if src <= 0 then return end
    local allowed = hasPermission(src)
    if not allowed then return end
    local catalog = testScenarioRows()
    local ids = {}
    for _, item in ipairs(catalog) do ids[#ids + 1] = tostring(item.id) end
    TriggerClientEvent('chat:addMessage', src, { color = {74,176,255}, args = {'DPN Medical Tests', table.concat(ids, ', ')} })
end, false)

RegisterCommand(Config.ConsoleOpenCommand or 'medadminforce', function(src, args)
    if src ~= 0 then return end
    local target = tonumber(args and args[1])
    if not target or not GetPlayerName(target) then
        print('[dpn-medical-admin-tools] Usage: medadminforce <online player id>')
        return
    end
    openFor(target, true)
end, true)

RegisterCommand(Config.ConsoleActionCommand or 'medadminexec', function(src, args)
    if src ~= 0 then return end
    local action = tostring(args and args[1] or '')
    local target = tonumber(args and args[2])
    if action == '' or not target then
        print('[dpn-medical-admin-tools] Usage: medadminexec <action> <online player id>')
        return
    end
    local ok, message = executeSecuredAction(0, action, target, true)
    print(('[dpn-medical-admin-tools] console action=%s target=%s ok=%s message=%s'):format(action, target, tostring(ok), tostring(message)))
end, true)

AddEventHandler('playerDropped', function()
    openMenus[source] = nil
    actionCooldowns[source] = nil
end)

CreateThread(function()
    getCore()
    Wait(750)
    local invoked, registered, detail = callCore('RegisterModule', 'dpn-medical-admin-tools', '12.0.0', {
        'native_admin_dashboard', 'native_mouse_controls', 'secure_actions', 'patient_recovery', 'hospital_control', 'medical_test_lab', 'injury_scenarios', 'dispatch_diagnostics', 'autonomous_network', 'intervention_forecasting', 'v12_integrated_network', 'special_population_testing', 'audit'
    })
    if not invoked or registered ~= true then
        debugLog(('module registration failed: %s'):format(tostring(detail or registered)))
    end
    log('v12.0.0 loaded: native mouse integrated critical-care network, secured actions, medical test laboratory and dispatch diagnostics active')
end)

-- v3.0 advanced-system diagnostic export. The native mouse dashboard remains the UI authority.
exports('GetAdvancedSystemSnapshot', function()
    local ok, health = callCore('GetSystemHealth')
    return ok and health or { version = 'unknown', modules = {}, activeEpisodes = {} }
end)
