local ADV_RESOURCE = GetCurrentResourceName()
local ADV_VERSION = GetResourceMetadata(ADV_RESOURCE, 'version', 0) or 'unknown'
CreateThread(function()
    Wait(1800)
    pcall(function()
        exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE, ADV_VERSION, {
            'unified_chart',
            'access_audit',
            'problem_list',
            'allergies',
            'care_timeline'
        })
    end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

exports('GetUnifiedChart',function(target,limit)
 local state=exports['dpn-medical-core']:GetPatientState(tonumber(target)); local records=exports['dpn-medical-records']:GetRecords(target,limit or 50); if not state then return nil end
 return {profile=state.profile,vitals=state.vitals,status=state.status,advanced=state.advanced,conditions=state.conditions,medications=state.medications,diagnostics=state.diagnostics,procedures=state.procedures,carePlan=state.carePlan,timeline=state.timeline,records=records}
end)
exports('AuditChartAccess',function(viewer,target,purpose)
 local vp=exports['qb-core']:GetCoreObject().Functions.GetPlayer(tonumber(viewer)); local tp=exports['qb-core']:GetCoreObject().Functions.GetPlayer(tonumber(target)); if not vp or not tp then return false end
 pcall(function() MySQL.insert('INSERT INTO dpn_medical_record_access (viewer_cid,patient_cid,purpose) VALUES (?,?,?)',{vp.PlayerData.citizenid,tp.PlayerData.citizenid,tostring(purpose or 'clinical')}) end); return true
end)

