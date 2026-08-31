local QBCore = exports['qb-core']:GetCoreObject()
local Bolos = {}
local eventCooldowns = {}

local function clean(value, maxLength)
    return tostring(value or ''):gsub('[%z\1-\31]', ''):sub(1, maxLength or 255)
end

local function getIdentifier(src)
    local player = QBCore.Functions.GetPlayer(tonumber(src))
    return player and player.PlayerData and player.PlayerData.citizenid or ('src:%s'):format(src)
end

local function getPlayerJob(src)
    local player = QBCore.Functions.GetPlayer(tonumber(src))
    local job = player and player.PlayerData and player.PlayerData.job
    return job and job.name, job and job.onduty == true
end

local function isAllowed(src, admin)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, admin and Config.AdminAcePermission or Config.AcePermission) then return true end
    if not Config.RequireJob then return true end
    local job, onDuty = getPlayerJob(src)
    if not job or Config.AllowedJobs[job] ~= true then return false end
    return not Config.RequireDuty or onDuty
end

local function authorizedRecipients()
    local recipients = {}
    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        local src = tonumber(playerId)
        if src and isAllowed(src, false) then recipients[#recipients + 1] = src end
    end
    return recipients
end

local function emitAuthorized(eventName, ...)
    for _, src in ipairs(authorizedRecipients()) do
        TriggerClientEvent(eventName, src, ...)
    end
end

local function cameraById(cameraId)
    cameraId = clean(cameraId, 64)
    for _, camera in ipairs(Config.Cameras) do
        if camera.id == cameraId then return camera end
    end
end

local function zoneById(zoneId)
    zoneId = clean(zoneId, 64)
    for _, zone in ipairs(Config.GunshotZones) do
        if zone.id == zoneId then return zone end
    end
end

local function nodeById(nodeId)
    nodeId = clean(nodeId, 64)
    for _, node in ipairs(Config.TrafficNodes) do
        if node.id == nodeId then return node end
    end
end

local function entitySnapshot(src, requireVehicle)
    local ok, snapshot = pcall(function()
        local ped = GetPlayerPed(src)
        if not ped or ped <= 0 or not DoesEntityExist(ped) then return nil end
        local coords = GetEntityCoords(ped)
        local result = { ped = ped, coords = { x = coords.x, y = coords.y, z = coords.z } }
        if requireVehicle then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if not vehicle or vehicle <= 0 or not DoesEntityExist(vehicle) then return nil end
            if GetPedInVehicleSeat(vehicle, -1) ~= ped then return nil end
            local vehicleCoords = GetEntityCoords(vehicle)
            result.vehicle = vehicle
            result.coords = { x = vehicleCoords.x, y = vehicleCoords.y, z = vehicleCoords.z }
            result.plate = DPN.PlateTrim(GetVehicleNumberPlateText(vehicle))
            result.speed = GetEntitySpeed(vehicle) * (Config.SpeedCamera.Unit == 'mph' and 2.236936 or 3.6)
            result.model = GetEntityModel(vehicle)
        end
        return result
    end)
    return ok and snapshot or nil
end

local function within(coords, target, radius)
    if not coords or not target then return false end
    return DPN.Distance(coords, { x = target.x, y = target.y, z = target.z }) <= tonumber(radius or 0)
end

local function loadBolos()
    MySQL.query('SELECT * FROM dpn_smartcity_bolos WHERE active = 1', {}, function(rows)
        Bolos = rows or {}
        emitAuthorized('dpn-smartcity:client:syncBolos', Bolos)
    end)
end

local function logEvent(eventType, title, data, src)
    data = type(data) == 'table' and data or {}
    local coords = data.coords and json.encode(data.coords) or nil
    local details = json.encode(data)
    local plate = data.plate and clean(data.plate, 16) or nil
    MySQL.insert('INSERT INTO dpn_smartcity_events (event_type, title, details, plate, coords, created_by) VALUES (?, ?, ?, ?, ?, ?)', {
        clean(eventType, 64), clean(title, 160), details, plate, coords, src and getIdentifier(src) or 'system'
    })
    if Config.Webhook and Config.Webhook ~= '' then
        PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
            username = 'DPN Smart City',
            content = ('**%s**\n%s'):format(clean(title, 160), details:sub(1, 1600))
        }), { ['Content-Type'] = 'application/json' })
    end
