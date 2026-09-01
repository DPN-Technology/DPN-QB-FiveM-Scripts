local QBCore = exports['qb-core']:GetCoreObject()

local sessions={}
local function auth(src) local p=QBCore.Functions.GetPlayer(src); return p and Config.Jobs[(p.PlayerData.job or {}).name] and (p.PlayerData.job or {}).onduty~=false end
QBCore.Commands.Add('lifepak','Start a live monitor session',{{name='id'}},true,function(src,args)
    local target=tonumber(args[1]); if not auth(src) or not target then return end; sessions[src]={target=target,expires=os.time()+Config.SessionSeconds}; TriggerClientEvent('QBCore:Notify',src,'LIFEPAK monitoring started.','success')
end)
QBCore.Commands.Add('lifepakshock','Deliver a defibrillation shock',{{name='id'}},true,function(src,args)
    local target=tonumber(args[1]); if not auth(src) or not target then return end; local p=QBCore.Functions.GetPlayer(src); local ok=exports['dpn-medical-core']:TreatPatient(target,nil,'aed',p.PlayerData.citizenid); if ok then exports['dpn-medical-core']:RevivePatient(target,{fullHeal=false,by=p.PlayerData.citizenid}) end
    TriggerClientEvent('QBCore:Notify',src,ok and 'Shock delivered.' or 'No shockable rhythm.',ok and 'success' or 'error')
end)
CreateThread(function()
    while true do Wait(3000); for src,s in pairs(sessions) do if os.time()>s.expires or not GetPlayerName(src) then sessions[src]=nil else local state=exports['dpn-medical-core']:GetPatientState(s.target); if state then TriggerClientEvent('dpn-medical-lifepak:client:snapshot',src,s.target,state) else sessions[src]=nil end end end end
end)
