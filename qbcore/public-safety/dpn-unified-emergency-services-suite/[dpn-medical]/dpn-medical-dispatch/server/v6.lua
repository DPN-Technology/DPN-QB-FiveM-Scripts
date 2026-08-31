local VERSION = '4.0.0'
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

local cad, unitStatus = {}, {}
exports('CreateCADIncident',function(sourceValue,data)
    data=type(data)=='table'and data or{};local id=uid('CAD',sourceValue);local item={id=id,type=data.type or'medical',priority=tonumber(data.priority)or 3,status='pending',location=data.location or{},caller=data.caller,patient=data.patient,notes=data.notes or{},createdBy=actor(sourceValue),createdAt=os.time(),units={},timeline={}};cad[id]=item;asyncInsert('INSERT INTO dpn_medical_v6_cad_incidents (incident_id,incident_type,priority,status,created_by,location_data,incident_data) VALUES (?,?,?,?,?,?,?)',{id,item.type,item.priority,item.status,item.createdBy,encode(item.location),encode(item)});TriggerEvent('dpn-medical:v6:cadChanged',item);return id,item
end)
exports('AssignCADUnit',function(incidentId,unitId,sourceValue) local item=cad[tostring(incidentId)];if not item then return false end;item.units[tostring(unitId)]={status='assigned',assignedBy=actor(sourceValue),assignedAt=os.time()};item.timeline[#item.timeline+1]={event='unit_assigned',unit=unitId,at=os.time()};return true,item end)
exports('SetCADUnitStatus',function(unitId,status,location,sourceValue) unitStatus[tostring(unitId)]={status=status,location=location or{},updatedBy=actor(sourceValue),updatedAt=os.time()};asyncInsert('INSERT INTO dpn_medical_v6_cad_units (unit_id,status,location_data,updated_by) VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE status=VALUES(status),location_data=VALUES(location_data),updated_by=VALUES(updated_by),updated_at=NOW()',{tostring(unitId),status,encode(location),unitStatus[tostring(unitId)].updatedBy});return true end)
exports('UpdateCADIncident',function(incidentId,status,note,sourceValue) local item=cad[tostring(incidentId)];if not item then return false end;item.status=status or item.status;item.timeline[#item.timeline+1]={event='status',status=item.status,note=note,actor=actor(sourceValue),at=os.time()};asyncUpdate('UPDATE dpn_medical_v6_cad_incidents SET status=?,incident_data=?,updated_at=NOW(),closed_at=IF(?=\'closed\',NOW(),closed_at) WHERE incident_id=?',{item.status,encode(item),item.status,item.id});return true,item end)
exports('GetCADBoard',function()local pending,active=0,0;for _,item in pairs(cad)do if item.status=='pending'then pending=pending+1 elseif item.status~='closed'then active=active+1 end end;return {incidents=cad,units=unitStatus,pending=pending,active=active,generatedAt=os.time()}end)
heartbeat({'cad_incidents','unit_status','unit_assignment','response_timeline','mci_linkage','clinical_priority'})
