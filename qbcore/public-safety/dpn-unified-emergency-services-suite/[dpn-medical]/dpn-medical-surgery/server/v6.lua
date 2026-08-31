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

local rooms, cases = {}, {}
for i=1,4 do rooms['OR'..i]={id='OR'..i,status='available',caseId=nil} end
exports('ScheduleORCase',function(sourceValue,target,procedure,priority,scheduledAt,roomId)
    roomId=roomId or 'OR1'; if not rooms[roomId] then return false,'Unknown operating room' end
    local id=uid('ORC',target);local item={id=id,target=tonumber(target),patientCid=citizen(target),procedure=procedure,priority=tonumber(priority) or 3,scheduledAt=tonumber(scheduledAt) or os.time(),room=roomId,status='scheduled',surgeon=actor(sourceValue),checklist={identity=false,site=false,procedure=false,allergy=false,airway=false,blood=false,antibiotic=false,count=false},anesthesia={},counts={sponges=0,sharps=0,instruments=0},events={}};cases[id]=item;rooms[roomId].status='reserved';rooms[roomId].caseId=id
    asyncInsert('INSERT INTO dpn_medical_v6_or_cases (case_id,patient_cid,procedure_code,status,priority,room_id,scheduled_at,surgeon_cid,case_data) VALUES (?,?,?,?,?,?,FROM_UNIXTIME(?),?,?)',{id,item.patientCid,procedure,item.status,item.priority,roomId,item.scheduledAt,item.surgeon,encode(item)});core('CreateClinicalOrder',target,'procedure',procedure,{priority=item.priority,module='surgery',reason='Scheduled operative management'},sourceValue);return id,item
end)
exports('CompleteSurgicalSafetyCheck',function(caseId,checkName,sourceValue,details)
    local item=cases[tostring(caseId)];if not item or item.checklist[checkName]==nil then return false,'Case/check not found'end;item.checklist[checkName]=true;item.events[#item.events+1]={type='checklist',check=checkName,actor=actor(sourceValue),at=os.time(),details=details};return true,item
end)
exports('StartORCase',function(caseId,sourceValue)
    local item=cases[tostring(caseId)];if not item then return false end;for _,key in ipairs({'identity','site','procedure','allergy','airway'})do if not item.checklist[key]then return false,'Required safety check incomplete: '..key end end;item.status='in_progress';item.startedAt=os.time();item.startedBy=actor(sourceValue);rooms[item.room].status='occupied';asyncUpdate('UPDATE dpn_medical_v6_or_cases SET status=?,started_at=NOW(),case_data=? WHERE case_id=?',{item.status,encode(item),item.id});return true,item
end)
exports('RecordAnesthesiaEvent',function(caseId,eventType,data,sourceValue) local item=cases[tostring(caseId)];if not item then return false end;local event={type=eventType,data=data or {},actor=actor(sourceValue),at=os.time()};item.anesthesia[#item.anesthesia+1]=event;asyncInsert('INSERT INTO dpn_medical_v6_anesthesia_events (case_id,event_type,provider_cid,event_data) VALUES (?,?,?,?)',{item.id,eventType,event.actor,encode(data)});return true,event end)
exports('RecordSurgicalCount',function(caseId,sponges,sharps,instruments,sourceValue) local item=cases[tostring(caseId)];if not item then return false end;item.counts={sponges=tonumber(sponges)or 0,sharps=tonumber(sharps)or 0,instruments=tonumber(instruments)or 0,actor=actor(sourceValue),at=os.time()};item.checklist.count=true;return true,item.counts end)
exports('CloseORCase',function(caseId,outcome,bloodLoss,sourceValue)
    local item=cases[tostring(caseId)];if not item then return false end;if not item.checklist.count then return false,'Final surgical count is incomplete'end;item.status='completed';item.outcome=outcome or 'stable';item.bloodLoss=tonumber(bloodLoss)or 0;item.closedAt=os.time();item.closedBy=actor(sourceValue);rooms[item.room]={id=item.room,status='turnover',caseId=nil};core('AddProcedure',item.target,{name=item.procedure,outcome=item.outcome,bloodLoss=item.bloodLoss,caseId=item.id});core('CreateStructuredHandoff',item.target,'PACU',{situation='Postoperative transfer',assessment={outcome=item.outcome,bloodLoss=item.bloodLoss},recommendation='Post-anesthesia monitoring'},sourceValue);asyncUpdate('UPDATE dpn_medical_v6_or_cases SET status=?,completed_at=NOW(),case_data=? WHERE case_id=?',{item.status,encode(item),item.id});return true,item
end)
exports('GetORBoard',function()return {rooms=rooms,cases=cases,generatedAt=os.time()}end)
