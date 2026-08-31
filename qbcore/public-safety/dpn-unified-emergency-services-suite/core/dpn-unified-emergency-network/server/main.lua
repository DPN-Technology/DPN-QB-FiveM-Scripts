local QBCore = exports['qb-core']:GetCoreObject()
DPN_UNES = DPN_UNES or {}
DPN_UNES.Server = DPN_UNES.Server or {}
DPN_UNES.Cache = DPN_UNES.Cache or { incidents = {}, units = {}, unitIndex = {}, bolos = {}, mutualAid = {}, audit = {} }
DPN_UNES.Cache.incidents = DPN_UNES.Cache.incidents or {}
DPN_UNES.Cache.units = DPN_UNES.Cache.units or {}
DPN_UNES.Cache.unitIndex = DPN_UNES.Cache.unitIndex or {}
DPN_UNES.Cache.bolos = DPN_UNES.Cache.bolos or {}
DPN_UNES.Cache.mutualAid = DPN_UNES.Cache.mutualAid or {}
DPN_UNES.Cache.audit = DPN_UNES.Cache.audit or {}

local function now() return os.time() end
local function cleanKey(value) return tostring(value or ''):lower():gsub('%s+', '') end
local function tableHas(list, value) for _, v in ipairs(list or {}) do if v == value then return true end end return false end

function DPN_UNES.Server.GetPlayer(src)
    return QBCore.Functions.GetPlayer(tonumber(src))
end

function DPN_UNES.Server.GetUnitKey(profile)
    if not profile then return nil end
    if profile.citizenid and profile.citizenid ~= '' then return ('cid:%s'):format(cleanKey(profile.citizenid)) end
    return ('src:%s'):format(tostring(profile.source))
end

function DPN_UNES.Server.Audit(src, action, target, details)
    if not DPN_UNES.Config.EnableAuditLogs then return end
    local unit = src and src ~= 0 and DPN_UNES.Server.GetUnitProfile(src) or nil
    local row = { time = now(), source = src or 0, callsign = unit and unit.callsign or 'SYSTEM', agency = unit and unit.agency or 'system', action = action, target = target, details = details or {} }
    table.insert(DPN_UNES.Cache.audit, 1, row)
    while #DPN_UNES.Cache.audit > 150 do table.remove(DPN_UNES.Cache.audit) end
    MySQL.insert('INSERT INTO dpn_unes_audit (source, citizenid, callsign, agency, action, target, details, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())', {
        row.source, unit and unit.citizenid or nil, row.callsign, row.agency, action, target, json.encode(details or {})
    })
end

function DPN_UNES.Server.GetUnitProfile(src)
    src = tonumber(src)
    local Player = DPN_UNES.Server.GetPlayer(src)
    if not Player then return nil end
    local job = Player.PlayerData.job or {}
    local jobName = job.name or 'unknown'
    local cfg = DPN_UNES.Config.Jobs[jobName]
    local char = Player.PlayerData.charinfo or {}
    local meta = Player.PlayerData.metadata or {}
    local grade = 0
    if type(job.grade) == 'table' then grade = tonumber(job.grade.level or job.grade.grade or 0) or 0 else grade = tonumber(job.grade or 0) or 0 end
    local existingKey = DPN_UNES.Cache.unitIndex[src]
    local existing = existingKey and DPN_UNES.Cache.units[existingKey] or {}
    local profile = {
        source = src,
        citizenid = Player.PlayerData.citizenid,
        name = ((char.firstname or 'Unknown') .. ' ' .. (char.lastname or '')):gsub('%s+$',''),
        callsign = meta.callsign or meta.callSign or meta.callsign_override or tostring(src),
        radio = meta.radio or meta.radioChannel or 'OFF',
        job = jobName,
        agency = cfg and cfg.type or 'civilian',
        agencyLabel = cfg and cfg.label or 'Civilian',
        canDispatch = cfg and cfg.dispatch == true or false,
        canCommand = cfg and cfg.command == true and grade >= 4 or false,
        grade = grade,
        onduty = job.onduty == true,
        status = existing.status or 'available',
        assignment = existing.assignment,
        coords = existing.coords,
        heading = existing.heading,
        vehicle = existing.vehicle,
        lastSeen = now(),
        heartbeat = now()
    }
    profile.unitKey = DPN_UNES.Server.GetUnitKey(profile)
    return profile
