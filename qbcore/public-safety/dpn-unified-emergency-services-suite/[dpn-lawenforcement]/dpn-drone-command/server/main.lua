local QBCore = exports['qb-core']:GetCoreObject()
local ActiveDrones = {}
local DroneLogs = {}

local function now()
    return os.date('%Y-%m-%d %H:%M:%S')
end

local function clean(value, maxLength)
    return tostring(value or ''):gsub('[%z\1-\31]', ''):sub(1, maxLength or 255)
end

local function playerInfo(src)
    local player = QBCore.Functions.GetPlayer(tonumber(src))
    if not player then return nil end
    local data = player.PlayerData or {}
    local job = data.job or {}
    local charinfo = data.charinfo or {}
    return {
        citizenid = data.citizenid or tostring(src),
        name = (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1'),
        job = job.name or 'unemployed',
        onDuty = job.onduty == true
    }
end

local function allowed(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, 'dpn.drone') or IsPlayerAceAllowed(src, 'dpn.admin') then return true end
    local info = playerInfo(src)
    if not info or Config.AllowedJobs[info.job] ~= true then return false end
    return not Config.RequireOnDuty or info.onDuty
end

local function recipients()
    local result = {}
    for _, id in ipairs(QBCore.Functions.GetPlayers()) do
        local src = tonumber(id)
        if src and allowed(src) then result[#result + 1] = src end
    end
    return result
end

local function broadcast(eventName, ...)
    for _, src in ipairs(recipients()) do
        TriggerClientEvent(eventName, src, ...)
    end
end

local function log(src, action, data)
    if not Config.LogEvents then return end
    local info = src > 0 and playerInfo(src) or nil
    local row = { source = src, action = action, data = data or {}, time = now() }
    DroneLogs[#DroneLogs + 1] = row
    if #DroneLogs > 250 then table.remove(DroneLogs, 1) end
    MySQL.insert('INSERT INTO dpn_drone_logs (citizenid, action, data, created_at) VALUES (?, ?, ?, ?)', {
        info and info.citizenid or 'SYSTEM', clean(action, 80), json.encode(data or {}), row.time
    })
    if Config.Webhook and Config.Webhook ~= '' then
        PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
            username = 'DPN Drone Command',
            embeds = {{
                title = clean(action, 80),
                description = ('```json\n%s\n```'):format(json.encode(data or {}):sub(1, 3500)),
                color = 3447003
            }}
        }), { ['Content-Type'] = 'application/json' })
    end
end

local function playerCoords(src)
    local ok, coords = pcall(function()
        local ped = GetPlayerPed(src)
        if not ped or ped <= 0 or not DoesEntityExist(ped) then return nil end
        local value = GetEntityCoords(ped)
        return { x = value.x, y = value.y, z = value.z }
    end)
    return ok and coords or nil
end

local function normalizeCoords(value)
    if type(value) ~= 'table' then return nil end
    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return nil end
    if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 2500 then return nil end
    return { x = x, y = y, z = z }
end

local function distance(a, b)
    if not a or not b then return math.huge end
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(x * x + y * y + z * z)
end

local function createAlert(alert, actorSource, systemSource)
    alert = type(alert) == 'table' and alert or {}
    actorSource = tonumber(actorSource) or 0
    if actorSource > 0 then
        if not allowed(actorSource) then return false end
        local drone = ActiveDrones[actorSource]
        if not drone then return false end
        alert.coords = drone.coords
        alert.droneId = drone.id
        alert.owner = actorSource
    else
        alert.coords = normalizeCoords(alert.coords)
    end

    local payload = {
        title = clean(alert.title or 'Drone Alert', 128),
        code = clean(alert.code or 'DRONE', 32),
        priority = math.max(1, math.min(4, math.floor(tonumber(alert.priority) or 2))),
        coords = alert.coords,
        description = clean(alert.description or 'Drone command generated alert', 1000),
        source = clean(systemSource or 'dpn-drone-command', 64),
        time = now(),
        droneId = alert.droneId,
        owner = alert.owner
    }

    log(actorSource, 'Drone Alert', payload)
    if Config.DispatchIntegration and GetResourceState('dpn-digital-dispatch') == 'started' then
        exports['dpn-digital-dispatch']:CreateDispatchCall({
            type = 'drone',
            title = payload.title,
            code = payload.code,
            priority = payload.priority,
            coords = payload.coords,
            description = payload.description,
            source = payload.source,
            departments = { 'law', 'dispatch' },
            metadata = { drone = true, droneId = payload.droneId, owner = payload.owner }
        }, 0)
    end
    if GetResourceState('dpn-emergency-network') == 'started' then
        pcall(function() exports['dpn-emergency-network']:PublishEvent('drone', 'drone_alert', {
            title=payload.title, message=payload.description, severity=payload.priority, coords=payload.coords,
            droneId=payload.droneId, owner=payload.owner, code=payload.code, suppressRouting=true
        }, 0) end)
    end
    broadcast('dpn-drone:client:alert', payload)
    return true
