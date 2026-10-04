local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local isLoggedIn = LocalPlayer.state.isLoggedIn

-- Local variables
local deployedSpikes = {}
local playerSpikes = {}
local isDeploying = false
local lastDeployTime = 0

-- Functions
local function HasAuthorization()
    if not isLoggedIn then return false end
    
    local job = PlayerData.job
    if not job then return false end
    
    local authorizedJob = Config.AuthorizedJobs[job.name]
    if not authorizedJob then return false end
    
    for _, grade in ipairs(authorizedJob.grades) do
        if job.grade.level == grade then
            return true
        end
    end
    
    return false
end

local function IsAuthorizedVehicle(vehicle)
    local model = GetEntityModel(vehicle)
    return Config.AuthorizedVehicles[model] == true
end

local function IsVehicleStationary(vehicle)
    local speed = GetEntitySpeed(vehicle) * 3.6 -- Convert to km/h
    return speed < 2.0
end

local function GetVehiclesInArea(coords, radius)
    local vehicles = {}
    local handle, vehicle = FindFirstVehicle()
    local finished = false
    
    repeat
        if DoesEntityExist(vehicle) then
            local vehicleCoords = GetEntityCoords(vehicle)
            local distance = #(coords - vehicleCoords)
            
            if distance <= radius then
                table.insert(vehicles, vehicle)
            end
        end
        
        finished, vehicle = FindNextVehicle(handle)
    until not finished
    
    EndFindVehicle(handle)
    return vehicles
end

local function CanDeployAtLocation(coords)
    -- Check distance from other spikes
    for _, spike in pairs(deployedSpikes) do
        if DoesEntityExist(spike.object) then
            local spikeCoords = GetEntityCoords(spike.object)
            local distance = #(coords - spikeCoords)
            if distance < Config.Limits.minDistanceBetweenSpikes then
                return false, 'tooClose'
            end
        end
    end
    
    -- Check global limit
    local totalSpikes = 0
    for _ in pairs(deployedSpikes) do
        totalSpikes = totalSpikes + 1
    end
    
    if totalSpikes >= Config.Limits.maxSpikesGlobal then
        return false, 'maxReached'
    end
    
    -- Check player limit
    local playerSpikeCount = 0
    for _, spike in pairs(playerSpikes) do
        if DoesEntityExist(spike.object) then
            playerSpikeCount = playerSpikeCount + 1
        end
    end
    
    if playerSpikeCount >= Config.Limits.maxSpikesPerPlayer then
        return false, 'maxReached'
    end
    
    return true
end

local function PlayAnimation(animData)
    local ped = PlayerPedId()
    
    RequestAnimDict(animData.dict)
    while not HasAnimDictLoaded(animData.dict) do
        Wait(1)
    end
    
    TaskPlayAnim(ped, animData.dict, animData.anim, 8.0, -8.0, animData.duration, animData.flags, 0, false, false, false)
    
    Wait(animData.duration)
    ClearPedTasks(ped)
    RemoveAnimDict(animData.dict)
end

local function PlaySound(soundData)
    PlaySoundFrontend(-1, soundData.name, soundData.set, true)
end

