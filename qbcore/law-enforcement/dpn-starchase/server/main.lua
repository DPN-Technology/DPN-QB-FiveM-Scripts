QBCore = exports[Config.CoreName]:GetCoreObject()

local ActiveTrackers = {}
local OfficerCooldowns = {}
local UpdateThrottle = {}
local TrackerCounter = 0

local function Debug(msg)
    if Config.Debug then print(('^5[dpn-starchase]^7 %s'):format(msg)) end
end

local function TrimPlate(plate)
    return tostring(plate or 'UNKNOWN'):gsub('^%s*(.-)%s*$', '%1'):sub(1, 16)
end

local function Now()
    return os.time()
end

local function GenerateTrackerId(src)
    TrackerCounter = TrackerCounter + 1
    return ('DPN-%s-%s-%04d'):format(os.date('%y%m%d%H%M%S'), tostring(src or 0), TrackerCounter)
end

local function PlayerName(Player)
    if not Player or not Player.PlayerData then return 'Unknown Officer' end
    local ci = Player.PlayerData.charinfo or {}
    local name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s*(.-)%s*$', '%1')
    if name == '' then name = GetPlayerName(Player.PlayerData.source) or 'Unknown Officer' end
    return name
end

local function IsAllowed(src, silent)
    if Config.AllowAdminBypass and IsPlayerAceAllowed(src, 'command.dpnstarchase.admin') then
        return true
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.job then
        return false, Config.Messages.noAccess
    end

    local job = Player.PlayerData.job
    local minGrade = Config.AllowedJobs[job.name]
    if minGrade == nil then
        return false, Config.Messages.noAccess
    end

    if Config.RequireOnDuty and not job.onduty then
        return false, Config.Messages.offDuty
    end

    local gradeLevel = 0
    if type(job.grade) == 'table' then
        gradeLevel = tonumber(job.grade.level or job.grade.grade or 0) or 0
    else
        gradeLevel = tonumber(job.grade or 0) or 0
    end

    if gradeLevel < minGrade then
        return false, Config.Messages.noAccess
    end

    return true
end

local function Notify(src, msg, nType, time)
    TriggerClientEvent('QBCore:Notify', src, msg, nType or 'primary', time or 4500)
end

local function HasItem(src, item)
    if not item or item == '' then return true end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local invItem = Player.Functions.GetItemByName(item)
    return invItem and (invItem.amount or 0) > 0
end

local function RemoveItem(src, item, amount)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    return Player.Functions.RemoveItem(item, amount or 1)
end

local function ActiveCountFor(src)
    local count = 0
    for _, tracker in pairs(ActiveTrackers) do
        if tracker.createdBy == src and tracker.status == 'active' then count = count + 1 end
    end
    return count
end

local function ActiveCountGlobal()
    local count = 0
    for _, tracker in pairs(ActiveTrackers) do
        if tracker.status == 'active' then count = count + 1 end
    end
    return count
end

local function CompactTracker(tracker)
    return {
        id = tracker.id,
        plate = tracker.plate,
        netId = tracker.netId,
        model = tracker.model,
        coords = tracker.coords,
        heading = tracker.heading,
        speed = tracker.speed,
        street = tracker.street,
        createdBy = tracker.createdBy,
        officerName = tracker.officerName,
        job = tracker.job,
        createdAt = tracker.createdAt,
        expiresAt = tracker.expiresAt,
        lastUpdate = tracker.lastUpdate,
        status = tracker.status,
        reason = tracker.reason
    }
end

