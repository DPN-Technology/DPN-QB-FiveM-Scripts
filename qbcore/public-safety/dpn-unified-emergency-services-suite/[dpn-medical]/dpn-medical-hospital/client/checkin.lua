local QBCore = exports['qb-core']:GetCoreObject()
local targetZones = {}
local fallbackCheckIn = false

local function AddHospitalBlip(hospital)
    local blip = AddBlipForCoord(hospital.checkIn.x, hospital.checkIn.y, hospital.checkIn.z)
    SetBlipSprite(blip, 61)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 2)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(hospital.label)
    EndTextCommandSetBlipName(blip)
end

local function RegisterTargetCheckIn(hospitalId, hospital)
    local zoneName = 'dpn_hospital_checkin_' .. hospitalId
    targetZones[#targetZones + 1] = zoneName

    exports[Config.TargetResource]:AddBoxZone(zoneName, hospital.checkIn, 1.5, 1.5, {
        name = zoneName,
        heading = 0,
        debugPoly = Config.Debug,
        minZ = hospital.checkIn.z - 1.0,
        maxZ = hospital.checkIn.z + 2.0
    }, {
        options = {
            {
                icon = 'fas fa-hospital',
                label = ('Check In To Hospital ($%s)'):format(Config.CheckInCost),
                canInteract = function()
                    return Config.AutoCheckinEnabled and not PlayerAdmission
                end,
                action = function()
                    TriggerServerEvent('dpn-hospital:server:selfCheckIn', hospitalId)
                end
            }
        },
        distance = 2.0
    })
end

CreateThread(function()
    local targetStarted = Config.UseTarget and GetResourceState(Config.TargetResource) == 'started'
    fallbackCheckIn = not targetStarted

    for hospitalId, hospital in pairs(Config.Hospitals) do
        AddHospitalBlip(hospital)
        if targetStarted then RegisterTargetCheckIn(hospitalId, hospital) end
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000

        if fallbackCheckIn and Config.AutoCheckinEnabled and not PlayerAdmission then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            for hospitalId, hospital in pairs(Config.Hospitals) do
                local distance = #(coords - hospital.checkIn)
                if distance < 20.0 then
                    sleep = 0
                    DrawMarker(2, hospital.checkIn.x, hospital.checkIn.y, hospital.checkIn.z + 0.15, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.25, 0.25, 0.25, 255, 255, 255, 180, false, true, 2, false, nil, nil, false)

                    if distance < 2.0 then
                        QBCore.Functions.DrawText3D(hospital.checkIn.x, hospital.checkIn.y, hospital.checkIn.z + 0.35, ('[E] Hospital Check-In - $%s'):format(Config.CheckInCost))
                        if IsControlJustReleased(0, 38) then
                            TriggerServerEvent('dpn-hospital:server:selfCheckIn', hospitalId)
                            Wait(1000)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if GetResourceState(Config.TargetResource) ~= 'started' then return end

    for _, zoneName in ipairs(targetZones) do
        pcall(function()
            exports[Config.TargetResource]:RemoveZone(zoneName)
        end)
    end
end)
