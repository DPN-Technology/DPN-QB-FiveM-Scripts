local QBCore = exports[Config.CoreName]:GetCoreObject()
PlayerData = {}
UiOpen = false
LocalTrackers = {}
PublicTrackers = {}
local LastFireGameTimer = 0
RouteTrackerId = nil
local Removing = false
local RemovedTrackerIds = {}
local LockHudEnabled = Config.LockOn and Config.LockOn.enabled or false
local CurrentLock = { vehicle = 0, coords = nil, scannedAt = 0, launcher = 0 }
local LastLockScan = 0
local VehicleSpeedMph

local function Debug(msg)
    if Config.Debug then print(('[dpn-starchase/client] %s'):format(msg)) end
end

local function Notify(msg, nType, time)
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(msg, nType or 'primary', time or 4500)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, false)
    end
end

local function VecFromTable(coords)
    if not coords then return nil end
    return vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
end

local function CoordsToTable(coords)
    return { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
end

local function RotationToDirection(rot)
    local adjusted = vector3((math.pi / 180) * rot.x, (math.pi / 180) * rot.y, (math.pi / 180) * rot.z)
    return vector3(-math.sin(adjusted.z) * math.abs(math.cos(adjusted.x)), math.cos(adjusted.z) * math.abs(math.cos(adjusted.x)), math.sin(adjusted.x))
end

local function GetStreetName(coords)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = streetHash ~= 0 and GetStreetNameFromHashKey(streetHash) or 'Unknown'
    local crossing = crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or nil
    if crossing and crossing ~= '' then
        return street .. ' / ' .. crossing
    end
    return street
end

local function HasAllowedJob()
    if Config.AllowAdminBypass and LocalPlayer and LocalPlayer.state and LocalPlayer.state.dpnStarChaseAdmin then
        return true
    end
    local job = PlayerData and PlayerData.job
    if not job or not job.name then return false, Config.Messages.noAccess end
    local minGrade = Config.AllowedJobs[job.name]
    if minGrade == nil then return false, Config.Messages.noAccess end
    if Config.RequireOnDuty and not job.onduty then return false, Config.Messages.offDuty end

    local gradeLevel = 0
    if type(job.grade) == 'table' then
        gradeLevel = tonumber(job.grade.level or job.grade.grade or 0) or 0
    else
        gradeLevel = tonumber(job.grade or 0) or 0
    end

    if gradeLevel < minGrade then return false, Config.Messages.noAccess end
    return true
end

local function IsVehicleAllowed(vehicle)
    if not DoesEntityExist(vehicle) then return false, Config.Messages.noVehicle end
    local model = GetEntityModel(vehicle)
    if Config.VehicleRules.blockedModels and Config.VehicleRules.blockedModels[model] then
        return false, Config.Messages.badVehicle
    end
    if Config.VehicleRules.allowedModels and next(Config.VehicleRules.allowedModels) ~= nil then
        if not Config.VehicleRules.allowedModels[model] then
            return false, Config.Messages.badVehicle
        end
    end
    if Config.VehicleRules.requireEmergencyClass then
        local class = GetVehicleClass(vehicle)
        if not Config.VehicleRules.allowedClasses[class] then
            return false, Config.Messages.badVehicle
        end
    end
    return true
end

local function GetLauncherVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return nil, Config.Messages.noVehicle end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if Config.VehicleRules.driverOnly and GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return nil, 'You must be driving the launcher vehicle.'
    end
    local ok, err = IsVehicleAllowed(vehicle)
    if not ok then return nil, err end
    return vehicle
end

local function LoadModel(model, timeout)
    timeout = timeout or 5000
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local expires = GetGameTimer() + timeout
    while not HasModelLoaded(model) and GetGameTimer() < expires do Wait(0) end
    return HasModelLoaded(model)
end

local function Draw3DText(coords, text, color, scale)
    color = color or { r = 255, g = 255, b = 255, a = 230 }
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(scale or 0.32, scale or 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(color.r or 255, color.g or 255, color.b or 255, color.a or 230)
    SetTextCentre(1)
    SetTextDropShadow(2, 0, 0, 0, 180)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function ApplySafeEntitySettings(entity, launcherVehicle, targetVehicle)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    SetEntityCollision(entity, false, false)
    SetEntityInvincible(entity, true)
    SetEntityCanBeDamaged(entity, false)
    SetEntityProofs(entity, true, true, true, true, true, true, true, true)
    SetEntityDynamic(entity, false)
    if Config.Fire and Config.Fire.forceNoCollision then
        pcall(function() SetEntityCompletelyDisableCollision(entity, false, true) end)
    end
    if launcherVehicle and DoesEntityExist(launcherVehicle) then
        SetEntityNoCollisionEntity(entity, launcherVehicle, true)
    end
    if targetVehicle and DoesEntityExist(targetVehicle) then
        SetEntityNoCollisionEntity(entity, targetVehicle, true)
    end
    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        SetEntityNoCollisionEntity(entity, ped, true)
    end
end

local function GetTrackerVisualCoords(tracker)
    if not tracker then return nil end

    if tracker.prop and DoesEntityExist(tracker.prop) then
        return GetEntityCoords(tracker.prop)
    end

    local veh = tracker.netId and NetToVeh(tracker.netId) or 0
    if DoesEntityExist(veh) then
        local boneName = Config.Tracker.attachBonePreference or 'bumper_r'
        local boneIndex = GetEntityBoneIndexByName(veh, boneName)
        if boneIndex ~= -1 then
            return GetWorldPositionOfEntityBone(veh, boneIndex)
        end

        local fallback = Config.Tracker.fallbackVehicleOffset or { x = 0.0, y = -2.15, z = 0.45 }
        return GetOffsetFromEntityInWorldCoords(veh, fallback.x, fallback.y, fallback.z)
    end

    return tracker.coords and VecFromTable(tracker.coords) or nil
end

local function CreateTrackerProp(data)
    if not data or not data.netId then return end
    local trackerId = data.id
    local veh = NetToVeh(data.netId)
    if not DoesEntityExist(veh) then return end

    local targetStore = LocalTrackers[trackerId] or PublicTrackers[trackerId]
    if targetStore and targetStore.prop and DoesEntityExist(targetStore.prop) then return end

    if not LoadModel(Config.Tracker.model) then return end

    local coords = GetEntityCoords(veh)
    local obj = CreateObject(Config.Tracker.model, coords.x, coords.y, coords.z + 1.0, false, false, false)
    if not DoesEntityExist(obj) then return end
    ApplySafeEntitySettings(obj, nil, veh)
    SetEntityAsMissionEntity(obj, true, true)

    local boneIndex = GetEntityBoneIndexByName(veh, Config.Tracker.attachBonePreference or 'bumper_r')
    local offset = Config.Tracker.attachOffset
    local rotation = Config.Tracker.attachRotation

    if boneIndex == -1 then
        boneIndex = 0
        offset = Config.Tracker.fallbackVehicleOffset or offset
        rotation = Config.Tracker.fallbackRotation or rotation
    end

    AttachEntityToEntity(
        obj,
        veh,
        boneIndex,
        offset.x,
        offset.y,
        offset.z,
        rotation.x,
        rotation.y,
        rotation.z,
        true,
        true,
        false,
        true,
        1,
        true
    )

    if LocalTrackers[trackerId] then LocalTrackers[trackerId].prop = obj end
    if PublicTrackers[trackerId] then PublicTrackers[trackerId].prop = obj end
    SetModelAsNoLongerNeeded(Config.Tracker.model)
end

local function DeleteTrackerProp(id)
    local stores = { LocalTrackers[id], PublicTrackers[id] }
    for _, store in ipairs(stores) do
        if store and store.prop and DoesEntityExist(store.prop) then
            DeleteEntity(store.prop)
            store.prop = nil
        end
    end
end

local function EnsureBlip(data)
    if not data or not data.id then return end
    local id = tostring(data.id)
    if RemovedTrackerIds[id] then return end
    data.id = id
    LocalTrackers[id] = LocalTrackers[id] or data
    local tracker = LocalTrackers[id]
    tracker.coords = data.coords or tracker.coords
    tracker.netId = data.netId or tracker.netId
    tracker.plate = data.plate or tracker.plate
    tracker.officerName = data.officerName or tracker.officerName
    tracker.street = data.street or tracker.street
    tracker.lastUpdate = data.lastUpdate or tracker.lastUpdate
    tracker.expiresAt = data.expiresAt or tracker.expiresAt
    tracker.speed = data.speed or tracker.speed
    tracker.heading = data.heading or tracker.heading

    local pos = VecFromTable(tracker.coords)
    if not pos then return end

    if not tracker.blip or not DoesBlipExist(tracker.blip) then
        tracker.blip = AddBlipForCoord(pos.x, pos.y, pos.z)
        SetBlipSprite(tracker.blip, Config.Blip.sprite)
        SetBlipScale(tracker.blip, Config.Blip.scale)
        SetBlipColour(tracker.blip, Config.Blip.color)
        SetBlipAsShortRange(tracker.blip, Config.Blip.shortRange)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('%s | %s'):format(Config.Blip.namePrefix, tracker.plate or 'NO PLATE'))
        EndTextCommandSetBlipName(tracker.blip)
    else
        SetBlipCoords(tracker.blip, pos.x, pos.y, pos.z)
    end

    if RouteTrackerId == id then
        SetBlipRoute(tracker.blip, true)
        SetBlipRouteColour(tracker.blip, Config.Blip.routeColor)
    end
end

local function FindTrackerStore(id, store)
    id = tostring(id or '')
    if store[id] then return id, store[id] end
    for key, value in pairs(store) do
        if tostring(key) == id or (value and tostring(value.id) == id) then
            return key, value
        end
    end
    return id, nil
end

local function ClearTrackerBlip(id)
    id = tostring(id or '')
    local key, tracker = FindTrackerStore(id, LocalTrackers)
    if tracker and tracker.blip then
        local blip = tracker.blip
        if DoesBlipExist(blip) then
            SetBlipRoute(blip, false)
            SetBlipFlashes(blip, false)
            RemoveBlip(blip)
            Wait(0)
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
        tracker.blip = nil
    end
    if RouteTrackerId and tostring(RouteTrackerId) == id then RouteTrackerId = nil end
    return key
end

local function PurgeTrackerLocal(id, reason)
    id = tostring(id or '')
    if id == '' then return end
    RemovedTrackerIds[id] = GetGameTimer() + 30000
    local key = ClearTrackerBlip(id)
    DeleteTrackerProp(id)
    if LocalTrackers[id] then LocalTrackers[id] = nil end
    if key and LocalTrackers[key] then LocalTrackers[key] = nil end
    if PublicTrackers[id] then PublicTrackers[id] = nil end
    CurrentLock = { vehicle = 0, coords = nil, scannedAt = GetGameTimer(), launcher = 0 }
    if reason then Debug(('Tracker purged locally: %s %s'):format(id, tostring(reason))) end
end

local function SyncUi()
    if UiOpen then
        SendNUIMessage({ action = 'sync', trackers = LocalTrackers })
    end
end

local function ResolveShapeTest(handle)
    local retval, hit, hitCoords, surfaceNormal, entityHit = 1, 0, vector3(0.0, 0.0, 0.0), vector3(0.0, 0.0, 0.0), 0
    local attempts = 0
    while retval == 1 and attempts < 10 do
        retval, hit, hitCoords, surfaceNormal, entityHit = GetShapeTestResult(handle)
        attempts = attempts + 1
        if retval == 1 then Wait(0) end
    end
    return retval, hit, hitCoords, surfaceNormal, entityHit
end

local function TargetFromRaycast(vehicle)
    local start = GetOffsetFromEntityInWorldCoords(vehicle, Config.Fire.launchOffset.x, Config.Fire.launchOffset.y, Config.Fire.launchOffset.z)
    local forward = GetEntityForwardVector(vehicle)
    local finish = start + (forward * Config.Fire.maxDistance)
    local ray = StartShapeTestCapsule(start.x, start.y, start.z, finish.x, finish.y, finish.z, Config.Fire.capsuleRadius, 10, vehicle, 7)
    local _, hit, hitCoords, _, entityHit = ResolveShapeTest(ray)

    if hit == 1 and entityHit and entityHit ~= 0 and IsEntityAVehicle(entityHit) then
        return entityHit, hitCoords
    end

    return nil, nil
end

local function IsInCone(origin, forward, targetCoords)
    local toTarget = targetCoords - origin
    local dist = #(toTarget)
    if dist <= 0.1 or dist > Config.Fire.maxDistance then return false, dist end
    local dir = toTarget / dist
    local dot = forward.x * dir.x + forward.y * dir.y + forward.z * dir.z
    local angle = math.deg(math.acos(math.max(-1.0, math.min(1.0, dot))))
    return angle <= Config.Fire.coneDegrees, dist
end

local function HasLos(start, targetVeh)
    if not Config.Fire.requireLineOfSight then return true end
    local coords = GetEntityCoords(targetVeh)
    local ray = StartShapeTestRay(start.x, start.y, start.z, coords.x, coords.y, coords.z + 0.5, 10, PlayerPedId(), 7)
    local _, hit, _, _, entityHit = ResolveShapeTest(ray)
    if hit == 0 then return true end
    return entityHit == targetVeh
end

local function FindBestTarget(launcherVehicle)
    local target, hitCoords = TargetFromRaycast(launcherVehicle)
    local start = GetOffsetFromEntityInWorldCoords(launcherVehicle, Config.Fire.launchOffset.x, Config.Fire.launchOffset.y, Config.Fire.launchOffset.z)

    if target and DoesEntityExist(target) then
        if Config.Fire.preventSameVehicle and target == launcherVehicle then return nil end
        if HasLos(start, target) then return target, hitCoords end
    end

    local origin = GetEntityCoords(launcherVehicle)
    local forward = GetEntityForwardVector(launcherVehicle)
    local bestVeh, bestDist = nil, Config.Fire.maxDistance + 1.0
    local vehicles = GetGamePool('CVehicle')

    for _, veh in ipairs(vehicles) do
        if veh ~= launcherVehicle and DoesEntityExist(veh) then
            local coords = GetEntityCoords(veh)
            local inCone, dist = IsInCone(origin, forward, coords)
            if inCone and dist < bestDist and HasLos(start, veh) then
                bestVeh, bestDist = veh, dist
            end
        end
    end

    return bestVeh, bestVeh and GetEntityCoords(bestVeh) or nil
end

local function GetConfigColor(path, fallback)
    return path or fallback
end

local function DrawVehicleBox(vehicle, color)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if not Config.LockOn.drawTargetBox then return end
    color = color or Config.LockOn.validColor or { r = 35, g = 255, b = 85, a = 220 }
    local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
    local corners = {
        GetOffsetFromEntityInWorldCoords(vehicle, minDim.x, minDim.y, minDim.z),
        GetOffsetFromEntityInWorldCoords(vehicle, maxDim.x, minDim.y, minDim.z),
        GetOffsetFromEntityInWorldCoords(vehicle, maxDim.x, maxDim.y, minDim.z),
        GetOffsetFromEntityInWorldCoords(vehicle, minDim.x, maxDim.y, minDim.z),
        GetOffsetFromEntityInWorldCoords(vehicle, minDim.x, minDim.y, maxDim.z),
        GetOffsetFromEntityInWorldCoords(vehicle, maxDim.x, minDim.y, maxDim.z),
        GetOffsetFromEntityInWorldCoords(vehicle, maxDim.x, maxDim.y, maxDim.z),
        GetOffsetFromEntityInWorldCoords(vehicle, minDim.x, maxDim.y, maxDim.z)
    }
    local edges = { {1,2}, {2,3}, {3,4}, {4,1}, {5,6}, {6,7}, {7,8}, {8,5}, {1,5}, {2,6}, {3,7}, {4,8} }
    for _, edge in ipairs(edges) do
        local a, b = corners[edge[1]], corners[edge[2]]
        DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, color.r, color.g, color.b, color.a)
    end
