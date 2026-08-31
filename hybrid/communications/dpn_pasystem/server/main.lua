local ActivePA = {}
local LastStart = {}
local Framework = nil
local FrameworkName = 'standalone'

local function nowMs()
    if GetGameTimer then return GetGameTimer() end
    return os.time() * 1000
end

local function normalizeCoords(coords)
    if not coords then return nil end
    return { x = (coords.x or 0.0) + 0.0, y = (coords.y or 0.0) + 0.0, z = (coords.z or 0.0) + 0.0 }
end

local function debugPrint(...)
    if Config.Debug then
        print('[dpn_pasystem:server]', ...)
    end
end

local function tryGetFramework()
    if Framework then return Framework, FrameworkName end

    local requested = Config.Framework or 'auto'

    if requested == 'auto' or requested == 'qb' then
        if GetResourceState('qb-core') == 'started' then
            local ok, obj = pcall(function()
                return exports['qb-core']:GetCoreObject()
            end)
            if ok and obj then
                Framework = obj
                FrameworkName = 'qb'
                return Framework, FrameworkName
            end
        end
    end

    if requested == 'auto' or requested == 'qbx' then
        if GetResourceState('qbx_core') == 'started' then
            local ok, obj = pcall(function()
                return exports['qbx_core']:GetCoreObject()
            end)
            if ok and obj then
                Framework = obj
                FrameworkName = 'qbx'
                return Framework, FrameworkName
            end
        end
    end

    if requested == 'auto' or requested == 'esx' then
        if GetResourceState('es_extended') == 'started' then
            local ok, obj = pcall(function()
                return exports['es_extended']:getSharedObject()
            end)
            if ok and obj then
                Framework = obj
                FrameworkName = 'esx'
                return Framework, FrameworkName
            end
        end
    end

    FrameworkName = 'standalone'
    return nil, FrameworkName
end

local function notify(src, message, msgType)
    TriggerClientEvent('dpn_pa:client:notify', src, message, msgType or 'primary')
end

local function tableContains(tbl, value)
    if type(tbl) ~= 'table' then return false end
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

local function getGradeNumber(grade)
    if type(grade) == 'table' then
        return tonumber(grade.level or grade.grade or grade.value or 0) or 0
    end
    return tonumber(grade or 0) or 0
end

local function getPlayerJob(src)
    local core, name = tryGetFramework()

    if name == 'qb' or name == 'qbx' then
        local Player = core and core.Functions and core.Functions.GetPlayer(src)
        if not Player or not Player.PlayerData or not Player.PlayerData.job then return nil end
        local job = Player.PlayerData.job
        return {
            name = job.name,
            label = job.label or job.name,
            grade = getGradeNumber(job.grade),
            onduty = job.onduty ~= false,
        }
    elseif name == 'esx' then
        local xPlayer = core and core.GetPlayerFromId and core.GetPlayerFromId(src)
        if not xPlayer or not xPlayer.getJob then return nil end
        local job = xPlayer.getJob()
        if not job then return nil end
        return {
            name = job.name,
            label = job.label or job.name,
            grade = getGradeNumber(job.grade),
            onduty = true,
        }
    end

    return nil
end

local function hasRequiredItem(src)
    if not Config.RequiredItem then return true end
    local item = Config.RequiredItem
    local core, name = tryGetFramework()

    if GetResourceState('ox_inventory') == 'started' then
        local ok, count = pcall(function()
            return exports.ox_inventory:Search(src, 'count', item)
        end)
        if ok and tonumber(count or 0) > 0 then return true end
    end

    if name == 'qb' or name == 'qbx' then
        local Player = core and core.Functions and core.Functions.GetPlayer(src)
        if Player and Player.Functions and Player.Functions.GetItemByName then
            local found = Player.Functions.GetItemByName(item)
            return found ~= nil
        end
    elseif name == 'esx' then
        local xPlayer = core and core.GetPlayerFromId and core.GetPlayerFromId(src)
        if xPlayer and xPlayer.getInventoryItem then
            local inv = xPlayer.getInventoryItem(item)
            return inv and tonumber(inv.count or 0) > 0
        end
    end

    return false
end

