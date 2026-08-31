local QBCore=exports['qb-core']:GetCoreObject()
RegisterNetEvent('dpn-medical-ambulance:client:spawn',function(model,coords,plate)
    local hash=joaat(model); RequestModel(hash); local timeout=GetGameTimer()+5000
    while not HasModelLoaded(hash) and GetGameTimer()<timeout do Wait(10) end
    if not HasModelLoaded(hash) then return QBCore.Functions.Notify('Vehicle model failed to load.','error') end
    local veh=CreateVehicle(hash,coords.x,coords.y,coords.z,coords.w,true,false); SetVehicleNumberPlateText(veh,plate); SetVehicleEngineOn(veh,true,true,false); TaskWarpPedIntoVehicle(PlayerPedId(),veh,-1); SetModelAsNoLongerNeeded(hash)
end)