local function GetTrackersList()
    local list = {}
    for _, tracker in pairs(ActiveTrackers) do
        if tracker.status == 'active' then
            list[#list + 1] = CompactTracker(tracker)
        end
    end
    table.sort(list, function(a, b) return (a.createdAt or 0) > (b.createdAt or 0) end)
    return list
end

local function BroadcastToAuthorized(eventName, ...)
    local players = QBCore.Functions.GetQBPlayers()
    for src, _ in pairs(players) do
        if IsAllowed(src, true) then
            TriggerClientEvent(eventName, src, ...)
        end
    end
end

local function BroadcastPublic(eventName, ...)
    TriggerClientEvent(eventName, -1, ...)
end

local function EndTracker(id, reason, src, extra)
    local tracker = ActiveTrackers[id]
    if not tracker or tracker.status ~= 'active' then return false end

    tracker.status = 'removed'
    tracker.reason = reason or 'removed'
    tracker.removedAt = Now()
    tracker.removedBy = src

    BroadcastToAuthorized('dpn-starchase:client:trackerRemoved', id, tracker.reason, CompactTracker(tracker))
    BroadcastPublic('dpn-starchase:client:publicTrackerRemoved', id, tracker.reason)

    if Config.Alerts.notifyAllLawOnRemove then
        BroadcastToAuthorized('QBCore:Notify', ('%s %s'):format(Config.Messages.removed, tracker.plate or ''), 'primary', 5000)
    elseif src then
        Notify(src, Config.Messages.removed, 'success')
    end

    DPNStarChaseDB.Log('removed_' .. tostring(reason or 'manual'), src, tracker, extra)
    ActiveTrackers[id] = nil
    return true
end

local function ValidateCoords(coords)
    if type(coords) ~= 'table' then return nil end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return nil end
    if math.abs(x) > 20000.0 or math.abs(y) > 20000.0 or z < -500.0 or z > 3000.0 then return nil end
    return { x = x, y = y, z = z }
end

local function GetAuthoritativeTarget(src, netId)
    netId = tonumber(netId)
    if not netId or netId <= 0 then
        return nil, 'Invalid StarChase target data.'
    end

    local target = NetworkGetEntityFromNetworkId(netId)
    if not target or target == 0 or not DoesEntityExist(target) then
        return nil, 'StarChase target is no longer available.'
    end

    if GetEntityType(target) ~= 2 then
        return nil, 'StarChase target must be a vehicle.'
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return nil, 'Officer entity is unavailable.'
    end

    local officerCoords = GetEntityCoords(ped)
    local targetCoords = GetEntityCoords(target)
    local maxDistance = tonumber(Config.Fire.maxDistance) or 62.0
    if #(officerCoords - targetCoords) > maxDistance + 5.0 then
        return nil, 'StarChase target is outside the authorized lock distance.'
    end

    return target
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(1000)
    DPNStarChaseDB.Init()
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    if IsAllowed(src, true) then
        TriggerClientEvent('dpn-starchase:client:syncTrackers', src, GetTrackersList())
    end
end)

RegisterNetEvent('dpn-starchase:server:requestOpenRemote', function()
    local src = source
    local ok, err = IsAllowed(src)
    if not ok then Notify(src, err or Config.Messages.noAccess, 'error') return end
    if Config.Items.useRemoteItem and not HasItem(src, Config.Items.remoteItem) then
        Notify(src, ('Missing %s.'):format(Config.Items.remoteItem), 'error')
        return
    end
    TriggerClientEvent('dpn-starchase:client:openRemote', src, GetTrackersList())
end)

RegisterCommand(Config.Commands.remote, function(src)
    if src == 0 then return end
    local ok, err = IsAllowed(src)
    if not ok then Notify(src, err or Config.Messages.noAccess, 'error') return end
    if Config.Items.useRemoteItem and not HasItem(src, Config.Items.remoteItem) then
        Notify(src, ('Missing %s.'):format(Config.Items.remoteItem), 'error')
        return
    end
    TriggerClientEvent('dpn-starchase:client:openRemote', src, GetTrackersList())
end, false)

RegisterCommand(Config.Commands.forceClear, function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'command.dpnstarchase.admin') then
        Notify(src, Config.Messages.noAccess, 'error')
        return
    end

    local count = 0
    for id, _ in pairs(ActiveTrackers) do
        if EndTracker(id, 'admin_clear', src, { command = true }) then count = count + 1 end
    end
    if src == 0 then
        print(('[dpn-starchase] Cleared %d trackers.'):format(count))
    else
        Notify(src, ('Cleared %d StarChase trackers.'):format(count), 'success')
    end
end, true)

if Config.Items.remoteItem and Config.Items.remoteItem ~= '' then
    QBCore.Functions.CreateUseableItem(Config.Items.remoteItem, function(src)
        local ok, err = IsAllowed(src)
        if not ok then Notify(src, err or Config.Messages.noAccess, 'error') return end
        TriggerClientEvent('dpn-starchase:client:openRemote', src, GetTrackersList())
    end)
end

