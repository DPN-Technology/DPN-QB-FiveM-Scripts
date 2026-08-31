local QBCore
local menuOpen = false
local waitingForServer = false
local payload = nil
local activeTab = 1
local selectedRow = 1
local selectedAction = 1
local selectedPatientId = nil
local selectedTest = 1
local mode = 'list'
local statusMessage = ''
local statusUntil = 0
local lastRefreshAt = 0
local openSequence = 0
local pendingConfirmation = nil
local confirmUntil = 0
local actionPending = false
local actionPendingUntil = 0
local executeSelectedAction
local executeSelectedTest
local mouse = {
    x = 0.5,
    y = 0.5,
    left = false,
    right = false,
    wheelUp = false,
    wheelDown = false,
    consumed = false
}

local tabs = { 'Patients', 'Medical Tests', 'Critical Command', 'Autonomous Network', 'V12 Network', 'V13 Continuum', 'V14 Trauma Ops', 'Modules', 'Audit' }
local actions = {
    { label = 'Revive (Preserve Injuries)', value = 'revive', group = 'LIFE SUPPORT', description = 'Restore consciousness and life state without erasing existing injuries.' },
    { label = 'Emergency Stabilize', value = 'stabilize', group = 'LIFE SUPPORT', description = 'Apply AED when needed, restore blood/oxygen/pressure, and revive unstable patients.' },
    { label = 'Full Medical Restore', value = 'full_heal', group = 'CLINICAL', description = 'Reset injuries, vitals, arrest state, and revive the patient at full health.', confirm = true },
    { label = 'Treat All Injuries', value = 'heal_injuries', group = 'CLINICAL', description = 'Repair bleeding, fractures, organ damage, pain, mobility, and depleted vitals.' },
    { label = 'Stop All Bleeding', value = 'stop_bleeding', group = 'CLINICAL', description = 'Treat external and internal bleeding across every body region.' },
    { label = 'Restore Vitals', value = 'restore_vitals', group = 'CLINICAL', description = 'Restore blood volume, oxygen saturation, blood pressure, and circulation.' },
    { label = 'Resync Medical State', value = 'resync', group = 'SYSTEM', description = 'Force the authoritative server medical state back to the selected client.' },
    { label = 'Reset Visual Effects', value = 'visual_reset', group = 'SYSTEM', description = 'Clear DPN medical UI, screen effects, camera shake, and damage tracking.' },
    { label = 'Hospital Respawn', value = 'hospital_respawn', group = 'HOSPITAL', description = 'Respawn, revive, and admit the patient to an available Pillbox ER bed.', confirm = true },
    { label = 'Admit to ER', value = 'admit_er', group = 'HOSPITAL', description = 'Create an emergency-room admission and assign an available ER bed.' },
    { label = 'Admit to ICU', value = 'admit_icu', group = 'HOSPITAL', description = 'Create a critical-care admission and assign an available ICU bed.' },
    { label = 'Force Discharge', value = 'discharge', group = 'HOSPITAL', description = 'Force discharge the selected patient from their active hospital admission.', confirm = true },
    { label = 'Run Digital Twin Analysis', value = 'digital_twin', group = 'CLINICAL OPS', description = 'Run the v6 physiology and organ-failure analysis for the selected patient.' },
    { label = 'Create Recommended Order Set', value = 'recommended_orders', group = 'CLINICAL OPS', description = 'Create prioritized orders from the patient digital twin and active protocols.', confirm = true },
    { label = 'Generate SBAR Handoff', value = 'generate_handoff', group = 'CLINICAL OPS', description = 'Generate a structured SBAR handoff from the current chart and physiology.' },
    { label = 'Acknowledge Safety Alerts', value = 'ack_alerts', group = 'CLINICAL OPS', description = 'Acknowledge all currently active v6 clinical safety alerts.', confirm = true },
    { label = 'Run Precision Twin', value = 'precision_twin', group = 'PRECISION V8', description = 'Calculate advanced hemodynamics, oxygen delivery, respiratory mechanics, renal risk, coagulopathy and predicted survival.' },
    { label = 'Create Precision Care Plan', value = 'precision_plan', group = 'PRECISION V8', description = 'Generate a patient-specific multidisciplinary care bundle from the v8 precision engine.', confirm = true },
    { label = 'Start Hemorrhage Simulation', value = 'simulation_hemorrhage', group = 'TESTING V8', description = 'Start a controlled, reversible hemorrhage simulation for validation.', dangerous = true, confirm = true },
    { label = 'Stop Precision Simulation', value = 'simulation_stop', group = 'TESTING V8', description = 'Stop the active precision simulation for this patient.' },
    { label = 'Run Adaptive V9 Twin', value = 'adaptive_twin', group = 'ADAPTIVE V9', description = 'Calculate longitudinal trajectory, electrolyte risk, medication accumulation, recovery probability and disposition.' },
    { label = 'Predict 30-Minute Trajectory', value = 'trajectory_30', group = 'ADAPTIVE V9', description = 'Forecast deterioration or recovery over the next 30 minutes.' },
    { label = 'Create Adaptive Care Pathway', value = 'adaptive_pathway', group = 'ADAPTIVE V9', description = 'Generate an executable multidisciplinary pathway from the v9 twin.', confirm = true },
    { label = 'Run Safety Reconciliation', value = 'safety_reconcile_v9', group = 'ADAPTIVE V9', description = 'Reconcile missing data, medication, electrolyte, QT and predicted-deterioration risks.' },
    { label = 'Replay Resilience Queue', value = 'resilience_replay_v9', group = 'SYSTEM V9', description = 'Replay queued cross-module events after a temporary resource or database failure.', confirm = true },
    { label = 'Run V10 Command Twin', value = 'command_twin_v10', group = 'CRITICAL COMMAND V10', description = 'Calculate hemorrhage, clot stability, arterial blood gas, toxicology, organ coupling, arrest prediction and care gaps.' },
    { label = 'Predict 15-Minute Critical Transition', value = 'transition_15_v10', group = 'CRITICAL COMMAND V10', description = 'Forecast untreated deterioration, projected blood volume and arrest risk over 15 minutes.' },
    { label = 'Create Closed-Loop Care Bundle', value = 'closed_loop_bundle_v10', group = 'CRITICAL COMMAND V10', description = 'Create an executable multidisciplinary care-gap bundle with target completion times.', confirm = true },
    { label = 'Activate Clinical Command Incident', value = 'activate_command_v10', group = 'CRITICAL COMMAND V10', description = 'Open a critical-care command incident and notify integrated modules.', confirm = true },
    { label = 'Run Cross-Module Reconciliation', value = 'reconcile_modules_v10', group = 'SYSTEM V10', description = 'Check required resources, care gaps, module registration and patient-data continuity.' },
    { label = 'Review Clinical Black Box', value = 'black_box_v10', group = 'SYSTEM V10', description = 'Review the latest server-authoritative clinical events for this patient.' },
    { label = 'Run V11 Autonomous Care Twin', value = 'care_twin_v11', group = 'AUTONOMOUS CARE V11', description = 'Calculate microcirculation, endocrine, infection, nutrition, device safety, recovery reserve and resource intensity.' },
    { label = 'Forecast Blood Intervention', value = 'forecast_blood_v11', group = 'AUTONOMOUS CARE V11', description = 'Run a counterfactual forecast of blood-product support without changing the live patient state.' },
    { label = 'Create Autonomous Care Plan', value = 'autonomous_plan_v11', group = 'AUTONOMOUS CARE V11', description = 'Create a multidisciplinary plan whose high-risk steps remain locked until human approval.', confirm = true },
    { label = 'Reconcile Devices and Medications', value = 'reconcile_devices_v11', group = 'SAFETY V11', description = 'Detect invasive-device risks, missing indications, medication burden and unsafe combinations.' },
    { label = 'Start Continuous Reassessment', value = 'start_reassessment_v11', group = 'MONITORING V11', description = 'Recalculate the patient risk and safety state every 30 seconds.' },
    { label = 'Stop Continuous Reassessment', value = 'stop_reassessment_v11', group = 'MONITORING V11', description = 'Stop the active v11 continuous reassessment loop.' },
    { label = 'Capture Waveform Snapshot', value = 'waveform_snapshot_v11', group = 'MONITORING V11', description = 'Generate an ECG, plethysmography and capnography snapshot from the authoritative patient state.' },
    { label = 'Run Full V11 System Test', value = 'system_test_v11', group = 'SYSTEM V11', description = 'Validate all 20 resources and their v11 operational boards.', confirm = true },
    { label = 'Run V12 Integrated Twin', value = 'integrated_twin_v12', group = 'INTEGRATED CARE V12', description = 'Calculate age-adjusted physiology, cardiopulmonary support, organ-support candidacy and data confidence.' },
    { label = 'Create V12 Integrated Protocol', value = 'integrated_protocol_v12', group = 'INTEGRATED CARE V12', description = 'Create a human-approved multidisciplinary protocol from the v12 recommendations.', confirm = true },
    { label = 'Start V12 Critical-Care Session', value = 'start_session_v12', group = 'MONITORING V12', description = 'Begin 15-second trend capture and escalation monitoring for the selected patient.' },
    { label = 'Stop V12 Critical-Care Session', value = 'stop_session_v12', group = 'MONITORING V12', description = 'Stop the active v12 critical-care monitoring session.' },
    { label = 'Evaluate Organ Support', value = 'organ_support_v12', group = 'CRITICAL SUPPORT V12', description = 'Evaluate ECMO, CRRT, mechanical-circulatory, neurocritical, pediatric and obstetric support needs.' },
    { label = 'Reconcile V12 Medical Network', value = 'network_reconcile_v12', group = 'SYSTEM V12', description = 'Check all 20 modules, circuit breakers, transactions and patient data confidence.' },
    { label = 'Run Full V12 System Test', value = 'system_test_v12', group = 'SYSTEM V12', description = 'Validate the integrated critical-care boards and exports across all 20 resources.', confirm = true },
    { label = 'Run V13 Continuum Twin', value = 'continuum_twin_v13', group = 'CONTINUUM V13', description = 'Calculate hemostasis, pharmacology, infection, recovery, uncertainty and continuum command risk.' },
    { label = 'Create V13 Patient Snapshot', value = 'snapshot_v13', group = 'SIMULATION V13', description = 'Create a server-authoritative patient state snapshot for testing and recovery.' },
    { label = 'Create V13 Continuum Pathway', value = 'pathway_v13', group = 'CONTINUUM V13', description = 'Create a multidisciplinary human-approved continuum care pathway.', confirm = true },
    { label = 'Run V13 Deterministic Simulation', value = 'simulate_v13', group = 'SIMULATION V13', description = 'Run a non-destructive seeded hemorrhage simulation and project risk over 12 steps.', confirm = true },
    { label = 'Reserve Critical-Care Kit', value = 'reserve_resource_v13', group = 'RESOURCE COMMAND V13', description = 'Reserve one critical-care equipment kit for the selected patient.', confirm = true },
    { label = 'Activate Regional Continuum Incident', value = 'incident_v13', group = 'REGIONAL COMMAND V13', description = 'Create a regional medical command incident using the selected patient risk.', confirm = true },
    { label = 'Run Full V13 System Test', value = 'system_test_v13', group = 'SYSTEM V13', description = 'Validate all 20 continuum-command resource boards and the v13 core self-test.', confirm = true },
    { label = 'Run V14 Trauma Command Twin', value = 'trauma_twin_v14', group = 'TRAUMA COMMAND V14', description = 'Calculate evolving trauma, occult bleeding, airway, neuro, transfusion and procedure readiness.' },
    { label = 'Start V14 Trauma Clock', value = 'trauma_clock_v14', group = 'TIME CRITICAL V14', description = 'Start a non-destructive time-critical trauma evolution session and advance it five minutes.', confirm = true },
    { label = 'Activate V14 Trauma Center', value = 'trauma_activation_v14', group = 'TRAUMA COMMAND V14', description = 'Create a trauma activation and notify medical dispatch.', confirm = true },
    { label = 'Activate Massive Transfusion', value = 'mtp_v14', group = 'RESUSCITATION V14', description = 'Open a balanced massive-transfusion case for the selected patient.', confirm = true },
    { label = 'Create Procedure Safety Checklist', value = 'procedure_checklist_v14', group = 'PROCEDURE SAFETY V14', description = 'Create a damage-control procedure checklist with airway, blood, consent and monitoring steps.' },
    { label = 'Compare Trauma Destinations', value = 'destination_compare_v14', group = 'TRANSPORT V14', description = 'Compare local ED, regional trauma center and level-one destination options.' },
    { label = 'Run Full V14 System Test', value = 'system_test_v14', group = 'SYSTEM V14', description = 'Validate the v14 trauma-command boards across all 20 resources.', confirm = true },
    { label = 'Go To Patient', value = 'goto', group = 'MOVEMENT', description = 'Teleport yourself to the selected patient.' },
    { label = 'Bring Patient', value = 'bring', group = 'MOVEMENT', description = 'Teleport the selected patient to your current location.' },
    { label = 'Incapacitate', value = 'incapacitate', group = 'LIFE STATE', description = 'Force the patient into the DPN incapacitated state.', dangerous = true, confirm = true },
    { label = 'Mark Deceased', value = 'mark_dead', group = 'LIFE STATE', description = 'Force the patient into the DPN deceased state and zero vital signs.', dangerous = true, confirm = true }
}

