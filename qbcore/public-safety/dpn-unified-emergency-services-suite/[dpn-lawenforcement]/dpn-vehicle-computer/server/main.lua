local QBCore = exports['qb-core']:GetCoreObject()
local hotlist = {}
local eventRate = {}
local rateAudit = {}

local function clean(value, maxLength)
    local text = tostring(value or ''):gsub('[%z\1-\8\11\12\14-\31]', '')
    if #text > maxLength then text = text:sub(1, maxLength) end
    return text
end

local function trimPlate(value)
    return clean(value, 16):upper():gsub('^%s*(.-)%s*$', '%1')
end

local function securityConfig()
    return type(Config.Security) == 'table' and Config.Security or {}
end

local function rateAllowed(src, action)
    src = tonumber(src) or 0
    if src <= 0 then return true end

    local security = securityConfig()
    local limits = type(security.EventLimits) == 'table' and security.EventLimits or {}
    local window = math.max(1, math.floor(tonumber(security.EventWindowSeconds) or 10))
    local limit = math.max(1, math.floor(tonumber(limits[action]) or 8))
    local now = os.time()

    local sourceBucket = eventRate[src]
    if not sourceBucket then
        sourceBucket = {}
        eventRate[src] = sourceBucket
    end

    local bucket = sourceBucket[action]
    if not bucket or now - bucket.started >= window then
        sourceBucket[action] = { started = now, count = 1 }
        return true
    end

    bucket.count = bucket.count + 1
    if bucket.count <= limit then return true end

    local auditKey = ('%s:%s'):format(src, action)
    local auditCooldown = math.max(1, math.floor(tonumber(security.RateLimitAuditCooldownSeconds) or 10))
    if not rateAudit[auditKey] or now - rateAudit[auditKey] >= auditCooldown then
        rateAudit[auditKey] = now
        print(('^3[dpn-vehicle-computer][SECURITY]^7 rate limited source=%s action=%s count=%s window=%ss'):format(
            src,
            clean(action, 32),
            bucket.count,
            window
        ))
    end

    return false
end

