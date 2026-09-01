local QBCore = exports['qb-core']:GetCoreObject()

local function auth(src) local p=QBCore.Functions.GetPlayer(src); return p and p.PlayerData.job and Config.Jobs[p.PlayerData.job.name] end
AddEventHandler('dpn-medical:server:lifeStateChanged',function(src,cid,fromState,toState,state,details)
    if toState~='dead' then return end
    MySQL.insert('INSERT INTO dpn_medical_death_cases (patient_cid,status,cause,manner,scene_data) VALUES (?,?,?,?,?)',{cid,'open',state.status.causeOfDeath or 'Pending','undetermined',json.encode(details or {})})
end)
local function pronounce(src,target,cause,manner)
    target=tonumber(target); if not auth(src) or not target then return false,'Denied' end
    local state=exports['dpn-medical-core']:GetPatientState(target); if not state or state.status.lifeState~='dead' then return false,'Patient is not deceased' end
    local p=QBCore.Functions.GetPlayer(target); local c=QBCore.Functions.GetPlayer(src)
    MySQL.update('UPDATE dpn_medical_death_cases SET status=?,cause=?,manner=?,coroner_cid=?,pronounced_at=NOW() WHERE patient_cid=? AND status=? ORDER BY id DESC LIMIT 1',{'pronounced',cause or state.status.causeOfDeath,manner or 'undetermined',c.PlayerData.citizenid,p.PlayerData.citizenid,'open'})
    if GetResourceState('dpn-medical-records')=='started' then pcall(function() exports['dpn-medical-records']:AddEntry(target,'death_pronouncement',{cause=cause,manner=manner},c.PlayerData.citizenid) end) end
    return true,'Death pronounced and case updated'
end
exports('Pronounce',pronounce)
QBCore.Commands.Add('pronounce','Pronounce a deceased patient',{{name='id'},{name='cause'},{name='manner'}},true,function(src,args)
    local ok,msg=pronounce(src,args[1],args[2],args[3]); TriggerClientEvent('QBCore:Notify',src,msg,ok and 'success' or 'error',5000)
end)
QBCore.Commands.Add('autopsy','Generate an injury-based autopsy summary',{{name='id'}},true,function(src,args)
    if not auth(src) then return end; local target=tonumber(args[1]); local state=exports['dpn-medical-core']:GetPatientState(target); if not state then return end
    local findings={}; for part,p in pairs(state.body) do if (p.damage or 0)>0 then findings[#findings+1]=('%s %s%%'):format(part,p.damage) end end
    TriggerClientEvent('chat:addMessage',src,{args={'DPN Coroner',#findings>0 and table.concat(findings,'; ') or 'No traumatic findings'}})
end)
