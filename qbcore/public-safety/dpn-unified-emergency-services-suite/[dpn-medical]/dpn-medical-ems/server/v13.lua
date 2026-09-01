local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local store = { plans={}, handoffs={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('CreateProlongedFieldCarePlanV13', function(target,unit,actor) local ok,twin=core('GetV13Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end;local item={id=uid('PFC13'),target=tonumber(target),unit=unit,actor=actor,risk=twin.v13.continuumRisk,resilience=twin.v13.resilienceScore,destination=twin.v13.recommendedDestination,monitoring={'vitals','bleeding','temperature','mental_status','medications'},sustainmentMinutes=math.max(30,math.floor((twin.v13.transferRisk or 0)*2)),status='active',createdAt=os.time()};store.plans[item.id]=item;return true,item end)

exports('CreateContinuumHandoffV13', function(target,fromUnit,toFacility,actor) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('HOF13'),target=tonumber(target),fromUnit=fromUnit,toFacility=toFacility,actor=actor,situation={risk=twin.v13.continuumRisk,command=twin.v13.commandLevel},assessment={clot=twin.hemostasisV13.clotStrength,toxicity=twin.pharmacologyV13.toxicityRisk,infection=twin.immuneV13.infectionProbability},recommendation={destination=twin.v13.recommendedDestination,team=twin.v13.recommendedTeam},readBack=false,createdAt=os.time()};store.handoffs[item.id]=item;return true,item end)

exports('ScoreCrewReadinessV13', function(crew,equipment,fatigue) local score=clamp((tonumber(crew)or 0)*.4+(tonumber(equipment)or 0)*.4+(100-(tonumber(fatigue)or 0))*.2,0,100);local item={id=uid('CRW13'),score=math.floor(score),status=score>=80 and'ready'or score>=60 and'limited'or'out_of_service',createdAt=os.time()};store.readiness[item.id]=item;return item end)

exports('GetV13EMSBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); print('[dpn-medical-ems] v13 continuum-command operations active') end)
