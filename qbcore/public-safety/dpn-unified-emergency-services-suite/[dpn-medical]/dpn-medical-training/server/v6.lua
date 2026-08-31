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

local credentials, scenarios = {}, {}
exports('GrantCredential',function(sourceValue,target,credential,level,expiresAt) local key=citizen(target);if not key then return false end;credentials[key]=credentials[key]or{};local item={credential=credential,level=level or'provider',issuedBy=actor(sourceValue),issuedAt=os.time(),expiresAt=tonumber(expiresAt),status='active'};credentials[key][credential]=item;asyncInsert('INSERT INTO dpn_medical_v6_credentials (patient_cid,credential_code,credential_level,status,issued_by,expires_at,credential_data) VALUES (?,?,?,?,?,FROM_UNIXTIME(?),?) ON DUPLICATE KEY UPDATE credential_level=VALUES(credential_level),status=VALUES(status),issued_by=VALUES(issued_by),expires_at=VALUES(expires_at),credential_data=VALUES(credential_data)',{key,credential,item.level,item.status,item.issuedBy,item.expiresAt,encode(item)});return true,item end)
exports('ValidateCredential',function(target,credential) local key=citizen(target);local item=key and credentials[key]and credentials[key][credential];if not item then return false,'Credential not found'end;if item.status~='active'then return false,'Credential inactive'end;if item.expiresAt and item.expiresAt<os.time()then return false,'Credential expired'end;return true,item end)
exports('CreateTrainingScenario',function(sourceValue,name,objectives,difficulty) local id=uid('SIM',sourceValue);local item={id=id,name=name,objectives=objectives or{},difficulty=tonumber(difficulty)or 1,status='open',instructor=actor(sourceValue),createdAt=os.time(),participants={}};scenarios[id]=item;asyncInsert('INSERT INTO dpn_medical_v6_training_scenarios (scenario_id,name,status,difficulty,instructor_cid,scenario_data) VALUES (?,?,?,?,?,?)',{id,name,item.status,item.difficulty,item.instructor,encode(item)});return id,item end)
exports('ScoreTrainingScenario',function(scenarioId,target,score,feedback,sourceValue) local item=scenarios[tostring(scenarioId)];if not item then return false end;local result={participant=citizen(target),score=tonumber(score)or 0,feedback=feedback,evaluator=actor(sourceValue),completedAt=os.time()};item.participants[target]=result;asyncInsert('INSERT INTO dpn_medical_v6_training_results (scenario_id,participant_cid,score,evaluator_cid,result_data) VALUES (?,?,?,?,?)',{item.id,result.participant,result.score,result.evaluator,encode(result)});return true,result end)
exports('GetCredentialProfile',function(target)return credentials[citizen(target)]or{}end)
heartbeat({'credential_management','scope_validation','simulation_scenarios','competency_scoring','expiration_tracking'})
