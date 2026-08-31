local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('dpn-mib:client:cloak', function()
    local ped=PlayerPedId(); SetEntityAlpha(ped,65,false); SetEntityInvincible(ped,true); QBCore.Functions.Notify('Field cloak active.','primary')
    SetTimeout(Config.Tools.cloak.duration*1000,function() ResetEntityAlpha(ped); SetEntityInvincible(ped,false); QBCore.Functions.Notify('Field cloak ended.','primary') end)
end)

RegisterNetEvent('dpn-mib:client:freezeTarget', function(seconds)
    local ped=PlayerPedId(); FreezeEntityPosition(ped,true); SetPedCanRagdoll(ped,false); QBCore.Functions.Notify('You have been placed in federal containment.','error',seconds*1000)
    SetTimeout(seconds*1000,function() FreezeEntityPosition(ped,false); SetPedCanRagdoll(ped,true) end)
end)

RegisterNetEvent('dpn-mib:client:setArmor', function(amount) SetPedArmour(PlayerPedId(), amount or 100); QBCore.Functions.Notify('Suit armor protocol complete.','success') end)

RegisterNetEvent('dpn-mib:client:scanNearest', function()
    local target=GetClosestPlayerServerId(Config.Tools.scan.range)
    if not target then return QBCore.Functions.Notify('No subject in scan range.','error') end
    TriggerServerEvent('dpn-mib:server:toolAction','scan',target,{})
end)

RegisterNetEvent('dpn-mib:client:scanResult', function(data)
    SendNUIMessage({ action='scanResult', result=data })
    QBCore.Functions.Notify(('Scan: %s | CID: %s | Job: %s'):format(data.name,data.cid,data.job),'primary',10000)
end)

RegisterNetEvent('dpn-mib:client:vehicleScan', function()
    local ped=PlayerPedId(); local veh=GetVehiclePedIsIn(ped,false)
    if veh==0 then veh=QBCore.Functions.GetClosestVehicle(GetEntityCoords(ped)) end
    if veh==0 then return QBCore.Functions.Notify('No vehicle detected.','error') end
    local plate=QBCore.Functions.GetPlate(veh); local engine=GetVehicleEngineHealth(veh); local body=GetVehicleBodyHealth(veh); local fuel=GetVehicleFuelLevel(veh); local model=GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    SendNUIMessage({ action='vehicleScan', result={plate=plate,model=model,engine=math.floor(engine),body=math.floor(body),fuel=math.floor(fuel)} })
    QBCore.Functions.Notify(('Vehicle scan: %s | %s | Engine %s'):format(plate,model,math.floor(engine)),'primary',9000)
end)

RegisterNetEvent('dpn-mib:client:wipeScene', function(coords,radius,reason)
    local ped=PlayerPedId(); if #(GetEntityCoords(ped)-vector3(coords.x,coords.y,coords.z))>radius then return end
    DoScreenFadeOut(250); Wait(450); ClearPedTasksImmediately(ped); ShakeGameplayCam('SMALL_EXPLOSION_SHAKE',0.2); Wait(350); DoScreenFadeIn(900)
    QBCore.Functions.Notify('You feel disoriented and cannot recall the last few moments.','error',9000)
end)

RegisterNetEvent('dpn-mib:client:bodycamStatic', function(coords,radius)
    if #(GetEntityCoords(PlayerPedId())-vector3(coords.x,coords.y,coords.z))>radius then return end
    SendNUIMessage({ action='static', duration=3500 })
end)

RegisterNetEvent('dpn-mib:client:cleanupArea', function()
    local ped=PlayerPedId(); local coords=GetEntityCoords(ped); local radius=Config.Tools.entity_cleanup.radius
    ClearAreaOfPeds(coords.x,coords.y,coords.z,radius,1); ClearAreaOfVehicles(coords.x,coords.y,coords.z,radius,false,false,false,false,false); ClearAreaOfObjects(coords.x,coords.y,coords.z,radius,0)
    QBCore.Functions.Notify('Anomaly cleanup complete.','success')
end)

RegisterNetEvent('dpn-mib:client:lockdown', function(coords, radius, duration, reason)
    local ped = PlayerPedId()
    local c = vector3(coords.x, coords.y, coords.z)
    if #(GetEntityCoords(ped) - c) > (radius or 75.0) then return end
    QBCore.Functions.Notify('MIB BLACKSITE LOCKDOWN ACTIVE: '..(reason or 'Federal operation'), 'error', 10000)
    local endAt = GetGameTimer() + ((duration or 60) * 1000)
    CreateThread(function()
        while GetGameTimer() < endAt do
            DrawMarker(28, c.x, c.y, c.z, 0.0,0.0,0.0, 0.0,0.0,0.0, radius or 75.0, radius or 75.0, radius or 75.0, 0,0,0,70, false, false, 2, false, nil, nil, false)
            Wait(0)
        end
    end)
end)
