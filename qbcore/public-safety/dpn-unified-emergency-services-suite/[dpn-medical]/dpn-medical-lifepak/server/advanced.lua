local ADV_RESOURCE = 'dpn-medical-lifepak'
local ADV_VERSION = '2.0.0'
CreateThread(function()
    Wait(1800)
    pcall(function() exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE,ADV_VERSION,'rhythm_analysis','trend_storage','pacing','cardioversion','code_summary') end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

exports('AnalyzeRhythm',function(target)
 local s=exports['dpn-medical-core']:GetPatientState(tonumber(target)); if not s then return nil end; local rhythm=(s.circulation and s.circulation.rhythm) or 'unknown'; local shockable=s.status.cardiacArrest and rhythm~='asystole'; return {rhythm=rhythm,shockable=shockable,hr=s.vitals.hr,etco2=s.vitals.etco2,spo2=s.vitals.spo2}
end)
exports('StoreTrend',function(target,deviceId)
 local p=exports['qb-core']:GetCoreObject().Functions.GetPlayer(tonumber(target)); local s=exports['dpn-medical-core']:GetClinicalSnapshot(tonumber(target)); if not p or not s then return false end; MySQL.insert('INSERT INTO dpn_medical_lifepak_trends (patient_cid,device_id,snapshot) VALUES (?,?,?)',{p.PlayerData.citizenid,deviceId,json.encode(s)}); return true
end)
exports('TranscutaneousPace',function(target,rate) local state=exports['dpn-medical-core']:GetPatientState(tonumber(target)); if not state or state.vitals.hr>=50 then return false end; exports['dpn-medical-core']:SetFlag(target,'pacedRate',tonumber(rate) or 70); exports['dpn-medical-core']:AddClinicalEvent(target,'transcutaneous_pacing',{rate=rate},'lifepak'); return true end)