local function jobAuthorized(src)
    local job = getPlayerJob(src)
    if not job then return false, 'no_job' end

    local allowed = Config.AllowedJobs[job.name]
    if not allowed then return false, 'bad_job', job end

    if Config.RequireOnDuty and job.onduty == false then
        return false, 'not_on_duty', job
    end

    local minGrade = tonumber(allowed.minGrade or 0) or 0
    if job.grade < minGrade then
        return false, 'grade', job
    end

    return true, 'job', job
end

local function aceAuthorized(src)
    if not Config.AcePermission or Config.AcePermission == '' then return false end
    return IsPlayerAceAllowed(src, Config.AcePermission)
end

local function isAuthorized(src)
    local mode = Config.PermissionMode or 'either'
    local jobOk, jobReason, job = jobAuthorized(src)
    local aceOk = aceAuthorized(src)

    if mode == 'job' then
        return jobOk, jobReason, job
    elseif mode == 'ace' then
        return aceOk, aceOk and 'ace' or 'ace_missing', job
    elseif mode == 'both' then
        if jobOk and aceOk then return true, 'both', job end
        return false, not jobOk and jobReason or 'ace_missing', job
    end

    if jobOk or aceOk then
        return true, jobOk and 'job' or 'ace', job
    end

    return false, jobReason or 'not_allowed', job
end

local function safeEntityFromNet(netId)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return 0 end
    local ok, entity = pcall(NetworkGetEntityFromNetworkId, netId)
    if ok then return entity or 0 end
    return 0
end

local function validateVehicleServer(src, data)
    if not Config.RequireVehicle then return true end
    if type(data) ~= 'table' then return false, 'no_vehicle' end

    local ped = GetPlayerPed(src)
    if ped == 0 then return false, 'no_vehicle' end

    local veh = safeEntityFromNet(data.vehicleNetId)
    if veh == 0 or not DoesEntityExist(veh) then
        return false, 'no_vehicle'
    end

    local pedCoords = GetEntityCoords(ped)
    local vehCoords = GetEntityCoords(veh)
    if #(pedCoords - vehCoords) > 12.0 then
        return false, 'no_vehicle'
    end

    if Config.RequireEmergencyVehicle then
        local okClass, vehicleClass = pcall(GetVehicleClass, veh)
        if okClass and vehicleClass and Config.AllowedVehicleClasses[vehicleClass] then
            return true, nil, veh
        end

        local okModel, model = pcall(GetEntityModel, veh)
        if okModel and model then
            for modelName in pairs(Config.AllowedVehicleModels) do
                if model == joaat(modelName) then
                    return true, nil, veh
                end
            end
        end

        return false, 'no_vehicle'
    end

    return true, nil, veh
end

local function makePayload(src)
    local active = ActivePA[src]
    if not active then return nil end

    return {
        source = src,
        session = active.session,
        range = active.range,
        plate = active.plate,
        job = active.jobLabel,
        name = active.name,
        coords = normalizeCoords(active.coords),
        startedAt = active.startedAt,
    }
end

local function stopPA(src, reason)
    local active = ActivePA[src]
    if not active then return end
    ActivePA[src] = nil
    TriggerClientEvent('dpn_pa:client:forceStop', src, reason or 'stopped')
    TriggerClientEvent('dpn_pa:client:incomingStop', -1, src, active.session)
    debugPrint(('Stopped PA for %s reason=%s'):format(src, reason or 'stopped'))
end

RegisterNetEvent('dpn_pa:server:requestAuth', function()
    local src = source
    local ok, reason, job = isAuthorized(src)
    TriggerClientEvent('dpn_pa:client:setAuth', src, {
        authorized = ok,
        reason = reason,
        job = job,
        framework = FrameworkName,
        ace = aceAuthorized(src),
    })
end)

