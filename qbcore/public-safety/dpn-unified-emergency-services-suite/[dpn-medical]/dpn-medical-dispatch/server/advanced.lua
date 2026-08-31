local ADV_RESOURCE = 'dpn-medical-dispatch'
local ADV_VERSION = '14.0.0'
CreateThread(function()
    Wait(1800)
    pcall(function() exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE,ADV_VERSION,'call_lifecycle','unit_assignment','response_timers','clinical_priority','mutual_aid') end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

local assignments={}
exports('AssignUnit',function(callId,unitId,assignedBy)
 callId=tonumber(callId); if not callId then return false end; assignments[callId]=assignments[callId] or {}; assignments[callId][tostring(unitId)]={assignedAt=os.time(),assignedBy=assignedBy,status='assigned'}
 pcall(function() MySQL.insert('INSERT INTO dpn_medical_dispatch_assignments (call_id,unit_id,assigned_by,status) VALUES (?,?,?,?)',{callId,tostring(unitId),assignedBy,'assigned'}) end); return true
end)
exports('UpdateUnitResponse',function(callId,unitId,status)
 local a=assignments[tonumber(callId)] and assignments[tonumber(callId)][tostring(unitId)]; if not a then return false end; a.status=tostring(status); a.updatedAt=os.time(); pcall(function() MySQL.update('UPDATE dpn_medical_dispatch_assignments SET status=?,updated_at=NOW() WHERE call_id=? AND unit_id=?',{a.status,callId,tostring(unitId)}) end); return true
end)
exports('CalculateClinicalPriority',function(snapshot)
 snapshot=type(snapshot)=='table' and snapshot or {}; if snapshot.cardiacArrest or snapshot.risk=='critical' then return 1 end; if snapshot.risk=='high' or snapshot.triage=='red' then return 2 end; if snapshot.risk=='moderate' then return 3 end; return 4
end)

