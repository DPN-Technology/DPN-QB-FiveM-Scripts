local QBCore=exports['qb-core']:GetCoreObject()
local carriedBy=nil
RegisterNetEvent('dpn-medical-ems:client:setCarried',function(carrier)
    carriedBy=carrier
    local ped=PlayerPedId()
    if carrier then
        local player=GetPlayerFromServerId(carrier); if player==-1 then return end
        AttachEntityToEntity(ped,GetPlayerPed(player),11816,0.30,0.45,0.0,0.0,0.0,180.0,false,false,false,false,2,false)
    else DetachEntity(ped,true,false); ClearPedTasksImmediately(ped) end
end)
RegisterCommand('emsnearest',function()
    local player,distance=QBCore.Functions.GetClosestPlayer()
    if player==-1 then return QBCore.Functions.Notify('No nearby patient.','error') end
    QBCore.Functions.Notify(('Nearest patient ID: %s (%.1fm)'):format(GetPlayerServerId(player),distance),'primary')
end,false)