end

local function cooldown(key, seconds)
    local timestamp = os.time()
    if eventCooldowns[key] and eventCooldowns[key] > timestamp then return false end
    eventCooldowns[key] = timestamp + math.max(1, tonumber(seconds) or 1)
    return true
end

local function createDispatch(title, message, coords, priority, code, metadata)
    local priorities = { critical = 1, high = 1, medium = 2, low = 3 }
    local numericPriority = tonumber(priority) or priorities[tostring(priority or 'medium'):lower()] or 2
    local lowered = tostring(title or ''):lower()
    local callType = lowered:find('bolo', 1, true) and 'bolo' or (lowered:find('gunshot', 1, true) and 'shots' or 'traffic')
    local payload = {
        type = callType,
        title = clean(title, 128),
        description = clean(message, 1000),
        coords = coords,
        priority = math.max(1, math.min(4, numericPriority)),
        code = clean(code or 'SMARTCITY', 32),
        source = 'dpn-smart-city',
        staffOnly = true,
        departments = { 'law', 'dispatch' },
        metadata = metadata or { smartCity = true, code = code or 'SMARTCITY' }
    }
    if GetResourceState(Config.DispatchResource) == 'started' then
        exports[Config.DispatchResource]:CreateDispatchCall(payload, 0)
    end
    if GetResourceState('dpn-emergency-network') == 'started' then
        local eventType = callType == 'bolo' and 'bolo' or (callType == 'shots' and 'shots_fired' or 'road_hazard')
        pcall(function() exports['dpn-emergency-network']:PublishEvent('smart_city', eventType, {
            title=payload.title, message=payload.description, severity=payload.priority, coords=payload.coords,
            code=payload.code, metadata=payload.metadata, suppressRouting=true
        }, 0) end)
    end
    emitAuthorized('dpn-smartcity:client:smartAlert', payload)
end

CreateThread(function()
    Wait(500)
    loadBolos()
end)

RegisterNetEvent('dpn-smartcity:server:requestData', function()
    local src = source
    if not isAllowed(src, false) then return end
    TriggerClientEvent('dpn-smartcity:client:syncBolos', src, Bolos)
    TriggerClientEvent('dpn-smartcity:client:syncConfig', src, {
        cameras = Config.Cameras,
        zones = Config.GunshotZones,
        nodes = Config.TrafficNodes
    })
end)

RegisterNetEvent('dpn-smartcity:server:addBolo', function(data)
    local src = source
    if not isAllowed(src, false) or type(data) ~= 'table' then return end
    local plate = DPN.PlateTrim(data.plate):sub(1, 16)
    if plate == '' then return end
    local reason = clean(data.reason or 'BOLO Vehicle', 1000)
    local priority = ({ high = 'high', medium = 'medium', low = 'low', critical = 'critical' })[tostring(data.priority):lower()] or 'medium'
    MySQL.insert('INSERT INTO dpn_smartcity_bolos (plate, reason, priority, created_by) VALUES (?, ?, ?, ?)', {
        plate, reason, priority, getIdentifier(src)
    }, function()
        loadBolos()
        logEvent('bolo_created', 'BOLO Created', { plate = plate, reason = reason, priority = priority }, src)
    end)
end)

RegisterNetEvent('dpn-smartcity:server:clearBolo', function(id)
    local src = source
    if not isAllowed(src, false) then return end
    id = tonumber(id)
    if not id then return end
    MySQL.update('UPDATE dpn_smartcity_bolos SET active = 0 WHERE id = ?', { id }, function()
        loadBolos()
        logEvent('bolo_cleared', 'BOLO Cleared', { id = id }, src)
    end)
end)

RegisterNetEvent('dpn-smartcity:server:gunshot', function(data)
    local src = source
    if not Config.Alerts.gunshots or type(data) ~= 'table' then return end
    local zone = zoneById(data.zoneId)
    local snapshot = entitySnapshot(src, false)
    if not zone or not snapshot or not within(snapshot.coords, zone.coords, (zone.radius or 0) + (Config.ServerValidationTolerance or 15.0)) then return end
    local key = ('gunshot:%s'):format(zone.id)
    if not cooldown(key, Config.Gunshot.CooldownSeconds) then return end
    local verified = {
        zoneId = zone.id,
        zoneName = zone.name,
        coords = snapshot.coords,
        weapon = tonumber(data.weapon) or 0,
        reportingSource = src
    }
    local title = 'Acoustic Gunshot Detection'
    local message = ('Possible shots fired near %s'):format(zone.name or 'unknown area')
    logEvent('gunshot', title, verified, src)
    if Config.Gunshot.CreateDispatchCall then
        createDispatch(title, message, snapshot.coords, 'high', '10-71', { smartCity = true, sensor = zone.id, verified = true })
    end
end)

