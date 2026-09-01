local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local store = { plans={}, handoffs={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('RunPopulationPKReviewV13', function(target,medication,dose,route) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local risk=clamp(twin.pharmacologyV13.toxicityRisk*.55+twin.pharmacologyV13.renalAccumulationRisk*.25+twin.pharmacologyV13.hepaticAccumulationRisk*.2,0,100);local item={id=uid('PK13'),target=tonumber(target),medication=medication,dose=dose,route=route,risk=math.floor(risk),status=risk>=70 and'hard_stop'or risk>=45 and'pharmacist_review'or'approved',createdAt=os.time()};store.reviews[item.id]=item;return item.status~='hard_stop',item end)

exports('CreateClosedLoopMedicationPlanV13', function(target,medications,actor) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('MED13'),target=tonumber(target),medications=medications or{},actor=actor,monitoring={'renal_function','hepatic_function','qtc','respiratory_rate','sedation'},toxicityRisk=twin.pharmacologyV13.toxicityRisk,status='planned',createdAt=os.time()};store.plans[item.id]=item;return true,item end)

exports('AuditControlledMedicationV13', function(patientCid,medication,amount,actor) local item={id=uid('CTL13'),patientCid=patientCid,medication=medication,amount=amount,actor=actor,status='logged',createdAt=os.time()};store.controlled[item.id]=item;return true,item end)

exports('GetV13PharmacyBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); print('[dpn-medical-pharmacy] v13 continuum-command operations active') end)