local function CreateSpikeStrip(vehicle)
    local ped = PlayerPedId()
    
    -- Validation checks
    if not HasAuthorization() then
        QBCore.Functions.Notify(Config.Notifications.notAuthorized, 'error')
        return
    end
    
    if not IsAuthorizedVehicle(vehicle) then
        QBCore.Functions.Notify(Config.Notifications.notAuthorized, 'error')
        return
    end
    
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        QBCore.Functions.Notify(Config.Notifications.wrongSeat, 'error')
        return
    end
    
    if not IsVehicleStationary(vehicle) then
        QBCore.Functions.Notify(Config.Notifications.vehicleMoving, 'error')
        return
    end
    
    -- Cooldown check
    local currentTime = GetGameTimer()
    if currentTime - lastDeployTime < Config.Limits.deploymentCooldown then
        QBCore.Functions.Notify(Config.Notifications.cooldown, 'error')
        return
    end
    
    -- Get deployment position
    local vehicleCoords = GetEntityCoords(vehicle)
    local vehicleHeading = GetEntityHeading(vehicle)
    local rearVector = GetEntityForwardVector(vehicle) * -1
    local spikeCoords = vehicleCoords + (rearVector * math.abs(Config.SpikeSettings.offset.y))
    spikeCoords = spikeCoords + vector3(Config.SpikeSettings.offset.x, 0.0, Config.SpikeSettings.offset.z)
    
    -- Check if deployment is possible
    local canDeploy, reason = CanDeployAtLocation(spikeCoords)
    if not canDeploy then
        QBCore.Functions.Notify(Config.Notifications[reason], 'error')
        return
    end
    
    isDeploying = true
    
    -- Play animation
    CreateThread(function()
        PlayAnimation(Config.Animation.deploy)
    end)
    
    Wait(Config.Animation.deploy.duration)
    
    -- Load model
    local model = Config.SpikeSettings.model
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(1)
    end
    
    -- Create spike object
    local spike = CreateObject(model, spikeCoords.x, spikeCoords.y, spikeCoords.z, true, true, true)
    SetEntityHeading(spike, vehicleHeading + Config.SpikeSettings.rotation.z)
    SetEntityRotation(spike, 
        Config.SpikeSettings.rotation.x, 
        Config.SpikeSettings.rotation.y, 
        vehicleHeading + Config.SpikeSettings.rotation.z, 
        2, true
    )
    
    FreezeEntityPosition(spike, true)
    SetEntityAsMissionEntity(spike, true, true)
    
    -- Create blip
    local blip = nil
    if Config.Visual.blip then
        blip = AddBlipForEntity(spike)
        SetBlipSprite(blip, Config.Visual.blip.sprite)
        SetBlipColour(blip, Config.Visual.blip.color)
        SetBlipScale(blip, Config.Visual.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.Visual.blip.label)
        EndTextCommandSetBlipName(blip)
    end
    
    -- Store spike data
    local spikeId = NetworkGetNetworkIdFromEntity(spike)
    local spikeData = {
        object = spike,
        coords = spikeCoords,
        heading = vehicleHeading,
        owner = GetPlayerServerId(PlayerId()),
        netId = spikeId,
        blip = blip,
        vehicle = vehicle,
        timestamp = GetGameTimer()
    }
    
    deployedSpikes[spikeId] = spikeData
    playerSpikes[spikeId] = spikeData
    
    -- Sync with server
    TriggerServerEvent('qb-mobilespikes:server:deploySpike', spikeCoords, vehicleHeading, spikeId)
    
    -- Play sound and notify
    PlaySound(Config.Sounds.deploy)
    QBCore.Functions.Notify(Config.Notifications.deployed, 'success')
    
    lastDeployTime = currentTime
    isDeploying = false
    
    SetModelAsNoLongerNeeded(model)
    
    -- Auto-retract timer
    if Config.Limits.autoRetractTime > 0 then
        SetTimeout(Config.Limits.autoRetractTime, function()
            if DoesEntityExist(spike) then
                RemoveSpikeStrip(spikeId)
            end
        end)
    end
end

local function RemoveSpikeStrip(spikeId)
    local spikeData = playerSpikes[spikeId]
    if not spikeData then return end
    
    -- Play animation
    CreateThread(function()
        PlayAnimation(Config.Animation.retract)
    end)
    
    Wait(Config.Animation.retract.duration)
    
    -- Remove blip
    if spikeData.blip and DoesBlipExist(spikeData.blip) then
        RemoveBlip(spikeData.blip)
    end
    
    -- Remove object
    if DoesEntityExist(spikeData.object) then
        DeleteObject(spikeData.object)
    end
    
    -- Clean up data
    deployedSpikes[spikeId] = nil
    playerSpikes[spikeId] = nil
    
    -- Sync with server
    TriggerServerEvent('qb-mobilespikes:server:removeSpike', spikeId)
    
    -- Play sound and notify
    PlaySound(Config.Sounds.retract)
    QBCore.Functions.Notify(Config.Notifications.retracted, 'success')
end