QBCore.Functions.CreateCallback('dpn-starchase:server:getTrackers', function(src, cb)
    local ok, err = IsAllowed(src)
    if not ok then cb({ ok = false, message = err or Config.Messages.noAccess, trackers = {} }) return end
    cb({ ok = true, trackers = GetTrackersList(), serverTime = Now() })
end)

QBCore.Functions.CreateCallback('dpn-starchase:server:launch', function(src, cb, payload)
    local ok, err = IsAllowed(src)
    if not ok then cb({ ok = false, message = err or Config.Messages.noAccess }) return end

    local now = Now()
    if OfficerCooldowns[src] and OfficerCooldowns[src] > now then
        cb({ ok = false, message = Config.Messages.cooldown, remaining = OfficerCooldowns[src] - now })
        return
    end

    if ActiveCountFor(src) >= Config.Tracker.maxActivePerOfficer then
        cb({ ok = false, message = Config.Messages.maxTrackers })
        return
    end

    if ActiveCountGlobal() >= Config.Tracker.maxActiveGlobal then
        cb({ ok = false, message = 'Global StarChase tracker limit reached.' })
        return
    end

    if Config.Items.requireAmmo and not HasItem(src, Config.Items.ammoItem) then
        cb({ ok = false, message = Config.Messages.ammoMissing })
        return
    end

    payload = type(payload) == 'table' and payload or {}
    local targetVehicle, targetErr = GetAuthoritativeTarget(src, payload.netId)
    if not targetVehicle then
        cb({ ok = false, message = targetErr or 'Invalid StarChase target data.' })
        return
    end

    local netId = tonumber(payload.netId)
    local targetCoords = GetEntityCoords(targetVehicle)
    local targetModel = GetEntityModel(targetVehicle)
    local targetPlate = TrimPlate(GetVehicleNumberPlateText(targetVehicle))
    local targetSpeed = GetEntitySpeed(targetVehicle) * 2.236936
    local targetHeading = GetEntityHeading(targetVehicle)

    local maxTargetSpeed = tonumber(Config.Fire.maxTargetSpeed) or 180.0
    if targetSpeed > maxTargetSpeed then
        cb({ ok = false, message = ('Target speed exceeds safe tracker lock limit: %.0f MPH.'):format(maxTargetSpeed) })
        return
    end

    if Config.Fire.rejectIfTargetStopped and targetSpeed < 1.0 then
        cb({ ok = false, message = 'Target vehicle is not moving.' })
        return
    end

    local officerPed = GetPlayerPed(src)
    local officerVehicle = officerPed and officerPed ~= 0 and GetVehiclePedIsIn(officerPed, false) or 0
    if Config.Fire.preventSameVehicle and officerVehicle and officerVehicle ~= 0 and officerVehicle == targetVehicle then
        cb({ ok = false, message = Config.Messages.noTarget })
        return
    end


    if Config.Items.requireAmmo and Config.Items.removeAmmoOnFire then
        if not RemoveItem(src, Config.Items.ammoItem, 1) then
            cb({ ok = false, message = Config.Messages.ammoMissing })
            return
        end
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Items.ammoItem], 'remove')
    end

    local Player = QBCore.Functions.GetPlayer(src)
    local jobName = Player.PlayerData.job and Player.PlayerData.job.name or 'unknown'
    local trackerId = GenerateTrackerId(src)
    local tracker = {
        id = trackerId,
        plate = targetPlate,
        netId = netId,
        model = tostring(targetModel),
        coords = { x = targetCoords.x + 0.0, y = targetCoords.y + 0.0, z = targetCoords.z + 0.0 },
        heading = targetHeading,
        speed = targetSpeed,
        street = tostring(payload.street or 'Unknown'):sub(1, 96),
        createdBy = src,
        officerName = PlayerName(Player),
        job = jobName,
        createdAt = now,
        expiresAt = now + Config.Tracker.lifetimeSeconds,
        lastUpdate = now,
        status = 'active'
    }

    ActiveTrackers[trackerId] = tracker
    OfficerCooldowns[src] = now + Config.Fire.cooldownSeconds

    local compact = CompactTracker(tracker)
    BroadcastToAuthorized('dpn-starchase:client:trackerAdded', compact)
    BroadcastPublic('dpn-starchase:client:publicTrackerAdded', {
        id = compact.id,
        netId = compact.netId,
        plate = compact.plate,
        coords = compact.coords
    })

    if Config.Alerts.notifyAllLawOnLaunch then
        BroadcastToAuthorized('QBCore:Notify', ('%s Plate: %s'):format(Config.Messages.launched, tracker.plate), 'success', 6500)
    else
        Notify(src, Config.Messages.launched, 'success')
    end

    DPNStarChaseDB.Log('launched', src, tracker, { payload = payload })

    if Config.Dispatch.enabled and Config.Dispatch.customAlert then
        local handled = Config.Dispatch.customAlert('launch', compact)
        Debug(('Dispatch launch handled: %s'):format(tostring(handled)))
    end

    cb({ ok = true, message = Config.Messages.launched, tracker = compact })