local function log(message)
    print(('[dpn-medical-admin-tools] NATIVE CLIENT %s'):format(tostring(message)))
end

local function debugLog(message)
    if Config.Debug then log(message) end
end

local function getCore()
    if QBCore then return QBCore end
    local ok, core = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if ok then QBCore = core end
    return QBCore
end

local function notify(message, kind)
    local core = getCore()
    if core and core.Functions and core.Functions.Notify then
        core.Functions.Notify(tostring(message), kind or 'primary', 6000)
    else
        TriggerEvent('chat:addMessage', {
            color = { 70, 170, 255 },
            args = { 'DPN Medical Admin', tostring(message) }
        })
    end
end

local function clamp(value, minimum, maximum)
    if maximum < minimum then return minimum end
    if value < minimum then return maximum end
    if value > maximum then return minimum end
    return value
end

local function rowsForTab()
    if not payload then return {} end
    if activeTab == 1 then return type(payload.patients) == 'table' and payload.patients or {} end
    if activeTab == 2 then return type(payload.tests) == 'table' and payload.tests or {} end
    if activeTab == 3 then return type(payload.precisionRows) == 'table' and payload.precisionRows or {} end
    if activeTab == 4 then return type(payload.autonomousRows) == 'table' and payload.autonomousRows or {} end
    if activeTab == 5 then return type(payload.v12Rows) == 'table' and payload.v12Rows or {} end
    if activeTab == 6 then return type(payload.v13Rows) == 'table' and payload.v13Rows or {} end
    if activeTab == 7 then return type(payload.v14Rows) == 'table' and payload.v14Rows or {} end
    if activeTab == 8 then return type(payload.modules) == 'table' and payload.modules or {} end
    return type(payload.audit) == 'table' and payload.audit or {}
end

local function closeMenu(reason)
    openSequence = openSequence + 1
    menuOpen = false
    waitingForServer = false
    payload = nil
    activeTab = 1
    selectedRow = 1
    selectedAction = 1
    selectedTest = 1
    selectedPatientId = nil
    mode = 'list'
    statusMessage = ''
    pendingConfirmation = nil
    confirmUntil = 0
    actionPending = false
    actionPendingUntil = 0
    TriggerServerEvent('dpn-medical-admin-tools:server:menuClosed')
    if reason then debugLog('closed: ' .. tostring(reason)) end
end