local function processCameraPass(src, cameraId)
    local camera = cameraById(cameraId)
    local snapshot = entitySnapshot(src, true)
    if not camera or not snapshot or not within(snapshot.coords, camera.coords, (camera.range or 100.0) + (Config.ServerValidationTolerance or 15.0)) then return end
    local plate = snapshot.plate
    if plate == '' then return end

    local limit = tonumber(camera.speedLimit) or Config.SpeedCamera.DefaultLimit
    local speed = math.floor((snapshot.speed or 0) + 0.5)
    if Config.Alerts.speeding and Config.SpeedCamera.Enabled and speed >= limit + Config.SpeedCamera.AlertOverBy then
        local speedKey = ('speed:%s:%s'):format(camera.id, plate)
        if cooldown(speedKey, Config.SpeedCamera.CooldownSeconds) then
            local verifiedSpeed = {
                cameraId = camera.id, cameraName = camera.name, plate = plate,
                speed = speed, limit = limit, coords = snapshot.coords,
                model = snapshot.model, verified = true
            }
            logEvent('speed_camera', 'Speed Camera Alert', verifiedSpeed, src)
            if Config.SpeedCamera.CreateDispatchCall then
                createDispatch('Speed Camera Alert', ('%s clocked at %s %s near %s'):format(plate, speed, Config.SpeedCamera.Unit, camera.name), snapshot.coords, 'low', '10-66', verifiedSpeed)
            end
        end
    end

    if Config.Alerts.boloHits then
        local matched
        for _, bolo in ipairs(Bolos) do
            local target = DPN.PlateTrim(bolo.plate)
            if Config.Bolo.ExactPlate and plate == target then matched = bolo break end
            if not Config.Bolo.ExactPlate and target ~= '' and (plate:find(target, 1, true) or target:find(plate, 1, true)) then matched = bolo break end
        end
        if matched then
            local boloKey = ('bolo:%s:%s'):format(camera.id, plate)
            if cooldown(boloKey, Config.Bolo.CooldownSeconds) then
                local verifiedBolo = {
                    cameraId = camera.id, cameraName = camera.name, plate = plate,
                    reason = clean(matched.reason, 1000), priority = matched.priority or 'high',
                    coords = snapshot.coords, model = snapshot.model, boloId = matched.id,
                    verified = true
                }
                logEvent('bolo_hit', 'BOLO Camera Hit', verifiedBolo, src)
                if Config.Bolo.CreateDispatchCall then
                    createDispatch('BOLO Camera Hit', ('Flagged vehicle %s detected near %s. Reason: %s'):format(plate, camera.name, verifiedBolo.reason), snapshot.coords, verifiedBolo.priority, '10-60', verifiedBolo)
                end
            end
        end
    end
end

RegisterNetEvent('dpn-smartcity:server:cameraPass', function(cameraId)
    processCameraPass(source, cameraId)
end)

RegisterNetEvent('dpn-smartcity:server:speedCamera', function(data)
    local src = source
    if not Config.Alerts.speeding or type(data) ~= 'table' then return end
    local camera = cameraById(data.cameraId)
    local snapshot = entitySnapshot(src, true)
    if not camera or not snapshot or not within(snapshot.coords, camera.coords, (camera.range or 100.0) + (Config.ServerValidationTolerance or 15.0)) then return end
    local plate = snapshot.plate
    if plate == '' then return end
    local limit = tonumber(camera.speedLimit) or Config.SpeedCamera.DefaultLimit
    local speed = math.floor((snapshot.speed or 0) + 0.5)
    if speed < limit + Config.SpeedCamera.AlertOverBy then return end
    local key = ('speed:%s:%s'):format(camera.id, plate)
    if not cooldown(key, Config.SpeedCamera.CooldownSeconds) then return end
    local verified = {
        cameraId = camera.id,
        cameraName = camera.name,
        plate = plate,
        speed = speed,
        limit = limit,
        coords = snapshot.coords,
        model = snapshot.model,
        verified = true
    }
    logEvent('speed_camera', 'Speed Camera Alert', verified, src)
    if Config.SpeedCamera.CreateDispatchCall then
        createDispatch('Speed Camera Alert', ('%s clocked at %s %s near %s'):format(plate, speed, Config.SpeedCamera.Unit, camera.name), snapshot.coords, 'low', '10-66', verified)
    end
end)