RegisterNetEvent('dpn_pa:server:startPA', function(data)
    local src = source
    local now = nowMs()
    local last = LastStart[src] or 0

    if now - last < Config.StartCooldownMs then
        notify(src, Config.Messages.too_fast, 'error')
        TriggerClientEvent('dpn_pa:client:startDenied', src, 'cooldown')
        return
    end
    LastStart[src] = now

    local allowed, reason, job = isAuthorized(src)
    if not allowed then
        if reason == 'not_on_duty' then
            notify(src, Config.Messages.not_on_duty, 'error')
        else
            notify(src, Config.Messages.no_permission, 'error')
        end
        TriggerClientEvent('dpn_pa:client:startDenied', src, reason)
        return
    end

    if not hasRequiredItem(src) then
        notify(src, Config.Messages.no_item, 'error')
        TriggerClientEvent('dpn_pa:client:startDenied', src, 'no_item')
        return
    end

    local vehOk, vehReason = validateVehicleServer(src, data)
    if not vehOk then
        notify(src, Config.Messages.no_vehicle, 'error')
        TriggerClientEvent('dpn_pa:client:startDenied', src, vehReason or 'no_vehicle')
        return
    end

    local range = Config.ClampRange(data and data.range)
    local session = ('%s:%s:%s'):format(src, now, math.random(1111, 9999))
    local ped = GetPlayerPed(src)
    local coords = normalizeCoords(data and data.coords or GetEntityCoords(ped))
    local name = GetPlayerName(src) or ('ID ' .. tostring(src))

    ActivePA[src] = {
        session = session,
        range = range,
        vehicleNetId = data and data.vehicleNetId or 0,
        plate = data and data.plate or 'UNKNOWN',
        model = data and data.model or 'unknown',
        coords = coords,
        name = name,
        jobName = job and job.name or 'ACE',
        jobLabel = job and job.label or 'Authorized',
        startedAt = now,
    }

    TriggerClientEvent('dpn_pa:client:startApproved', src, {
        session = session,
        range = range,
        maxSeconds = Config.MaxTransmissionSeconds,
    })

    TriggerClientEvent('dpn_pa:client:incomingPA', -1, makePayload(src))
    debugPrint(('Started PA for %s range=%.1f plate=%s'):format(src, range, ActivePA[src].plate))
end)

RegisterNetEvent('dpn_pa:server:heartbeat', function(data)
    local src = source
    local active = ActivePA[src]
    if not active then return end

    local allowed = isAuthorized(src)
    if not allowed then
        stopPA(src, 'permission')
        return
    end

    local vehOk = validateVehicleServer(src, data or active)
    if not vehOk then
        stopPA(src, 'vehicle')
        return
    end

    active.coords = normalizeCoords(data and data.coords or active.coords)
    active.range = Config.ClampRange(data and data.range or active.range)
    active.vehicleNetId = data and data.vehicleNetId or active.vehicleNetId
    active.plate = data and data.plate or active.plate

    if Config.MaxTransmissionSeconds then
        local ageSeconds = (nowMs() - active.startedAt) / 1000
        if ageSeconds >= Config.MaxTransmissionSeconds then
            stopPA(src, 'timeout')
            return
        end
    end

    TriggerClientEvent('dpn_pa:client:incomingPA', -1, makePayload(src))
end)

RegisterNetEvent('dpn_pa:server:stopPA', function(reason)
    stopPA(source, reason or 'client_stop')
end)

RegisterCommand(Config.Commands.status, function(src)
    if src == 0 then
        local count = 0
        for _ in pairs(ActivePA) do count = count + 1 end
        print(('[dpn_pasystem] Active PA transmissions: %s'):format(count))
        for id, active in pairs(ActivePA) do
            print(('  ID %s | %s | %s | range %.1f'):format(id, active.name, active.plate, active.range))
        end
        return
    end

    local ok, reason, job = isAuthorized(src)
    TriggerClientEvent('dpn_pa:client:statusReport', src, {
        authorized = ok,
        reason = reason,
        job = job,
        active = ActivePA[src] ~= nil,
    })
end, false)

AddEventHandler('playerDropped', function()
    stopPA(source, 'dropped')
    LastStart[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(ActivePA) do
        TriggerClientEvent('dpn_pa:client:forceStop', src, 'resource_stop')
    end
    ActivePA = {}
end)

exports('IsPAActive', function(src)
    return ActivePA[tonumber(src)] ~= nil
end)

exports('StopPA', function(src, reason)
    stopPA(tonumber(src), reason or 'export')
end)
