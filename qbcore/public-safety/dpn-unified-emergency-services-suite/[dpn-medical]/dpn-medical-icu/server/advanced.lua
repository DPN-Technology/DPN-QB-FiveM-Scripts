local ADV_RESOURCE = 'dpn-medical-icu'
local ADV_VERSION = '2.0.0'
CreateThread(function()
    Wait(1800)
    pcall(function() exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE,ADV_VERSION,'icu_orders','alarm_engine','ventilation','vasopressors','organ_support') end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

local orders={}
exports('SetICUOrder',function(target,orderId,data)
 target=tonumber(target); orders[target]=orders[target] or {}; orders[target][orderId]=type(data)=='table' and data or {}; orders[target][orderId].updatedAt=os.time(); local p=exports['qb-core']:GetCoreObject().Functions.GetPlayer(target); if p then pcall(function() MySQL.insert('INSERT INTO dpn_medical_icu_orders (patient_cid,order_id,order_data,status) VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE order_data=VALUES(order_data),status=VALUES(status),updated_at=NOW()',{p.PlayerData.citizenid,orderId,json.encode(data or {}),'active'}) end) end; return true
end)
exports('GetICUAlarms',function(target)
 local s=exports['dpn-medical-core']:GetClinicalSnapshot(tonumber(target)); if not s then return {} end; local a={}; if s.map<65 then a[#a+1]={type='low_map',severity='critical',value=s.map} end; if s.spo2<90 then a[#a+1]={type='hypoxia',severity='critical',value=s.spo2} end; if s.lactate>=4 then a[#a+1]={type='lactic_acidosis',severity='high',value=s.lactate} end; if s.gcs<=8 then a[#a+1]={type='airway_risk',severity='critical',value=s.gcs} end; return a
end)

