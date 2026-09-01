local ADV_RESOURCE = GetCurrentResourceName()
local ADV_VERSION = GetResourceMetadata(ADV_RESOURCE, 'version', 0) or 'unknown'
CreateThread(function()
    Wait(1800)
    pcall(function()
        exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE, ADV_VERSION, {
            'unit_status',
            'fleet_readiness',
            'loadouts',
            'mileage',
            'maintenance'
        })
    end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

local units={}
exports('RegisterUnit',function(unitId,data) unitId=tostring(unitId); units[unitId]=type(data)=='table' and data or {}; units[unitId].status=units[unitId].status or 'available'; units[unitId].updatedAt=os.time(); return true end)
exports('SetUnitStatus',function(unitId,status,location) unitId=tostring(unitId); units[unitId]=units[unitId] or {}; units[unitId].status=tostring(status); units[unitId].location=location; units[unitId].updatedAt=os.time(); pcall(function() MySQL.insert('INSERT INTO dpn_medical_ambulance_units (unit_id,status,location_data,last_seen) VALUES (?,?,?,NOW()) ON DUPLICATE KEY UPDATE status=VALUES(status),location_data=VALUES(location_data),last_seen=NOW()',{unitId,status,json.encode(location or {})}) end); return true end)
exports('GetUnits',function() return units end)
exports('GetAvailableUnits',function() local out={}; for id,u in pairs(units) do if u.status=='available' then out[id]=u end end return out end)

