local VERSION='9.0.0'
local authorizations, necessity, coverage = {}, {}, {}
local function uid(p)return('%s-%s-%04d'):format(p,os.time(),math.random(0,9999))end
local function core(name,...)local a=table.pack(...);local ok,x,y=pcall(function()local p=exports['dpn-medical-core'];return p[name](p,table.unpack(a,1,a.n))end);return ok,x,y end
exports('EvaluateMedicalNecessityV9',function(target,service)
 local ok,twin=core('GetV9Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end;local score=(twin.v9.adaptiveRisk or 0)+(twin.v9.networkPriority<=2 and 20 or 0);local item={id=uid('NEC'),target=tonumber(target),service=service,score=math.min(100,score),necessary=score>=45,clinical={risk=twin.v9.adaptiveRisk,disposition=twin.v9.disposition,trajectory=twin.v9.trajectory},createdAt=os.time()};necessity[item.id]=item;return true,item
end)
exports('CreateEpisodeAuthorizationV9',function(patientCid,episodeId,services,plan)local item={id=uid('AUTH'),patientCid=patientCid,episodeId=episodeId,services=services or{},plan=plan,status='pending_review',createdAt=os.time()};authorizations[item.id]=item;return item.id,item end)
exports('EstimateAdaptiveCoverageV9',function(total,plan,risk)local deductible=tonumber(plan and plan.deductibleRemaining)or 0;local rate=tonumber(plan and plan.coverageRate)or .8;local covered=math.max(0,(tonumber(total)or 0)-deductible)*rate;local item={total=total,deductible=deductible,covered=math.floor(covered*100)/100,patient=math.floor(((tonumber(total)or 0)-covered)*100)/100,riskAdjustment=tonumber(risk)or 0,createdAt=os.time()};coverage[#coverage+1]=item;return item end)
exports('GetV9InsuranceBoard',function()return{version=VERSION,authorizations=authorizations,necessity=necessity,coverage=coverage,generatedAt=os.time()}end)
CreateThread(function()Wait(5700);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-insurance',VERSION,{'medical_necessity','episode_authorization','adaptive_coverage','clinical_documentation_support'})end);print('[dpn-medical-insurance] v9 clinical necessity and episode authorization active')end)