local function CheckSpikeCollisions()
    local playerPed = PlayerPedId()
    local playerVehicle = GetVehiclePedIsIn(playerPed, false)
    
    for spikeId, spikeData in pairs(deployedSpikes) do
        if DoesEntityExist(spikeData.object) then
            local spikeCoords = GetEntityCoords(spikeData.object)
            local vehicles = GetVehiclesInArea(spikeCoords, Config.DamageSettings.damageRadius)
            
            for _, vehicle in ipairs(vehicles) do
                if vehicle ~= playerVehicle and vehicle ~= spikeData.vehicle then
                    local model = GetEntityModel(vehicle)
                    
                    -- Check if vehicle is immune
                    if not Config.DamageSettings.immuneVehicles[model] then
                        local speed = GetEntitySpeed(vehicle) * 3.6 -- km/h
                        
                        if speed >= Config.DamageSettings.minDamageSpeed and speed <= Config.DamageSettings.maxDamageSpeed then
                            -- Damage tires
                            if math.random(1, 100) <= Config.DamageSettings.tireDamageChance then
                                for wheel = 0, 7 do
                                    if math.random(1, 100) <= 60 then
                                        SetVehicleTyreBurst(vehicle, wheel, true, 1000.0)
                                    end
                                end
                            end
                            
                            -- Damage engine
                            if math.random(1, 100) <= Config.DamageSettings.engineDamageChance then
                                local currentHealth = GetVehicleEngineHealth(vehicle)
                                SetVehicleEngineHealth(vehicle, currentHealth - Config.DamageSettings.damageAmount.engine)
                            end
                            
                            -- Damage body
                            local currentBodyHealth = GetVehicleBodyHealth(vehicle)
                            SetVehicleBodyHealth(vehicle, currentBodyHealth - Config.DamageSettings.damageAmount.body)
                            
                            -- Play damage sound
                            PlaySound(Config.Sounds.damage)
                            
                            -- Notify if player is in damaged vehicle
                            if GetPedInVehicleSeat(vehicle, -1) == playerPed then
                                QBCore.Functions.Notify(Config.Notifications.damaged, 'error')
                            end
                        end
                    end
                end
            end
        end
    end
end

