local QBCore = exports['qb-core']:GetCoreObject()

local function auth(src) local p=QBCore.Functions.GetPlayer(src); local j=p and p.PlayerData.job or {}; return Config.Jobs[j.name] and j.onduty~=false end
QBCore.Commands.Add('ambulance','Spawn a DPN medical response vehicle',{{name='model'},{name='station'}},false,function(src,args)
    if not auth(src) then return TriggerClientEvent('QBCore:Notify',src,'EMS duty required.','error') end
    local model=args[1] or 'ambulance'; local station=Config.Stations[args[2] or 'pillbox']; if not Config.Vehicles[model] or not station then return end
    local p=QBCore.Functions.GetPlayer(src); local plate=('DPN%04d'):format(math.random(0,9999)); MySQL.insert('INSERT INTO dpn_medical_ambulance_log (citizenid,vehicle_model,plate,action) VALUES (?,?,?,?)',{p.PlayerData.citizenid,model,plate,'checkout'})
    TriggerClientEvent('dpn-medical-ambulance:client:spawn',src,model,station.spawn,plate)
end)
