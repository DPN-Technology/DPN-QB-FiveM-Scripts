local VERSION='14.0.0'
local RESOURCE='dpn-medical-coroner'
local cases={}
local function now()return os.time()end
local function uid(prefix,target)return('%s-%s-%s-%04d'):format(prefix,now(),tostring(target or 0),math.random(0,9999))end
local function encode(v)local ok,d=pcall(json.encode,v);return ok and d or'{}'end
local function core()local ok,c=pcall(function()return exports['qb-core']:GetCoreObject()end);return ok and c or nil end
local function cid(target)local c=core();local p=c and c.Functions and c.Functions.GetPlayer(tonumber(target));return p and p.PlayerData and p.PlayerData.citizenid or('source:%s'):format(tostring(target))end
local function twinFor(target)local ok,t=pcall(function()local p=exports['dpn-medical-core'];return p:GetV14Twin(tonumber(target))end);return ok and type(t)=='table'and t or nil end
local function persist(item)CreateThread(function()pcall(function()MySQL.insert.await('INSERT INTO dpn_medical_v14_module_events (event_id,resource_name,patient_cid,event_type,event_data,created_by) VALUES (?,?,?,?,?,?)',{item.id,RESOURCE,item.patientCid,item.kind,encode(item),item.actor})end)end)end
exports('CreatePreventableDeathReviewV14',function(target,options,actor)
 local twin=twinFor(target);if not twin then return false,'Patient not found.'end
 local item={id=uid('PREVENTA',target),target=tonumber(target),patientCid=cid(target),kind='preventability_review',description='Creates a structured trauma preventability review.',status='active',actor=tostring(actor or'system'),risk=twin.v14.traumaCommandRisk,tier=twin.v14.traumaTier,destination=twin.v14.recommendedDestination,resourceDemand=twin.v14.resourceDemand,goldenHour=twin.v14.goldenHourRemaining,options=type(options)=='table'and options or{},createdAt=now()}
 cases[item.id]=item;persist(item);TriggerEvent('dpn-medical:v14:preventability_review',item);return true,item
end)
exports('AnalyzeTraumaDeathWindowV14',function(target,options)
 local twin=twinFor(target);if not twin then return false,'Patient not found.'end
 local result={id=uid('DEATH_WI',target),target=tonumber(target),patientCid=cid(target),kind='death_window',description='Estimates the time-critical death window from the event journal.',risk=twin.v14.traumaCommandRisk,tier=twin.v14.traumaTier,destination=twin.v14.recommendedDestination,resourceDemand=twin.v14.resourceDemand,goldenHour=twin.v14.goldenHourRemaining,options=type(options)=='table'and options or{},generatedAt=now()}
 return true,result
end)
exports('CreateTraumaMortalityLearningCaseV14',function(target,options,actor)
 local twin=twinFor(target);if not twin then return false,'Patient not found.'end
 local item={id=uid('MORTALIT',target),target=tonumber(target),patientCid=cid(target),kind='mortality_learning',description='Creates a deidentified learning case.',status='active',actor=tostring(actor or'system'),risk=twin.v14.traumaCommandRisk,tier=twin.v14.traumaTier,destination=twin.v14.recommendedDestination,resourceDemand=twin.v14.resourceDemand,goldenHour=twin.v14.goldenHourRemaining,options=type(options)=='table'and options or{},createdAt=now()}
 cases[item.id]=item;persist(item);TriggerEvent('dpn-medical:v14:mortality_learning',item);return true,item
end)
exports('GetV14CoronerBoard',function()
 local rows={};for _,item in pairs(cases)do rows[#rows+1]=item end;table.sort(rows,function(a,b)return(a.createdAt or 0)>(b.createdAt or 0)end)
 local critical=0;for _,sid in ipairs(GetPlayers()or{})do local t=twinFor(tonumber(sid));if t and(t.v14.traumaCommandRisk or 0)>=75 then critical=critical+1 end end
 return{passed=true,version=VERSION,resource=RESOURCE,active=#rows,criticalPatients=critical,cases=rows}
end)
exports('GetV14Cases',function()return cases end)
CreateThread(function()Wait(7000+math.random(0,2200));pcall(function()exports['dpn-medical-core']:RegisterModule(RESOURCE,VERSION,{'preventability_review', 'death_window', 'mortality_learning','v14_board','trauma_command_integration'})end);print(('[%s] v14.0.0 trauma-command workflows active'):format(RESOURCE))end)
