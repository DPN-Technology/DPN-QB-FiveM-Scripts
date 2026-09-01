local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local store = { plans={}, handoffs={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('BuildContinuumOrganSupportPlanV13', function(target,actor) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('ORG13'),target=tonumber(target),actor=actor,supports=twin.organSupportV12.recommendedSupports or{},hemostasis=twin.hemostasisV13,pharmacology=twin.pharmacologyV13,immune=twin.immuneV13,status='planned',createdAt=os.time()};store.plans[item.id]=item;return true,item end)

exports('CreateDailyLiberationAssessmentV13', function(target,actor) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local readiness=clamp(twin.v13.resilienceScore*.45+twin.recoveryV13.recoveryReserve*.35+(100-twin.pharmacologyV13.sedativeBurden)*.2,0,100);local item={id=uid('LIB13'),target=tonumber(target),actor=actor,readiness=math.floor(readiness),status=readiness>=75 and'ready_for_trial'or'continue_support',createdAt=os.time()};store.liberation[item.id]=item;return true,item end)

exports('RecordMultidisciplinaryRoundV13', function(target,goals,actor) local item={id=uid('RND13'),target=tonumber(target),goals=goals or{},actor=actor,status='documented',createdAt=os.time()};store.rounds[item.id]=item;return true,item end)

exports('GetV13ICUBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); print('[dpn-medical-icu] v13 continuum-command operations active') end)
