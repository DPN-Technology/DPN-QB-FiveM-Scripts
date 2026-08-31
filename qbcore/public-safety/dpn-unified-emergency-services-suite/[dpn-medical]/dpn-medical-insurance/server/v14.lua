local VERSION='14.0.0'
local RESOURCE='dpn-medical-insurance'
local cases={}
local function now()return os.time()end
local function uid(prefix,target)return('%s-%s-%s-%04d'):format(prefix,now(),tostring(target or 0),math.random(0,9999))end
local function encode(v)local ok,d=pcall(json.encode,v);return ok and d or'{}'end
local function core()local ok,c=pcall(function()return exports['qb-core']:GetCoreObject()end);return ok and c or nil end
local function cid(target)local c=core();local p=c and c.Functions and c.Functions.GetPlayer(tonumber(target));return p and p.PlayerData and p.PlayerData.citizenid or('source:%s'):format(tostring(target))end
local function twinFor(target)local ok,t=pcall(function()local p=exports['dpn-medical-core'];return p:GetV14Twin(tonumber(target))end);return ok and type(t)=='table'and t or nil end
local function persist(item)CreateThread(function()pcall(function()MySQL.insert.await('INSERT INTO dpn_medical_v14_module_events (event_id,resource_name,patient_cid,event_type,event_data,created_by) VALUES (?,?,?,?,?,?)',{item.id,RESOURCE,item.patientCid,item.kind,encode(item),item.actor})end)end)end
exports('CreateTraumaAuthorizationV14',function(target,options,actor)
 local twin=twinFor(target);if not twin then return false,'Patient not found.'end
 local item={id=uid('TRAUMA_A',target),target=tonumber(target),patientCid=cid(target),kind='trauma_authorization',description='Creates high-acuity trauma authorization and medical-necessity package.',status='active',actor=tostring(actor or'system'),risk=twin.v14.traumaCommandRisk,tier=twin.v14.traumaTier,destination=twin.v14.recommendedDestination,resourceDemand=twin.v14.resourceDemand,goldenHour=twin.v14.goldenHourRemaining,options=type(options)=='table'and options or{},createdAt=now()}
 cases[item.id]=item;persist(item);TriggerEvent('dpn-medical:v14:trauma_authorization',item);return true,item
end)
exports('EstimateTraumaResponsibilityV14',function(target,options)
 local twin=twinFor(target);if not twin then return false,'Patient not found.'end
 local result={id=uid('PATIENT_',target),target=tonumber(target),patientCid=cid(target),kind='patient_estimate',description='Estimates patient responsibility for the trauma episode.',risk=twin.v14.traumaCommandRisk,tier=twin.v14.traumaTier,destination=twin.v14.recommendedDestination,resourceDemand=twin.v14.resourceDemand,goldenHour=twin.v14.goldenHourRemaining,options=type(options)=='table'and options or{},generatedAt=now()}
 return true,result
end)
exports('CreateCriticalTransferAuthorizationV14',function(target,options,actor)
 local twin=twinFor(target);if not twin then return false,'Patient not found.'end
 local item={id=uid('TRANSFER',target),target=tonumber(target),patientCid=cid(target),kind='transfer_authorization',description='Creates expedited critical-transfer authorization.',status='active',actor=tostring(actor or'system'),risk=twin.v14.traumaCommandRisk,tier=twin.v14.traumaTier,destination=twin.v14.recommendedDestination,resourceDemand=twin.v14.resourceDemand,goldenHour=twin.v14.goldenHourRemaining,options=type(options)=='table'and options or{},createdAt=now()}
 cases[item.id]=item;persist(item);TriggerEvent('dpn-medical:v14:transfer_authorization',item);return true,item
end)
exports('GetV14InsuranceBoard',function()
 local rows={};for _,item in pairs(cases)do rows[#rows+1]=item end;table.sort(rows,function(a,b)return(a.createdAt or 0)>(b.createdAt or 0)end)
 local critical=0;for _,sid in ipairs(GetPlayers()or{})do local t=twinFor(tonumber(sid));if t and(t.v14.traumaCommandRisk or 0)>=75 then critical=critical+1 end end
 return{passed=true,version=VERSION,resource=RESOURCE,active=#rows,criticalPatients=critical,cases=rows}
end)
exports('GetV14Cases',function()return cases end)
CreateThread(function()Wait(7000+math.random(0,2200));pcall(function()exports['dpn-medical-core']:RegisterModule(RESOURCE,VERSION,{'trauma_authorization', 'patient_estimate', 'transfer_authorization','v14_board','trauma_command_integration'})end);print(('[%s] v14.0.0 trauma-command workflows active'):format(RESOURCE))end)