end

local function FormatLockLabel(targetVehicle, distance)
    local plate = GetVehicleNumberPlateText(targetVehicle) or 'NO PLATE'
    local speed = VehicleSpeedMph(targetVehicle)
    local parts = { '~g~LOCKED~w~' }
    if Config.LockOn.showPlate then parts[#parts + 1] = ('PLATE %s'):format(plate) end
    if Config.LockOn.showDistance then parts[#parts + 1] = ('%.0f FT'):format((distance or 0.0) * 3.28084) end
    if Config.LockOn.showSpeed then parts[#parts + 1] = ('%.0f MPH'):format(speed) end
    return table.concat(parts, '  |  ')
end

local function DrawLockOnHud(launcherVehicle, targetVehicle, hitCoords)
    if not Config.LockOn or not Config.LockOn.enabled then return end
    local start = GetOffsetFromEntityInWorldCoords(launcherVehicle, Config.Fire.launchOffset.x, Config.Fire.launchOffset.y, Config.Fire.launchOffset.z)
    local validColor = Config.LockOn.validColor or { r = 35, g = 255, b = 85, a = 220 }
    local missColor = Config.LockOn.noTargetColor or { r = 255, g = 65, b = 65, a = 180 }

    if targetVehicle and targetVehicle ~= 0 and DoesEntityExist(targetVehicle) then
        local targetCoords = hitCoords or GetEntityCoords(targetVehicle)
        local displayCoords = targetCoords + vector3(0.0, 0.0, 1.45)
        local dist = #(GetEntityCoords(launcherVehicle) - targetCoords)
        Draw3DText(displayCoords, FormatLockLabel(targetVehicle, dist), validColor, Config.LockOn.textScale or 0.34)
        if Config.LockOn.drawTargetMarker then
            DrawMarker(2, displayCoords.x, displayCoords.y, displayCoords.z + 0.35, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.34, 0.34, 0.34, validColor.r, validColor.g, validColor.b, 170, false, true, 2, false, nil, nil, false)
        end
        if Config.LockOn.drawLine then
            DrawLine(start.x, start.y, start.z, targetCoords.x, targetCoords.y, targetCoords.z + 0.35, Config.LockOn.lineColor.r, Config.LockOn.lineColor.g, Config.LockOn.lineColor.b, Config.LockOn.lineColor.a)
        end
        DrawVehicleBox(targetVehicle, validColor)
    else
        local forward = GetEntityForwardVector(launcherVehicle)
        local point = start + (forward * math.min(Config.Fire.maxDistance, Config.LockOn.maxNoTargetDrawDistance or 24.0))
        Draw3DText(point + vector3(0.0, 0.0, 0.7), '~r~NO LOCK~w~ - ALIGN FRONT CONE', missColor, Config.LockOn.textScale or 0.34)
        if Config.LockOn.drawLine then
            DrawLine(start.x, start.y, start.z, point.x, point.y, point.z, missColor.r, missColor.g, missColor.b, 110)
        end
    end
end

local function RefreshLockTarget(launcherVehicle)
    local now = GetGameTimer()
    if now - LastLockScan < (Config.LockOn.refreshMs or 120) then return end
    LastLockScan = now
    local targetVehicle, hitCoords = FindBestTarget(launcherVehicle)
    CurrentLock = {
        vehicle = targetVehicle or 0,
        coords = hitCoords,
        scannedAt = now,
        launcher = launcherVehicle
    }
end

VehicleSpeedMph = function(vehicle)
    return GetEntitySpeed(vehicle) * 2.236936
end

local function PlayLaunchFx(launcherVehicle, targetVehicle)
    if Config.Fire.launchScreenShake then ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.05) end
    if Config.Fire.launchSound then PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true) end

    local model = Config.Fire.projectileModel
    if not LoadModel(model, 2000) then return end

    local start = GetOffsetFromEntityInWorldCoords(launcherVehicle, Config.Fire.launchOffset.x, Config.Fire.launchOffset.y, Config.Fire.launchOffset.z)
    local finish = GetOffsetFromEntityInWorldCoords(targetVehicle, Config.Fire.targetOffset.x, Config.Fire.targetOffset.y, Config.Fire.targetOffset.z)
    local obj = CreateObject(model, start.x, start.y, start.z, false, false, false)
    if not DoesEntityExist(obj) then return end

    ApplySafeEntitySettings(obj, launcherVehicle, targetVehicle)
    SetEntityAsMissionEntity(obj, true, true)

    local launchedAt = GetGameTimer()
    local flightTime = 460
    CreateThread(function()
        while DoesEntityExist(obj) do
            local alpha = math.min(1.0, (GetGameTimer() - launchedAt) / flightTime)
            local pos = start + ((finish - start) * alpha)
            SetEntityCoordsNoOffset(obj, pos.x, pos.y, pos.z, false, false, false)
            DrawLine(start.x, start.y, start.z, pos.x, pos.y, pos.z, 220, 20, 20, 220)
            if alpha >= 1.0 then break end
            Wait(0)
        end
        if DoesEntityExist(obj) then DeleteEntity(obj) end
        SetModelAsNoLongerNeeded(model)
    end)
end

function DPNStarChase_AttemptLaunch(cb)
    local okAccess, accessErr = HasAllowedJob()
    if not okAccess then
        if cb then cb(false, accessErr) end
        Notify(accessErr, 'error')
        return
    end

    local now = GetGameTimer()
    local localCooldown = (Config.Fire.cooldownSeconds * 1000)
    if now - LastFireGameTimer < localCooldown then
        local left = math.ceil((localCooldown - (now - LastFireGameTimer)) / 1000)
        local msg = ('%s %ss'):format(Config.Messages.cooldown, left)
        if cb then cb(false, msg) end
        Notify(msg, 'error')
        return
    end

    local launcherVehicle, vehErr = GetLauncherVehicle()
    if not launcherVehicle then
        if cb then cb(false, vehErr) end
        Notify(vehErr, 'error')
        return
    end

    local launcherSpeed = VehicleSpeedMph(launcherVehicle)
    if launcherSpeed < Config.Fire.minLauncherSpeed or launcherSpeed > Config.Fire.maxLauncherSpeed then
        local msg = ('Launcher speed must be between %.0f and %.0f MPH.'):format(Config.Fire.minLauncherSpeed, Config.Fire.maxLauncherSpeed)
        if cb then cb(false, msg) end
        Notify(msg, 'error')
        return
    end

    local targetVehicle = FindBestTarget(launcherVehicle)
    if not targetVehicle or not DoesEntityExist(targetVehicle) then
        if cb then cb(false, Config.Messages.noTarget) end
        Notify(Config.Messages.noTarget, 'error')
        return
    end

    if Config.Fire.preventSameVehicle and targetVehicle == launcherVehicle then
        if cb then cb(false, Config.Messages.noTarget) end
        Notify(Config.Messages.noTarget, 'error')
        return
    end

    local targetSpeed = VehicleSpeedMph(targetVehicle)
    if targetSpeed > Config.Fire.maxTargetSpeed then
        local msg = ('Target speed exceeds safe tracker lock limit: %.0f MPH.'):format(Config.Fire.maxTargetSpeed)
        if cb then cb(false, msg) end
        Notify(msg, 'error')
        return
    end

    if Config.Fire.rejectIfTargetStopped and targetSpeed < 1.0 then
        if cb then cb(false, 'Target vehicle is not moving.') end
        Notify('Target vehicle is not moving.', 'error')
        return
    end

    local targetCoords = GetEntityCoords(targetVehicle)
    local modelHash = GetEntityModel(targetVehicle)
    local payload = {
        netId = VehToNet(targetVehicle),
        plate = GetVehicleNumberPlateText(targetVehicle),
        model = tostring(modelHash),
        coords = CoordsToTable(targetCoords),
        heading = GetEntityHeading(targetVehicle),
        speed = targetSpeed,
        street = GetStreetName(targetCoords)
    }

    QBCore.Functions.TriggerCallback('dpn-starchase:server:launch', function(resp)
        resp = resp or { ok = false, message = 'No server response.' }
        if resp.ok then
            LastFireGameTimer = GetGameTimer()
            PlayLaunchFx(launcherVehicle, targetVehicle)
            Notify(resp.message or Config.Messages.launched, 'success')
            if cb then cb(true, resp.message, resp.tracker) end
        else
            Notify(resp.message or 'StarChase launch denied.', 'error')
            if cb then cb(false, resp.message or 'StarChase launch denied.') end
        end
    end, payload)
end

RegisterCommand(Config.Commands.removeNearest, function()
    local okAccess, accessErr = HasAllowedJob()
    if not okAccess then Notify(accessErr, 'error') return end
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local nearestId, nearestDist = nil, 9999.0

    for id, tracker in pairs(LocalTrackers) do
        local pos = tracker.coords and VecFromTable(tracker.coords)
        local veh = tracker.netId and NetToVeh(tracker.netId) or 0
        if DoesEntityExist(veh) then pos = GetEntityCoords(veh) end
        if pos then
            local dist = #(pcoords - pos)
            if dist < nearestDist then nearestId, nearestDist = id, dist end
        end
    end

    if not nearestId or nearestDist > Config.Tracker.physicalRemovalDistance + 2.5 then
        Notify(Config.Messages.nearestMissing, 'error')
        return
    end

    if Removing then return end
    Removing = true
    local duration = Config.Tracker.officerRemovalSeconds
    local label = 'Removing StarChase tracker...'

    if GetResourceState('progressbar') == 'started' then
        exports['progressbar']:Progress({ name = 'dpn_starchase_remove', duration = duration, label = label, useWhileDead = false, canCancel = true, controlDisables = { disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true } }, function(cancelled)
            Removing = false
            if cancelled then return end
            QBCore.Functions.TriggerCallback('dpn-starchase:server:removeNearest', function(resp)
                if resp and resp.ok then PurgeTrackerLocal(nearestId, 'officer_remove_callback') end
                Notify((resp and resp.message) or Config.Messages.removed, resp and resp.ok and 'success' or 'error')
                if resp and resp.trackers then TriggerEvent('dpn-starchase:client:syncTrackers', resp.trackers) end
            end, nearestId, CoordsToTable(GetEntityCoords(PlayerPedId())))
        end)
    else
        FreezeEntityPosition(ped, true)
        Wait(duration)
        FreezeEntityPosition(ped, false)
        Removing = false
        QBCore.Functions.TriggerCallback('dpn-starchase:server:removeNearest', function(resp)
            if resp and resp.ok then PurgeTrackerLocal(nearestId, 'officer_remove_callback') end
            Notify((resp and resp.message) or Config.Messages.removed, resp and resp.ok and 'success' or 'error')
            if resp and resp.trackers then TriggerEvent('dpn-starchase:client:syncTrackers', resp.trackers) end
        end, nearestId, CoordsToTable(GetEntityCoords(PlayerPedId())))
    end
end, false)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback('dpn-starchase:server:getTrackers', function(resp)
        if resp and resp.ok then
            TriggerEvent('dpn-starchase:client:syncTrackers', resp.trackers or {})
        end
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    for id, _ in pairs(LocalTrackers) do
        ClearTrackerBlip(id)
        DeleteTrackerProp(id)
    end
    LocalTrackers = {}
    PublicTrackers = {}
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
    local ok = HasAllowedJob()
    if not ok then
        for id, _ in pairs(LocalTrackers) do
            ClearTrackerBlip(id)
        end
        LocalTrackers = {}
    else
        QBCore.Functions.TriggerCallback('dpn-starchase:server:getTrackers', function(resp)
            if resp and resp.ok then TriggerEvent('dpn-starchase:client:syncTrackers', resp.trackers or {}) end
        end)
    end
end)

CreateThread(function()
    while not QBCore do Wait(100) end
    PlayerData = QBCore.Functions.GetPlayerData() or {}
    Wait(1500)
    local ok = HasAllowedJob()
    if ok then
        QBCore.Functions.TriggerCallback('dpn-starchase:server:getTrackers', function(resp)
            if resp and resp.ok then TriggerEvent('dpn-starchase:client:syncTrackers', resp.trackers or {}) end
        end)
    end
end)

RegisterNetEvent('dpn-starchase:client:syncTrackers', function(trackers)
    for id, _ in pairs(LocalTrackers) do
        ClearTrackerBlip(id)
        DeleteTrackerProp(id)
    end
    LocalTrackers = {}
    for _, tracker in ipairs(trackers or {}) do
        if tracker and tracker.id then
            tracker.id = tostring(tracker.id)
            RemovedTrackerIds[tracker.id] = nil
            LocalTrackers[tracker.id] = tracker
            EnsureBlip(tracker)
            CreateTrackerProp(tracker)
        end
    end
    SyncUi()
end)

RegisterNetEvent('dpn-starchase:client:trackerAdded', function(data)
    if not data or not data.id then return end
    data.id = tostring(data.id)
    RemovedTrackerIds[data.id] = nil
    LocalTrackers[data.id] = data
    EnsureBlip(data)
    CreateTrackerProp(data)
    SyncUi()
end)

RegisterNetEvent('dpn-starchase:client:trackerUpdated', function(data)
    if not data or not data.id then return end
    data.id = tostring(data.id)
    if RemovedTrackerIds[data.id] or not LocalTrackers[data.id] then return end
    EnsureBlip(data)
    SyncUi()
end)

RegisterNetEvent('dpn-starchase:client:trackerRemoved', function(id, reason)
    PurgeTrackerLocal(id, reason)
    SyncUi()
end)

RegisterNetEvent('dpn-starchase:client:publicTrackerAdded', function(data)
    if not data or not data.id then return end
    data.id = tostring(data.id)
    if RemovedTrackerIds[data.id] then return end
    PublicTrackers[data.id] = data
    CreateTrackerProp(data)
end)

RegisterNetEvent('dpn-starchase:client:publicTrackerRemoved', function(id)
    PurgeTrackerLocal(id, 'public_remove')
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local okAccess = HasAllowedJob()
        if okAccess then
            for id, tracker in pairs(LocalTrackers) do
                if tracker.netId then
                    local veh = NetToVeh(tracker.netId)
                    if DoesEntityExist(veh) then
                        local coords = GetEntityCoords(veh)
                        local pedCoords = GetEntityCoords(PlayerPedId())
                        if #(pedCoords - coords) <= Config.Tracker.broadcastUpdateDistance then
                            sleep = math.min(sleep, 500)
                            TriggerServerEvent('dpn-starchase:server:updateTracker', id, {
                                street = GetStreetName(coords)
                            })
                            CreateTrackerProp(tracker)
                        end
                    end
                end
            end
        end
        Wait(math.max(500, math.floor(Config.Tracker.heartbeatSeconds * 1000)))
    end
end)

CreateThread(function()
    while true do
        local sleep = 1500
        local now = os.time()
        for id, tracker in pairs(LocalTrackers) do
            if tracker.blip and DoesBlipExist(tracker.blip) then
                local stale = tracker.lastUpdate and (now - tracker.lastUpdate > Config.Tracker.staleAfterSeconds)
                SetBlipColour(tracker.blip, stale and Config.Blip.staleColor or Config.Blip.color)
                if Config.Blip.flashWhenStale then
                    SetBlipFlashes(tracker.blip, stale)
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if Config.Tracker.civilianRemoval then
            local okLaw = HasAllowedJob()
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)
            for id, tracker in pairs(PublicTrackers) do
                local veh = tracker.netId and NetToVeh(tracker.netId) or 0
                if DoesEntityExist(veh) then
                    local tcoords = GetTrackerVisualCoords(tracker) or GetOffsetFromEntityInWorldCoords(veh, Config.Tracker.fallbackVehicleOffset.x, Config.Tracker.fallbackVehicleOffset.y, Config.Tracker.fallbackVehicleOffset.z)
                    local dist = #(pcoords - tcoords)
                    if dist <= 8.0 then
                        sleep = 0
                        DrawMarker(2, tcoords.x, tcoords.y, tcoords.z + 0.18, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.18, 0.18, 0.18, 255, 35, 35, 150, false, true, 2, false, nil, nil, false)
                        if not okLaw and dist <= Config.Tracker.physicalRemovalDistance and not Removing then
                            Draw3DText(tcoords + vector3(0.0, 0.0, 0.35), '~r~StarChase Tracker~w~\nPress ~g~E~w~ to remove')
                            if IsControlJustReleased(0, Config.Tracker.civilianRemovalKey) then
                                Removing = true
                                if GetResourceState('progressbar') == 'started' then
                                    exports['progressbar']:Progress({ name = 'dpn_starchase_civ_remove', duration = Config.Tracker.civilianRemovalSeconds, label = 'Removing GPS tracker...', useWhileDead = false, canCancel = true, controlDisables = { disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true } }, function(cancelled)
                                        Removing = false
                                        if not cancelled then TriggerServerEvent('dpn-starchase:server:civilianRemove', id, CoordsToTable(GetEntityCoords(PlayerPedId()))) end
                                    end)
                                else
                                    FreezeEntityPosition(ped, true)
                                    Wait(Config.Tracker.civilianRemovalSeconds)
                                    FreezeEntityPosition(ped, false)
                                    Removing = false
                                    TriggerServerEvent('dpn-starchase:server:civilianRemove', id, CoordsToTable(GetEntityCoords(PlayerPedId())))
                                end
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterCommand(Config.Commands.fire or 'starchasefire', function()
    DPNStarChase_AttemptLaunch()
end, false)

RegisterCommand(Config.Commands.toggleLockHud or 'starchaselockhud', function()
    LockHudEnabled = not LockHudEnabled
    Notify(LockHudEnabled and Config.Messages.lockHudOn or Config.Messages.lockHudOff, LockHudEnabled and 'success' or 'primary')
end, false)

if Config.Controls then
    if Config.Controls.quickDeploy and Config.Controls.quickDeploy.enabled then
        RegisterKeyMapping(Config.Controls.quickDeploy.command or Config.Commands.fire or 'starchasefire', Config.Controls.quickDeploy.description or 'DPN StarChase Quick Deploy Tracker', 'keyboard', Config.Controls.quickDeploy.defaultKey or 'F11')
    end
    if Config.Controls.removeNearest and Config.Controls.removeNearest.enabled then
        RegisterKeyMapping(Config.Controls.removeNearest.command or Config.Commands.removeNearest or 'removestarchase', Config.Controls.removeNearest.description or 'Remove Nearest DPN StarChase Tracker', 'keyboard', Config.Controls.removeNearest.defaultKey or 'F9')
    end
    if Config.Controls.toggleLockHud and Config.Controls.toggleLockHud.enabled then
        RegisterKeyMapping(Config.Controls.toggleLockHud.command or Config.Commands.toggleLockHud or 'starchaselockhud', Config.Controls.toggleLockHud.description or 'Toggle DPN StarChase Lock-On HUD', 'keyboard', Config.Controls.toggleLockHud.defaultKey or 'F3')
    end
end

CreateThread(function()
    while true do
        local sleep = 600
        if Config.LockOn and Config.LockOn.enabled and LockHudEnabled then
            local okAccess = HasAllowedJob()
            if okAccess then
                local launcherVehicle = GetLauncherVehicle()
                if launcherVehicle and DoesEntityExist(launcherVehicle) then
                    sleep = 0
                    RefreshLockTarget(launcherVehicle)
                    DrawLockOnHud(launcherVehicle, CurrentLock.vehicle, CurrentLock.coords)
                end
            end
        end

        local now = GetGameTimer()
        for id, expires in pairs(RemovedTrackerIds) do
            if expires <= now then RemovedTrackerIds[id] = nil end
        end
        Wait(sleep)
    end
end)

exports('LaunchTracker', function()
    DPNStarChase_AttemptLaunch()
end)

exports('GetActiveTrackers', function()
    return LocalTrackers
end)
