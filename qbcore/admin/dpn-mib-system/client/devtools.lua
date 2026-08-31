local QBCore = exports['qb-core']:GetCoreObject()
local devOverlay = false
local noclip = false

local function notify(msg, typ) if QBCore and QBCore.Functions then QBCore.Functions.Notify(msg, typ or 'primary') end end

RegisterNetEvent('dpn-mib:client:adminAction', function(action, data)
    data = data or {}
    local ped = PlayerPedId()
    if action == 'heal' then SetEntityHealth(ped, GetEntityMaxHealth(ped)); ClearPedBloodDamage(ped); notify('Admin heal complete.', 'success')
    elseif action == 'godmode' then local e = not GetPlayerInvincible(PlayerId()); SetPlayerInvincible(PlayerId(), e); notify('Godmode '..(e and 'enabled' or 'disabled'), 'primary')
    elseif action == 'invisible' then local e = IsEntityVisible(ped); SetEntityVisible(ped, not e, false); notify('Invisibility '..(e and 'enabled' or 'disabled'), 'primary')
    elseif action == 'noclip' then noclip = not noclip; SetEntityInvincible(ped, noclip); SetEntityCollision(ped, not noclip, not noclip); notify('Noclip '..(noclip and 'enabled' or 'disabled'), 'primary')
    elseif action == 'repair_vehicle' or action == 'clean_vehicle' or action == 'flip_vehicle' or action == 'delete_vehicle' then
        local veh = GetVehiclePedIsIn(ped, false); if veh == 0 then veh = QBCore.Functions.GetClosestVehicle(GetEntityCoords(ped)) end
        if veh == 0 then return notify('No vehicle found.', 'error') end
        if action == 'repair_vehicle' then SetVehicleFixed(veh); SetVehicleEngineHealth(veh,1000.0); SetVehicleBodyHealth(veh,1000.0); notify('Vehicle repaired.', 'success') end
        if action == 'clean_vehicle' then SetVehicleDirtLevel(veh,0.0); notify('Vehicle cleaned.', 'success') end
        if action == 'flip_vehicle' then SetVehicleOnGroundProperly(veh); notify('Vehicle flipped upright.', 'success') end
        if action == 'delete_vehicle' then DeleteEntity(veh); notify('Vehicle deleted.', 'success') end
    elseif action == 'copy_coords' then
        local c=GetEntityCoords(ped); local h=GetEntityHeading(ped); local text=('vector4(%.2f, %.2f, %.2f, %.2f)'):format(c.x,c.y,c.z,h)
        SendNUIMessage({ action='devResult', title='Copied Coordinates', text=text }); notify(text, 'primary')
    elseif action == 'debug_overlay' then devOverlay = not devOverlay; notify('Developer overlay '..(devOverlay and 'enabled' or 'disabled'), 'primary')
    elseif action == 'entity_inspector' then
        local hit, coords, entity = RaycastEntity(250.0)
        local text = hit and ('Entity: %s | Model: %s | Coords: %.2f %.2f %.2f'):format(entity, GetEntityModel(entity), coords.x, coords.y, coords.z) or 'No entity hit.'
        SendNUIMessage({ action='devResult', title='Entity Inspector', text=text }); notify(text, 'primary')
    end
end)

CreateThread(function()
    while true do
        if noclip then
            local ped=PlayerPedId(); local c=GetEntityCoords(ped); local f=GetEntityForwardVector(ped); local speed=IsControlPressed(0,21) and 3.5 or 1.0
            if IsControlPressed(0,32) then c = c + f * speed end
            if IsControlPressed(0,33) then c = c - f * speed end
            if IsControlPressed(0,44) then c = c + vector3(0,0,speed) end
            if IsControlPressed(0,38) then c = c - vector3(0,0,speed) end
            SetEntityCoordsNoOffset(ped,c.x,c.y,c.z,false,false,false)
            Wait(0)
        elseif devOverlay then
            local c=GetEntityCoords(PlayerPedId())
            DrawTxt(0.015,0.70,('DPN DEV | FPS approx | Coords %.2f %.2f %.2f | Bucket N/A'):format(c.x,c.y,c.z))
            Wait(0)
        else Wait(500) end
    end
end)

function DrawTxt(x,y,text)
    SetTextFont(4); SetTextScale(0.32,0.32); SetTextColour(0,255,130,220); SetTextOutline(); BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(text); EndTextCommandDisplayText(x,y)
end

function RaycastEntity(distance)
    local camRot = GetGameplayCamRot(2); local camCoord = GetGameplayCamCoord()
    local z=math.rad(camRot.z); local x=math.rad(camRot.x); local num=math.abs(math.cos(x)); local dir=vector3(-math.sin(z)*num, math.cos(z)*num, math.sin(x))
    local dest=camCoord+(dir*distance); local ray=StartShapeTestRay(camCoord.x,camCoord.y,camCoord.z,dest.x,dest.y,dest.z,-1,PlayerPedId(),0)
    local _, hit, endCoords, _, entity = GetShapeTestResult(ray)
    return hit == 1, endCoords, entity
end
RegisterNetEvent('dpn-mib:client:devResultDirect', function(title, text)
    SendNUIMessage({ action='devResult', title=title, text=text })
end)