end

RegisterNetEvent('dpn-drone:server:requestDeploy', function()
    local src = source
    if not allowed(src) then
        return TriggerClientEvent('dpn-drone:client:deployDenied', src, 'You must be on duty and authorized to deploy a drone.')
    end
    if ActiveDrones[src] then
        return TriggerClientEvent('dpn-drone:client:deployDenied', src, 'You already have an active drone.')
    end
    local coords = playerCoords(src)
    if not coords then return TriggerClientEvent('dpn-drone:client:deployDenied', src, 'Unable to verify your deployment position.') end
    local id = ('DRN-%s-%s'):format(src, os.time())
    ActiveDrones[src] = {
        id = id,
        owner = src,
        launchCoords = coords,
        coords = coords,
        battery = 100,
        launched_at = now(),
        status = 'active',
        lastUpdate = GetGameTimer(),
        mode = 'normal'
    }
    log(src, 'Drone Deployed', ActiveDrones[src])
    TriggerClientEvent('dpn-drone:client:deployApproved', src, ActiveDrones[src])
    broadcast('dpn-drone:client:syncDrone', src, ActiveDrones[src])
end)

RegisterNetEvent('dpn-drone:server:updateDrone', function(payload)
    local src = source
    local drone = ActiveDrones[src]
    if not drone or not allowed(src) or type(payload) ~= 'table' then return end
    local timestamp = GetGameTimer()
    if timestamp - (drone.lastUpdate or 0) < (Config.ServerUpdateMinimumMs or 1000) then return end

    local coords = normalizeCoords(payload.coords)
    if not coords then return end
    local elapsedSeconds = math.max(1, (timestamp - (drone.lastUpdate or timestamp)) / 1000)
    local maximumStep = (Config.ServerMaximumSpeedMetersPerSecond or 75.0) * elapsedSeconds
    if distance(coords, drone.coords) > maximumStep then return end
    if distance(coords, drone.launchCoords) > (Config.Drone.MaxRange + (Config.ServerRangeTolerance or 40.0)) then return end
    if coords.z - drone.launchCoords.z > (Config.Drone.MaxAltitude + (Config.ServerAltitudeTolerance or 15.0)) then return end

    local battery = math.max(0, math.min(100, math.floor(tonumber(payload.battery) or drone.battery)))
    if battery > drone.battery + 1 then battery = drone.battery end
    local modes = { normal = true, night = true, thermal = true }
    local mode = modes[tostring(payload.mode)] and tostring(payload.mode) or drone.mode

    drone.coords = coords
    drone.battery = battery
    drone.mode = mode
    drone.target = type(payload.target) == 'table' and payload.target or nil
    drone.lastUpdate = timestamp
    broadcast('dpn-drone:client:syncDrone', src, drone)
end)

RegisterNetEvent('dpn-drone:server:recall', function(reason)
    local src = source
    local drone = ActiveDrones[src]
    if not drone then return end
    log(src, 'Drone Recalled', { id = drone.id, reason = clean(reason or 'manual', 80) })
    broadcast('dpn-drone:client:removeDrone', src)
    ActiveDrones[src] = nil
end)

RegisterNetEvent('dpn-drone:server:createAlert', function(alert)
    createAlert(alert, source, 'dpn-drone-command')
end)

AddEventHandler('playerDropped', function()
    local src = source
    if ActiveDrones[src] then
        broadcast('dpn-drone:client:removeDrone', src)
        ActiveDrones[src] = nil
    end
end)

exports('GetActiveDrones', function() return ActiveDrones end)
exports('GetDroneByOwner', function(src) return ActiveDrones[tonumber(src)] end)
exports('CreateDroneAlert', function(alert)
    return createAlert(alert, 0, 'dpn-drone-command:export')
end)