local function DrawText3D(coords, text)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    local pCoords = GetEntityCoords(PlayerPedId())
    local dist = #(pCoords - coords)
    
    if onScreen and dist <= Config.Visual.text3DDistance then
        local scale = (4.5 / dist) * 2
        local fov = (1 / GetGameplayCamFov()) * 100
        scale = scale * fov
        
        SetTextScale(0.0 * scale, 0.55 * scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry('STRING')
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(x, y)
    end
end

-- Main control thread
CreateThread(function()
    while true do
        local sleep = 500

        if isLoggedIn then
            local ped = PlayerPedId()
            local inVehicle = IsPedInAnyVehicle(ped, false)

            if inVehicle then
                local vehicle = GetVehiclePedIsIn(ped, false)

                if IsAuthorizedVehicle(vehicle) and HasAuthorization() then
                    -- Keep input polling frame-level only while an authorized
                    -- driver can actually use the deployment controls.
                    sleep = 0
                    -- Deploy spikes
                    if IsControlJustReleased(0, Config.Controls.deploy.key) and not isDeploying then
                        CreateSpikeStrip(vehicle)
                    end
                    
                    -- Toggle nearest spike removal
                    if IsControlJustReleased(0, Config.Controls.toggle.key) then
                        local playerCoords = GetEntityCoords(ped)
                        local closestSpike = nil
                        local closestDistance = math.huge
                        
                        for spikeId, spikeData in pairs(playerSpikes) do
                            if DoesEntityExist(spikeData.object) then
                                local distance = #(playerCoords - spikeData.coords)
                                if distance < closestDistance and distance <= 10.0 then
                                    closestDistance = distance
                                    closestSpike = spikeId
                                end
                            end
                        end
                        
                        if closestSpike then
                            RemoveSpikeStrip(closestSpike)
                        else
                            QBCore.Functions.Notify(Config.Notifications.notDeployed, 'error')
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- Collision check thread
CreateThread(function()
    while true do
        Wait(200)
        if next(deployedSpikes) then
            CheckSpikeCollisions()
        else
            Wait(1000)
        end
    end
end)

-- Visual effects thread
CreateThread(function()
    while true do
        local sleep = 750
        local playerCoords = GetEntityCoords(PlayerPedId())

        for _, spikeData in pairs(deployedSpikes) do
            if DoesEntityExist(spikeData.object) then
                local distance = #(playerCoords - spikeData.coords)
                
                if distance <= 50.0 then
                    -- Rendering must stay frame-level only when a visible element
                    -- actually needs per-frame drawing.
                    if (Config.Visual.drawMarker and distance <= 25.0)
                        or (Config.Visual.drawText3D and distance <= Config.Visual.text3DDistance) then
                        sleep = 0
                    end

                    -- Draw marker
                    if Config.Visual.drawMarker and distance <= 25.0 then
                        local marker = Config.Visual.marker
                        DrawMarker(
                            marker.type,
                            spikeData.coords.x,
                            spikeData.coords.y,
                            spikeData.coords.z + 0.1,
                            marker.rotation.x,
                            marker.rotation.y,
                            marker.rotation.z,
                            marker.rotation.x,
                            marker.rotation.y,
                            marker.rotation.z,
                            marker.size.x,
                            marker.size.y,
                            marker.size.z,
                            marker.color.r,
                            marker.color.g,
                            marker.color.b,
                            marker.color.a,
                            marker.bobUpAndDown,
                            marker.faceCamera,
                            2,
                            marker.rotate,
                            nil,
                            nil,
                            false
                        )
                    end
                    
                    -- Draw 3D text
                    if Config.Visual.drawText3D and distance <= Config.Visual.text3DDistance then
                        DrawText3D(spikeData.coords + vector3(0.0, 0.0, 0.5), '~r~SPIKE STRIP~s~\n~w~DANGER')
                    end
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- Event handlers
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    isLoggedIn = true
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

RegisterNetEvent('qb-mobilespikes:client:syncSpike', function(coords, heading, spikeId, owner)
    local playerId = GetPlayerServerId(PlayerId())
    
    if owner ~= playerId then
        -- Load model
        local model = Config.SpikeSettings.model
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(1)
        end
        
        -- Create synced spike
        local spike = CreateObject(model, coords.x, coords.y, coords.z, false, false, true)
        SetEntityHeading(spike, heading + Config.SpikeSettings.rotation.z)
        FreezeEntityPosition(spike, true)
        
        -- Create blip
        local blip = nil
        if Config.Visual.blip then
            blip = AddBlipForEntity(spike)
            SetBlipSprite(blip, Config.Visual.blip.sprite)
            SetBlipColour(blip, Config.Visual.blip.color)
            SetBlipScale(blip, Config.Visual.blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(Config.Visual.blip.label)
            EndTextCommandSetBlipName(blip)
        end
        
        deployedSpikes[spikeId] = {
            object = spike,
            coords = coords,
            heading = heading,
            owner = owner,
            netId = spikeId,
            blip = blip,
            timestamp = GetGameTimer()
        }
        
        SetModelAsNoLongerNeeded(model)
    end
end)

RegisterNetEvent('qb-mobilespikes:client:removeSpike', function(spikeId)
    local spikeData = deployedSpikes[spikeId]
    if spikeData then
        -- Remove blip
        if spikeData.blip and DoesBlipExist(spikeData.blip) then
            RemoveBlip(spikeData.blip)
        end
        
        -- Remove object
        if DoesEntityExist(spikeData.object) then
            DeleteObject(spikeData.object)
        end
        
        deployedSpikes[spikeId] = nil
        playerSpikes[spikeId] = nil
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for spikeId, spikeData in pairs(deployedSpikes) do
            if spikeData.blip and DoesBlipExist(spikeData.blip) then
                RemoveBlip(spikeData.blip)
            end
            if DoesEntityExist(spikeData.object) then
                DeleteObject(spikeData.object)
            end
        end
        deployedSpikes = {}
        playerSpikes = {}
    end
end)