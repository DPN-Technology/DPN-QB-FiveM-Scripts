local ADV_RESOURCE = GetCurrentResourceName()
local ADV_VERSION = GetResourceMetadata(ADV_RESOURCE, 'version', 0) or 'unknown'
CreateThread(function()
    Wait(1800)
    pcall(function()
        exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE, ADV_VERSION, {
            'imaging_queue',
            'turnaround',
            'critical_results',
            'contrast_safety',
            'structured_reports'
        })
    end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

local queue={}
exports('QueueStudy',function(src,target,study,part,priority)
 target=tonumber(target); local patient=exports['qb-core']:GetCoreObject().Functions.GetPlayer(target); if not patient or not Config.Costs[study] then return false end
 local id=MySQL.insert.await('INSERT INTO dpn_medical_radiology_queue (patient_cid,study_type,body_part,priority,status,ordered_by) VALUES (?,?,?,?,?,?)',{patient.PlayerData.citizenid,study,part,tonumber(priority) or 3,'queued',tostring(src)})
 queue[id]={id=id,target=target,study=study,part=part,priority=tonumber(priority) or 3,queuedAt=os.time(),status='queued'}; return id
end)
exports('GetQueue',function() local rows={}; for _,v in pairs(queue) do rows[#rows+1]=v end; table.sort(rows,function(a,b) if a.priority==b.priority then return a.queuedAt<b.queuedAt end return a.priority<b.priority end); return rows end)
exports('FinalizeQueuedStudy',function(src,orderId)
 local q=queue[tonumber(orderId)]; if not q then return false,'Order not found' end; local ok,result=exports['dpn-medical-radiology']:OrderStudy(src,q.target,q.study,q.part); if ok then q.status='final'; q.finalAt=os.time(); MySQL.update('UPDATE dpn_medical_radiology_queue SET status=?,finalized_at=NOW(),turnaround_seconds=? WHERE id=?',{'final',q.finalAt-q.queuedAt,orderId}); if result:find('internal bleeding',1,true) or result:find('damage',1,true) then exports['dpn-medical-core']:AddClinicalEvent(q.target,'critical_imaging_result',{orderId=orderId,findings=result},tostring(src)) end; queue[tonumber(orderId)]=nil end; return ok,result
end)

