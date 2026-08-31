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

local sessions = {}
exports('StartAdvancedMonitorSession',function(sourceValue,target,deviceId) local id=uid('MON',target);local item={id=id,target=tonumber(target),patientCid=citizen(target),deviceId=deviceId or'LIFEPAK',operator=actor(sourceValue),status='active',startedAt=os.time(),events={},twelveLeads={}};sessions[id]=item;asyncInsert('INSERT INTO dpn_medical_v6_monitor_sessions (session_id,patient_cid,device_id,status,operator_cid,session_data) VALUES (?,?,?,?,?,?)',{id,item.patientCid,item.deviceId,item.status,item.operator,encode(item)});return id,item end)
exports('RecordTwelveLead',function(sessionId,interpretation,measurements,sourceValue) local item=sessions[tostring(sessionId)];if not item then return false end;local event={id=uid('ECG',sessionId),interpretation=interpretation or'normal_sinus',measurements=measurements or{},provider=actor(sourceValue),recordedAt=os.time()};item.twelveLeads[#item.twelveLeads+1]=event;asyncInsert('INSERT INTO dpn_medical_v6_twelve_leads (ecg_id,session_id,interpretation,provider_cid,ecg_data) VALUES (?,?,?,?,?)',{event.id,item.id,event.interpretation,event.provider,encode(event)});core('AddClinicalEvent',item.target,'twelve_lead_ecg',event,event.provider);return event.id,event end)
exports('RecordMonitorEvent',function(sessionId,eventType,data,sourceValue) local item=sessions[tostring(sessionId)];if not item then return false end;local event={type=eventType,data=data or{},operator=actor(sourceValue),at=os.time()};item.events[#item.events+1]=event;asyncInsert('INSERT INTO dpn_medical_v6_monitor_events (session_id,event_type,operator_cid,event_data) VALUES (?,?,?,?)',{item.id,eventType,event.operator,encode(event)});return true,event end)
exports('EndAdvancedMonitorSession',function(sessionId,sourceValue) local item=sessions[tostring(sessionId)];if not item then return false end;item.status='completed';item.endedAt=os.time();item.endedBy=actor(sourceValue);asyncUpdate('UPDATE dpn_medical_v6_monitor_sessions SET status=?,session_data=?,ended_at=NOW() WHERE session_id=?',{item.status,encode(item),item.id});return true,item end)
exports('GetAdvancedMonitorSession',function(id)return sessions[tostring(id)]end)
