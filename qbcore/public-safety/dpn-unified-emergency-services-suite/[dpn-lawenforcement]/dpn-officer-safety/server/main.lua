local Units = {}
local Alerts = {}
local Cooldowns = {}
local allowedStatuses = { ['10-8']=true, ['10-6']=true, ['10-7']=true, ['10-23']=true, ['10-8 Vehicle']=true, ['10-8 Foot']=true }
local allowedAlertTypes = {
    panic=true, officerDown=true, crash=true, shotsFired=true, welfare=true,
    pursuit=true, weaponDrawn=true, footPursuit=true, backup=true, external=true
}

local function clean(value, maxLength)
    return tostring(value or ''):gsub('[%z\1-\31]', ''):sub(1, maxLength or 255)
end

local function now() return os.time() end

local function safeJson(data)
    local ok, encoded = pcall(json.encode, data or {})
    return ok and encoded or '{}'
end

local function logWebhook(title, data)
    if not Config.EnableServerLogs or Config.Webhook == '' then return end
    PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
        username = 'DPN Officer Safety',
        embeds = {{
            title = clean(title, 128),
            color = 16724530,
            description = ('```json\n%s\n```'):format(safeJson(data):sub(1, 3500)),
            footer = { text = 'DPN Technology' }
        }}
    }), { ['Content-Type'] = 'application/json' })
end

local function onCooldown(src, alertType)
    local key = ('%s:%s'):format(src, alertType)
    local seconds = Config.AlertCooldowns[alertType] or Config.AlertCooldowns[alertType:gsub('%u', function(c) return '_' .. c:lower() end)] or 10
    if Cooldowns[key] and now() - Cooldowns[key] < seconds then return true end
    Cooldowns[key] = now()
    return false
end

local function getVerifiedState(src)
    local result = { coords = { x=0.0, y=0.0, z=0.0 }, health = 100 }
    pcall(function()
        local ped = GetPlayerPed(src)
        if ped and ped > 0 and DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            result.coords = { x=coords.x, y=coords.y, z=coords.z }
            result.health = math.max(0, math.min(200, GetEntityHealth(ped)))
        end
    end)
    return result
end

