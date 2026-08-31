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

local claims, coding = {}, {}
exports('CreateRevenueCycleClaim',function(sourceValue,target,invoiceId,payer,total) local id=uid('RCM',target);local item={id=id,target=tonumber(target),patientCid=citizen(target),invoiceId=invoiceId,payer=payer or'self_pay',total=tonumber(total)or 0,status='draft',createdBy=actor(sourceValue),createdAt=os.time(),codes={},edits={}};claims[id]=item;asyncInsert('INSERT INTO dpn_medical_v6_revenue_claims (claim_id,patient_cid,invoice_id,payer,status,total_amount,created_by,claim_data) VALUES (?,?,?,?,?,?,?,?)',{id,item.patientCid,tostring(invoiceId),item.payer,item.status,item.total,item.createdBy,encode(item)});return id,item end)
exports('AddClinicalCode',function(claimId,codeType,code,description,amount,sourceValue) local item=claims[tostring(claimId)];if not item then return false end;local line={id=uid('COD',claimId),type=codeType or'CPT',code=code,description=description,amount=tonumber(amount)or 0,coder=actor(sourceValue)};item.codes[#item.codes+1]=line;coding[line.id]=line;asyncInsert('INSERT INTO dpn_medical_v6_claim_codes (code_line_id,claim_id,code_type,code_value,description,amount,coder_cid) VALUES (?,?,?,?,?,?,?)',{line.id,item.id,line.type,line.code,line.description,line.amount,line.coder});return line.id,line end)
exports('ScrubRevenueClaim',function(claimId) local item=claims[tostring(claimId)];if not item then return false end;local edits={};if #item.codes==0 then edits[#edits+1]='No clinical codes attached'end;local sum=0;for _,line in ipairs(item.codes)do sum=sum+(line.amount or 0);if not line.code or line.code==''then edits[#edits+1]='Blank code line'end end;if math.abs(sum-item.total)>1 then edits[#edits+1]=('Code total %.2f does not match claim %.2f'):format(sum,item.total)end;item.edits=edits;item.status=#edits==0 and'ready'or'needs_correction';return #edits==0,item end)
exports('SubmitRevenueClaim',function(sourceValue,claimId) local clean,item=exports['dpn-medical-billing-plus']:ScrubRevenueClaim(claimId);if not item then return false end;if not clean then return false,item.edits end;item.status='submitted';item.submittedBy=actor(sourceValue);item.submittedAt=os.time();asyncUpdate('UPDATE dpn_medical_v6_revenue_claims SET status=?,submitted_by=?,submitted_at=NOW(),claim_data=? WHERE claim_id=?',{item.status,item.submittedBy,encode(item),item.id});return true,item end)
exports('GetRevenueCycleDashboard',function()local totals={draft=0,ready=0,submitted=0,needs_correction=0,value=0};for _,item in pairs(claims)do totals[item.status]=(totals[item.status]or 0)+1;totals.value=totals.value+(item.total or 0)end;return {claims=claims,totals=totals,generatedAt=os.time()}end)
