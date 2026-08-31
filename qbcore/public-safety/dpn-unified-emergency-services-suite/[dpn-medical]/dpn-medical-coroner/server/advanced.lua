local ADV_RESOURCE = GetCurrentResourceName()
local ADV_VERSION = GetResourceMetadata(ADV_RESOURCE, 'version', 0) or 'unknown'
CreateThread(function()
    Wait(1800)
    pcall(function()
        exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE, ADV_VERSION, {
            'scene_exam',
            'evidence_chain',
            'toxicology',
            'cause_manner',
            'body_release'
        })
    end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

exports('CreateEvidenceItem',function(caseId,evidenceType,description,collectedBy)
 local id=MySQL.insert.await('INSERT INTO dpn_medical_coroner_evidence (case_id,evidence_type,description,collected_by,chain_status) VALUES (?,?,?,?,?)',{caseId,evidenceType,description,collectedBy,'secured'}); return id
end)
exports('TransferEvidence',function(evidenceId,toCustodian,reason)
 pcall(function() MySQL.insert('INSERT INTO dpn_medical_coroner_chain (evidence_id,to_custodian,reason) VALUES (?,?,?)',{evidenceId,toCustodian,reason}) end); MySQL.update('UPDATE dpn_medical_coroner_evidence SET current_custodian=?,chain_status=? WHERE id=?',{toCustodian,'transferred',evidenceId}); return true
end)
exports('BuildPostmortemSummary',function(target)
 local state=exports['dpn-medical-core']:GetPatientState(tonumber(target)); if not state then return nil end; local injuries={}; for part,p in pairs(state.body or {}) do if (p.damage or 0)>0 then injuries[#injuries+1]={part=part,damage=p.damage,bleeding=p.bleeding,internal=p.internalBleeding,organs=p.organs} end end; return {cause=state.status.causeOfDeath,time=state.status.diedAt,injuries=injuries,medications=state.medications,conditions=state.conditions,timeline=state.timeline}
end)