local function recipients()
    local list = {}
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and DPNBridge.IsAllowed(src) then list[#list+1] = src end
    end
    return list
end

local function emitAuthorized(eventName, ...)
    for _, src in ipairs(recipients()) do
        TriggerClientEvent(eventName, src, ...)
    end
end

local function createDispatchCall(alert)
    if GetResourceState(Config.Integrations.Dispatch) ~= 'started' then return end
    exports[Config.Integrations.Dispatch]:CreateDispatchCall({
        type = (alert.type == 'officerDown' or alert.type == 'panic') and 'panic' or alert.type,
        title = alert.title,
        description = alert.message,
        coords = alert.coords,
        priority = alert.priority or 1,
        source = 'dpn-officer-safety',
        departments = { 'law', 'dispatch', 'medical' },
        unit = alert.unit,
        metadata = alert.metadata or {}
    }, 0)
end

local function createIncident(alert)
    if GetResourceState(Config.Integrations.IncidentCommand) ~= 'started' then return end
    TriggerEvent('dpn-incident-command:server:autoIncident', alert)
end

local function insertAlert(alert)
    Alerts[#Alerts+1] = alert
    if #Alerts > 200 then table.remove(Alerts, 1) end
    MySQL.insert('INSERT INTO dpn_officer_safety_alerts (identifier, officer_name, type, priority, message, coords, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        alert.identifier, alert.officer, alert.type, alert.priority or 1, alert.message, safeJson(alert.coords), safeJson(alert.metadata)
    })
end

local function networkPublishAlert(alert)
    if GetResourceState('dpn-emergency-network') ~= 'started' then return end
    local mapping = { panic='officer_panic', officerDown='officer_down', shotsFired='shots_fired', crash='traffic_collision', pursuit='pursuit', footPursuit='pursuit', backup='officer_panic' }
    local eventType = mapping[alert.type] or 'generic'
    pcall(function()
        exports['dpn-emergency-network']:PublishEvent('officer_safety', eventType, {
            title=alert.title, message=alert.message, severity=alert.priority, coords=alert.coords,
            officer=alert.officer, unit=alert.unit, identifier=alert.identifier, alertId=alert.id,
            metadata=alert.metadata, suppressRouting=true
        }, 0)
    end)
end

local function broadcastAlert(alert)
    insertAlert(alert)
    logWebhook(alert.title or alert.type, alert)
    emitAuthorized('dpn-officer-safety:client:alert', alert)
    if alert.dispatch then createDispatchCall(alert) end
    if alert.incident then createIncident(alert) end
    networkPublishAlert(alert)
end

RegisterNetEvent('dpn-officer-safety:server:register', function(data)
    local src = source
    if not DPNBridge.IsAllowed(src) then return end
    local state = getVerifiedState(src)
    local identifier = DPNBridge.GetIdentifier(src)
    local job, grade, label = DPNBridge.GetJob(src)
    local requestedUnit = type(data) == 'table' and clean(data.unit, 20) or ''
    Units[src] = {
        src = src, identifier = identifier, officer = DPNBridge.GetName(src),
        job = job, jobLabel = label, grade = grade,
        unit = requestedUnit ~= '' and requestedUnit or ('U-'..src),
        status = '10-8', health = state.health,
        heartRate = Config.Stress.BaseHeartRate, stress = 0,
        coords = state.coords, lastSeen = now()
    }
    emitAuthorized('dpn-officer-safety:client:syncUnits', Units)
    TriggerClientEvent('dpn-officer-safety:client:alerts', src, Alerts)
end)

RegisterNetEvent('dpn-officer-safety:server:updateStatus', function(data)
    local src = source
    if not DPNBridge.IsAllowed(src) or not Units[src] or type(data) ~= 'table' then return end
    local state = getVerifiedState(src)
    Units[src].coords = state.coords
    Units[src].health = state.health
    Units[src].heartRate = math.max(35, math.min(Config.Stress.MaxHeartRate, math.floor(tonumber(data.heartRate) or Units[src].heartRate)))
    Units[src].stress = math.max(0, math.min(100, math.floor(tonumber(data.stress) or Units[src].stress)))
    local status = clean(data.status, 32)
    if allowedStatuses[status] then Units[src].status = status end
    Units[src].lastSeen = now()
    emitAuthorized('dpn-officer-safety:client:syncUnits', Units)
end)

local function createAlertFor(src, alertType, payload, trusted)
    src = tonumber(src) or 0
    payload = type(payload) == 'table' and payload or {}
    alertType = clean(alertType or 'external', 32)
    if not trusted and not allowedAlertTypes[alertType] then return false end
    if src > 0 and not DPNBridge.IsAllowed(src) then return false end
    if src > 0 and onCooldown(src, alertType) then return false end

    local state = src > 0 and getVerifiedState(src) or { coords = payload.coords or {x=0,y=0,z=0}, health=100 }
    local identifier = src > 0 and DPNBridge.GetIdentifier(src) or 'SYSTEM'
    local officer = src > 0 and DPNBridge.GetName(src) or clean(payload.officer or 'DPN System', 128)
    local unit = Units[src] and Units[src].unit or (src > 0 and ('U-'..src) or 'SYSTEM')
    local metadata = type(payload.metadata) == 'table' and payload.metadata or {}
    metadata.verifiedHealth = state.health

    local alert = {
        id = ('DPN-%s-%s'):format(os.time(), math.random(1000,9999)),
        src = src, identifier = identifier, officer = officer, unit = unit,
        type = alertType,
        title = clean(payload.title or alertType, 128),
        message = clean(payload.message or alertType, 1000),
        priority = math.max(1, math.min(4, math.floor(tonumber(payload.priority) or 1))),
        coords = state.coords,
        metadata = metadata,
        dispatch = payload.dispatch ~= false,
        incident = payload.incident == true,
        createdAt = os.date('%Y-%m-%d %H:%M:%S')
    }
    broadcastAlert(alert)
    return alert
end

RegisterNetEvent('dpn-officer-safety:server:createAlert', function(alertType, payload)
    createAlertFor(source, alertType, payload, false)
end)

RegisterNetEvent('dpn-officer-safety:server:ackAlert', function(alertId)
    local src = source
    if not DPNBridge.IsAllowed(src) then return end
    alertId = clean(alertId, 64)
    for _, alert in ipairs(Alerts) do
        if alert.id == alertId then
            alert.ackBy = DPNBridge.GetName(src)
            alert.ackAt = os.date('%Y-%m-%d %H:%M:%S')
            break
        end
    end
    emitAuthorized('dpn-officer-safety:client:alerts', Alerts)
end)

RegisterNetEvent('dpn-officer-safety:server:panic', function()
    local src = source
    createAlertFor(src, 'panic', {
        title = 'Officer Panic Button',
        message = ('%s activated emergency panic.'):format(DPNBridge.GetName(src)),
        priority = 1, dispatch = true, incident = true
    }, false)
end)

exports('CreateSafetyAlert', function(src, alertType, payload)
    local alert = createAlertFor(src, alertType or 'external', payload or {}, true)
    return alert and alert.id or false
end)
exports('GetUnits', function() return Units end)
exports('GetAlerts', function() return Alerts end)

AddEventHandler('playerDropped', function()
    local src = source
    Units[src] = nil
    local prefix = tostring(src) .. ':'
    for key in pairs(Cooldowns) do
        if key:sub(1, #prefix) == prefix then Cooldowns[key] = nil end
    end
    emitAuthorized('dpn-officer-safety:client:syncUnits', Units)
end)
