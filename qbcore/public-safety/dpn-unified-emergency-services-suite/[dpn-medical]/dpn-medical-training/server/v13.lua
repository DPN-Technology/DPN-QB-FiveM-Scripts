local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local store = { plans={}, handoffs={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('CreateDeterministicTrainingCaseV13', function(scenario,seed,instructor) local item={id=uid('TRN13'),scenario=scenario,seed=tonumber(seed)or os.time(),instructor=instructor,status='ready',actions={},createdAt=os.time()};store.cases[item.id]=item;return true,item end)

exports('ScoreClinicalReasoningV13', function(caseId,actions,expected) local matched=0;local exp={};for _,v in ipairs(expected or{})do exp[tostring(v)]=true end;for _,v in ipairs(actions or{})do if exp[tostring(v)]then matched=matched+1 end end;local score=math.floor(matched/math.max(1,#(expected or{}))*100);local item={id=uid('SCR13'),caseId=caseId,score=score,status=score>=80 and'competent'or score>=60 and'remediation'or'failed',createdAt=os.time()};store.scores[item.id]=item;return true,item end)

exports('CreateRemediationPlanV13', function(provider,deficits) local item={id=uid('REM13'),provider=provider,deficits=deficits or{},status='assigned',createdAt=os.time()};store.remediation[item.id]=item;return true,item end)

exports('GetV13TrainingBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); pcall(function() exports['dpn-medical-core']:RegisterModule('dpn-medical-training', VERSION, {'CreateDeterministicTrainingCaseV13','ScoreClinicalReasoningV13','CreateRemediationPlanV13'}) end); print('[dpn-medical-training] v13 continuum-command operations active') end)
