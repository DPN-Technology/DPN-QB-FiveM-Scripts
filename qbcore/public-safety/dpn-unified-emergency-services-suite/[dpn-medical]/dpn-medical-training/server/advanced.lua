local ADV_RESOURCE = 'dpn-medical-training'
local ADV_VERSION = '2.0.0'
CreateThread(function()
    Wait(1800)
    pcall(function() exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE,ADV_VERSION,'competency_matrix','scope_validation','continuing_education','skill_decay') end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

exports('ValidateScope',function(target,action)
 local map={aed='acls',surgery='surgery',radiology='radiology',trauma='trauma',advanced_airway='paramedic'}; local cert=map[action]; if not cert then return true end; return exports['dpn-medical-training']:HasCertification(target,cert),cert
end)
exports('RecordCompetency',function(target,skill,score,evaluator)
 local p=exports['qb-core']:GetCoreObject().Functions.GetPlayer(tonumber(target)); if not p then return false end; score=math.max(0,math.min(100,tonumber(score) or 0)); MySQL.insert('INSERT INTO dpn_medical_training_competencies (citizenid,skill,score,evaluated_by) VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE score=VALUES(score),evaluated_by=VALUES(evaluated_by),evaluated_at=NOW()',{p.PlayerData.citizenid,skill,score,evaluator}); return true
end)

