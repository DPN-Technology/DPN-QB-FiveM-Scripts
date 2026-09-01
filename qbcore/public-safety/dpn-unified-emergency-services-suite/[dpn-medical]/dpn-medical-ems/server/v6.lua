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

local incidents = {}
local destinationLoad = {}

local function triage(target)
    local ok,twin=core('GetDigitalTwin',target); if not ok or type(twin)~='table' then return 'unknown','No digital twin available' end
    if twin.lifeState=='dead' or (twin.vitals and twin.vitals.hr or 0)<=0 then return 'black','No signs of life' end
    local rr=tonumber(twin.vitals.rr) or 0; local map=tonumber(twin.advanced.map) or 0; local gcs=tonumber(twin.neuro.gcs) or 15
    if rr>30 or rr<8 or map<65 or gcs<13 then return 'red','Immediate life threat' end
    if twin.v6 and twin.v6.sofa>=4 then return 'yellow','Delayed but significant injury' end
    return 'green','Minor/ambulatory'
end

exports('CreateMCI',function(sourceValue,label,location,level)
    local id=uid('MCI',sourceValue); local incident={id=id,label=tostring(label or 'Mass casualty incident'),location=location or {},level=tonumber(level) or 1,status='active',commander=actor(sourceValue),createdAt=os.time(),victims={},units={},destinations={}}
    incidents[id]=incident; asyncInsert('INSERT INTO dpn_medical_v6_mci_incidents (incident_id,label,status,level,commander_cid,location_data,incident_data) VALUES (?,?,?,?,?,?,?)',{id,incident.label,incident.status,incident.level,incident.commander,encode(location),encode(incident)})
    TriggerEvent('dpn-medical:v6:mciChanged',incident); return id,incident
end)
exports('TriageMCIPatient',function(incidentId,target,tag,notes,provider)
    local incident=incidents[tostring(incidentId)]; if not incident then return false,'Incident not found' end
    local recommended,reason=triage(target); tag=tostring(tag or recommended):lower(); local valid={red=true,yellow=true,green=true,black=true}; if not valid[tag] then return false,'Invalid triage tag' end
    local victim={target=tonumber(target),citizenid=citizen(target),tag=tag,recommended=recommended,reason=reason,notes=notes,provider=actor(provider),triagedAt=os.time()}; incident.victims[tonumber(target)]=victim
    core('AddClinicalEvent',target,'mci_triage',victim,actor(provider)); asyncInsert('INSERT INTO dpn_medical_v6_mci_victims (incident_id,patient_cid,triage_tag,status,triage_data) VALUES (?,?,?,?,?)',{incident.id,victim.citizenid,tag,'triaged',encode(victim)})
    return true,victim
end)
exports('AssignMCIUnit',function(incidentId,unitId,role)
    local incident=incidents[tostring(incidentId)]; if not incident then return false end; incident.units[tostring(unitId)]={role=role or 'transport',assignedAt=os.time()}; return true
end)
exports('SetDestinationLoad',function(destination,capacity,occupied,diversion)
    destinationLoad[tostring(destination)]={capacity=tonumber(capacity) or 0,occupied=tonumber(occupied) or 0,diversion=diversion==true,updatedAt=os.time()}; return true
end)
exports('RecommendDestination',function(target)
    local ok,twin=core('GetDigitalTwin',target); local desired=ok and twin and twin.v6 and twin.v6.disposition or 'emergency_department'; local best,bestSpace
    for name,data in pairs(destinationLoad) do local space=(data.capacity or 0)-(data.occupied or 0); if not data.diversion and (not bestSpace or space>bestSpace) then best,bestSpace=name,space end end
    return best or 'pillbox',desired,bestSpace or 0
end)
exports('BuildPrehospitalHandoff',function(provider,target,destination,narrative)
    local _,encounter=core('CreateStructuredHandoff',target,destination,{situation=narrative,metadata={phase='prehospital',provider=actor(provider)}},provider); return encounter
end)
exports('GetMCI',function(id)return incidents[tostring(id)]end)
exports('GetActiveMCIs',function()local out={};for _,v in pairs(incidents)do if v.status=='active'then out[#out+1]=v end end;return out end)
exports('CloseMCI',function(id,sourceValue) local incident=incidents[tostring(id)];if not incident then return false end;incident.status='closed';incident.closedAt=os.time();incident.closedBy=actor(sourceValue);asyncUpdate('UPDATE dpn_medical_v6_mci_incidents SET status=?,closed_at=NOW(),incident_data=? WHERE incident_id=?',{'closed',encode(incident),incident.id});return true end)
QBCore.Commands.Add('mci','Create a DPN medical MCI',{{name='label'}},false,function(src,args)local id=exports['dpn-medical-ems']:CreateMCI(src,table.concat(args,' '),{},1);TriggerClientEvent('QBCore:Notify',src,'MCI created: '..tostring(id),'success')end)
QBCore.Commands.Add('mcitriage','Triage a patient in an MCI',{{name='incident'},{name='id'},{name='tag'}},true,function(src,args)local ok,msg=exports['dpn-medical-ems']:TriageMCIPatient(args[1],tonumber(args[2]),args[3],nil,src);TriggerClientEvent('QBCore:Notify',src,ok and 'MCI triage recorded.' or tostring(msg),ok and 'success' or 'error')end)
