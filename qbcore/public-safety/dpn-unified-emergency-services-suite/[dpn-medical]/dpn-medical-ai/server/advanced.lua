local ADV_RESOURCE = GetCurrentResourceName()
local ADV_VERSION = GetResourceMetadata(ADV_RESOURCE, 'version', 0) or 'unknown'
CreateThread(function()
    Wait(1800)
    pcall(function()
        exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE, ADV_VERSION, {
            'explainable_ai',
            'risk_trends',
            'protocol_compliance',
            'disposition_prediction'
        })
    end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

local trend={}
exports('AdvancedAssessment',function(target)
 target=tonumber(target); local snapshot=exports['dpn-medical-core']:GetClinicalSnapshot(target); if not snapshot then return nil end
 local protocols=exports['dpn-medical-core']:GetProtocolRecommendations(target); local explanation={}
 if snapshot.shockIndex>=1 then explanation[#explanation+1]=('Shock index %.2f is elevated'):format(snapshot.shockIndex) end
 if snapshot.map<65 then explanation[#explanation+1]=('MAP %s indicates poor perfusion'):format(snapshot.map) end
 if snapshot.news>=7 then explanation[#explanation+1]=('NEWS score %s predicts significant deterioration'):format(snapshot.news) end
 if snapshot.qsofa>=2 then explanation[#explanation+1]=('qSOFA %s indicates sepsis risk'):format(snapshot.qsofa) end
 local previous=trend[target]; trend[target]={score=snapshot.deterioration,time=os.time()}; local delta=previous and snapshot.deterioration-previous.score or 0
 local disposition=snapshot.recommendedCare; pcall(function() MySQL.insert('INSERT INTO dpn_medical_ai_alerts (patient_id,risk_score,risk_level,trend_delta,recommendation,explanation) VALUES (?,?,?,?,?,?)',{target,snapshot.deterioration,snapshot.risk,delta,disposition,json.encode(explanation)}) end)
 return {snapshot=snapshot,protocols=protocols,explanation=explanation,trendDelta=delta,disposition=disposition,confidence=math.min(99,65+math.floor(snapshot.deterioration/3))}
end)