local function getPlayerData(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return nil end
    local data = player.PlayerData
    local charinfo = data.charinfo or {}
    local grade = data.job and data.job.grade or 0
    if type(grade) == 'table' then grade = grade.level or grade.grade or 0 end
    return {
        name = (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1'),
        job = data.job and data.job.name or 'unknown',
        grade = tonumber(grade) or 0,
        onDuty = data.job and data.job.onduty == true,
        identifier = data.citizenid
    }
end

local function isAllowed(src)
    if IsPlayerAceAllowed(src, 'dpn.leo') or IsPlayerAceAllowed(src, 'dpn.vehiclecomputer') then
        return true, getPlayerData(src)
    end
    if GetResourceState('dpn-le-core') == 'started' then
        local ok, allowed = pcall(function()
            return exports['dpn-le-core']:IsAllowed(src, true, false)
        end)
        if ok and allowed then return true, getPlayerData(src) end
    end
    local data = getPlayerData(src)
    return data and Config.AllowedJobs[data.job] == true and data.onDuty, data
end

local function verifiedCoords(src)
    local ok, result = pcall(function()
        local ped = GetPlayerPed(src)
        if not ped or ped <= 0 or not DoesEntityExist(ped) then return nil end
        local coords = GetEntityCoords(ped)
        return { x = coords.x, y = coords.y, z = coords.z }
    end)
    return ok and result or nil
end

local function verifiedVehicle(src)
    local ok, result = pcall(function()
        local ped = GetPlayerPed(src)
        if not ped or ped <= 0 or not DoesEntityExist(ped) then return nil end
        local vehicle = GetVehiclePedIsIn(ped, false)
        if not vehicle or vehicle <= 0 or not DoesEntityExist(vehicle) then return nil end
        local driver = GetPedInVehicleSeat(vehicle, -1) == ped
        if not Config.AllowPassengerUse and not driver then return nil end
        if Config.RequireEmergencyVehicle and GetVehicleClass(vehicle) ~= 18 then return nil end
        return {
            netId = NetworkGetNetworkIdFromEntity(vehicle),
            plate = trimPlate(GetVehicleNumberPlateText(vehicle)),
            model = tostring(GetEntityModel(vehicle)),
            speed = math.floor(GetEntitySpeed(vehicle) * 2.236936 + 0.5),
            seat = driver and 'Driver' or 'Passenger'
        }
    end)
    return ok and result or nil
end

local function authorizedRecipients()
    local result = {}
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        local allowed = target and isAllowed(target)
        if allowed then result[#result + 1] = target end
    end
    return result
end

local function notify(src, message, kind)
    TriggerClientEvent('dpn-vehicle-computer:client:notify', src, message, kind or 'primary')
end

local function enforceRateLimit(src, action)
    if rateAllowed(src, action) then return true end
    notify(src, 'Vehicle computer request rate limit reached. Try again shortly.', 'error')
    return false
end

local function webhook(title, description)
    if not Config.Webhooks.Enabled or Config.Webhooks.VehicleComputer == '' then return end
    PerformHttpRequest(Config.Webhooks.VehicleComputer, function() end, 'POST', json.encode({
        username = 'DPN Vehicle Computer',
        embeds = {{ title = title, description = description, color = 3447003 }}
    }), { ['Content-Type'] = 'application/json' })
end

local function loadHotlist()
    local rows = MySQL.query.await('SELECT plate, reason, added_by, created_at FROM dpn_vehicle_hotlist WHERE active = 1', {}) or {}
    hotlist = {}
    for _, row in ipairs(rows) do
        row.flagged = true
        hotlist[trimPlate(row.plate)] = row
    end
end

local function ownerFromCitizenId(citizenid)
    if not citizenid then return 'Unknown' end
    local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row or not row.charinfo then return 'Unknown' end
    local ok, charinfo = pcall(json.decode, row.charinfo)
    if not ok or type(charinfo) ~= 'table' then return 'Unknown' end
    return (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1')
end

local function sanitizeDispatchCall(input, officerName, src)
    input = type(input) == 'table' and input or {}

    local callType = clean(input.type or 'traffic', 40):lower()
    if callType == '' then callType = 'traffic' end

    local priority = math.floor(tonumber(input.priority) or 3)
    if priority < 1 then priority = 1 end
    if priority > 5 then priority = 5 end

    return {
        type = callType,
        title = clean(input.title or 'Vehicle Computer Call', 128),
        description = clean(input.description or input.desc or 'Call created from vehicle computer.', 1000),
        priority = priority,
        createdBy = officerName,
        staffOnly = true,
        coords = verifiedCoords(src),
        departments = { 'law', 'dispatch' },
        metadata = { source = 'vehicle-computer' }
    }
end

CreateThread(function()
    Wait(750)
    loadHotlist()
end)

AddEventHandler('playerDropped', function()
    local src = tonumber(source) or 0
    eventRate[src] = nil

    local prefix = ('%s:'):format(src)
    for key in pairs(rateAudit) do
        if key:sub(1, #prefix) == prefix then
            rateAudit[key] = nil
        end
    end
end)

RegisterNetEvent('dpn-vehicle-computer:server:open', function()
    local src = source
    if not enforceRateLimit(src, 'open') then return end

    local allowed, data = isAllowed(src)
    if not allowed then
        return notify(src, 'You must be on duty to access the vehicle computer.', 'error')
    end

    local vehicle = verifiedVehicle(src)
    if Config.RequireVehicle and not vehicle then
        return notify(src, 'A verified authorized vehicle is required.', 'error')
    end

    TriggerClientEvent('dpn-vehicle-computer:client:openUI', src, {
        officer = data,
        vehicle = vehicle,
        statuses = Config.Statuses,
        modules = Config.Modules,
        hotlist = hotlist
    })
    webhook('Computer Opened', ('%s opened vehicle computer.'):format(data.name))
end)

RegisterNetEvent('dpn-vehicle-computer:server:setStatus', function(status)
    local src = source
    if not enforceRateLimit(src, 'setStatus') then return end

    local allowed = isAllowed(src)
    if not allowed then return end

    status = clean(status, 16)
    if status == '' or not Config.Statuses[status] then return end

    local ok = GetResourceState('dpn-le-core') == 'started' and exports['dpn-le-core']:SetOfficerStatus(src, status)
    if not ok and GetResourceState('dpn-digital-dispatch') == 'started' then
        exports['dpn-digital-dispatch']:UpdateUnit(src, { status = status })
    end
    notify(src, ('Status set to %s - %s'):format(status, Config.Statuses[status]), 'success')
end)

RegisterNetEvent('dpn-vehicle-computer:server:createCall', function(input)
    local src = source
    if not enforceRateLimit(src, 'createCall') then return end

    local allowed, data = isAllowed(src)
    if not allowed then return end

    local call = sanitizeDispatchCall(input, data.name, src)
    if not call.coords then
        return notify(src, 'Unable to verify your server-side position for this call.', 'error')
    end

    if GetResourceState('dpn-digital-dispatch') == 'started' then
        exports['dpn-digital-dispatch']:CreateDispatchCall(call, src)
    else
        TriggerEvent('dpn_dispatch:server:createCall', call)
    end
    webhook('Call Created From Vehicle Computer', ('%s created call: %s'):format(data.name, call.title))
end)

RegisterNetEvent('dpn-vehicle-computer:server:panic', function()
    local src = source
    if not enforceRateLimit(src, 'panic') then return end

    local allowed, data = isAllowed(src)
    if not allowed then return end

    local coords = verifiedCoords(src)
    if not coords then return end

    local call = {
        type = 'panic',
        title = 'OFFICER PANIC BUTTON',
        priority = 1,
        coords = coords,
        description = ('Emergency panic activation from %s'):format(data.name),
        staffOnly = true,
        departments = { 'law', 'dispatch', 'medical' },
        metadata = { source = 'vehicle-computer', officer = data.identifier }
    }

    if GetResourceState('dpn-digital-dispatch') == 'started' then
        exports['dpn-digital-dispatch']:CreateDispatchCall(call, src)
    end

    for _, target in ipairs(authorizedRecipients()) do
        TriggerClientEvent('dpn-vehicle-computer:client:panicAlert', target, data.name, coords)
    end
    webhook('PANIC BUTTON', ('%s activated panic button.'):format(data.name))
end)

RegisterNetEvent('dpn-vehicle-computer:server:plateCheck', function(plate)
    local src = source
    if not enforceRateLimit(src, 'plateCheck') then return end
    if not isAllowed(src) then return end

    plate = trimPlate(plate)
    if plate == '' then return end

    local vehicle = MySQL.single.await(
        'SELECT citizenid, vehicle, garage, state FROM player_vehicles WHERE TRIM(plate) = ? LIMIT 1',
        { plate }
    )
    local flagged = hotlist[plate]
    local result = {
        plate = plate,
        flagged = flagged ~= nil,
        reason = flagged and flagged.reason or 'No active alerts',
        owner = vehicle and ownerFromCitizenId(vehicle.citizenid) or 'Unregistered',
        citizenid = vehicle and vehicle.citizenid or nil,
        model = vehicle and vehicle.vehicle or 'Unknown',
        garage = vehicle and vehicle.garage or nil,
        state = vehicle and vehicle.state or nil
    }
    TriggerClientEvent('dpn-vehicle-computer:client:plateResult', src, result)
end)

RegisterNetEvent('dpn-vehicle-computer:server:addHotlist', function(plate, reason)
    local src = source
    if not enforceRateLimit(src, 'addHotlist') then return end

    local allowed, data = isAllowed(src)
    if not allowed then return end

    plate = trimPlate(plate)
    reason = clean(reason or 'Officer safety alert', 255)
    if plate == '' then return end

    MySQL.query([[INSERT INTO dpn_vehicle_hotlist (plate, reason, added_by, active)
        VALUES (?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE reason=VALUES(reason), added_by=VALUES(added_by), active=1, created_at=CURRENT_TIMESTAMP]], {
        plate,
        reason,
        data.name
    })

    hotlist[plate] = {
        plate = plate,
        flagged = true,
        reason = reason,
        added_by = data.name,
        created_at = os.date('%Y-%m-%d %H:%M:%S')
    }
    notify(src, ('Plate %s added to the hotlist.'):format(plate), 'success')
end)

RegisterNetEvent('dpn-vehicle-computer:server:saveNote', function(text)
    local src = source
    if not enforceRateLimit(src, 'saveNote') then return end

    local allowed, data = isAllowed(src)
    if not allowed then return end

    text = clean(text, 4000)
    if text == '' then return end

    MySQL.insert(
        'INSERT INTO dpn_vehicle_computer_notes (officer, officer_cid, text) VALUES (?, ?, ?)',
        { data.name, data.identifier, text }
    )
    notify(src, 'Patrol note saved.', 'success')
end)

exports('IsAllowed', isAllowed)
exports('GetHotlist', function()
    return hotlist
end)

exports('AddHotlistPlate', function(plate, reason)
    plate = trimPlate(plate)
    if plate == '' then return false end

    reason = clean(reason or 'External alert', 255)
    MySQL.query([[INSERT INTO dpn_vehicle_hotlist (plate, reason, added_by, active) VALUES (?, ?, 'DPN System', 1)
        ON DUPLICATE KEY UPDATE reason=VALUES(reason), active=1]], { plate, reason })

    hotlist[plate] = {
        plate = plate,
        flagged = true,
        reason = reason,
        added_by = 'DPN System'
    }
    return true
end)
