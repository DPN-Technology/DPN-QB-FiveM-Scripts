local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    Wait(1000)
    exports['dpn-medical-core']:RegisterModule('dpn-medical-rehab','2.0.0',{'rehab','care_plans','mobility_recovery'})
end)

AddEventHandler('dpn-medical-rehab:server:createAutomaticPlan',function(target,part,reason)
    local p=QBCore.Functions.GetPlayer(tonumber(target)); if not p then return end
    MySQL.insert('INSERT INTO dpn_medical_rehab_plans (patient_cid,body_part,reason,sessions_required,sessions_completed,status) VALUES (?,?,?,?,?,?)',{p.PlayerData.citizenid,part,reason,5,0,'active'})
end)
local function session(src,target,part)
    target=tonumber(target); local provider=QBCore.Functions.GetPlayer(src); local patient=QBCore.Functions.GetPlayer(target); if not provider or not patient or not Config.Jobs[(provider.PlayerData.job or {}).name] then return false end
    local ok=exports['dpn-medical-core']:TreatPatient(target,nil,'rehab_session',provider.PlayerData.citizenid); if not ok then return false end
    MySQL.update('UPDATE dpn_medical_rehab_plans SET sessions_completed=sessions_completed+1,status=IF(sessions_completed+1>=sessions_required,?,status) WHERE patient_cid=? AND status=? ORDER BY id DESC LIMIT 1',{'completed',patient.PlayerData.citizenid,'active'})
    if GetResourceState('dpn-medical-billing-plus')=='started' then pcall(function() exports['dpn-medical-billing-plus']:CreateInvoice(target,Config.SessionCost,'Rehabilitation session','rehab') end) end
    return true
end
exports('CompleteSession',session)
QBCore.Commands.Add('rehab','Complete a rehabilitation session',{{name='id'},{name='part'}},true,function(src,args) local ok=session(src,args[1],args[2]); TriggerClientEvent('QBCore:Notify',src,ok and 'Rehab session completed.' or 'Rehab denied.',ok and 'success' or 'error') end)