local function requestOpen()
    if menuOpen then
        closeMenu('toggle')
        return
    end
    if waitingForServer then
        notify('Medical Admin is already waiting for server authorization.', 'error')
        return
    end
    waitingForServer = true
    TriggerServerEvent('dpn-medical-admin-tools:server:requestOpenNative')
    log('REQUEST_OPEN_NATIVE sent')
    local sequence = openSequence + 1
    openSequence = sequence
    SetTimeout(8000, function()
        if waitingForServer and openSequence == sequence then
            waitingForServer = false
            notify('Medical Admin did not receive a server response. Check the server console.', 'error')
            log('SERVER_RESPONSE_TIMEOUT')
        end
    end)
end

local function requestRefresh()
    if not menuOpen then return end
    local now = GetGameTimer()
    if now - lastRefreshAt < (tonumber(Config.RefreshCooldownMs) or 750) then return end
    lastRefreshAt = now
    TriggerServerEvent('dpn-medical-admin-tools:server:refreshNative')
    statusMessage = 'Refreshing live medical data...'
    statusUntil = now + 2500
end

local function selectedPatient()
    if not payload or type(payload.patients) ~= 'table' then return nil end
    for _, patient in ipairs(payload.patients) do
        if tonumber(patient.id) == tonumber(selectedPatientId) then return patient end
    end
    local patient = payload.patients[1]
    if patient then selectedPatientId = tonumber(patient.id) end
    return patient
end

local function cycleTestTarget(direction)
    local patients = payload and payload.patients or {}
    if #patients == 0 then selectedPatientId = nil return end
    local index = 1
    for i, patient in ipairs(patients) do
        if tonumber(patient.id) == tonumber(selectedPatientId) then index = i break end
    end
    index = clamp(index + direction, 1, #patients)
    selectedPatientId = tonumber(patients[index].id)
end

local function drawText(text, x, y, scale, r, g, b, a, center)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r or 235, g or 244, b or 255, a or 255)
    SetTextOutline()
    SetTextCentre(center == true)
    SetTextEntry('STRING')
    AddTextComponentSubstringPlayerName(tostring(text or ''))
    DrawText(x, y)
end

local function drawRect(x, y, width, height, r, g, b, a)
    DrawRect(x, y, width, height, r, g, b, a)
end

local function updateMouseState()
    mouse.consumed = false
    mouse.left = false
    mouse.right = false
    mouse.wheelUp = false
    mouse.wheelDown = false

    if Config.EnableMouse == false then return end

    if type(SetMouseCursorThisFrame) == 'function' then
        SetMouseCursorThisFrame()
    elseif type(SetMouseCursorActiveThisFrame) == 'function' then
        SetMouseCursorActiveThisFrame()
    end
    if type(SetMouseCursorSprite) == 'function' then
        SetMouseCursorSprite(tonumber(Config.MouseCursorSprite) or 1)
    end

    mouse.x = GetDisabledControlNormal(0, 239)
    mouse.y = GetDisabledControlNormal(0, 240)
    mouse.left = IsDisabledControlJustPressed(0, 237) or IsDisabledControlJustPressed(0, 24)
    mouse.right = IsDisabledControlJustPressed(0, 238) or IsDisabledControlJustPressed(0, 25)

    if Config.MouseWheelNavigation ~= false then
        mouse.wheelUp = IsDisabledControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 15)
        mouse.wheelDown = IsDisabledControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 14)
    end
end

local function mouseInside(x, y, width, height)
    if Config.EnableMouse == false then return false end
    return mouse.x >= (x - width / 2)
        and mouse.x <= (x + width / 2)
        and mouse.y >= (y - height / 2)
        and mouse.y <= (y + height / 2)
end

local function mouseClicked(x, y, width, height)
    if mouse.consumed or not mouse.left or not mouseInside(x, y, width, height) then return false end
    mouse.consumed = true
    return true
end

local function drawButton(label, x, y, width, height, danger, disabled)
    local hovered = not disabled and mouseInside(x, y, width, height)
    local r, g, b = 12, 35, 58
    if hovered then
        if danger then r, g, b = 118, 31, 43 else r, g, b = 18, 77, 118 end
    elseif danger then
        r, g, b = 78, 24, 34
    end
    if disabled then r, g, b = 28, 35, 45 end
    drawRect(x, y, width, height, r, g, b, 245)
    drawText(label, x, y - 0.014, 0.27, disabled and 110 or 225, disabled and 122 or 239, disabled and 136 or 252, 255, true)
    return hovered and mouseClicked(x, y, width, height)
end

local function trim(text, length)
    text = tostring(text or '')
    if #text <= length then return text end
    return text:sub(1, math.max(1, length - 3)) .. '...'
end

local function lifeColour(state)
    state = tostring(state or 'alive'):lower()
    if state == 'dead' then return 255, 88, 108 end
    if state == 'incapacitated' then return 255, 173, 103 end
    return 73, 215, 157
end

local function drawHeader()
    drawRect(0.5, 0.12, 0.82, 0.065, 7, 18, 33, 245)
    drawText('DPN MEDICAL ADMINISTRATION', 0.105, 0.094, 0.48, 74, 176, 255, 255, false)
    local serverName = payload and payload.serverName or 'DPN Medical Server'
    local adminName = payload and payload.admin and payload.admin.name or GetPlayerName(PlayerId()) or 'Administrator'
    drawText(trim(serverName, 46), 0.105, 0.125, 0.31, 150, 176, 207, 255, false)
    drawText('Administrator: ' .. trim(adminName, 22), 0.56, 0.125, 0.28, 210, 229, 248, 255, false)

    if drawButton('REFRESH', 0.80, 0.12, 0.075, 0.040, false, false) then
        requestRefresh()
    end
    if drawButton('CLOSE', 0.875, 0.12, 0.060, 0.040, true, false) then
        closeMenu('mouse close')
    end
end

local function drawTabs()
    local startX = 0.105
    for index, label in ipairs(tabs) do
        local x = startX + ((index - 1) * 0.12)
        local centerX = x + 0.052
        local selected = activeTab == index
        local hovered = mouseInside(centerX, 0.174, 0.105, 0.042)
        drawRect(centerX, 0.174, 0.105, 0.042,
            selected and 22 or (hovered and 18 or 12),
            selected and 62 or (hovered and 50 or 28),
            selected and 95 or (hovered and 76 or 48), 238)
        drawText(label, centerX, 0.161, 0.31, selected and 235 or 150, selected and 246 or 176, selected and 255 or 207, 255, true)
        if mouseClicked(centerX, 0.174, 0.105, 0.042) then
            activeTab = index
            selectedRow = 1
            mode = 'list'
            pendingConfirmation = nil
            confirmUntil = 0
        end
    end
    drawText('Mouse: click tabs, rows and actions | Wheel: scroll | Right-click: back | Keyboard controls remain active', 0.5, 0.198, 0.255, 142, 166, 198, 255, true)
end

local function drawStats()
    local stats = payload and payload.stats or {}
    local values = {
        { 'Players', stats.players or 0 },
        { 'Alive', stats.alive or 0 },
        { 'Incapacitated', stats.incapacitated or 0 },
        { 'Deceased', stats.dead or 0 },
        { 'Admitted', stats.admitted or 0 },
        { 'Modules', tostring(stats.modulesStarted or 0) .. '/' .. tostring(stats.modulesExpected or 20) }
    }
    local startX = 0.105
    for index, item in ipairs(values) do
        local x = startX + ((index - 1) * 0.132)
        drawRect(x + 0.058, 0.241, 0.116, 0.062, 12, 28, 48, 238)
        drawText(item[2], x + 0.058, 0.218, 0.39, 235, 246, 255, 255, true)
        drawText(item[1], x + 0.058, 0.248, 0.25, 142, 166, 198, 255, true)
    end
end

