local QBCore = exports['qb-core']:GetCoreObject()
local inRange = false
local lastRingTime = 0
local doorbellTarget = nil

-- Create target interaction if qb-target is available
Citizen.CreateThread(function()
    if Config.UseTarget and GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddBoxZone('pd_doorbell', Config.PDReception, 1.5, 1.5, {
            name = 'pd_doorbell',
            heading = 0,
            debugPoly = false,
            minZ = Config.PDReception.z - 1.0,
            maxZ = Config.PDReception.z + 1.0
        }, {
            options = {
                {
                    type = 'client',
                    event = 'qb-pd-doorbell:ring',
                    icon = 'fas fa-bell',
                    label = Config.RingText,
                    onSelect = function()
                        TriggerServerEvent('qb-pd-doorbell:ringBell')
                    end
                }
            },
            distance = Config.InteractDistance
        })

        -- Optional: Spawn a visual doorbell prop
        local bellHash = GetHashKey(Config.BellModel)
        RequestModel(bellHash)
        while not HasModelLoaded(bellHash) do
            Citizen.Wait(100)
        end
        local bell = CreateObject(bellHash, Config.PDReception.x, Config.PDReception.y, Config.PDReception.z - 0.8, false, false, false)
        SetEntityHeading(bell, 90.0) -- Adjust rotation
        FreezeEntityPosition(bell, true)
        SetModelAsNoLongerNeeded(bellHash)
    else
        -- Fallback: Proximity key press (F3)
        Citizen.CreateThread(function()
            while true do
                Citizen.Wait(0)
                local playerCoords = GetEntityCoords(PlayerPedId())
                inRange = #(playerCoords - Config.PDReception) < Config.InteractDistance

                if inRange then
                    QBCore.Functions.DrawText3D(Config.PDReception.x, Config.PDReception.y, Config.PDReception.z + 0.5, '[F3] ' .. Config.RingText)
                    if IsControlJustPressed(0, 170) then -- F3 key
                        TriggerServerEvent('qb-pd-doorbell:ringBell')
                    end
                end
            end
        end)
    end
end)

-- Client event for ringing (with cooldown check)
RegisterNetEvent('qb-pd-doorbell:ring', function()
    local currentTime = GetGameTimer()
    if currentTime - lastRingTime < Config.Cooldown then
        QBCore.Functions.Notify('Please wait before ringing again.', 'error', 2000)
        return
    end
    lastRingTime = currentTime
    TriggerServerEvent('qb-pd-doorbell:ringBell')
end)

-- Play bell sound and notify player
RegisterNetEvent('qb-pd-doorbell:playSound', function()
    local playerPed = PlayerPedId()
    PlaySoundFromEntity(-1, Config.BellSound, playerPed, 'DLC_EXEC_SOUNDS', true, 10)
    QBCore.Functions.Notify(Config.RingerNotify, 'success', 3000)
end)