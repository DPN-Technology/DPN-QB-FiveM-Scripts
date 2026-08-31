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

local medicationOrders, mar, reconciliations = {}, {}, {}
exports('CreateMedicationOrder',function(sourceValue,target,drug,dose,route,frequency,durationHours,indication)
    local ok,safe,reason,details=core('CheckTreatmentSafety',target,drug,nil,{dose=dose,route=route});if not ok then return false,'Core unavailable'end
    local id=uid('MED',target);local item={id=id,target=tonumber(target),patientCid=citizen(target),drug=drug,dose=dose,route=route or 'oral',frequency=frequency or 'once',durationHours=tonumber(durationHours)or 24,indication=indication,status=safe and 'pending_verification' or 'held',safetyReason=reason,safetyDetails=details,prescriber=actor(sourceValue),createdAt=os.time(),verified=false};medicationOrders[id]=item;asyncInsert('INSERT INTO dpn_medical_v6_medication_orders (order_id,patient_cid,drug_name,dose,route,frequency,status,prescriber_cid,order_data) VALUES (?,?,?,?,?,?,?,?,?)',{id,item.patientCid,drug,tostring(dose),item.route,item.frequency,item.status,item.prescriber,encode(item)});core('CreateClinicalOrder',target,'medication',drug,{priority=2,module='pharmacy',instructions=('%s %s %s'):format(tostring(dose),item.route,item.frequency),reason=indication},sourceValue);return id,item
end)
exports('VerifyMedicationOrder',function(orderId,sourceValue,approved,note) local item=medicationOrders[tostring(orderId)];if not item then return false,'Order not found'end;item.verified=approved==true;item.status=approved==true and 'active' or 'rejected';item.verifiedBy=actor(sourceValue);item.verificationNote=note;item.verifiedAt=os.time();asyncUpdate('UPDATE dpn_medical_v6_medication_orders SET status=?,verified_by=?,verified_at=NOW(),order_data=? WHERE order_id=?',{item.status,item.verifiedBy,encode(item),item.id});return true,item end)
exports('AdministerOrderedDose',function(sourceValue,orderId,target,administrationNote)
    local item=medicationOrders[tostring(orderId)];if not item or item.status~='active'or not item.verified then return false,'Medication order is not active and verified'end
    local ok,result,detail=pcall(function()return exports['dpn-medical-pharmacy']:AdministerMedication(sourceValue,target,item.drug,item.dose,item.route)end);if not ok or result~=true then return false,tostring(detail or result or 'Administration failed')end
    local event={id=uid('MAR',target),orderId=item.id,target=tonumber(target),patientCid=citizen(target),drug=item.drug,dose=item.dose,route=item.route,administeredBy=actor(sourceValue),administeredAt=os.time(),note=administrationNote};mar[target]=mar[target]or{};mar[target][#mar[target]+1]=event;asyncInsert('INSERT INTO dpn_medical_v6_mar (mar_id,order_id,patient_cid,drug_name,dose,route,administered_by,administration_data) VALUES (?,?,?,?,?,?,?,?)',{event.id,event.orderId,event.patientCid,event.drug,tostring(event.dose),event.route,event.administeredBy,encode(event)});return true,event
end)
exports('ReconcileMedications',function(sourceValue,target,homeMedications,changes) local item={id=uid('REC',target),target=tonumber(target),patientCid=citizen(target),homeMedications=homeMedications or {},changes=changes or {},completedBy=actor(sourceValue),completedAt=os.time()};reconciliations[target]=item;asyncInsert('INSERT INTO dpn_medical_v6_med_reconciliation (reconciliation_id,patient_cid,completed_by,reconciliation_data) VALUES (?,?,?,?)',{item.id,item.patientCid,item.completedBy,encode(item)});core('AddClinicalEvent',target,'medication_reconciliation',item,item.completedBy);return item.id,item end)
exports('GetMedicationOrders',function(target)local out={};for _,item in pairs(medicationOrders)do if not target or item.target==tonumber(target)then out[#out+1]=item end end;return out end)
exports('GetMAR',function(target)return mar[tonumber(target)]or{}end)
heartbeat({'computerized_provider_order_entry','pharmacist_verification','medication_administration_record','medication_reconciliation','interaction_safety','controlled_medication_audit'})
