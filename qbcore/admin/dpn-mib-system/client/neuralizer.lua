local QBCore = exports['qb-core']:GetCoreObject()

local function inFront(ped, targetPed, maxRange, cone)
    local pc=GetEntityCoords(ped); local tc=GetEntityCoords(targetPed); local dist=#(pc-tc)
    if dist>maxRange then return false end
    local forward=GetEntityForwardVector(ped); local dir=(tc-pc)/dist
    local dot=forward.x*dir.x+forward.y*dir.y+forward.z*dir.z
    local angle=math.deg(math.acos(dot))
    return angle <= (cone/2.0)
end

RegisterNetEvent('dpn-mib:client:useNeuralizer', function(class, reason)
    local ped=PlayerPedId(); local target=GetClosestPlayerServerId(Config.Neuralizer.Range)
    if not target then return QBCore.Functions.Notify('No subject in neuralizer range.','error') end
    local targetPed=GetPlayerPed(GetPlayerFromServerId(target))
    if not inFront(ped,targetPed,Config.Neuralizer.Range,Config.Neuralizer.Cone) then return QBCore.Functions.Notify('Subject must be in front of you.','error') end
    RequestAnimDict('weapons@first_person@aim_rng@generic@projectile@thermal_charge@'); while not HasAnimDictLoaded('weapons@first_person@aim_rng@generic@projectile@thermal_charge@') do Wait(10) end
    TaskPlayAnim(ped,'weapons@first_person@aim_rng@generic@projectile@thermal_charge@','plant_floor',8.0,-8.0,900,48,0,false,false,false)
    Wait(450)
    TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 10.0, 'neuralizer', 0.6)
    TriggerServerEvent('dpn-mib:server:neuralize', target, class or 'beta', reason or 'Field neuralizer deployment')
end)

RegisterNetEvent('dpn-mib:client:blackout', function(seconds, classLabel)
    local ped=PlayerPedId()
    if Config.Neuralizer.NoDamage then SetEntityInvincible(ped,true) end
    StartScreenEffect('DeathFailOut',0,true)
    DoScreenFadeOut(150)
    Wait((seconds or 15)*1000)
    StopScreenEffect('DeathFailOut')
    DoScreenFadeIn(1200)
    if Config.Neuralizer.NoDamage then SetEntityInvincible(ped,false) end
    QBCore.Functions.Notify((classLabel or 'Neuralizer')..': you feel confused and lose track of time.','error',9000)
end)

RegisterNetEvent('dpn-mib:client:clearShortMemory', function(minutes)
    ClearPedTasksImmediately(PlayerPedId())
    SetGameplayCamRelativeHeading(0.0)
    SetGameplayCamRelativePitch(0.0,1.0)
end)

RegisterNetEvent('dpn-mib:client:advancedNeuralizeTarget', function(cfg)
    cfg = cfg or {}
    local ped = PlayerPedId()
    DoScreenFadeOut(100)
    Wait((cfg.blackout or 10) * 1000)
    ClearPedTasksImmediately(ped)
    SetTimecycleModifier('BarryFadeOut')
    ShakeGameplayCam('DRUNK_SHAKE', 0.85)
    SetPedCanSwitchWeapon(ped, false)
    DoScreenFadeIn(900)
    SetTimeout((Config.AdvancedNeuralizer.DisableWeaponsSeconds or 20) * 1000, function() SetPedCanSwitchWeapon(ped, true) end)
    SetTimeout((Config.AdvancedNeuralizer.DizzinessSeconds or 25) * 1000, function() ClearTimecycleModifier(); StopGameplayCamShaking(true) end)
    if QBCore and QBCore.Functions then QBCore.Functions.Notify('Your memory feels fragmented. Last known details are unclear.', 'error', 10000) end
end)

RegisterNetEvent('dpn-mib:client:advancedNeuralizeArea', function(coords, cfg)
    local ped = PlayerPedId(); local c = vector3(coords.x, coords.y, coords.z)
    if #(GetEntityCoords(ped) - c) > (cfg.radius or 20.0) then return end
    TriggerEvent('dpn-mib:client:advancedNeuralizeTarget', cfg)
end)
