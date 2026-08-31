local VERSION = '3.0.0'
local RESOURCE = GetCurrentResourceName()
local QBCore = exports['qb-core']:GetCoreObject()
local function encode(value) local ok,result=pcall(json.encode,value or {}); return ok and result or '{}' end
local function targetPlayer(target) return QBCore.Functions.GetPlayer(tonumber(target)) end
local function citizen(target) local p=targetPlayer(target); return p and p.PlayerData and p.PlayerData.citizenid or nil end
local function actor(sourceValue) if type(sourceValue)=='string' then return sourceValue:sub(1,64) end; local p=targetPlayer(sourceValue); return p and p.PlayerData and p.PlayerData.citizenid or ('source:%s'):format(tostring(sourceValue or 'system')) end
local function uid(prefix,target) return ('%s-%s-%s-%04d'):format(prefix,os.date('%Y%m%d%H%M%S'),tostring(target or 0),math.random(0,9999)) end
local function asyncInsert(query,params) CreateThread(function() pcall(function() MySQL.insert.await(query,params) end) end) end
local function asyncUpdate(query,params) CreateThread(function() pcall(function() MySQL.update.await(query,params) end) end) end
local function core(method,...)
    local args=table.pack(...)
    local ok,a,b,c=pcall(function() local proxy=exports['dpn-medical-core']; local fn=proxy and proxy[method]; if type(fn)~='function' then error('missing core export '..tostring(method)) end; return fn(proxy,table.unpack(args,1,args.n)) end)
    if not ok then return false,nil,tostring(a) end
    return true,a,b,c
end
local function heartbeat(capabilities)
    CreateThread(function()
        Wait(2500)
        pcall(function() exports['dpn-medical-core']:RegisterModule(RESOURCE,VERSION,capabilities) end)
        while true do Wait(60000); TriggerEvent('dpn-medical-core:server:moduleHeartbeat',RESOURCE,VERSION,{online=true,time=os.time()}) end
    end)
end

local inspections, maintenance, crews = {}, {}, {}
exports('CompletePreTripInspection',function(sourceValue,unitId,checklist,mileage,fuel) local id=uid('CHK',unitId);local failed={};for name,value in pairs(checklist or{})do if value~=true then failed[#failed+1]=name end end;local item={id=id,unitId=tostring(unitId),checklist=checklist or{},failed=failed,mileage=tonumber(mileage)or 0,fuel=tonumber(fuel)or 100,status=#failed==0 and'passed'or'failed',inspector=actor(sourceValue),completedAt=os.time()};inspections[unitId]=item;asyncInsert('INSERT INTO dpn_medical_v6_ambulance_inspections (inspection_id,unit_id,status,inspector_cid,mileage,fuel_level,inspection_data) VALUES (?,?,?,?,?,?,?)',{id,item.unitId,item.status,item.inspector,item.mileage,item.fuel,encode(item)});if #failed>0 then maintenance[unitId]={status='out_of_service',reason='Failed pre-trip inspection',issues=failed,updatedAt=os.time()}end;return id,item end)
exports('SetAmbulanceMaintenance',function(sourceValue,unitId,status,reason,odometer,nextService) local item={unitId=tostring(unitId),status=status,reason=reason,odometer=tonumber(odometer)or 0,nextService=tonumber(nextService),updatedBy=actor(sourceValue),updatedAt=os.time()};maintenance[unitId]=item;asyncInsert('INSERT INTO dpn_medical_v6_ambulance_maintenance (unit_id,status,reason,odometer,next_service,updated_by,maintenance_data) VALUES (?,?,?,?,FROM_UNIXTIME(?),?,?) ON DUPLICATE KEY UPDATE status=VALUES(status),reason=VALUES(reason),odometer=VALUES(odometer),next_service=VALUES(next_service),updated_by=VALUES(updated_by),maintenance_data=VALUES(maintenance_data),updated_at=NOW()',{item.unitId,status,reason,item.odometer,item.nextService,item.updatedBy,encode(item)});return true,item end)
exports('AssignAmbulanceCrew',function(unitId,primary,partner,shiftEnd) local item={unitId=tostring(unitId),primary=actor(primary),partner=actor(partner),shiftEnd=tonumber(shiftEnd),assignedAt=os.time()};crews[unitId]=item;return true,item end)
exports('GetFleetReadiness',function() local units={};local ready,out=0,0;local ok,current=pcall(function()return exports['dpn-medical-ambulance']:GetUnits()end);for id,data in pairs(ok and current or{})do local m=maintenance[id];local inspection=inspections[id];local isReady=not m or(m.status~='out_of_service'and m.status~='maintenance');if inspection and inspection.status=='failed'then isReady=false end;units[id]={unit=data,maintenance=m,inspection=inspection,crew=crews[id],ready=isReady};if isReady then ready=ready+1 else out=out+1 end end;return {ready=ready,outOfService=out,units=units,generatedAt=os.time()}end)
heartbeat({'pretrip_inspections','fleet_maintenance','crew_assignment','equipment_readiness','fuel_and_mileage_tracking'})
