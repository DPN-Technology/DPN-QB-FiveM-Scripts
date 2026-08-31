local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local uiOpen = false
local state = {}
local pursuitBlips = {}
local lastShot = 0
local streetDirection

local function refreshPlayerData()
    PlayerData = QBCore.Functions.GetPlayerData() or {}
end

local function jobName()
    refreshPlayerData()
    return PlayerData.job and PlayerData.job.name or 'unemployed'
end

local function isAuthorized()
    local job = jobName()
    return Config.AllowedJobs[job] ~= nil or Config.JusticeJobs[job] == true
end

local function isLawOnDuty()
    refreshPlayerData()
    local job = PlayerData.job or {}
    local definition = Config.AllowedJobs[job.name]
    return definition and definition.department == 'law' and (not Config.RequireDuty or job.onduty == true)
end

local function notify(message, kind, duration)
    QBCore.Functions.Notify(tostring(message or ''), kind or 'primary', duration or 5000)
end

local function sendNui()
    SendNUIMessage({ action='sync', state=state })
end

local function requestState()
    TriggerServerEvent('dpn-le-operations:server:requestState')
end

local function openUi()
    if uiOpen then return end
    if not isAuthorized() then return notify('Your current job is not authorized for the Advanced Operations Center.', 'error') end
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action='open' })
    requestState()
end

local function closeUi()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action='close' })
end

RegisterCommand(Config.Command, openUi, false)
if Config.OpenKey and Config.OpenKey ~= '' then RegisterKeyMapping(Config.Command, 'Open DPN Advanced Law Enforcement Operations', 'keyboard', Config.OpenKey) end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() refreshPlayerData(); requestState() end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
    if uiOpen and not isAuthorized() then closeUi() end
end)
RegisterNetEvent('QBCore:Player:SetPlayerData', function(data) PlayerData = data or PlayerData end)

RegisterNetEvent('dpn-le-operations:client:sync', function(payload)
    state = type(payload) == 'table' and payload or {}
    sendNui()
end)

RegisterNetEvent('dpn-le-operations:client:refreshAvailable', function()
    if uiOpen then requestState() end
end)

RegisterNetEvent('dpn-le-operations:client:networkChanged', function(networkState)
    if type(networkState) == 'table' then
        state.network = networkState
        if uiOpen then sendNui() end
    end
end)

local function rotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local cosX = math.abs(math.cos(x))
    return vector3(-math.sin(z) * cosX, math.cos(z) * cosX, math.sin(x))
end

local function raycastVehicle(maxDistance)
    local camCoords = GetGameplayCamCoord()
    local direction = rotationToDirection(GetGameplayCamRot(2))
    local destination = camCoords + direction * (maxDistance or Config.Pursuits.AcquisitionDistance)
    local ray = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, destination.x, destination.y, destination.z, 10, PlayerPedId(), 0)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    if hit == 1 and entity and entity > 0 and IsEntityAVehicle(entity) then return entity end
    return nil
end

local function targetVehicle()
    local aimed = raycastVehicle(Config.Pursuits.AcquisitionDistance)
    if aimed then return aimed end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local search = coords + forward * 12.0
    local vehicle = GetClosestVehicle(search.x, search.y, search.z, 45.0, 0, 70)
    if vehicle and vehicle > 0 and DoesEntityExist(vehicle) then return vehicle end
    return nil
end

local function currentVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return GetVehiclePedIsIn(ped, false) end
    local coords = GetEntityCoords(ped)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, Config.Fleet.CheckoutDistance, 0, 70)
    return vehicle and vehicle > 0 and vehicle or nil
end

local function fuelLevel(vehicle)
    if not vehicle or vehicle <= 0 then return 0.0 end
    local ok, value = pcall(GetVehicleFuelLevel, vehicle)
    return ok and value or 0.0
end

streetDirection = function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash)
    local crossing = crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or ''
    local heading = GetEntityHeading(ped)
    local cardinal = heading < 45 and 'North' or heading < 135 and 'West' or heading < 225 and 'South' or heading < 315 and 'East' or 'North'
    return crossing ~= '' and ('%sbound %s / %s'):format(cardinal, street, crossing) or ('%sbound %s'):format(cardinal, street)
end

RegisterNUICallback('close', function(_, cb) closeUi(); cb({ ok=true }) end)
RegisterNUICallback('refresh', function(_, cb) requestState(); cb({ ok=true }) end)