end)

QBCore.Functions.CreateCallback('dpn-starchase:server:removeTracker', function(src, cb, trackerId, reason)
    local ok, err = IsAllowed(src)
    if not ok then cb({ ok = false, message = err or Config.Messages.noAccess }) return end

    local tracker = ActiveTrackers[tostring(trackerId or '')]
    if not tracker then cb({ ok = false, message = 'Tracker no longer active.' }) return end

    EndTracker(tracker.id, reason or 'remote_removed', src, { ui = true })
    cb({ ok = true, message = Config.Messages.removed, removedId = tostring(trackerId or ''), trackers = GetTrackersList() })
end)

QBCore.Functions.CreateCallback('dpn-starchase:server:removeNearest', function(src, cb, trackerId, coords)
    local ok, err = IsAllowed(src)
    if not ok then cb({ ok = false, message = err or Config.Messages.noAccess }) return end

    local tracker = ActiveTrackers[tostring(trackerId or '')]
    if not tracker then cb({ ok = false, message = Config.Messages.nearestMissing }) return end

    EndTracker(tracker.id, 'physical_officer_removed', src, { coords = ValidateCoords(coords) })
    cb({ ok = true, message = Config.Messages.removed, removedId = tostring(trackerId or ''), trackers = GetTrackersList() })
end)

RegisterNetEvent('dpn-starchase:server:civilianRemove', function(trackerId, coords)
    local src = source
    if not Config.Tracker.civilianRemoval then return end
    local tracker = ActiveTrackers[tostring(trackerId or '')]
    if not tracker then return end

    EndTracker(tracker.id, 'physical_removed', src, { coords = ValidateCoords(coords), civilian = true })
    if Config.Tracker.removalAlertToPolice then
        BroadcastToAuthorized('QBCore:Notify', ('StarChase tracker on %s was physically removed.'):format(tracker.plate or 'unknown plate'), 'error', 6500)
    end
end)

RegisterNetEvent('dpn-starchase:server:updateTracker', function(trackerId, update)
    local src = source
    if not IsAllowed(src, true) then return end

    local id = tostring(trackerId or '')
    local tracker = ActiveTrackers[id]
    if not tracker or tracker.status ~= 'active' then return end

    local now = Now()
    UpdateThrottle[id] = UpdateThrottle[id] or 0
    if UpdateThrottle[id] > now then return end
    UpdateThrottle[id] = now + 1

    update = type(update) == 'table' and update or {}
    local coords = ValidateCoords(update.coords)
    if not coords then return end

    tracker.coords = coords
    tracker.heading = tonumber(update.heading) or tracker.heading or 0.0
    tracker.speed = tonumber(update.speed) or tracker.speed or 0.0
    tracker.street = tostring(update.street or tracker.street or 'Unknown')
    tracker.lastUpdate = now

    BroadcastToAuthorized('dpn-starchase:client:trackerUpdated', CompactTracker(tracker))
end)

CreateThread(function()
    while true do
        Wait(30000)
        local now = Now()
        local expired = {}

        for id, tracker in pairs(ActiveTrackers) do
            if tracker.status == 'active' and tracker.expiresAt and tracker.expiresAt <= now then
                expired[#expired + 1] = id
            end
        end

        for _, id in ipairs(expired) do
            local tracker = ActiveTrackers[id]
            if tracker then
                tracker.reason = 'expired'
                DPNStarChaseDB.Log('expired', nil, tracker)
                BroadcastToAuthorized('dpn-starchase:client:trackerRemoved', id, Config.Messages.expired, CompactTracker(tracker))
                BroadcastPublic('dpn-starchase:client:publicTrackerRemoved', id, 'expired')
                ActiveTrackers[id] = nil
            end
        end
    end
end)
