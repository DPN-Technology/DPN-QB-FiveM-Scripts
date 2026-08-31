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

local notes, locks = {}, {}
exports('CreateSignedClinicalNote',function(sourceValue,target,noteType,title,body,episodeId)
    local id=uid('NOTE',target);local item={id=id,target=tonumber(target),patientCid=citizen(target),type=tostring(noteType or 'progress_note'),title=tostring(title or 'Clinical note'),body=tostring(body or ''),episodeId=episodeId,author=actor(sourceValue),status='signed',signedAt=os.time(),addenda={}};notes[id]=item
    local ok,result=pcall(function()return exports['dpn-medical-records']:AddEntry(target,'signed_note',item,item.author)end);if not ok or result~=true then return false,'Unable to write longitudinal record'end
    asyncInsert('INSERT INTO dpn_medical_v6_notes (note_id,patient_cid,note_type,title,status,author_cid,episode_id,note_data,signed_at) VALUES (?,?,?,?,?,?,?,?,NOW())',{id,item.patientCid,item.type,item.title,item.status,item.author,episodeId,encode(item)});return id,item
end)
exports('AddNoteAddendum',function(sourceValue,noteId,text) local item=notes[tostring(noteId)];if not item then return false,'Note not found'end;local add={id=uid('ADD',noteId),text=tostring(text or ''),author=actor(sourceValue),createdAt=os.time()};item.addenda[#item.addenda+1]=add;asyncInsert('INSERT INTO dpn_medical_v6_note_addenda (addendum_id,note_id,author_cid,addendum_text) VALUES (?,?,?,?)',{add.id,item.id,add.author,add.text});return true,add end)
exports('LockPatientChart',function(sourceValue,target,reason,seconds) local key=citizen(target);if not key then return false end;locks[key]={holder=actor(sourceValue),reason=reason,expiresAt=os.time()+(tonumber(seconds)or 120)};return true,locks[key]end)
exports('UnlockPatientChart',function(sourceValue,target) local key=citizen(target);local lock=key and locks[key];if not lock then return true end;if lock.holder~=actor(sourceValue)then return false,'Chart lock belongs to another provider'end;locks[key]=nil;return true end)
exports('GetEpisodeSummary',function(target)
    local ok,twin=core('GetDigitalTwin',target);if not ok then return nil end;local _,orders=core('GetClinicalOrders',target,true);local _,handoffs=core('GetHandoffs',target);local records=exports['dpn-medical-records']:GetRecords(target,100);return {patient=target,citizenid=citizen(target),digitalTwin=twin,orders=orders or{},handoffs=handoffs or{},records=records or{},generatedAt=os.time()}
end)
exports('GetSignedNotes',function(target)local out={};for _,item in pairs(notes)do if not target or item.target==tonumber(target)then out[#out+1]=item end end;table.sort(out,function(a,b)return a.signedAt>b.signedAt end);return out end)
heartbeat({'signed_notes','addenda','chart_locking','episode_summary','longitudinal_timeline','schema_adaptation','access_audit'})
