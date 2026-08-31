local ADV_RESOURCE = GetCurrentResourceName()
local ADV_VERSION = GetResourceMetadata(ADV_RESOURCE, 'version', 0) or 'unknown'
CreateThread(function()
    Wait(1800)
    pcall(function()
        exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE, ADV_VERSION, {
            'or_cases',
            'surgical_safety_checklist',
            'anesthesia_risk',
            'complications',
            'postop_orders'
        })
    end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

local QBCoreAdv=exports['qb-core']:GetCoreObject(); local cases={}
exports('CreateSurgicalCase',function(src,target,procedureId,part)
 target=tonumber(target); local proc=Config.Procedures[procedureId]; local patient=QBCoreAdv.Functions.GetPlayer(target); local provider=QBCoreAdv.Functions.GetPlayer(tonumber(src)); if not proc or not patient or not provider then return false,'Invalid case' end
 local snapshot=exports['dpn-medical-core']:GetClinicalSnapshot(target); local safety={identity=true,procedure=procedureId,site=part or proc.part,allergies=(exports['dpn-medical-core']:GetPatientState(target).profile or {}).allergies,bloodAvailable=snapshot.blood<3500,airwayRisk=snapshot.gcs<9,anesthesiaRisk=snapshot.risk}
 local id=MySQL.insert.await('INSERT INTO dpn_medical_surgery_cases (patient_cid,surgeon_cid,procedure_id,body_part,status,safety_checklist,risk_snapshot) VALUES (?,?,?,?,?,?,?)',{patient.PlayerData.citizenid,provider.PlayerData.citizenid,procedureId,part or proc.part,'planned',json.encode(safety),json.encode(snapshot)})
 cases[id]={id=id,target=target,procedure=procedureId,part=part or proc.part,status='planned',safety=safety}; exports['dpn-medical-core']:AddClinicalEvent(target,'surgery_case_planned',{caseId=id,procedure=procedureId,safety=safety},provider.PlayerData.citizenid); return id,safety
end)
exports('AdvanceSurgicalCase',function(caseId,stage,data)
 local c=cases[tonumber(caseId)]; if not c then return false end; local allowed={planned=true,preop=true,anesthesia=true,incision=true,repair=true,closure=true,recovery=true,completed=true,cancelled=true}; if not allowed[stage] then return false end; c.status=stage; c.updatedAt=os.time(); pcall(function() MySQL.update('UPDATE dpn_medical_surgery_cases SET status=?,stage_data=?,updated_at=NOW() WHERE id=?',{stage,json.encode(data or {}),caseId}) end); exports['dpn-medical-core']:AddProcedure(c.target,{id='surgery_case_'..caseId,type=c.procedure,bodyPart=c.part,outcome=stage,metadata=data or {}}); return true
end)
exports('CalculateComplicationRisk',function(target)
 local s=exports['dpn-medical-core']:GetClinicalSnapshot(tonumber(target)); if not s then return nil end; local risk=math.floor(math.min(100,s.deterioration*0.55+(s.lactate or 1)*6+(s.blood<3000 and 20 or 0))); return {score=risk,level=risk>=70 and 'very_high' or risk>=45 and 'high' or risk>=25 and 'moderate' or 'low'}
end)

