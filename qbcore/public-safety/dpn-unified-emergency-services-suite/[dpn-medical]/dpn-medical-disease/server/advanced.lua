local ADV_RESOURCE = 'dpn-medical-disease'
local ADV_VERSION = '2.0.0'
CreateThread(function()
    Wait(1800)
    pcall(function() exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE,ADV_VERSION,'exposure_tracking','isolation','outbreaks','sepsis_bridge','public_health') end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

exports('RecordExposure',function(sourceTarget,exposedTarget,diseaseId,distance,duration)
 local core=exports['qb-core']:GetCoreObject(); local a=core.Functions.GetPlayer(tonumber(sourceTarget)); local b=core.Functions.GetPlayer(tonumber(exposedTarget)); if not a or not b then return false end; local risk=math.min(100,math.floor((tonumber(duration) or 0)/6+math.max(0,5-(tonumber(distance) or 5))*12)); MySQL.insert('INSERT INTO dpn_medical_disease_exposures (source_cid,exposed_cid,disease_id,risk_score,distance,duration_seconds) VALUES (?,?,?,?,?,?)',{a.PlayerData.citizenid,b.PlayerData.citizenid,diseaseId,risk,distance,duration}); if risk>=60 then exports['dpn-medical-core']:AddClinicalEvent(exposedTarget,'disease_exposure',{disease=diseaseId,risk=risk},'disease-system') end; return risk
end)
exports('SetIsolation',function(target,level,reason) return exports['dpn-medical-core']:SetDevice(target,'isolation',{level=level,reason=reason,active=true,startedAt=os.time()}) end)