end

function DPN_UNES.Server.IsEmergencyUnit(src)
    local profile = DPN_UNES.Server.GetUnitProfile(src)
    return profile and profile.agency ~= 'civilian' and profile.onduty
end

function DPN_UNES.Server.IsDispatcher(src)
    local p = DPN_UNES.Server.GetUnitProfile(src)
    return p and p.onduty and p.canDispatch
end

function DPN_UNES.Server.UpsertUnit(src, data)
    src = tonumber(src)
    local profile = DPN_UNES.Server.GetUnitProfile(src)
    if not profile or not profile.onduty or profile.agency == 'civilian' then
        local oldKey = DPN_UNES.Cache.unitIndex[src]
        if oldKey then DPN_UNES.Cache.units[oldKey] = nil; DPN_UNES.Cache.unitIndex[src] = nil end
        TriggerClientEvent('dpn-unes:client:unitRemoved', -1, oldKey or tostring(src))
        return nil
    end

    local key = profile.unitKey
    local previousKey = DPN_UNES.Cache.unitIndex[src]
    if previousKey and previousKey ~= key then DPN_UNES.Cache.units[previousKey] = nil; TriggerClientEvent('dpn-unes:client:unitRemoved', -1, previousKey) end

    local old = DPN_UNES.Cache.units[key] or {}
    data = type(data) == 'table' and data or {}

    -- Live-map position is server authoritative. Client GPS payloads are treated as hints only.
    local ped = GetPlayerPed(src)
    if ped and ped > 0 and DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        profile.coords = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
        profile.heading = GetEntityHeading(ped) + 0.0
    else
        profile.coords = old.coords or profile.coords
        profile.heading = old.heading
    end

    if type(data.vehicle) == 'table' then
        profile.vehicle = {
            plate = tostring(data.vehicle.plate or ''):sub(1, 16),
            model = tostring(data.vehicle.model or ''):sub(1, 64),
            speed = math.max(0, math.min(250, tonumber(data.vehicle.speed) or 0)),
            netId = tonumber(data.vehicle.netId)
        }
    else
        profile.vehicle = old.vehicle
    end

    profile.status = tableHas(DPN_UNES.Config.UnitStatuses, data.status) and data.status or old.status or profile.status or 'available'
    profile.assignment = old.assignment
    profile.lastSeen = now()
    profile.heartbeat = now()

    DPN_UNES.Cache.units[key] = profile
    DPN_UNES.Cache.unitIndex[src] = key
    TriggerClientEvent('dpn-unes:client:unitUpdated', -1, profile)
    return profile
end

function DPN_UNES.Server.GetOpenPayload(src)
    return {
        profile = DPN_UNES.Server.GetUnitProfile(src),
        incidents = DPN_UNES.Cache.incidents,
        units = DPN_UNES.Cache.units,
        bolos = DPN_UNES.Cache.bolos,
        mutualAid = DPN_UNES.Cache.mutualAid,
        audit = DPN_UNES.Cache.audit,
        config = { colors = DPN_UNES.Config.AgencyColors, statuses = DPN_UNES.Config.UnitStatuses, routing = DPN_UNES.Config.Routing, liveMap = DPN_UNES.Config.LiveMap },
        serverTime = now()
    }
end

RegisterNetEvent('QBCore:Server:OnJobUpdate', function(src) if src then DPN_UNES.Server.UpsertUnit(src) end end)
RegisterNetEvent('QBCore:Server:SetDuty', function() DPN_UNES.Server.UpsertUnit(source) end)

