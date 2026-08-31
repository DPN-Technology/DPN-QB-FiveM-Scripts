local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    Wait(1000)
    exports['dpn-medical-core']:RegisterModule('dpn-medical-icu','2.0.0',{'icu','continuous_monitoring','escalation'})
end)

local active={}
local function admit(src,target)
    target=tonumber(target); local p=QBCore.Functions.GetPlayer(src); local patient=QBCore.Functions.GetPlayer(target); if not p or not patient or not Config.Jobs[(p.PlayerData.job or {}).name] then return false end
    active[target]={patientCid=patient.PlayerData.citizenid,admittedBy=p.PlayerData.citizenid,started=os.time()}; exports['dpn-medical-core']:SetFlag(target,'icu',true)
    MySQL.insert('INSERT INTO dpn_medical_icu_episodes (patient_cid,admitted_by,status) VALUES (?,?,?)',{patient.PlayerData.citizenid,p.PlayerData.citizenid,'active'}); return true
end
exports('AdmitICU',function(target,bySource) return admit(bySource or 0,target) end)
exports('DischargeICU',function(target) target=tonumber(target); if not active[target] then return false end; MySQL.update('UPDATE dpn_medical_icu_episodes SET status=?,ended_at=NOW() WHERE patient_cid=? AND status=?',{'completed',active[target].patientCid,'active'}); active[target]=nil; exports['dpn-medical-core']:SetFlag(target,'icu',false); return true end)
QBCore.Commands.Add('icuadmit','Admit patient to ICU monitoring',{{name='id'}},true,function(src,args) local ok=admit(src,args[1]); TriggerClientEvent('QBCore:Notify',src,ok and 'ICU monitoring started.' or 'ICU admission denied.',ok and 'success' or 'error') end)
CreateThread(function()
    while true do Wait(math.max(10,Config.SnapshotSeconds)*1000)
        for target,episode in pairs(active) do local state=exports['dpn-medical-core']:GetPatientState(target); if not state then active[target]=nil else
            MySQL.insert('INSERT INTO dpn_medical_icu_vitals (patient_cid,vitals,triage) VALUES (?,?,?)',{episode.patientCid,json.encode(state.vitals),state.status.triage})
            if state.status.triage=='black' or state.status.cardiacArrest then
                for _,sid in ipairs(GetPlayers()) do local p=QBCore.Functions.GetPlayer(tonumber(sid)); if p and Config.Jobs[(p.PlayerData.job or {}).name] then TriggerClientEvent('QBCore:Notify',tonumber(sid),('ICU CRITICAL ALERT: patient ID %s'):format(target),'error',8000) end end
            end
        end end
    end
end)
