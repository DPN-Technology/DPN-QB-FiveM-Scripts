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

local eligibility, claims, appeals = {}, {}, {}
exports('VerifyEligibility',function(target,serviceDate) local key=citizen(target);if not key then return false end;local item={patientCid=key,eligible=true,plan='standard',serviceDate=serviceDate or os.date('%Y-%m-%d'),copay=250,deductibleRemaining=1000,verifiedAt=os.time()};eligibility[key]=item;asyncInsert('INSERT INTO dpn_medical_v6_eligibility (patient_cid,service_date,eligible,plan_name,eligibility_data) VALUES (?,?,?,?,?) ON DUPLICATE KEY UPDATE eligible=VALUES(eligible),plan_name=VALUES(plan_name),eligibility_data=VALUES(eligibility_data),verified_at=NOW()',{key,item.serviceDate,item.eligible,item.plan,encode(item)});return true,item end)
exports('SubmitInsuranceClaim',function(sourceValue,target,invoiceId,codes,total) local id=uid('CLM',target);local item={id=id,target=tonumber(target),patientCid=citizen(target),invoiceId=invoiceId,codes=codes or{},total=tonumber(total)or 0,status='submitted',submittedBy=actor(sourceValue),submittedAt=os.time(),edits={}};claims[id]=item;asyncInsert('INSERT INTO dpn_medical_v6_claims (claim_id,patient_cid,invoice_id,status,total_amount,submitted_by,claim_data) VALUES (?,?,?,?,?,?,?)',{id,item.patientCid,tostring(invoiceId),item.status,item.total,item.submittedBy,encode(item)});return id,item end)
exports('AdjudicateClaim',function(claimId,status,allowedAmount,reason,sourceValue) local item=claims[tostring(claimId)];if not item then return false end;item.status=status;item.allowedAmount=tonumber(allowedAmount)or 0;item.reason=reason;item.adjudicatedBy=actor(sourceValue);item.adjudicatedAt=os.time();asyncUpdate('UPDATE dpn_medical_v6_claims SET status=?,allowed_amount=?,denial_reason=?,claim_data=?,updated_at=NOW() WHERE claim_id=?',{status,item.allowedAmount,reason,encode(item),item.id});return true,item end)
exports('AppealClaim',function(sourceValue,claimId,reason,documents) local item=claims[tostring(claimId)];if not item then return false end;local appeal={id=uid('APL',claimId),claimId=item.id,reason=reason,documents=documents or{},status='submitted',submittedBy=actor(sourceValue),submittedAt=os.time()};appeals[appeal.id]=appeal;asyncInsert('INSERT INTO dpn_medical_v6_claim_appeals (appeal_id,claim_id,status,submitted_by,appeal_data) VALUES (?,?,?,?,?)',{appeal.id,appeal.claimId,appeal.status,appeal.submittedBy,encode(appeal)});return appeal.id,appeal end)
exports('GetClaims',function(target)local out={};for _,item in pairs(claims)do if not target or item.target==tonumber(target)then out[#out+1]=item end end;return out end)
heartbeat({'eligibility_verification','claim_submission','claim_adjudication','appeals','preauthorization','patient_financial_estimates'})
