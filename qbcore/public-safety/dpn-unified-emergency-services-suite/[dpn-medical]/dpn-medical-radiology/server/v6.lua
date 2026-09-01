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

local reports, screenings = {}, {}
exports('ScreenContrastRisk',function(target,study,sourceValue)
    local ok,twin=core('GetDigitalTwin',target);if not ok or not twin then return false,'Patient unavailable'end
    local creatinine=tonumber(twin.labs and twin.labs.creatinine)or 1.0;local allergies=twin.profile and twin.profile.allergies or {};local risk='low';local reasons={}
    if creatinine>=2 then risk='high';reasons[#reasons+1]='Renal dysfunction' elseif creatinine>=1.4 then risk='moderate';reasons[#reasons+1]='Elevated creatinine'end
    if allergies.contrast or allergies.iodine then risk='high';reasons[#reasons+1]='Documented contrast/iodine allergy'end
    local item={target=tonumber(target),patientCid=citizen(target),study=study,risk=risk,reasons=reasons,screenedBy=actor(sourceValue),screenedAt=os.time()};screenings[target]=item;asyncInsert('INSERT INTO dpn_medical_v6_contrast_screening (patient_cid,study_type,risk_level,screened_by,screening_data) VALUES (?,?,?,?,?)',{item.patientCid,study,risk,item.screenedBy,encode(item)});return true,item
end)
exports('CreateStructuredRadiologyReport',function(sourceValue,target,study,bodyPart,findings,impression,critical)
    local id=uid('RAD',target);local item={id=id,target=tonumber(target),patientCid=citizen(target),study=study,bodyPart=bodyPart,findings=findings or {},impression=impression or 'No acute finding',critical=critical==true,status='final',radiologist=actor(sourceValue),finalizedAt=os.time(),acknowledged=false};reports[id]=item;asyncInsert('INSERT INTO dpn_medical_v6_radiology_reports (report_id,patient_cid,study_type,body_part,status,critical_result,radiologist_cid,report_data) VALUES (?,?,?,?,?,?,?,?)',{id,item.patientCid,study,bodyPart,item.status,item.critical,item.radiologist,encode(item)});core('AddClinicalEvent',target,'radiology_report',item,item.radiologist);if item.critical then core('RaiseSafetyAlert',target,'critical_imaging','critical','Critical radiology result requires acknowledgment.',{reportId=id,impression=item.impression},RESOURCE)end;return id,item
end)
exports('AcknowledgeCriticalResult',function(reportId,sourceValue,note) local item=reports[tostring(reportId)];if not item then return false end;item.acknowledged=true;item.acknowledgedBy=actor(sourceValue);item.acknowledgedAt=os.time();item.acknowledgmentNote=note;asyncUpdate('UPDATE dpn_medical_v6_radiology_reports SET acknowledged_by=?,acknowledged_at=NOW(),report_data=? WHERE report_id=?',{item.acknowledgedBy,encode(item),item.id});return true,item end)
exports('GetRadiologyReports',function(target)local out={};for _,item in pairs(reports)do if not target or item.target==tonumber(target)then out[#out+1]=item end end;table.sort(out,function(a,b)return a.finalizedAt>b.finalizedAt end);return out end)
