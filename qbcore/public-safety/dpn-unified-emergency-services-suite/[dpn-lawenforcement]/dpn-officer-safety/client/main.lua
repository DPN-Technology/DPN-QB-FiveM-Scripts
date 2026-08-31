
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData() or {}
local uiOpen = false
local registered = false
local units = {}
local alerts = {}
local stress = 0
local heartRate = Config.Stress.BaseHeartRate
local lastCoords = nil
local lastMove = GetGameTimer()
local lastVehicleSpeed = 0.0
local weaponDrawnAt = nil
local pursuitStarted = nil
local sprintStarted = nil
local panicPress = nil

local function mph(ms) return ms * 2.236936 end
local function isAllowedJob()
    local job = PlayerData.job or {}
    return job.onduty == true and Config.Jobs[job.name] == true
end

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    PlayerData = data or {}
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job or {}
    if not isAllowedJob() then registered = false end
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(onDuty)
    PlayerData.job = PlayerData.job or {}
    PlayerData.job.onduty = onDuty == true
    if not onDuty then registered = false end
end)

local function notify(msg, typ)
    Config.Notification(msg, typ)
end

RegisterNetEvent('dpn-officer-safety:client:notify', notify)

local function getCoordsTable()
    local c = GetEntityCoords(PlayerPedId())
    return {x=c.x,y=c.y,z=c.z}
end

local function createAlert(typ, data)
    if not isAllowedJob() then return end
    TriggerServerEvent('dpn-officer-safety:server:createAlert', typ, data or {})
end

local function openUI()
    if not Config.EnableNUI then return end
    if not isAllowedJob() then return notify('You must be on duty with an authorized emergency-services job.', 'error') end
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({action='open', units=units, alerts=alerts, self={heartRate=heartRate, stress=stress}})
end

local function closeUI()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({action='close'})
end

RegisterCommand(Config.Command, function()
    if uiOpen then closeUI() else openUI() end
end)
RegisterKeyMapping(Config.Command, 'Open DPN Officer Safety', 'keyboard', Config.OpenKey)

RegisterCommand('dpnpanic', function()
    if not isAllowedJob() then return notify('You must be on duty to activate officer panic.', 'error') end
    TriggerServerEvent('dpn-officer-safety:server:panic', getCoordsTable())
end)
RegisterKeyMapping('dpnpanic', 'DPN Officer Panic', 'keyboard', Config.PanicKey)

RegisterNUICallback('close', function(_, cb) closeUI(); cb(true) end)
RegisterNUICallback('ack', function(data, cb) TriggerServerEvent('dpn-officer-safety:server:ackAlert', data.id); cb(true) end)
RegisterNUICallback('panic', function(_, cb) if isAllowedJob() then TriggerServerEvent('dpn-officer-safety:server:panic', getCoordsTable()) end; cb(true) end)
RegisterNUICallback('status', function(data, cb)
    TriggerServerEvent('dpn-officer-safety:server:updateStatus', {status=data.status, coords=getCoordsTable(), heartRate=heartRate, stress=stress})
    cb(true)
end)

RegisterNetEvent('dpn-officer-safety:client:syncUnits', function(data)
    units = data or {}
    SendNUIMessage({action='units', units=units})
end)

RegisterNetEvent('dpn-officer-safety:client:alerts', function(data)
    alerts = data or {}
    SendNUIMessage({action='alerts', alerts=alerts})
end)