RegisterNUICallback('launchModule', function(data, cb)
    data = type(data) == 'table' and data or {}
    local module = Config.ModuleLauncher[data.module]
    if not module then return cb({ ok=false, error='unknown_module' }) end
    closeUi()
    if module.command and module.command ~= '' then
        ExecuteCommand(module.command)
        return cb({ ok=true })
    end
    cb({ ok=false, error='module_has_no_command' })
end)
RegisterNUICallback('networkSignal', function(data, cb)
    data = type(data) == 'table' and data or {}
    local signal = Config.NetworkQuickSignals[data.signal]
    if not signal then return cb({ ok=false, error='unknown_signal' }) end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    TriggerServerEvent('dpn-emergency-network:server:publish', signal.eventType, {
        title=signal.label,
        message=data.message or signal.label,
        severity=signal.severity,
        coords={ x=coords.x, y=coords.y, z=coords.z },
        direction=streetDirection(),
        reference=data.reference
    })
    cb({ ok=true })
end)
RegisterNUICallback('acknowledgeNetworkEvent', function(data, cb)
    TriggerServerEvent('dpn-emergency-network:server:acknowledge', data.eventId)
    cb({ ok=true })
end)
RegisterNUICallback('resolveNetworkEvent', function(data, cb)
    TriggerServerEvent('dpn-emergency-network:server:resolve', data.eventId, data.resolution)
    cb({ ok=true })
end)
RegisterNUICallback('linkNetworkRecords', function(data, cb)
    TriggerServerEvent('dpn-emergency-network:server:linkRecords', data)
    cb({ ok=true })
end)
RegisterNUICallback('networkWaypoint', function(data, cb)
    local coords = data and data.coords
    if type(coords) == 'table' and tonumber(coords.x) and tonumber(coords.y) then
        SetNewWaypoint(tonumber(coords.x) + 0.0, tonumber(coords.y) + 0.0)
        notify('Network-event waypoint set.', 'success')
        return cb({ ok=true })
    end
    cb({ ok=false, error='missing_coords' })
end)
RegisterNUICallback('startShift', function(data, cb) TriggerServerEvent('dpn-le-operations:server:startShift', data.notes); cb({ ok=true }) end)
RegisterNUICallback('endShift', function(data, cb) TriggerServerEvent('dpn-le-operations:server:endShift', data); cb({ ok=true }) end)
RegisterNUICallback('createUnit', function(data, cb) TriggerServerEvent('dpn-le-operations:server:createUnit', data); cb({ ok=true }) end)
RegisterNUICallback('joinUnit', function(data, cb) TriggerServerEvent('dpn-le-operations:server:joinUnit', data.unitId); cb({ ok=true }) end)
RegisterNUICallback('leaveUnit', function(_, cb) TriggerServerEvent('dpn-le-operations:server:leaveUnit'); cb({ ok=true }) end)
RegisterNUICallback('requestWarrant', function(data, cb) TriggerServerEvent('dpn-le-operations:server:requestWarrant', data); cb({ ok=true }) end)
RegisterNUICallback('reviewWarrant', function(data, cb) TriggerServerEvent('dpn-le-operations:server:reviewWarrant', data); cb({ ok=true }) end)
RegisterNUICallback('serveWarrant', function(data, cb) TriggerServerEvent('dpn-le-operations:server:serveWarrant', data); cb({ ok=true }) end)
RegisterNUICallback('revokeWarrant', function(data, cb) TriggerServerEvent('dpn-le-operations:server:revokeWarrant', data); cb({ ok=true }) end)

RegisterNUICallback('startPursuit', function(data, cb)
    local vehicle = targetVehicle()
    if not vehicle then notify('No suspect vehicle was acquired. Aim at or approach the vehicle.', 'error'); return cb({ ok=false, error='no_vehicle' }) end
    data.vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
    data.direction = streetDirection()
    TriggerServerEvent('dpn-le-operations:server:startPursuit', data)
    cb({ ok=true })
end)
RegisterNUICallback('joinPursuit', function(data, cb) TriggerServerEvent('dpn-le-operations:server:joinPursuit', data.pursuitId); cb({ ok=true }) end)
RegisterNUICallback('updatePursuit', function(data, cb) data.direction=streetDirection(); TriggerServerEvent('dpn-le-operations:server:updatePursuit', data); cb({ ok=true }) end)
RegisterNUICallback('requestTactic', function(data, cb) TriggerServerEvent('dpn-le-operations:server:requestTactic', data); cb({ ok=true }) end)
RegisterNUICallback('reviewTactic', function(data, cb) TriggerServerEvent('dpn-le-operations:server:reviewTactic', data); cb({ ok=true }) end)
RegisterNUICallback('endPursuit', function(data, cb) TriggerServerEvent('dpn-le-operations:server:endPursuit', data); cb({ ok=true }) end)

RegisterNUICallback('createForceReport', function(data, cb) TriggerServerEvent('dpn-le-operations:server:createForceReport', data); cb({ ok=true }) end)
RegisterNUICallback('updateForceReport', function(data, cb) TriggerServerEvent('dpn-le-operations:server:updateForceReport', data); cb({ ok=true }) end)
RegisterNUICallback('reviewForceReport', function(data, cb) TriggerServerEvent('dpn-le-operations:server:reviewForceReport', data); cb({ ok=true }) end)
RegisterNUICallback('reviewPursuit', function(data, cb) TriggerServerEvent('dpn-le-operations:server:reviewPursuit', data); cb({ ok=true }) end)