RegisterNetEvent('dpn-smartcity:server:boloHit', function(data)
    local src = source
    if not Config.Alerts.boloHits or type(data) ~= 'table' then return end
    local camera = cameraById(data.cameraId)
    local snapshot = entitySnapshot(src, true)
    if not camera or not snapshot or not within(snapshot.coords, camera.coords, (camera.range or 100.0) + (Config.ServerValidationTolerance or 15.0)) then return end
    local plate = snapshot.plate
    local matched
    for _, bolo in ipairs(Bolos) do
        local target = DPN.PlateTrim(bolo.plate)
        if Config.Bolo.ExactPlate and plate == target then matched = bolo break end
        if not Config.Bolo.ExactPlate and target ~= '' and (plate:find(target, 1, true) or target:find(plate, 1, true)) then matched = bolo break end
    end
    if not matched then return end
    local key = ('bolo:%s:%s'):format(camera.id, plate)
    if not cooldown(key, Config.Bolo.CooldownSeconds) then return end
    local verified = {
        cameraId = camera.id,
        cameraName = camera.name,
        plate = plate,
        reason = clean(matched.reason, 1000),
        priority = matched.priority or 'high',
        coords = snapshot.coords,
        model = snapshot.model,
        boloId = matched.id,
        verified = true
    }
    logEvent('bolo_hit', 'BOLO Camera Hit', verified, src)
    if Config.Bolo.CreateDispatchCall then
        createDispatch('BOLO Camera Hit', ('Flagged vehicle %s detected near %s. Reason: %s'):format(plate, camera.name, verified.reason), snapshot.coords, verified.priority, '10-60', verified)
    end
end)

RegisterNetEvent('dpn-smartcity:server:trafficOverride', function(nodeId, mode)
    local src = source
    if not isAllowed(src, false) then return end
    local node = nodeById(nodeId)
    local allowedModes = { normal = true, emergency = true, scene = true, stop = true }
    mode = clean(mode, 24):lower()
    if not node or not allowedModes[mode] then return end
    emitAuthorized('dpn-smartcity:client:trafficOverride', node.id, mode, Config.TrafficControl.SceneModeSeconds)
    logEvent('traffic_override', 'Traffic Light Override', { nodeId = node.id, mode = mode }, src)
end)

RegisterNetEvent('dpn-smartcity:server:getRecentEvents', function()
    local src = source
    if not isAllowed(src, false) then return end
    MySQL.query('SELECT * FROM dpn_smartcity_events ORDER BY id DESC LIMIT 50', {}, function(rows)
        TriggerClientEvent('dpn-smartcity:client:recentEvents', src, rows or {})
    end)
end)

exports('AddBolo', function(plate, reason, priority)
    plate = DPN.PlateTrim(plate):sub(1, 16)
    if plate == '' then return false end
    MySQL.insert('INSERT INTO dpn_smartcity_bolos (plate, reason, priority, created_by) VALUES (?, ?, ?, ?)', {
        plate, clean(reason or 'BOLO Vehicle', 1000), clean(priority or 'medium', 16), 'export'
    }, loadBolos)
    return true
end)

exports('ClearBoloByPlate', function(plate)
    MySQL.update('UPDATE dpn_smartcity_bolos SET active = 0 WHERE plate = ?', { DPN.PlateTrim(plate):sub(1, 16) }, loadBolos)
end)

exports('CreateSmartAlert', function(eventType, title, message, coords, priority)
    local payload = { message = clean(message, 1000), coords = coords, priority = priority }
    logEvent(eventType or 'custom', title or 'Smart City Alert', payload, nil)
    createDispatch(title or 'Smart City Alert', payload.message, coords, priority or 'medium', 'SMART', payload)
end)
