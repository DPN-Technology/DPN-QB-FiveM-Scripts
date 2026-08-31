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

local outbreaks, isolationAudits = {}, {}
exports('OpenOutbreak',function(sourceValue,diseaseId,location,threshold) local id=uid('OUT',sourceValue);local item={id=id,diseaseId=diseaseId,location=location,status='investigating',threshold=tonumber(threshold)or 3,cases={},openedBy=actor(sourceValue),openedAt=os.time()};outbreaks[id]=item;asyncInsert('INSERT INTO dpn_medical_v6_outbreaks (outbreak_id,disease_id,status,location_name,opened_by,outbreak_data) VALUES (?,?,?,?,?,?)',{id,diseaseId,item.status,tostring(location),item.openedBy,encode(item)});return id,item end)
exports('AddOutbreakCase',function(outbreakId,target,classification,sourceValue) local item=outbreaks[tostring(outbreakId)];if not item then return false end;local case={patientCid=citizen(target),target=tonumber(target),classification=classification or'suspected',reportedBy=actor(sourceValue),reportedAt=os.time()};item.cases[target]=case;asyncInsert('INSERT INTO dpn_medical_v6_outbreak_cases (outbreak_id,patient_cid,classification,reported_by,case_data) VALUES (?,?,?,?,?)',{item.id,case.patientCid,case.classification,case.reportedBy,encode(case)});if type(location)=='string'then end;return true,case end)
exports('AuditIsolationCompliance',function(sourceValue,target,compliant,ppe,notes) local item={id=uid('ISO',target),target=tonumber(target),patientCid=citizen(target),compliant=compliant==true,ppe=ppe or{},notes=notes,auditor=actor(sourceValue),auditedAt=os.time()};isolationAudits[item.id]=item;asyncInsert('INSERT INTO dpn_medical_v6_isolation_audits (audit_id,patient_cid,compliant,auditor_cid,audit_data) VALUES (?,?,?,?,?)',{item.id,item.patientCid,item.compliant,item.auditor,encode(item)});if not item.compliant then core('RaiseSafetyAlert',target,'isolation_noncompliance','high','Isolation precautions are not being followed.',item,RESOURCE)end;return item.id,item end)
exports('GetOutbreakDashboard',function()local active=0;for _,item in pairs(outbreaks)do if item.status~='closed'then active=active+1 end end;return {active=active,outbreaks=outbreaks,isolationAudits=isolationAudits,generatedAt=os.time()}end)
heartbeat({'outbreak_surveillance','case_classification','isolation_compliance','exposure_tracking','public_health_alerting'})
