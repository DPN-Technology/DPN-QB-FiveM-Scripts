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

local predictions = {}
local metrics={runs=0,critical=0,acknowledged=0,falsePositives=0}
exports('PredictDeteriorationV6',function(target,horizonMinutes)
    local ok,twin=core('GetDigitalTwin',target);if not ok or not twin then return false,'Patient unavailable'end;horizonMinutes=tonumber(horizonMinutes)or 30
    local base=tonumber(twin.advanced.deterioration)or 0;local sofa=tonumber(twin.v6.sofa)or 0;local trend=0;local _,obs=core('GetObservationTrend',target,nil,20);for _,item in ipairs(obs or{})do if item.type=='oxygen_saturation'and tonumber(item.value)and tonumber(item.value)<92 then trend=trend+2 elseif item.type=='systolic'and tonumber(item.value)and tonumber(item.value)<90 then trend=trend+3 end end
    local probability=math.max(0,math.min(99,math.floor(base*0.65+sofa*3+trend+horizonMinutes*0.05)));local risk=probability>=75 and'critical'or(probability>=50 and'high'or(probability>=25 and'moderate'or'low'));local reasons={('Current deterioration score: %s'):format(base),('SOFA: %s'):format(sofa),('Observed trend burden: %s'):format(trend)};local id=uid('AIP',target);local item={id=id,target=tonumber(target),patientCid=citizen(target),horizonMinutes=horizonMinutes,probability=probability,risk=risk,reasons=reasons,recommended=twin.recommendedOrders or{},advisoryOnly=true,createdAt=os.time(),acknowledged=false};predictions[id]=item;metrics.runs=metrics.runs+1;if risk=='critical'then metrics.critical=metrics.critical+1;core('RaiseSafetyAlert',target,'ai_deterioration_prediction','high','Clinical decision support predicts deterioration.',item,RESOURCE)end;asyncInsert('INSERT INTO dpn_medical_v6_ai_predictions (prediction_id,patient_cid,risk_level,probability,horizon_minutes,status,prediction_data) VALUES (?,?,?,?,?,?,?)',{id,item.patientCid,risk,probability,horizonMinutes,'active',encode(item)});return id,item
end)
exports('AcknowledgePrediction',function(predictionId,sourceValue,outcome) local item=predictions[tostring(predictionId)];if not item then return false end;item.acknowledged=true;item.acknowledgedBy=actor(sourceValue);item.outcome=outcome;item.acknowledgedAt=os.time();metrics.acknowledged=metrics.acknowledged+1;if outcome=='false_positive'then metrics.falsePositives=metrics.falsePositives+1 end;asyncUpdate('UPDATE dpn_medical_v6_ai_predictions SET status=?,acknowledged_by=?,outcome=?,prediction_data=?,updated_at=NOW() WHERE prediction_id=?',{'acknowledged',item.acknowledgedBy,outcome,encode(item),item.id});return true,item end)
exports('RunClinicalSafetyReview',function(target) local ok,twin=core('GetDigitalTwin',target);if not ok then return nil end;local issues={};if twin.profile.codeStatus=='dnr'and twin.lifeState=='alive'then issues[#issues+1]={severity='info',issue='DNR directive active'}end;if twin.v6.clottingRisk~='normal'then issues[#issues+1]={severity='warning',issue='Coagulation risk: '..twin.v6.clottingRisk}end;if twin.v6.sepsisBundleDue then issues[#issues+1]={severity='high',issue='Sepsis bundle due'}end;return {patient=target,issues=issues,recommendations=twin.recommendedOrders,advisoryOnly=true,generatedAt=os.time()}end)
exports('GetAIModelMetrics',function()return metrics end)
heartbeat({'deterioration_forecasting','explainable_reasons','clinical_safety_review','model_outcome_feedback','advisory_only_controls'})
