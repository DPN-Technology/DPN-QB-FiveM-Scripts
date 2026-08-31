local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    Wait(1000)
    exports['dpn-medical-core']:RegisterModule('dpn-medical-ems','14.0.0',{'ems_actions','field_treatment','revive','triage','carry','pcr'})
end)

local function notify(src,msg,kind) TriggerClientEvent('QBCore:Notify',src,msg,kind or 'primary',5000) end
local function authorized(src)
    local p=QBCore.Functions.GetPlayer(src); if not p then return false end
    local j=p.PlayerData.job or {}; return Config.Jobs[j.name] and (not Config.RequireOnDuty or j.onduty~=false)
end
local function near(a,b,max)
    local pa,pb=GetPlayerPed(a),GetPlayerPed(b); if pa<=0 or pb<=0 then return false end
    return #(GetEntityCoords(pa)-GetEntityCoords(pb))<=max
end
local function addRecord(target,kind,data)
    if GetResourceState('dpn-medical-records')=='started' then pcall(function() exports['dpn-medical-records']:AddEntry(target,kind,data) end) end
end
RegisterNetEvent('dpn-medical-ems:server:treat',function(target,treatment,part)
    local src=source; target=tonumber(target)
    if not authorized(src) or not target or not near(src,target,Config.TreatmentDistance) then return notify(src,'Treatment denied.','error') end
    local p=QBCore.Functions.GetPlayer(src); local ok=exports['dpn-medical-core']:TreatPatient(target,part,treatment,p.PlayerData.citizenid)
    if ok then addRecord(target,'ems_treatment',{treatment=treatment,part=part,provider=p.PlayerData.citizenid}); notify(src,'Treatment completed.','success') else notify(src,'Treatment failed.','error') end
end)
RegisterNetEvent('dpn-medical-ems:server:revive',function(target)
    local src=source; target=tonumber(target)
    if not authorized(src) or not target or not near(src,target,Config.ReviveDistance) then return notify(src,'Revive denied.','error') end
    local state=exports['dpn-medical-core']:GetPatientState(target)
    if not state or state.status.lifeState=='alive' then return notify(src,'Patient is not incapacitated.','error') end
    local p=QBCore.Functions.GetPlayer(src)
    for _,t in ipairs(Config.ReviveTreatment) do exports['dpn-medical-core']:TreatPatient(target,nil,t,p.PlayerData.citizenid) end
    local ok=exports['dpn-medical-core']:RevivePatient(target,{fullHeal=false,by=p.PlayerData.citizenid})
    if ok then addRecord(target,'field_revive',{provider=p.PlayerData.citizenid}); notify(src,'Patient revived; injuries remain and require treatment.','success') end
end)
RegisterNetEvent('dpn-medical-ems:server:carry',function(target)
    local src=source; target=tonumber(target)
    if not authorized(src) or not target or not near(src,target,3.0) then return end
    local state=exports['dpn-medical-core']:GetPatientState(target); if not state or state.status.lifeState=='alive' then return end
    local carrying=Player(target).state.dpnMedicalCarrier
    if carrying then Player(target).state:set('dpnMedicalCarrier',nil,true); TriggerClientEvent('dpn-medical-ems:client:setCarried',target,nil)
    else Player(target).state:set('dpnMedicalCarrier',src,true); TriggerClientEvent('dpn-medical-ems:client:setCarried',target,src) end
end)
QBCore.Commands.Add('emstreat','Treat a nearby patient',{{name='id'},{name='treatment'},{name='part'}},true,function(src,args) TriggerEvent('dpn-medical-ems:command:treat',src,args) end)
AddEventHandler('dpn-medical-ems:command:treat',function(src,args)
    local target=tonumber(args[1]); if not authorized(src) or not target or not near(src,target,Config.TreatmentDistance) then return notify(src,'Treatment denied.','error') end
    local p=QBCore.Functions.GetPlayer(src); local ok=exports['dpn-medical-core']:TreatPatient(target,args[3],args[2],p.PlayerData.citizenid)
    notify(src,ok and 'Treatment completed.' or 'Treatment failed.',ok and 'success' or 'error')
end)
QBCore.Commands.Add('emsrevive','Revive a nearby patient',{{name='id'}},true,function(src,args)
    local target=tonumber(args[1]); if not authorized(src) or not target or not near(src,target,Config.ReviveDistance) then return notify(src,'Revive denied.','error') end
    local p=QBCore.Functions.GetPlayer(src); local ok=exports['dpn-medical-core']:RevivePatient(target,{fullHeal=false,by=p.PlayerData.citizenid}); notify(src,ok and 'Patient revived.' or 'Revive failed.',ok and 'success' or 'error')
end)
QBCore.Commands.Add('emstriage','Read patient triage and vitals',{{name='id'}},true,function(src,args)
    local target=tonumber(args[1]); if not authorized(src) or not target or not near(src,target,7.0) then return notify(src,'Unable to inspect patient.','error') end
    local s=exports['dpn-medical-core']:GetPatientState(target); if not s then return end
    local v=s.vitals; TriggerClientEvent('chat:addMessage',src,{args={'DPN EMS',('Triage %s | %s | BP %s/%s HR %s RR %s SpO2 %s Blood %s'):format(s.status.triage,s.status.lifeState,v.systolic,v.diastolic,v.hr,v.rr,v.spo2,v.blood)}})
end)
QBCore.Commands.Add('emscarry','Carry/release an incapacitated patient',{{name='id'}},true,function(src,args)
    local target=tonumber(args[1]); if not authorized(src) or not target or not near(src,target,3.0) then return end
    local carrying=Player(target).state.dpnMedicalCarrier
    if carrying then Player(target).state:set('dpnMedicalCarrier',nil,true); TriggerClientEvent('dpn-medical-ems:client:setCarried',target,nil)
    else Player(target).state:set('dpnMedicalCarrier',src,true); TriggerClientEvent('dpn-medical-ems:client:setCarried',target,src) end
end)


QBCore.Commands.Add('emsduty','Toggle DPN EMS duty status',{},false,function(src)
    local p=QBCore.Functions.GetPlayer(src); if not p then return end
    local j=p.PlayerData.job or {}; if not Config.Jobs[j.name] then return notify(src,'You are not employed by an EMS-authorized job.','error') end
    p.Functions.SetJobDuty(not j.onduty)
    notify(src,('EMS duty %s.'):format(not j.onduty and 'enabled' or 'disabled'),'success')
end)

QBCore.Commands.Add('emspcr','Create a patient care report',{{name='id'},{name='narrative'}},true,function(src,args)
    local target=tonumber(args[1]); if not authorized(src) or not target then return notify(src,'PCR denied.','error') end
    local patient=QBCore.Functions.GetPlayer(target); local provider=QBCore.Functions.GetPlayer(src); if not patient or not provider then return end
    local narrative=table.concat(args,' ',2); if narrative=='' then narrative='Patient assessment and treatment documented.' end
    local state=exports['dpn-medical-core']:GetPatientState(target)
    local report={narrative=narrative,medicalState=state and {vitals=state.vitals,status=state.status} or nil}
    local id=MySQL.insert.await('INSERT INTO dpn_medical_ems_reports (patient_cid,provider_cid,report_data) VALUES (?,?,?)',{patient.PlayerData.citizenid,provider.PlayerData.citizenid,json.encode(report)})
    addRecord(target,'ems_pcr',{reportId=id,narrative=narrative,provider=provider.PlayerData.citizenid})
    notify(src,('PCR #%s submitted.'):format(id),'success')
end)