RegisterNetEvent('dpn-unes:server:unitLocation', function(data)
    DPN_UNES.Server.UpsertUnit(source, data or {})
end)

RegisterNetEvent('dpn-unes:server:setUnitStatus', function(status)
    if not tableHas(DPN_UNES.Config.UnitStatuses, status) then return end
    local unit = DPN_UNES.Server.UpsertUnit(source, { status = status })
    if unit then DPN_UNES.Server.Audit(source, 'unit_status', unit.unitKey, { status = status }) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local oldKey = DPN_UNES.Cache.unitIndex[src]
    if oldKey then DPN_UNES.Cache.units[oldKey] = nil; DPN_UNES.Cache.unitIndex[src] = nil; TriggerClientEvent('dpn-unes:client:unitRemoved', -1, oldKey) end
end)

CreateThread(function()
    while true do
        Wait(DPN_UNES.Config.UnitRefreshMs or 10000)
        local seen = {}
        for _, id in ipairs(GetPlayers()) do
            local unit = DPN_UNES.Server.UpsertUnit(tonumber(id))
            if unit then seen[unit.unitKey] = true end
        end
        for key, unit in pairs(DPN_UNES.Cache.units) do
            if not seen[key] and (now() - (unit.lastSeen or 0)) > (DPN_UNES.Config.StaleUnitSeconds or 75) then
                DPN_UNES.Cache.units[key] = nil
                TriggerClientEvent('dpn-unes:client:unitRemoved', -1, key)
            end
        end
    end
end)

RegisterCommand(DPN_UNES.Config.Command, function(src)
    if src == 0 then return end
    if not DPN_UNES.Server.IsEmergencyUnit(src) then
        TriggerClientEvent('QBCore:Notify', src, 'You are not authorized to access the Unified Emergency Service Network.', 'error')
        return
    end
    DPN_UNES.Server.UpsertUnit(src)
    TriggerClientEvent('dpn-unes:client:open', src, DPN_UNES.Server.GetOpenPayload(src))
    DPN_UNES.Server.Audit(src, 'open_ui', 'unes', {})
end, false)

RegisterCommand(DPN_UNES.Config.PanicCommand, function(src)
    if src == 0 or not DPN_UNES.Server.IsEmergencyUnit(src) then return end
    TriggerEvent('dpn-unes:server:createIncident', src, {
        type = 'panic', title = 'PANIC BUTTON ACTIVATED', description = 'Responder panic activation. Immediate multi-agency response requested.', priority = 1, agencies = {'law','ems','fire'}
    })
end, false)

-- v4 live-map repair: manually refresh all unit/incident coordinates for the requesting UI.
RegisterNetEvent('dpn-unes:server:requestSnapshot', function()
    local src = source
    if src == 0 or not DPN_UNES.Server.IsEmergencyUnit(src) then return end
    DPN_UNES.Server.UpsertUnit(src)
    TriggerClientEvent('dpn-unes:client:snapshot', src, DPN_UNES.Server.GetOpenPayload(src))
end)


-- v7 Oulsen satmap diagnostics: prints current cached GPS points to server console.
RegisterNetEvent('dpn-unes:server:mapDebug', function()
    local src = source
    if src == 0 or not DPN_UNES.Server.IsEmergencyUnit(src) then return end
    local count, gps = 0, 0
    for key, unit in pairs(DPN_UNES.Cache.units or {}) do
        count = count + 1
        if unit.coords and unit.coords.x and unit.coords.y then gps = gps + 1 end
        print(('[DPN-UNES MAP DEBUG] %s | %s | coords=%s,%s | lastSeen=%s'):format(key, unit.callsign or 'UNK', unit.coords and math.floor(unit.coords.x or 0) or 'nil', unit.coords and math.floor(unit.coords.y or 0) or 'nil', unit.lastSeen or 0))
    end
    TriggerClientEvent('QBCore:Notify', src, ('Map debug printed to server console: %s/%s units have GPS.'):format(gps, count), 'primary')
end)