RegisterNUICallback('checkoutVehicle', function(_, cb)
    local vehicle = currentVehicle()
    if not vehicle then notify('No fleet vehicle is nearby.', 'error'); return cb({ ok=false }) end
    TriggerServerEvent('dpn-le-operations:server:checkoutVehicle', { vehicleNetId=NetworkGetNetworkIdFromEntity(vehicle), fuel=fuelLevel(vehicle) })
    cb({ ok=true })
end)
RegisterNUICallback('returnVehicle', function(data, cb)
    local vehicle = currentVehicle()
    local payload = { checkoutId=data.checkoutId, damageNotes=data.damageNotes, fuel=0, body=0, engine=0, vehicleNetId=0 }
    if vehicle then
        payload.vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
        payload.fuel = fuelLevel(vehicle)
        payload.body = GetVehicleBodyHealth(vehicle)
        payload.engine = GetVehicleEngineHealth(vehicle)
    end
    TriggerServerEvent('dpn-le-operations:server:returnVehicle', payload)
    cb({ ok=true })
end)
RegisterNUICallback('checkoutArmory', function(data, cb) TriggerServerEvent('dpn-le-operations:server:checkoutArmory', data); cb({ ok=true }) end)
RegisterNUICallback('returnArmory', function(data, cb) TriggerServerEvent('dpn-le-operations:server:returnArmory', data.checkoutId); cb({ ok=true }) end)
RegisterNUICallback('completeTask', function(data, cb) TriggerServerEvent('dpn-le-operations:server:completeTask', data.taskId); cb({ ok=true }) end)
RegisterNUICallback('waypointPursuit', function(data, cb)
    local pursuit = state.pursuits and state.pursuits[data.pursuitId]
    if pursuit and pursuit.lastCoords then SetNewWaypoint(pursuit.lastCoords.x + 0.0, pursuit.lastCoords.y + 0.0); notify('Pursuit waypoint set.', 'success') end
    cb({ ok=true })
end)

local function removePursuitBlip(pursuitId)
    local blip = pursuitBlips[pursuitId]
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    pursuitBlips[pursuitId] = nil
end

local function updatePursuitBlip(pursuitId, pursuit)
    if not isLawOnDuty() or not pursuit or not pursuit.lastCoords then return end
    local coords = pursuit.lastCoords
    local blip = pursuitBlips[pursuitId]
    if not blip or not DoesBlipExist(blip) then
        blip = AddBlipForCoord(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
        SetBlipSprite(blip, 225)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 1.0)
        SetBlipFlashes(blip, true)
        ShowHeadingIndicatorOnBlip(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('Pursuit %s • %s'):format(pursuitId, pursuit.plate or 'UNKNOWN'))
        EndTextCommandSetBlipName(blip)
        pursuitBlips[pursuitId] = blip
    else
        SetBlipCoords(blip, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    end
end

RegisterNetEvent('dpn-le-operations:client:pursuitActivated', function(pursuitId, pursuit)
    if not isLawOnDuty() then return end
    updatePursuitBlip(pursuitId, pursuit)
    notify(('Active pursuit: %s'):format(pursuit.plate or pursuitId), 'error')
end)
RegisterNetEvent('dpn-le-operations:client:pursuitUpdated', function(pursuitId, pursuit)
    if not isLawOnDuty() then return end
    if state.pursuits then state.pursuits[pursuitId] = pursuit end
    updatePursuitBlip(pursuitId, pursuit)
    if uiOpen then sendNui() end
end)
RegisterNetEvent('dpn-le-operations:client:pursuitEnded', function(pursuitId)
    removePursuitBlip(pursuitId)
    if state.pursuits then state.pursuits[pursuitId] = nil end
    if uiOpen then sendNui() end
end)

CreateThread(function()
    refreshPlayerData()
    while true do
        if Config.Force.AutoDraftOnWeaponDischarge and isLawOnDuty() and IsPedShooting(PlayerPedId()) then
            local current = GetGameTimer()
            if current - lastShot >= Config.Force.DischargeCooldownSeconds * 1000 then
                lastShot = current
                TriggerServerEvent('dpn-le-operations:server:autoForceDraft', { weaponHash=GetSelectedPedWeapon(PlayerPedId()) })
            end
            Wait(250)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(2000)
        if isLawOnDuty() and state.profile and state.pursuits then
            local cid = state.profile.citizenid
            for pursuitId, pursuit in pairs(state.pursuits) do
                if pursuit.units and pursuit.units[cid] then
                    TriggerServerEvent('dpn-le-operations:server:updatePursuit', { pursuitId=pursuitId, direction=streetDirection() })
                end
            end
        end
    end
end)

CreateThread(function()
    Wait(2500)
    refreshPlayerData()
    if isAuthorized() then requestState() end
end)


CreateThread(function()
    while true do
        Wait(math.max(5, tonumber(Config.NetworkRefreshSeconds) or 15) * 1000)
        if uiOpen then requestState() end
    end
end)
