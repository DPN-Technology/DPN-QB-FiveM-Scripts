local VERSION='9.0.0'
local perioperative, anesthesia, recovery = {}, {}, {}
local function uid(p)return('%s-%s-%04d'):format(p,os.time(),math.random(0,9999))end
local function core(name,...)local a=table.pack(...);local ok,x,y=pcall(function()local p=exports['dpn-medical-core'];return p[name](p,table.unpack(a,1,a.n))end);return ok,x,y end
exports('CreatePerioperativePlanV9',function(target,procedure,team)
 local ok,twin=core('GetV9Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end
 local risk=math.min(100,(twin.v9.adaptiveRisk or 0)*.55+(twin.v9.hepaticRisk or 0)*.2+(twin.v9.electrolyteRisk or 0)*.25)
 local plan={id=uid('PERIOP'),target=tonumber(target),procedure=procedure,team=team or{},risk=math.floor(risk),readiness=risk<70 and'conditional'or'high_risk',requirements={},createdAt=os.time()}
 if twin.v9.electrolyteRisk>=35 then plan.requirements[#plan.requirements+1]='correct_electrolytes'end;if twin.v9.qtRisk>=35 then plan.requirements[#plan.requirements+1]='continuous_ecg'end;if twin.v9.hepaticRisk>=40 then plan.requirements[#plan.requirements+1]='dose_adjust_anesthesia'end
 perioperative[plan.id]=plan;return true,plan
end)
exports('RecordAnesthesiaCheckpointV9',function(caseId,stage,data,actor)local item=anesthesia[tostring(caseId)]or{id=uid('ANES'),caseId=caseId,events={}};item.events[#item.events+1]={stage=stage,data=data or{},actor=actor,at=os.time()};item.updatedAt=os.time();anesthesia[tostring(caseId)]=item;return true,item end)
exports('CreatePostoperativeRecoveryPlanV9',function(target,caseId)local ok,twin=core('GetV9Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end;local item={id=uid('PACU'),target=tonumber(target),caseId=caseId,level=twin.v9.adaptiveRisk>=70 and'icu'or twin.v9.adaptiveRisk>=45 and'monitored_pacu'or'standard_pacu',goals={'airway_stable','pain_controlled','hemodynamics_stable','nausea_controlled'},createdAt=os.time()};recovery[item.id]=item;return true,item end)
exports('GetV9SurgeryBoard',function()return{version=VERSION,perioperative=perioperative,anesthesia=anesthesia,recovery=recovery,generatedAt=os.time()}end)
CreateThread(function()Wait(5200);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-surgery',VERSION,{'perioperative_risk','anesthesia_checkpoints','postoperative_recovery','adaptive_or_readiness'})end);print('[dpn-medical-surgery] v9 perioperative risk and recovery orchestration active')end)