local function drawPatients(rows)
    drawRect(0.295, 0.555, 0.38, 0.56, 7, 18, 33, 238)
    drawRect(0.69, 0.555, 0.40, 0.56, 7, 18, 33, 238)
    drawText('CONNECTED PATIENTS', 0.115, 0.286, 0.33, 74, 176, 255, 255, false)

    local visible = 11
    local start = math.max(1, selectedRow - math.floor(visible / 2))
    if start + visible - 1 > #rows then start = math.max(1, #rows - visible + 1) end

    if #rows == 0 then
        drawText('No connected patients were returned.', 0.295, 0.50, 0.34, 150, 176, 207, 255, true)
    end

    for line = 1, visible do
        local index = start + line - 1
        local row = rows[index]
        if row then
            local y = 0.322 + ((line - 1) * 0.043)
            local hovered = mouseInside(0.295, y + 0.014, 0.35, 0.037)
            local selected = index == selectedRow
            drawRect(0.295, y + 0.014, 0.35, 0.037,
                selected and 16 or (hovered and 16 or 12),
                selected and 55 or (hovered and 45 or 30),
                selected and 84 or (hovered and 70 or 50), selected and 245 or 220)
            local lr, lg, lb = lifeColour(row.lifeState)
            drawRect(0.128, y + 0.014, 0.005, 0.029, lr, lg, lb, 255)
            drawText(('#%s  %s'):format(tostring(row.id or '?'), trim(row.name or 'Unknown', 24)), 0.138, y, 0.30, 235, 246, 255, 255, false)
            drawText(trim((row.job or 'Unknown') .. ' | ' .. tostring(row.lifeState or 'alive'), 26), 0.335, y, 0.26, 150, 176, 207, 255, false)
            if mouseClicked(0.295, y + 0.014, 0.35, 0.037) then
                selectedRow = index
                selectedPatientId = tonumber(row.id)
                pendingConfirmation = nil
                confirmUntil = 0
            end
        end
    end

    local patient = rows[selectedRow]
    if patient then
        selectedPatientId = tonumber(patient.id)
        drawText(trim(patient.name or 'Unknown Patient', 34), 0.505, 0.286, 0.42, 235, 246, 255, 255, false)
        drawText(('ID #%s | %s | %s'):format(tostring(patient.id or '?'), trim(patient.citizenid or 'unknown', 18), trim(patient.job or 'Unknown', 18)), 0.505, 0.321, 0.28, 150, 176, 207, 255, false)
        local lr, lg, lb = lifeColour(patient.lifeState)
        drawText(('STATE: %s   TRIAGE: %s'):format(tostring(patient.lifeState or 'alive'):upper(), tostring(patient.triage or 'green'):upper()), 0.505, 0.356, 0.31, lr, lg, lb, 255, false)

        local vitals = {
            ('Heart Rate: %s bpm'):format(tostring(patient.hr or 0)),
            ('Blood Pressure: %s/%s'):format(tostring(patient.systolic or 0), tostring(patient.diastolic or 0)),
            ('Respirations: %s/min'):format(tostring(patient.rr or 0)),
            ('SpO2: %s%%'):format(tostring(patient.spo2 or 0)),
            ('Blood: %s mL | MAP %s'):format(tostring(patient.blood or 0), tostring(patient.map or 0)),
            ('GCS %s | Lactate %s'):format(tostring(patient.gcs or 15), tostring(patient.lactate or 1.0)),
            ('Command: %s%% | Arrest: %s'):format(tostring(patient.commandRisk or 0), (tonumber(patient.arrestMinutes) or -1) > 0 and (tostring(patient.arrestMinutes) .. 'm') or 'not imminent'),
            ('Clot: %s%% | Gaps: %s | %s'):format(tostring(patient.clotStability or 100), tostring(patient.careGaps or 0), tostring(patient.acidBase or 'normal'):gsub('_', ' '))
        }
        for index, text in ipairs(vitals) do
            local column = (index - 1) % 2
            local rowIndex = math.floor((index - 1) / 2)
            drawRect(0.595 + column * 0.19, 0.415 + rowIndex * 0.07, 0.175, 0.052, 12, 28, 48, 235)
            drawText(text, 0.513 + column * 0.19, 0.399 + rowIndex * 0.07, 0.28, 220, 235, 250, 255, false)
        end

        if drawButton('OPEN SECURED ACTIONS', 0.69, 0.724, 0.29, 0.045, false, false) then
            selectedAction = 1
            pendingConfirmation = nil
            confirmUntil = 0
            mode = 'actions'
        end
    end
end

