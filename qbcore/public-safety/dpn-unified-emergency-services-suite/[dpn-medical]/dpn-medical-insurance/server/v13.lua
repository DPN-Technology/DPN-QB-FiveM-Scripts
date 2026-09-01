local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local store = { plans={}, handoffs={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('EvaluateContinuumAuthorizationV13', function(target,service,policy) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local necessity=clamp(twin.v13.continuumRisk*.65+twin.v13.careComplexity*.35,0,100);local item={id=uid('AUTH13'),target=tonumber(target),service=service,policy=policy,medicalNecessity=math.floor(necessity),status=necessity>=40 and'approved'or'manual_review',createdAt=os.time()};store.authorizations[item.id]=item;return true,item end)

exports('EstimatePatientResponsibilityV13', function(target,total,coverage) local amount=tonumber(total)or 0;local covered=clamp(tonumber(coverage)or 0,0,100);return true,{target=tonumber(target),total=amount,covered=amount*covered/100,patient=amount*(100-covered)/100,createdAt=os.time()} end)

exports('CreateAppealPacketV13', function(claimId,reason,actor) local item={id=uid('APL13'),claimId=claimId,reason=reason,actor=actor,status='draft',createdAt=os.time()};store.appeals[item.id]=item;return true,item end)

exports('GetV13InsuranceBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); print('[dpn-medical-insurance] v13 continuum-command operations active') end)
