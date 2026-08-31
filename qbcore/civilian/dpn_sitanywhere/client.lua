local QBCore = exports['qb-core']:GetCoreObject()
local isSitting = false
local currentSeat = nil
local lastSitTime = 0
local sitThread = nil

-- Function to check if player can sit
local function CanSit()
    local PlayerData = QBCore.Functions.GetPlayerData()
    local playerPed = PlayerPedId()
    
    if isSitting then return false end
    if IsPedInAnyVehicle(playerPed, false) then return false end
    if IsEntityDead(playerPed) then return false end
    if GetEntityHealth(playerPed) < 101 then return false end -- Dead/injured
    -- Optional: Check if cuffed (QBCore handcuff export)
    -- if exports['qb-policejob']:IsHandcuffed() then return false end
    
    local currentTime = GetGameTimer()
    if currentTime - lastSitTime < Config.Cooldown then
        QBCore.Functions.Notify(Config.CooldownNotify, 'error', 2000)
        return false
    end
    
    return true
end

-- Function to find nearest seat
local function GetNearestSeat()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local nearestSeat = nil
    local minDist = Config.InteractDistance
    
    for _, model in ipairs(Config.SeatModels) do
        local seats = GetGamePool('CObject') -- All objects
        for _, seat in ipairs(seats) do
            if GetEntityModel(seat) == model then
                local seatCoords = GetEntityCoords(seat)
                local dist = #(playerCoords - seatCoords)
                if dist < minDist then
                    minDist = dist
                    nearestSeat = seat
                end
            end
        end
    end
    
    return nearestSeat, minDist
end

-- Function to sit on seat
local function SitOnSeat(seat)
    if not CanSit() or not seat then return end
    
    local playerPed = PlayerPedId()
    local seatCoords = GetEntityCoords(seat)
    local seatHeading = GetEntityHeading(seat)
    
    -- Load animations
    RequestAnimDict(Config.SitAnimDict)
    while not HasAnimDictLoaded(Config.SitAnimDict) do
        Citizen.Wait(100)
    end
    
    -- Position player on seat (adjust offset based on model if needed)
    local offset = Config.SeatOffset
    -- Example: For benches, adjust y offset
    -- if GetEntityModel(seat) == GetHashKey('prop_bench_01a') then offset = vector4(0.0, -0.5, 0.0, 0.0) end
    
    SetEntityCoords(playerPed, seatCoords.x + offset.x, seatCoords.y + offset.y, seatCoords.z + offset.z, false, false, false, true)
    SetEntityHeading(playerPed, seatHeading + offset.w)
    
    -- Play sit animation
    TaskPlayAnim(playerPed, Config.SitAnimDict, Config.SitAnimName, 8.0, -8.0, -1, 1, 0, false, false, false)
    
    -- Attach to seat to prevent sliding
    AttachEntityToEntity(playerPed, seat, 0, offset.x, offset.y, offset.z, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    
    isSitting = true
    currentSeat = seat
    lastSitTime = GetGameTimer()
    
    QBCore.Functions.Notify(Config.SitNotify, 'success', 2000)
    
    -- Disable controls while sitting
    sitThread = Citizen.CreateThread(function()
        while isSitting do
            Citizen.Wait(0)
            DisableControlAction(0, 21, true) -- Attack
            DisableControlAction(0, 24, true) -- Attack2
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 47, true) -- Weapon
            DisableControlAction(0, 58, true) -- Weapon
            DisableControlAction(0, 263, true) -- Move up/down
            DisableControlAction(0, 32, true) -- W/S
            DisableControlAction(0, 33, true) -- A/D
            DisableControlAction(0, 34, true) -- Q
            DisableControlAction(0, 35, true) -- Shift
            DisableControlAction(0, 36, true) -- CTRL
            
            -- Stand up on E press
            if IsControlJustPressed(0, Config.SitKey) then
                StandUp()
            end
            
            -- Auto-stand if health low or in vehicle
            if GetEntityHealth(playerPed) < 101 or IsPedInAnyVehicle(playerPed, false) then
                StandUp()
            end
        end
    end)
end

-- Function to stand up
function StandUp()
    if not isSitting then return end
    
    local playerPed = PlayerPedId()
    
    -- Load stand animation
    RequestAnimDict(Config.StandAnimDict)
    while not HasAnimDictLoaded(Config.StandAnimDict) do
        Citizen.Wait(100)
    end
    
    -- Play stand animation
    TaskPlayAnim(playerPed, Config.StandAnimDict, Config.StandAnimName, 8.0, -8.0, 1000, 0, 0, false, false, false)
    
    -- Detach and clear
    if currentSeat then
        DetachEntity(playerPed, true, false)
    end
    ClearPedTasks(playerPed)
    
    isSitting = false
    currentSeat = nil
    
    if sitThread then
        sitThread = nil
    end
    
    QBCore.Functions.Notify(Config.StandNotify, 'success', 2000)
end

-- qb-target integration
Citizen.CreateThread(function()
    if Config.UseTarget and GetResourceState('qb-target') == 'started' then
        for _, model in ipairs(Config.SeatModels) do
            exports['qb-target']:AddTargetModel(model, {
                options = {
                    {
                        type = 'client',
                        event = 'qb-sit:anywhere',
                        icon = 'fas fa-chair',
                        label = 'Sit',
                        onSelect = function(data)
                            local seat = data.entity
                            SitOnSeat(seat)
                        end
                    }
                },
                distance = Config.InteractDistance
            })
        end
    else
        -- Fallback: Proximity E key
        Citizen.CreateThread(function()
            while true do
                Citizen.Wait(500) -- Check every 0.5s for performance
                if not isSitting and CanSit() then
                    local seat, dist = GetNearestSeat()
                    if seat and dist <= Config.InteractDistance then
                        QBCore.Functions.DrawText3D(GetEntityCoords(seat).x, GetEntityCoords(seat).y, GetEntityCoords(seat).z + 1.0, '[E] Sit')
                        if IsControlJustPressed(0, Config.SitKey) then
                            SitOnSeat(seat)
                        end
                    end
                end
            end
        end)
    end
end)

-- Command for ground sitting (bonus for "anywhere")
RegisterCommand('sitground', function()
    if not CanSit() then return end
    
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    -- Load ground sit animation
    RequestAnimDict(Config.GroundSitAnimDict)
    while not HasAnimDictLoaded(Config.GroundSitAnimDict) do
        Citizen.Wait(100)
    end
    
    TaskPlayAnim(playerPed, Config.GroundSitAnimDict, Config.GroundSitAnimName, 8.0, -8.0, -1, 1, 0, false, false, false)
    
    isSitting = true -- Reuse flag for ground
    lastSitTime = GetGameTimer()
    QBCore.Functions.Notify('You sat on the ground. Press E to stand.', 'success', 3000)
    
    -- Stand thread for ground
    sitThread = Citizen.CreateThread(function()
        while isSitting do
            Citizen.Wait(0)
            -- Disable some controls (less than seat)
            DisableControlAction(0, 21, true) -- Attack
            DisableControlAction(0, 24, true) -- Attack2
            
            if IsControlJustPressed(0, Config.SitKey) then
                ClearPedTasks(playerPed)
                isSitting = false
                sitThread = nil
                QBCore.Functions.Notify('You stood up.', 'success', 2000)
            end
        end
    end)
end, false)

-- Cleanup on resource stop or player death
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName and isSitting then
        StandUp()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    isSitting = false
    currentSeat = nil
end)

-- Handle death/cuff events (if integrated with qb-police)
RegisterNetEvent('hospital:client:Revive', function()
    if isSitting then StandUp() end
end)