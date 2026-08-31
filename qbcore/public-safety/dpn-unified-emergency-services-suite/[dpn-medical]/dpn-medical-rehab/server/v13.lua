local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local store = { plans={}, handoffs={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('BuildContinuumRecoveryPlanV13', function(target,actor) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('RHB13'),target=tonumber(target),actor=actor,reserve=twin.recoveryV13.recoveryReserve,rehabNeed=twin.recoveryV13.rehabilitationNeed,dischargeReadiness=twin.recoveryV13.dischargeReadiness,goals={'mobility','self_care','cognition','pain_control','home_safety'},status='active',createdAt=os.time()};store.plans[item.id]=item;return true,item end)

exports('RecordFunctionalMilestoneV13', function(planId,milestone,score,actor) local item={id=uid('MIL13'),planId=planId,milestone=milestone,score=score,actor=actor,createdAt=os.time()};store.milestones[item.id]=item;return true,item end)

exports('EstimateHomeReadinessV13', function(target,supports) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local score=clamp(twin.recoveryV13.dischargeReadiness+(tonumber(supports)or 0)*.2,0,100);return true,{target=tonumber(target),score=math.floor(score),status=score>=75 and'ready'or'barriers_remain',createdAt=os.time()} end)

exports('GetV13RehabBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); pcall(function() exports['dpn-medical-core']:RegisterModule('dpn-medical-rehab', VERSION, {'BuildContinuumRecoveryPlanV13','RecordFunctionalMilestoneV13','EstimateHomeReadinessV13'}) end); print('[dpn-medical-rehab] v13 continuum-command operations active') end)
