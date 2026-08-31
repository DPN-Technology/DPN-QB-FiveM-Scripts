local spectating=false
local lastCoords=nil

RegisterNetEvent('dpn-mib:client:spectate', function(target)
    local ply=GetPlayerFromServerId(target)
    if ply == -1 then return end
    local ped=PlayerPedId(); local tped=GetPlayerPed(ply)
    if not spectating then
        spectating=true; lastCoords=GetEntityCoords(ped)
        SetEntityVisible(ped,false,false); SetEntityCollision(ped,false,false); FreezeEntityPosition(ped,true)
        NetworkSetInSpectatorMode(true,tped)
    else
        spectating=false
        NetworkSetInSpectatorMode(false,tped)
        SetEntityVisible(ped,true,false); SetEntityCollision(ped,true,true); FreezeEntityPosition(ped,false)
        if lastCoords then SetEntityCoords(ped,lastCoords.x,lastCoords.y,lastCoords.z,false,false,false,false) end
    end
end)