local function drawMedicalTests(rows)
    drawRect(0.295, 0.555, 0.38, 0.56, 7, 18, 33, 238)
    drawRect(0.69, 0.555, 0.40, 0.56, 7, 18, 33, 238)
    drawText('MEDICAL TEST LABORATORY', 0.115, 0.286, 0.33, 74, 176, 255, 255, false)

    local visible = 11
    selectedRow = clamp(selectedRow, 1, math.max(1, #rows))
    selectedTest = selectedRow
    local start = math.max(1, selectedRow - math.floor(visible / 2))
    if start + visible - 1 > #rows then start = math.max(1, #rows - visible + 1) end

    if #rows == 0 then
        drawText('Test catalog unavailable. Verify dpn-medical-core v7.', 0.295, 0.50, 0.31, 255, 130, 135, 255, true)
    end

    for line = 1, visible do
        local index = start + line - 1
        local row = rows[index]
        if row then
            local y = 0.322 + ((line - 1) * 0.043)
            local hovered = mouseInside(0.295, y + 0.014, 0.35, 0.037)
            local selected = index == selectedRow
            local danger = row.dangerous == true
            drawRect(0.295, y + 0.014, 0.35, 0.037,
                selected and (danger and 92 or 16) or (hovered and (danger and 78 or 16) or 12),
                selected and (danger and 25 or 55) or (hovered and (danger and 28 or 45) or 30),
                selected and (danger and 38 or 84) or (hovered and (danger and 42 or 70) or 50), selected and 245 or 220)
            drawText(trim(row.label or row.id or 'Unknown Test', 31), 0.13, y, 0.285, 235, 246, 255, 255, false)
            drawText(trim(row.category or 'TEST', 14), 0.397, y, 0.225, danger and 255 or 125, danger and 118 or 184, danger and 132 or 220, 255, true)
            if mouseClicked(0.295, y + 0.014, 0.35, 0.037) then
                selectedRow = index
                selectedTest = index
                pendingConfirmation = nil
                confirmUntil = 0
            end
        end
    end

    local patient = selectedPatient()
    local test = rows[selectedRow]
    drawText('TEST TARGET', 0.505, 0.286, 0.27, 74, 176, 255, 255, false)
    if patient then
        drawText(trim(patient.name or 'Unknown Patient', 34), 0.505, 0.317, 0.40, 235, 246, 255, 255, false)
        drawText(('ID #%s | %s | %s'):format(tostring(patient.id or '?'), tostring(patient.lifeState or 'alive'):upper(), tostring(patient.triage or 'green'):upper()), 0.505, 0.352, 0.28, 150, 176, 207, 255, false)
        if drawButton('PREVIOUS TARGET', 0.585, 0.398, 0.145, 0.040, false, false) then cycleTestTarget(-1) end
        if drawButton('NEXT TARGET', 0.745, 0.398, 0.145, 0.040, false, false) then cycleTestTarget(1) end
    else
        drawText('No connected patient is available.', 0.505, 0.326, 0.31, 255, 130, 135, 255, false)
    end

    if test then
        drawRect(0.69, 0.515, 0.35, 0.165, 10, 27, 47, 242)
        drawText(test.category or 'TEST', 0.525, 0.443, 0.25, test.dangerous and 255 or 74, test.dangerous and 118 or 176, test.dangerous and 132 or 255, 255, false)
        drawText(trim(test.label or test.id or '', 48), 0.525, 0.474, 0.36, 235, 246, 255, 255, false)
        drawText(trim(test.description or '', 92), 0.525, 0.518, 0.275, 205, 224, 244, 255, false)
        local warning = test.nonDestructive and 'NON-DESTRUCTIVE SYSTEM CHECK' or (test.dangerous and 'DANGEROUS SIMULATION — TEST ENVIRONMENT ONLY' or 'CONTROLLED PATIENT SIMULATION')
        drawText(warning, 0.69, 0.578, 0.245, test.dangerous and 255 or 142, test.dangerous and 110 or 196, test.dangerous and 125 or 224, 255, true)

        if pendingConfirmation == ('test:' .. tostring(test.id)) and GetGameTimer() < confirmUntil then
            drawText('CONFIRM: click RUN TEST again within 4 seconds', 0.69, 0.628, 0.27, 255, 108, 122, 255, true)
        end
        if drawButton('RUN SELECTED TEST', 0.69, 0.680, 0.29, 0.048, test.dangerous == true, not patient or actionPending) then
            executeSelectedTest()
        end
        drawText('Every run is permission-checked, audited, snapshot-backed, and restorable.', 0.69, 0.724, 0.245, 142, 166, 198, 255, true)
    end
end


local function drawPrecisionOps(rows)
    drawRect(0.5, 0.555, 0.78, 0.56, 7, 18, 33, 238)
    drawText('CRITICAL-CARE COMMAND NETWORK — V10', 0.12, 0.286, 0.33, 74, 176, 255, 255, false)
    local dashboard = payload and payload.precision or {}
    drawText(('Critical: %s | Imminent Arrest: %s | Care Gaps: %s | Active Commands: %s'):format(tostring(dashboard.critical or 0), tostring(dashboard.imminentArrest or 0), tostring(dashboard.careGaps or 0), tostring(dashboard.activeCommands or 0)), 0.50, 0.286, 0.28, 150, 176, 207, 255, true)
    local visible = 11
    local start = math.max(1, selectedRow - math.floor(visible / 2))
    if start + visible - 1 > #rows then start = math.max(1, #rows - visible + 1) end
    if #rows == 0 then drawText('No precision patient data is available.', 0.5, 0.50, 0.34, 150, 176, 207, 255, true) end
    for line = 1, visible do
        local index = start + line - 1
        local row = rows[index]
        if row then
            local y = 0.330 + ((line - 1) * 0.043)
            local hovered = mouseInside(0.5, y + 0.014, 0.73, 0.037)
            local selected = index == selectedRow
            local risk = tonumber(row.risk) or 0
            drawRect(0.5, y + 0.014, 0.73, 0.037, selected and 16 or (hovered and 16 or 12), selected and 55 or (hovered and 45 or 30), selected and 84 or (hovered and 70 or 50), selected and 245 or 220)
            drawText(trim(('#%s %s'):format(tostring(row.id or '?'), row.name or row.citizenid or 'Patient'), 30), 0.15, y, 0.285, 235, 246, 255, 255, false)
            drawText(('Command Risk %s%% | ICU Need %s%%'):format(tostring(risk), tostring(row.icuNeed or '?')), 0.40, y, 0.265, risk >= 70 and 255 or 150, risk >= 70 and 105 or 190, risk >= 70 and 120 or 230, 255, false)
            drawText(('Arrest %s min | Clot %s%% | %s'):format(tostring(row.minutesToCritical or '-'), tostring(row.clotStability or '?'), tostring(row.destination or 'routine')), 0.62, y, 0.245, 150, 176, 207, 255, false)
            if mouseClicked(0.5, y + 0.014, 0.73, 0.037) then selectedRow = index; selectedPatientId = tonumber(row.id) or selectedPatientId end
        end
    end
end

local function drawAutonomousNetwork(rows)
    local dashboard = payload and payload.autonomousNetwork or {}
    drawRect(0.5, 0.525, 0.74, 0.61, 5, 14, 27, 242)
    drawText('V11 AUTONOMOUS CARE NETWORK', 0.5, 0.235, 0.42, 88, 205, 255, 255, true)
    drawText(('Immediate %s | Critical %s | High intensity %s | Reassessments %s | Open plans %s'):format(
        tostring(dashboard.immediate or 0), tostring(dashboard.critical or 0), tostring(dashboard.highIntensity or 0),
        tostring(dashboard.activeReassessments or 0), tostring(dashboard.openPlans or 0)),
        0.5, 0.270, 0.28, 170, 196, 224, 255, true)
    local visible = 10
    local start = math.max(1, selectedRow - math.floor(visible / 2))
    if start + visible - 1 > #rows then start = math.max(1, #rows - visible + 1) end
    if #rows == 0 then drawText('No v11 autonomous-care patient data is available.', 0.5, 0.50, 0.34, 150, 176, 207, 255, true) end
    for line = 1, visible do
        local index = start + line - 1
        local row = rows[index]
        if row then
            local y = 0.315 + ((line - 1) * 0.046)
            local hovered = mouseInside(0.5, y + 0.015, 0.68, 0.040)
            local selected = index == selectedRow
            local critical = (tonumber(row.risk) or 0) >= 70
            drawRect(0.5, y + 0.015, 0.68, 0.040,
                selected and (critical and 96 or 18) or (hovered and (critical and 72 or 15) or 10),
                selected and (critical and 28 or 58) or (hovered and (critical and 31 or 48) or 27),
                selected and (critical and 40 or 90) or (hovered and (critical and 44 or 74) or 46), 238)
            drawText(trim(('#%s %s'):format(row.id or '?', row.name or 'Unknown'), 23), 0.18, y, 0.275, 232, 245, 255, 255, false)
            drawText(('Risk %s%%'):format(row.risk or 0), 0.385, y, 0.255, critical and 255 or 120, critical and 120 or 210, critical and 130 or 245, 255, true)
            drawText(('Mort %s%%'):format(row.mortality or 0), 0.49, y, 0.245, 225, 225, 240, 255, true)
            drawText(('Home %s%%'):format(row.homeostasis or 0), 0.59, y, 0.245, 100, 220, 170, 255, true)
            drawText(trim(row.levelOfCare or 'unknown', 16), 0.715, y, 0.235, 170, 196, 224, 255, true)
            if row.continuousReassessment then drawText('LIVE', 0.805, y, 0.225, 88, 255, 175, 255, true) end
            if mouseClicked(0.5, y + 0.015, 0.68, 0.040) then
                selectedRow = index
                selectedPatientId = tonumber(row.id)
            end
        end
    end
    local selected = rows[selectedRow]
    if selected then
        drawText(('Priority %s | Resource intensity %s%% | Tissue O2 %s%% | Frailty %s%% | Active plans %s'):format(
            tostring(selected.priority), tostring(selected.resourceIntensity), tostring(selected.tissueOxygenation),
            tostring(selected.frailty), tostring(selected.activePlans)), 0.5, 0.805, 0.265, 210, 230, 248, 255, true)
        if drawButton('OPEN PATIENT ACTIONS', 0.5, 0.845, 0.27, 0.045, false, false) then
            selectedPatientId = tonumber(selected.id)
            selectedAction = 1
            mode = 'actions'
        end
    end
end

local function drawV12Network(rows)
    local dashboard = payload and payload.v12Network or {}
    drawRect(0.5, 0.525, 0.78, 0.61, 5, 14, 27, 242)
    drawText('V12 INTEGRATED CRITICAL-CARE NETWORK', 0.5, 0.235, 0.42, 96, 220, 255, 255, true)
    drawText(('Critical %s | Special populations %s | Support candidates %s | Low confidence %s | Sessions %s | Transactions %s/%s'):format(
        tostring(dashboard.critical or 0), tostring(dashboard.specialPopulationPatients or 0),
        tostring(dashboard.organSupportCandidates or 0), tostring(dashboard.lowConfidencePatients or 0),
        tostring(dashboard.activeSessions or 0), tostring(dashboard.pendingTransactions or 0), tostring(dashboard.failedTransactions or 0)),
        0.5, 0.270, 0.265, 170, 196, 224, 255, true)
    local visible = 10
    local start = math.max(1, selectedRow - math.floor(visible / 2))
    if start + visible - 1 > #rows then start = math.max(1, #rows - visible + 1) end
    if #rows == 0 then drawText('No v12 integrated patient data is available.', 0.5, 0.50, 0.34, 150, 176, 207, 255, true) end
    for line = 1, visible do
        local index = start + line - 1
        local row = rows[index]
        if row then
            local y = 0.315 + ((line - 1) * 0.046)
            local hovered = mouseInside(0.5, y + 0.015, 0.72, 0.040)
            local selected = index == selectedRow
            local critical = (tonumber(row.risk) or 0) >= 70
            drawRect(0.5, y + 0.015, 0.72, 0.040,
                selected and (critical and 96 or 18) or (hovered and (critical and 72 or 15) or 10),
                selected and (critical and 28 or 58) or (hovered and (critical and 31 or 48) or 27),
                selected and (critical and 40 or 90) or (hovered and (critical and 44 or 74) or 46), 238)
            drawText(trim(('#%s %s'):format(row.id or '?', row.name or 'Unknown'), 22), 0.15, y, 0.27, 232, 245, 255, 255, false)
            drawText(('Risk %s%%'):format(row.risk or 0), 0.36, y, 0.25, critical and 255 or 120, critical and 120 or 210, critical and 130 or 245, 255, true)
            drawText(trim(row.commandLevel or 'routine', 13), 0.46, y, 0.235, 225, 225, 240, 255, true)
            drawText(trim(row.population or 'adult', 10), 0.56, y, 0.235, 100, 220, 170, 255, true)
            drawText(('Conf %s%%'):format(row.confidence or 0), 0.66, y, 0.235, 170, 196, 224, 255, true)
            drawText(trim(row.destination or 'self_care', 16), 0.78, y, 0.225, 170, 196, 224, 255, true)
            if row.activeSession then drawText('LIVE', 0.855, y, 0.215, 88, 255, 175, 255, true) end
            if mouseClicked(0.5, y + 0.015, 0.72, 0.040) then
                selectedRow = index
                selectedPatientId = tonumber(row.id)
            end
        end
    end
    local selected = rows[selectedRow]
    if selected then
        drawText(('Decomp %s min | Cardiac reserve %s%% | P/F %s | Supports %s | Protocols %s | Trends %s'):format(
            tostring(selected.decompensationMinutes or '-'), tostring(selected.cardiacReserve or 0),
            tostring(selected.pfRatio or '-'), tostring(selected.supportCount or 0),
            tostring(selected.protocolCount or 0), tostring(selected.trendPoints or 0)),
            0.5, 0.805, 0.255, 210, 230, 248, 255, true)
        if drawButton('OPEN V12 PATIENT ACTIONS', 0.5, 0.845, 0.29, 0.045, false, false) then
            selectedPatientId = tonumber(selected.id)
            selectedAction = 1
            mode = 'actions'
        end
    end
end

local function drawV13Continuum(rows)
    drawText('V13 CONTINUUM COMMAND NETWORK',0.5,0.235,0.42,98,220,255,255,true)
    local dashboard=payload and payload.v13Network or{}
    drawText(('Critical %s | Coagulopathy %s | Toxicity %s | Infection %s | Low confidence %s | Simulations %s'):format(tostring(dashboard.critical or 0),tostring(dashboard.coagulopathy or 0),tostring(dashboard.toxicity or 0),tostring(dashboard.infection or 0),tostring(dashboard.lowConfidence or 0),tostring(dashboard.activeSimulations or 0)),0.5,0.276,0.27,190,218,242,255,true)
    local start=math.max(1,selectedRow-5);local finish=math.min(#rows,start+10)
    for index=start,finish do local row=rows[index];local y=0.325+(index-start)*0.043;local selected=index==selectedRow;drawRect(0.5,y,0.82,0.037,selected and 28 or 16,selected and 92 or 38,selected and 126 or 55,selected and 225 or 195);drawText(('%s [%s]'):format(row.name or row.citizenid or'Unknown',tostring(row.id or'?')),0.105,y-0.010,0.27,235,246,255,255,false);drawText(('Risk %s%% | %s | Res %s%% | Clot %s%% | Tox %s%% | Inf %s%% | Conf %s%%'):format(tostring(row.risk or 0),tostring(row.destination or'unknown'),tostring(row.resilience or 0),tostring(row.clot or 0),tostring(row.toxicity or 0),tostring(row.infection or 0),tostring(row.confidence or 0)),0.37,y-0.010,0.245,190,218,242,255,false);if mouseClicked(0.5,y,0.82,0.037)then selectedRow=index;selectedPatientId=tonumber(row.id)end end
    if rows[selectedRow]and drawButton('OPEN V13 PATIENT ACTIONS',0.5,0.845,0.29,0.045,false,false)then selectedPatientId=tonumber(rows[selectedRow].id);mode='actions';selectedAction=1 end
end

local function drawV14Trauma(rows)
    drawText('V14 TIME-CRITICAL TRAUMA OPERATIONS',0.5,0.235,0.42,255,156,78,255,true)
    local dashboard=payload and payload.v14Network or{}
    drawText(('Trauma 1 %s | Airway threats %s | Occult bleeds %s | Compartment risks %s | Active MTP %s | Trauma clocks %s'):format(tostring(dashboard.traumaOne or 0),tostring(dashboard.airwayThreat or 0),tostring(dashboard.occultBleed or 0),tostring(dashboard.compartmentRisk or 0),tostring(dashboard.activeMTP or 0),tostring(dashboard.activeSessions or 0)),0.5,0.276,0.27,232,211,188,255,true)
    local start=math.max(1,selectedRow-5);local finish=math.min(#rows,start+10)
    for index=start,finish do
        local row=rows[index];local y=0.325+(index-start)*0.043;local selected=index==selectedRow
        drawRect(0.5,y,0.82,0.037,selected and 112 or 42,selected and 58 or 31,selected and 24 or 18,selected and 230 or 200)
        drawText(('%s [%s]'):format(row.name or row.citizenid or'Unknown',tostring(row.id or'?')),0.105,y-0.010,0.27,255,244,232,255,false)
        drawText(('Risk %s%% | %s | Golden %sm | Occult %s%% | Airway %s%% | Proc %s%% | Demand %s%%'):format(tostring(row.risk or 0),tostring(row.tier or'none'),tostring(row.goldenHour or 0),tostring(row.occult or 0),tostring(row.airway or 0),tostring(row.procedure or 0),tostring(row.resourceDemand or 0)),0.37,y-0.010,0.245,236,210,186,255,false)
        if mouseClicked(0.5,y,0.82,0.037)then selectedRow=index;selectedPatientId=tonumber(row.id)end
    end
    if rows[selectedRow]and drawButton('OPEN V14 TRAUMA ACTIONS',0.5,0.845,0.29,0.045,false,false)then selectedPatientId=tonumber(rows[selectedRow].id);mode='actions';selectedAction=1 end
end

local function drawModules(rows)
    drawRect(0.5, 0.555, 0.78, 0.56, 7, 18, 33, 238)
    drawText('DPN MEDICAL MODULE HEALTH', 0.12, 0.286, 0.33, 74, 176, 255, 255, false)
    local visible = 13
    local start = math.max(1, selectedRow - math.floor(visible / 2))
    if start + visible - 1 > #rows then start = math.max(1, #rows - visible + 1) end
    for line = 1, visible do
        local index = start + line - 1
        local row = rows[index]
        if row then
            local y = 0.322 + ((line - 1) * 0.035)
            local hovered = mouseInside(0.5, y + 0.012, 0.73, 0.030)
            local selected = index == selectedRow
            drawRect(0.5, y + 0.012, 0.73, 0.030,
                selected and 16 or (hovered and 16 or 12),
                selected and 55 or (hovered and 45 or 30),
                selected and 84 or (hovered and 70 or 50), selected and 245 or 220)
            local started = row.started == true
            drawRect(0.145, y + 0.012, 0.008, 0.018, started and 73 or 255, started and 215 or 88, started and 157 or 108, 255)
            drawText(trim(row.name or 'Unknown module', 38), 0.158, y, 0.29, 235, 246, 255, 255, false)
            drawText(('v%s | %s | %s'):format(tostring(row.version or 'unknown'), tostring(row.state or 'missing'), row.registered and 'registered' or 'not registered'), 0.53, y, 0.27, 150, 176, 207, 255, false)
            if mouseClicked(0.5, y + 0.012, 0.73, 0.030) then selectedRow = index end
        end
    end
end

local function drawAudit(rows)
    drawRect(0.5, 0.555, 0.78, 0.56, 7, 18, 33, 238)
    drawText('MEDICAL ADMIN AUDIT LOG', 0.12, 0.286, 0.33, 74, 176, 255, 255, false)
    local visible = 12
    local start = math.max(1, selectedRow - math.floor(visible / 2))
    if start + visible - 1 > #rows then start = math.max(1, #rows - visible + 1) end
    if #rows == 0 then drawText('No audit entries are available.', 0.5, 0.50, 0.34, 150, 176, 207, 255, true) end
    for line = 1, visible do
        local index = start + line - 1
        local row = rows[index]
        if row then
            local y = 0.322 + ((line - 1) * 0.039)
            local hovered = mouseInside(0.5, y + 0.013, 0.73, 0.034)
            local selected = index == selectedRow
            drawRect(0.5, y + 0.013, 0.73, 0.034,
                selected and 16 or (hovered and 16 or 12),
                selected and 55 or (hovered and 45 or 30),
                selected and 84 or (hovered and 70 or 50), selected and 245 or 220)
            drawText(trim(row.created_at or '--', 20), 0.15, y, 0.27, 150, 176, 207, 255, false)
            drawText(trim(row.actor_cid or 'unknown', 21), 0.30, y, 0.27, 220, 235, 250, 255, false)
            drawText(trim(row.action or 'unknown', 24), 0.48, y, 0.27, 74, 176, 255, 255, false)
            drawText('Target: ' .. trim(row.target or '--', 12), 0.69, y, 0.27, 220, 235, 250, 255, false)
            if mouseClicked(0.5, y + 0.013, 0.73, 0.034) then selectedRow = index end
        end
    end
end

local function drawActionMenu(patient)
    drawRect(0.5, 0.52, 0.58, 0.70, 5, 14, 27, 248)
    drawText('ADVANCED SECURED PATIENT ACTIONS', 0.5, 0.185, 0.43, 74, 176, 255, 255, true)
    drawText(trim(('#%s  %s'):format(tostring(patient.id or '?'), patient.name or 'Unknown'), 52), 0.5, 0.225, 0.33, 235, 246, 255, 255, true)
    drawText('Click an action to execute | Confirmed actions require a second click | Right-click to return', 0.5, 0.257, 0.255, 150, 176, 207, 255, true)

    if drawButton('BACK', 0.745, 0.196, 0.072, 0.038, false, false) then
        mode = 'list'
        pendingConfirmation = nil
        confirmUntil = 0
        return
    end

    local visible = 9
    local start = math.max(1, selectedAction - math.floor(visible / 2))
    if start + visible - 1 > #actions then start = math.max(1, #actions - visible + 1) end

    for line = 1, visible do
        local index = start + line - 1
        local action = actions[index]
        if action then
            local y = 0.304 + ((line - 1) * 0.049)
            local hovered = mouseInside(0.5, y + 0.016, 0.50, 0.040)
            local selected = index == selectedAction
            local danger = action.dangerous == true
            drawRect(0.5, y + 0.016, 0.50, 0.040,
                selected and (danger and 105 or 22) or (hovered and (danger and 92 or 18) or 12),
                selected and (danger and 25 or 62) or (hovered and (danger and 28 or 50) or 28),
                selected and (danger and 35 or 95) or (hovered and (danger and 40 or 76) or 48),
                240)
            drawText(action.label, 0.31, y, 0.29, 235, 246, 255, 255, false)
            drawText(action.group or 'ACTION', 0.665, y, 0.23, danger and 255 or 130, danger and 120 or 180, danger and 130 or 220, 255, true)
            if mouseClicked(0.5, y + 0.016, 0.50, 0.040) then
                selectedAction = index
                executeSelectedAction()
            end
        end
    end

    local selected = actions[selectedAction]
    if selected then
        drawRect(0.5, 0.782, 0.50, 0.105, 10, 27, 47, 242)
        drawText(selected.group or 'ACTION', 0.27, 0.742, 0.25, 74, 176, 255, 255, false)
        drawText(trim(selected.description or '', 88), 0.27, 0.774, 0.27, 220, 235, 250, 255, false)
        if pendingConfirmation == selected.value and GetGameTimer() < confirmUntil then
            drawText('CONFIRMATION REQUIRED: click the same action again', 0.5, 0.825, 0.28, 255, 108, 122, 255, true)
        elseif actionPending and GetGameTimer() < actionPendingUntil then
            drawText('Secured action is processing...', 0.5, 0.825, 0.28, 255, 196, 110, 255, true)
        else
            drawText(('Action %s of %s | Mouse and keyboard enabled'):format(selectedAction, #actions), 0.5, 0.825, 0.25, 142, 166, 198, 255, true)
        end
    end
end

local function drawMenu()
    drawHeader()
    drawTabs()
    drawStats()
    local rows = rowsForTab()
    selectedRow = clamp(selectedRow, 1, math.max(1, #rows))
    if mode == 'actions' then
        local patient = selectedPatient()
        if patient then drawActionMenu(patient) else mode = 'list' end
    elseif activeTab == 1 then
        drawPatients(rows)
    elseif activeTab == 2 then
        drawMedicalTests(rows)
    elseif activeTab == 3 then
        drawPrecisionOps(rows)
    elseif activeTab == 4 then
        drawAutonomousNetwork(rows)
    elseif activeTab == 5 then
        drawV12Network(rows)
    elseif activeTab == 6 then
        drawV13Continuum(rows)
    elseif activeTab == 7 then
        drawV14Trauma(rows)
    elseif activeTab == 8 then
        drawModules(rows)
    else
        drawAudit(rows)
    end

    local now = GetGameTimer()
    if statusMessage ~= '' and now < statusUntil then
        drawRect(0.5, 0.88, 0.58, 0.045, 12, 40, 68, 245)
        drawText(statusMessage, 0.5, 0.864, 0.29, 220, 235, 250, 255, true)
    end
end

executeSelectedAction = function()
    local patient = selectedPatient()
    local action = actions[selectedAction]
    if not patient or not action then return end

    local now = GetGameTimer()
    if actionPending and now < actionPendingUntil then
        statusMessage = 'Wait for the current secured action to finish.'
        statusUntil = now + 1800
        return
    end

    if action.confirm == true then
        if pendingConfirmation ~= action.value or now >= confirmUntil then
            pendingConfirmation = action.value
            confirmUntil = now + 4000
            statusMessage = ('Confirm %s: click the action again or press ENTER within 4 seconds.'):format(action.label)
            statusUntil = confirmUntil
            return
        end
    end

    pendingConfirmation = nil
    confirmUntil = 0
    actionPending = true
    actionPendingUntil = now + 8000
    statusMessage = ('Executing %s for %s...'):format(action.label, patient.name or ('ID ' .. tostring(patient.id)))
    statusUntil = now + 8000
    TriggerServerEvent('dpn-medical-admin-tools:server:actionNative', action.value, tonumber(patient.id))
end

executeSelectedTest = function()
    local tests = payload and payload.tests or {}
    local test = tests[selectedRow]
    local patient = selectedPatient()
    if not test or not patient then return end

    local now = GetGameTimer()
    if actionPending and now < actionPendingUntil then
        statusMessage = 'Wait for the current secured action or test to finish.'
        statusUntil = now + 1800
        return
    end

    local confirmKey = 'test:' .. tostring(test.id)
    if test.confirm == true or test.dangerous == true then
        if pendingConfirmation ~= confirmKey or now >= confirmUntil then
            pendingConfirmation = confirmKey
            confirmUntil = now + 4000
            statusMessage = ('Confirm %s on %s: click RUN TEST again within 4 seconds.'):format(test.label or test.id, patient.name or patient.id)
            statusUntil = confirmUntil
            return
        end
    end

    pendingConfirmation = nil
    confirmUntil = 0
    actionPending = true
    actionPendingUntil = now + 10000
    statusMessage = ('Running %s on %s...'):format(test.label or test.id, patient.name or ('ID ' .. tostring(patient.id)))
    statusUntil = now + 10000
    TriggerServerEvent('dpn-medical-admin-tools:server:testScenarioNative', tostring(test.id), tonumber(patient.id))
end

RegisterNetEvent('dpn-medical-admin-tools:client:openNative', function(data)
    waitingForServer = false
    payload = type(data) == 'table' and data or { patients = {}, tests = {}, precisionRows = {}, autonomousRows = {}, v12Rows = {}, v13Network = {}, v13Rows = {}, v14Network = {}, v14Rows = {}, modules = {}, audit = {}, stats = {} }
    menuOpen = true
    activeTab = 1
    selectedRow = 1
    selectedAction = 1
    selectedTest = 1
    selectedPatientId = payload.patients and payload.patients[1] and tonumber(payload.patients[1].id) or nil
    mode = 'list'
    pendingConfirmation = nil
    confirmUntil = 0
    actionPending = false
    actionPendingUntil = 0
    statusMessage = payload.notice or 'Medical administration connected.'
    statusUntil = GetGameTimer() + 3000
    log(('OPEN_NATIVE received patients=%s tests=%s modules=%s'):format(
        tostring(type(payload.patients) == 'table' and #payload.patients or 0),
        tostring(type(payload.tests) == 'table' and #payload.tests or 0),
        tostring(type(payload.modules) == 'table' and #payload.modules or 0)
    ))
end)

RegisterNetEvent('dpn-medical-admin-tools:client:updateNative', function(data)
    if type(data) ~= 'table' then return end
    payload = data
    local rows = rowsForTab()
    selectedRow = clamp(selectedRow, 1, math.max(1, #rows))
    -- Do not overwrite a secured action result with the generic refresh notice.
    if GetGameTimer() >= statusUntil then
        statusMessage = data.notice or 'Live medical data refreshed.'
        statusUntil = GetGameTimer() + 1800
    end
end)

RegisterNetEvent('dpn-medical-admin-tools:client:deniedNative', function(message)
    waitingForServer = false
    closeMenu('permission denied')
    notify(message or 'DPN Medical Admin permission denied.', 'error')
end)

RegisterNetEvent('dpn-medical-admin-tools:client:actionResultNative', function(result)
    result = type(result) == 'table' and result or {}
    actionPending = false
    actionPendingUntil = 0
    pendingConfirmation = nil
    confirmUntil = 0
    statusMessage = tostring(result.message or (result.ok and 'Action completed.' or 'Action failed.'))
    statusUntil = GetGameTimer() + 3500
    if result.ok == false then
        notify(statusMessage, 'error')
    elseif Config.NotifyActionSuccess == true then
        notify(statusMessage, 'success')
    end
end)

RegisterNetEvent('dpn-medical-admin-tools:client:teleportNative', function(coords)
    if type(coords) ~= 'table' then return end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end
    local ped = PlayerPedId()
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    if tonumber(coords.h) then SetEntityHeading(ped, tonumber(coords.h)) end
end)

RegisterCommand(Config.Command or 'medadmin', requestOpen, false)
RegisterCommand(Config.Alias or 'dpnmedadmin', requestOpen, false)
RegisterCommand(Config.CloseCommand or 'medadminclose', function() closeMenu('command') end, false)
RegisterCommand(Config.RefreshCommand or 'medadminrefresh', requestRefresh, false)
RegisterCommand(Config.DiagnosticCommand or 'medadmindiag', function()
    local rowCount = #rowsForTab()
    local text = ('native=true mouse=%s open=%s waiting=%s tab=%s mode=%s rows=%s core=%s'):format(
        tostring(Config.EnableMouse ~= false),
        tostring(menuOpen), tostring(waitingForServer), tostring(activeTab), tostring(mode),
        tostring(rowCount), tostring(GetResourceState('dpn-medical-core'))
    )
    log('DIAG ' .. text)
    notify(text, 'primary')
end, false)

if Config.EnableKeybind ~= false then
    pcall(function()
        RegisterKeyMapping(Config.Command or 'medadmin', 'Open DPN Medical Administration', 'keyboard', Config.DefaultKeybind or 'F10')
    end)
end

CreateThread(function()
    while true do
        if not menuOpen then
            Wait(250)
        else
            Wait(0)
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 14, true)
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 68, true)
            DisableControlAction(0, 69, true)
            DisableControlAction(0, 70, true)
            DisableControlAction(0, 91, true)
            DisableControlAction(0, 92, true)
            DisableControlAction(0, 172, true)
            DisableControlAction(0, 173, true)
            DisableControlAction(0, 174, true)
            DisableControlAction(0, 175, true)
            DisableControlAction(0, 177, true)
            DisableControlAction(0, 191, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 237, true)
            DisableControlAction(0, 238, true)
            DisableControlAction(0, 239, true)
            DisableControlAction(0, 240, true)
            DisableControlAction(0, 241, true)
            DisableControlAction(0, 242, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 45, true)
            DisablePlayerFiring(PlayerId(), true)

            updateMouseState()
            drawMenu()

            local rows = rowsForTab()
            if mouse.right then
                if mode == 'actions' then
                    mode = 'list'
                    pendingConfirmation = nil
                    confirmUntil = 0
                else
                    closeMenu('mouse right-click')
                end
            elseif mouse.wheelUp then
                if mode == 'actions' then
                    selectedAction = clamp(selectedAction - 1, 1, #actions)
                    pendingConfirmation = nil
                    confirmUntil = 0
                else
                    selectedRow = clamp(selectedRow - 1, 1, math.max(1, #rows))
                end
            elseif mouse.wheelDown then
                if mode == 'actions' then
                    selectedAction = clamp(selectedAction + 1, 1, #actions)
                    pendingConfirmation = nil
                    confirmUntil = 0
                else
                    selectedRow = clamp(selectedRow + 1, 1, math.max(1, #rows))
                end
            end

            if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
                if mode == 'actions' then
                    mode = 'list'
                    pendingConfirmation = nil
                    confirmUntil = 0
                else
                    closeMenu('back')
                end
            elseif IsDisabledControlJustPressed(0, 45) then
                requestRefresh()
            elseif IsDisabledControlJustPressed(0, 174) and mode == 'list' then
                activeTab = clamp(activeTab - 1, 1, #tabs)
                selectedRow = 1
            elseif IsDisabledControlJustPressed(0, 175) and mode == 'list' then
                activeTab = clamp(activeTab + 1, 1, #tabs)
                selectedRow = 1
            elseif IsDisabledControlJustPressed(0, 172) then
                if mode == 'actions' then
                    selectedAction = clamp(selectedAction - 1, 1, #actions)
                    pendingConfirmation = nil
                    confirmUntil = 0
                else
                    selectedRow = clamp(selectedRow - 1, 1, math.max(1, #rows))
                end
            elseif IsDisabledControlJustPressed(0, 173) then
                if mode == 'actions' then
                    selectedAction = clamp(selectedAction + 1, 1, #actions)
                    pendingConfirmation = nil
                    confirmUntil = 0
                else
                    selectedRow = clamp(selectedRow + 1, 1, math.max(1, #rows))
                end
            elseif IsDisabledControlJustPressed(0, 191) then
                if mode == 'actions' then
                    executeSelectedAction()
                elseif activeTab == 1 and selectedPatient() then
                    selectedAction = 1
                    pendingConfirmation = nil
                    confirmUntil = 0
                    mode = 'actions'
                elseif activeTab == 2 then
                    executeSelectedTest()
                end
            end
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    closeMenu('player unload')
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    menuOpen = false
    waitingForServer = false
    TriggerEvent('chat:addSuggestion', '/medadmin', 'Open native DPN Medical Administration')
    TriggerEvent('chat:addSuggestion', '/medadminclose', 'Close DPN Medical Administration')
    TriggerEvent('chat:addSuggestion', '/medtest', 'Run a secured medical test: /medtest [id] [scenario]')
    TriggerEvent('chat:addSuggestion', '/medtestlist', 'List available DPN medical test scenarios')
    log('v14.0.0 loaded: native mouse trauma-operations dashboard, secured actions and medical test laboratory active')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        menuOpen = false
        waitingForServer = false
    end
end)
