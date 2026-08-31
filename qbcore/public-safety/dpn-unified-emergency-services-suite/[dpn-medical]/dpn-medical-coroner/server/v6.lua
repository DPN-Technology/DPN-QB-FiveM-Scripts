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

local cases, certificates = {}, {}
exports('OpenCoronerCaseV6',function(sourceValue,target,sceneData) local id=uid('COR',target);local item={id=id,target=tonumber(target),patientCid=citizen(target),status='open',investigator=actor(sourceValue),openedAt=os.time(),scene=sceneData or{},autopsy={status='not_started',steps={},findings={}},evidence={},release={}};cases[id]=item;asyncInsert('INSERT INTO dpn_medical_v6_coroner_cases (case_id,patient_cid,status,investigator_cid,case_data) VALUES (?,?,?,?,?)',{id,item.patientCid,item.status,item.investigator,encode(item)});return id,item end)
exports('RecordAutopsyStep',function(caseId,step,findings,sourceValue) local item=cases[tostring(caseId)];if not item then return false end;local event={step=step,findings=findings or{},pathologist=actor(sourceValue),at=os.time()};item.autopsy.status='in_progress';item.autopsy.steps[#item.autopsy.steps+1]=event;asyncInsert('INSERT INTO dpn_medical_v6_autopsy_steps (case_id,step_name,pathologist_cid,findings_data) VALUES (?,?,?,?)',{item.id,step,event.pathologist,encode(findings)});return true,event end)
exports('IssueDeathCertificate',function(caseId,cause,manner,contributing,sourceValue) local item=cases[tostring(caseId)];if not item then return false end;local cert={id=uid('DC',caseId),caseId=item.id,patientCid=item.patientCid,cause=cause,manner=manner or'undetermined',contributing=contributing or{},certifier=actor(sourceValue),issuedAt=os.time(),status='issued'};certificates[cert.id]=cert;item.status='certified';asyncInsert('INSERT INTO dpn_medical_v6_death_certificates (certificate_id,case_id,patient_cid,cause_of_death,manner_of_death,certifier_cid,certificate_data) VALUES (?,?,?,?,?,?,?)',{cert.id,cert.caseId,cert.patientCid,cert.cause,cert.manner,cert.certifier,encode(cert)});return cert.id,cert end)
exports('AuthorizeBodyRelease',function(caseId,destination,recipient,sourceValue) local item=cases[tostring(caseId)];if not item then return false end;item.release={destination=destination,recipient=recipient,authorizedBy=actor(sourceValue),authorizedAt=os.time()};item.status='released';asyncUpdate('UPDATE dpn_medical_v6_coroner_cases SET status=?,case_data=?,closed_at=NOW() WHERE case_id=?',{item.status,encode(item),item.id});return true,item.release end)
exports('GetCoronerBoard',function()return {cases=cases,certificates=certificates,generatedAt=os.time()}end)
heartbeat({'medicolegal_case_management','autopsy_workflow','death_certification','body_release','evidence_chain_of_custody'})
