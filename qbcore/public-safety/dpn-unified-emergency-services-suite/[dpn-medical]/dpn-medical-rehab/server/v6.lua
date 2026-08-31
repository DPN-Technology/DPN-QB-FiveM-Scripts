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

local pathways, sessions = {}, {}
exports('CreateRehabPathway',function(sourceValue,target,pathwayType,goals,baseline) local id=uid('RHB',target);local item={id=id,target=tonumber(target),patientCid=citizen(target),type=pathwayType or'trauma_recovery',goals=goals or{},baseline=tonumber(baseline)or 0,current=tonumber(baseline)or 0,status='active',provider=actor(sourceValue),createdAt=os.time(),milestones={}};pathways[id]=item;asyncInsert('INSERT INTO dpn_medical_v6_rehab_pathways (pathway_id,patient_cid,pathway_type,status,baseline_score,current_score,provider_cid,pathway_data) VALUES (?,?,?,?,?,?,?,?)',{id,item.patientCid,item.type,item.status,item.baseline,item.current,item.provider,encode(item)});return id,item end)
exports('RecordTherapySessionV6',function(sourceValue,pathwayId,interventions,score,pain,notes) local path=pathways[tostring(pathwayId)];if not path then return false end;local item={id=uid('THR',pathwayId),pathwayId=path.id,interventions=interventions or{},score=tonumber(score)or path.current,pain=tonumber(pain)or 0,notes=notes,provider=actor(sourceValue),completedAt=os.time()};path.current=item.score;sessions[path.id]=sessions[path.id]or{};sessions[path.id][#sessions[path.id]+1]=item;asyncInsert('INSERT INTO dpn_medical_v6_rehab_sessions (session_id,pathway_id,provider_cid,functional_score,pain_score,session_data) VALUES (?,?,?,?,?,?)',{item.id,path.id,item.provider,item.score,item.pain,encode(item)});asyncUpdate('UPDATE dpn_medical_v6_rehab_pathways SET current_score=?,pathway_data=?,updated_at=NOW() WHERE pathway_id=?',{path.current,encode(path),path.id});return item.id,item end)
exports('AddRehabMilestone',function(pathwayId,label,targetScore) local path=pathways[tostring(pathwayId)];if not path then return false end;local item={id=uid('MLS',pathwayId),label=label,targetScore=tonumber(targetScore)or 100,completed=false};path.milestones[#path.milestones+1]=item;return item.id,item end)
exports('DischargeRehabPathway',function(sourceValue,pathwayId,outcome) local path=pathways[tostring(pathwayId)];if not path then return false end;path.status='completed';path.outcome=outcome;path.dischargedBy=actor(sourceValue);path.dischargedAt=os.time();asyncUpdate('UPDATE dpn_medical_v6_rehab_pathways SET status=?,current_score=?,pathway_data=?,completed_at=NOW() WHERE pathway_id=?',{path.status,path.current,encode(path),path.id});return true,path end)
exports('GetRehabDashboard',function()return {pathways=pathways,sessions=sessions,generatedAt=os.time()}end)
heartbeat({'rehab_pathways','functional_scoring','therapy_sessions','milestones','discharge_outcomes'})
