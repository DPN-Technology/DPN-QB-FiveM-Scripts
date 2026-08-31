local ADV_RESOURCE = 'dpn-medical-ems'
local ADV_VERSION = '14.0.0'
CreateThread(function()
    Wait(1800)
    pcall(function() exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE,ADV_VERSION,'advanced_assessment','protocols','care_episodes','handoff','response_metrics') end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

local QBCoreAdv=exports['qb-core']:GetCoreObject()
local encounters={}
local function provider(src) local p=QBCoreAdv.Functions.GetPlayer(tonumber(src)); return p and p.PlayerData.citizenid end
local function startEncounter(src,target,mechanism)
 target=tonumber(target); if not target then return false end
 local episodeId=exports['dpn-medical-core']:CreateCareEpisode(target,'prehospital',{openedBy=provider(src),source='ems',mechanism=mechanism})
 local snapshot=exports['dpn-medical-core']:GetClinicalSnapshot(target); if not snapshot then return false end
 encounters[target]={episodeId=episodeId,provider=provider(src),startedAt=os.time(),mechanism=mechanism or 'unknown',assessments={},interventions={}}
 exports['dpn-medical-core']:AddCarePlanTask(target,{label='Complete primary survey (ABCDE)',priority=1,assignedTo=provider(src)})
 exports['dpn-medical-core']:AddCarePlanTask(target,{label='Repeat vital signs and trend deterioration score',priority=1,assignedTo=provider(src)})
 pcall(function() MySQL.insert('INSERT INTO dpn_medical_ems_encounters (episode_id,patient_cid,provider_cid,mechanism,status,initial_snapshot) VALUES (?,?,?,?,?,?)',{episodeId,QBCoreAdv.Functions.GetPlayer(target).PlayerData.citizenid,provider(src),mechanism or 'unknown','active',json.encode(snapshot)}) end)
 return episodeId,snapshot
end
exports('StartEncounter',startEncounter)
exports('GetEncounter',function(target) return encounters[tonumber(target)] end)
exports('RecordAssessment',function(src,target,assessment)
 target=tonumber(target); local e=encounters[target]; if not e then return false end; assessment=type(assessment)=='table' and assessment or {}; assessment.time=os.time(); assessment.by=provider(src); e.assessments[#e.assessments+1]=assessment
 exports['dpn-medical-core']:AddClinicalEvent(target,'ems_assessment',assessment,provider(src)); return true
end)
exports('CompleteHandoff',function(src,target,destination,narrative)
 target=tonumber(target); local e=encounters[target]; if not e then return false end
 local snapshot=exports['dpn-medical-core']:GetClinicalSnapshot(target); local duration=os.time()-e.startedAt
 exports['dpn-medical-core']:AddClinicalEvent(target,'ems_handoff',{destination=destination,narrative=narrative,durationSeconds=duration,finalSnapshot=snapshot},provider(src))
 exports['dpn-medical-core']:CloseCareEpisode(target,'hospital_handoff',{destination=destination,durationSeconds=duration})
 pcall(function() MySQL.update('UPDATE dpn_medical_ems_encounters SET status=?,destination=?,handoff_at=NOW(),final_snapshot=? WHERE episode_id=?',{'completed',destination,json.encode(snapshot),e.episodeId}) end)
 encounters[target]=nil; return true
end)
QBCoreAdv.Commands.Add('emsassess','Start advanced EMS assessment',{{name='id'},{name='mechanism'}},true,function(src,args)
 local id,snapshot=startEncounter(src,args[1],table.concat(args,' ',2)); TriggerClientEvent('QBCore:Notify',src,id and ('Encounter '..id..' started; risk '..snapshot.risk) or 'Unable to start encounter.',id and 'success' or 'error')
end)
QBCoreAdv.Commands.Add('emshandoff','Complete EMS hospital handoff',{{name='id'},{name='destination'},{name='narrative'}},true,function(src,args)
 local ok=exports['dpn-medical-ems']:CompleteHandoff(src,args[1],args[2],table.concat(args,' ',3)); TriggerClientEvent('QBCore:Notify',src,ok and 'Handoff completed.' or 'No active encounter.',ok and 'success' or 'error')
end)