RegisterNetEvent('dpn-officer-safety:client:alert', function(alert)
    alerts[#alerts+1] = alert
    notify(('DPN Safety: %s'):format(alert.title or alert.type), 'error')
    SendNUIMessage({action='newAlert', alert=alert})
    if Config.EnableGpsBlips and alert.coords then
        local blip = AddBlipForCoord(alert.coords.x, alert.coords.y, alert.coords.z)
        SetBlipSprite(blip, 161)
        SetBlipScale(blip, 1.15)
        SetBlipColour(blip, 1)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(alert.title or 'DPN Safety Alert')
        EndTextCommandSetBlipName(blip)
        SetTimeout(90000, function() if DoesBlipExist(blip) then RemoveBlip(blip) end end)
    end
end)

CreateThread(function()
    while true do
        Wait(2500)
        if isAllowedJob() and not registered then
            TriggerServerEvent('dpn-officer-safety:server:register', { unit = ('U-%s'):format(GetPlayerServerId(PlayerId())) })
            registered = true
        elseif not isAllowedJob() then
            registered = false
            if uiOpen then closeUI() end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(2500)
        if registered and isAllowedJob() then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            if not lastCoords or #(coords-lastCoords) > 1.5 then
                lastMove = GetGameTimer()
                lastCoords = coords
            end
            local health = GetEntityHealth(ped)
            TriggerServerEvent('dpn-officer-safety:server:updateStatus', {
                coords = getCoordsTable(),
                health = health,
                heartRate = heartRate,
                stress = stress,
                status = IsPedInAnyVehicle(ped,false) and '10-8 Vehicle' or '10-8 Foot'
            })
            SendNUIMessage({action='self', self={heartRate=heartRate, stress=stress, health=health}})
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.OfficerDown.CheckMs)
        if isAllowedJob() and Config.OfficerDown.Enabled then
            local ped = PlayerPedId()
            local health = GetEntityHealth(ped)
            if IsPedFatallyInjured(ped) or health <= Config.OfficerDown.HealthThreshold then
                createAlert('officerDown', {
                    title='Officer Down',
                    message='Automatic officer down alert triggered.',
                    priority=1,
                    coords=getCoordsTable(),
                    dispatch=Config.OfficerDown.AutoCreateDispatchCall,
                    incident=Config.OfficerDown.AutoCreateIncident,
                    metadata={health=health}
                })
                stress = math.min(100, stress + 35)
                Wait(15000)
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        if isAllowedJob() and Config.Crash.Enabled and IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) == ped then
                local speed = mph(GetEntitySpeed(veh))
                local delta = lastVehicleSpeed - speed
                if lastVehicleSpeed >= Config.Crash.MinSpeedMph and delta >= Config.Crash.DeltaSpeedMph then
                    local sev = delta >= Config.Crash.HeavyDeltaSpeedMph and 'severe' or 'moderate'
                    createAlert('crash', {
                        title='Officer Vehicle Crash',
                        message=('Automatic %s crash alert detected.'):format(sev),
                        priority=sev == 'severe' and 1 or 2,
                        coords=getCoordsTable(),
                        dispatch=Config.Crash.AutoCreateDispatchCall,
                        metadata={speedBefore=lastVehicleSpeed, speedAfter=speed, delta=delta, severity=sev}
                    })
                    stress = math.min(100, stress + 25)
                    Wait(5000)
                end
                lastVehicleSpeed = speed
            end
        else
            lastVehicleSpeed = 0.0
        end
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        if isAllowedJob() and Config.ShotsFired.Enabled and IsPedShooting(ped) then
            local weapon = GetSelectedPedWeapon(ped)
            createAlert('shotsFired', {
                title='Officer Shots Fired',
                message='Officer weapon discharge detected.',
                priority=1,
                coords=getCoordsTable(),
                dispatch=Config.ShotsFired.AutoCreateDispatchCall,
                metadata={weapon=weapon}
            })
            stress = math.min(100, stress + 20)
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local armed = IsPedArmed(ped, 4) and IsPlayerFreeAiming(PlayerId())
        if isAllowedJob() and Config.WeaponDrawn.Enabled and armed then
            weaponDrawnAt = weaponDrawnAt or GetGameTimer()
            if GetGameTimer() - weaponDrawnAt > Config.WeaponDrawn.SecondsBeforeAlert * 1000 then
                createAlert('weaponDrawn', {title='Extended Weapon Drawn', message='Officer has had a firearm ready for an extended time.', priority=2, coords=getCoordsTable(), dispatch=Config.WeaponDrawn.AutoCreateDispatchCall})
                weaponDrawnAt = GetGameTimer()
            end
            stress = math.min(100, stress + 1)
        else
            weaponDrawnAt = nil
        end
        if isAllowedJob() and Config.Welfare.Enabled and GetGameTimer() - lastMove > Config.Welfare.SecondsWithoutMovement * 1000 then
            createAlert('welfare', {title='Officer Welfare Check', message='Officer has not moved for an extended period.', priority=2, coords=getCoordsTable(), dispatch=Config.Welfare.AutoCreateDispatchCall})
            lastMove = GetGameTimer()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if isAllowedJob() and Config.Pursuit.Enabled then
            if IsPedInAnyVehicle(ped,false) and mph(GetEntitySpeed(GetVehiclePedIsIn(ped,false))) >= Config.Pursuit.MinVehicleSpeedMph then
                pursuitStarted = pursuitStarted or GetGameTimer()
                if GetGameTimer() - pursuitStarted > Config.Pursuit.SecondsBeforeAlert * 1000 then
                    createAlert('pursuit', {title='Possible Vehicle Pursuit', message='High-speed law enforcement movement detected.', priority=2, coords=getCoordsTable(), dispatch=Config.Pursuit.AutoCreateDispatchCall})
                    pursuitStarted = GetGameTimer()
                end
                stress = math.min(100, stress + 2)
            else
                pursuitStarted = nil
            end
            if not IsPedInAnyVehicle(ped,false) and IsPedSprinting(ped) then
                sprintStarted = sprintStarted or GetGameTimer()
                if GetGameTimer() - sprintStarted > Config.Pursuit.FootPursuitSprintSeconds * 1000 then
                    createAlert('footPursuit', {title='Possible Foot Pursuit', message='Extended officer sprint detected.', priority=2, coords=getCoordsTable(), dispatch=Config.Pursuit.AutoCreateDispatchCall})
                    sprintStarted = GetGameTimer()
                end
                stress = math.min(100, stress + 1)
            else
                sprintStarted = nil
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Stress.TickMs)
        if isAllowedJob() and Config.Stress.Enabled then
            stress = math.max(0, stress - Config.Stress.DecayPerTick)
            local ped = PlayerPedId()
            local moving = IsPedRunning(ped) or IsPedSprinting(ped) or IsPedInMeleeCombat(ped)
            local target = Config.Stress.BaseHeartRate + math.floor(stress * 0.9) + (moving and 18 or 0)
            heartRate = math.max(Config.Stress.BaseHeartRate, math.min(Config.Stress.MaxHeartRate, target))
        end
    end
end)

exports('Panic', function() if isAllowedJob() then TriggerServerEvent('dpn-officer-safety:server:panic', getCoordsTable()) end end)
exports('CreateAlert', function(typ, data) createAlert(typ, data) end)
exports('GetVitals', function() return {heartRate=heartRate, stress=stress} end)
