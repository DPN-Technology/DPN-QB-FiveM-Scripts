local VERSION='9.0.0'
local advisories, overrides, outcomes = {}, {}, {}
local function uid(p)return('%s-%s-%04d'):format(p,os.time(),math.random(0,9999))end
local function core(name,...)local a=table.pack(...);local ok,x,y=pcall(function()local p=exports['dpn-medical-core'];return p[name](p,table.unpack(a,1,a.n))end);return ok,x,y end
exports('GenerateAdaptiveEnsembleAdvisoryV9',function(target)
 local ok,twin=core('GetV9Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end;local models={{name='physiology',score=twin.v9.adaptiveRisk,weight=.45},{name='trajectory',score=twin.trajectory30.projectedRisk,weight=.30},{name='organ_failure',score=math.min(100,(twin.v6.sofa or 0)*7),weight=.25}};local score=0;for _,m in ipairs(models)do score=score+m.score*m.weight end;local item={id=uid('AI9'),target=tonumber(target),score=math.floor(score),confidence=twin.v9.confidence,models=models,recommendation=twin.v9.disposition,explanations=twin.safety.findings or{},advisoryOnly=true,createdAt=os.time()};advisories[item.id]=item;return true,item
end)
exports('RecordAIOverrideV9',function(advisoryId,clinician,decision,reason)local item={id=uid('OVR'),advisoryId=advisoryId,clinician=clinician,decision=decision,reason=reason,createdAt=os.time()};overrides[item.id]=item;return true,item end)
exports('CalibrateAIOutcomeV9',function(advisoryId,outcome)local advisory=advisories[tostring(advisoryId)];if not advisory then return false,'Advisory not found.'end;local item={id=uid('AIOUT'),advisoryId=advisoryId,predicted=advisory.score,outcome=outcome,error=math.abs((tonumber(outcome and outcome.risk)or advisory.score)-advisory.score),createdAt=os.time()};outcomes[item.id]=item;return true,item end)
exports('GetV9AIBoard',function()return{version=VERSION,advisories=advisories,overrides=overrides,outcomes=outcomes,generatedAt=os.time()}end)
CreateThread(function()Wait(6100);print('[dpn-medical-ai] v9 governed adaptive ensemble and outcome calibration active')end)
