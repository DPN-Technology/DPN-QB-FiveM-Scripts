local ADV_RESOURCE = GetCurrentResourceName()
local ADV_VERSION = GetResourceMetadata(ADV_RESOURCE, 'version', 0) or 'unknown'
CreateThread(function()
    Wait(1800)
    pcall(function()
        exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE, ADV_VERSION, {
            'functional_goals',
            'outcome_scores',
            'multidisciplinary_rehab',
            'home_programs'
        })
    end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

exports('CreateGoal',function(target,bodyPart,label,targetScore)
 local p=exports['qb-core']:GetCoreObject().Functions.GetPlayer(tonumber(target)); if not p then return false end; local id=MySQL.insert.await('INSERT INTO dpn_medical_rehab_goals (patient_cid,body_part,goal_label,target_score,current_score,status) VALUES (?,?,?,?,?,?)',{p.PlayerData.citizenid,bodyPart,label,targetScore,0,'active'}); exports['dpn-medical-core']:AddCarePlanTask(target,{id='rehab_goal_'..id,label=label,priority=3,metadata={bodyPart=bodyPart,targetScore=targetScore}}); return id
end)
exports('UpdateGoalProgress',function(goalId,score,notes) score=math.max(0,math.min(100,tonumber(score) or 0)); MySQL.update('UPDATE dpn_medical_rehab_goals SET current_score=?,notes=?,status=IF(? >= target_score,?,status),updated_at=NOW() WHERE id=?',{score,notes,score,'completed',goalId}); return true end)

