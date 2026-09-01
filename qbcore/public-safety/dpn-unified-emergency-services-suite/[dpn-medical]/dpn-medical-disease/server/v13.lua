local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local store = { plans={}, handoffs={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('BuildSourceControlPlanV13', function(target,actor) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('SRC13'),target=tonumber(target),actor=actor,probability=twin.immuneV13.infectionProbability,urgency=twin.immuneV13.sourceControlUrgency,isolation=twin.immuneV13.isolationNeed,steps={'cultures','antimicrobial_review','imaging','device_review','source_control'},status='planned',createdAt=os.time()};store.sourceControl[item.id]=item;return true,item end)

exports('CreateExposureClusterV13', function(indexPatient,contacts,pathogen) local item={id=uid('CLU13'),indexPatient=indexPatient,contacts=contacts or{},pathogen=pathogen,status='investigating',createdAt=os.time()};store.clusters[item.id]=item;return true,item end)

exports('AuditIsolationV13', function(patientCid,observations) local score=100;for _,o in ipairs(observations or{})do if o.compliant==false then score=score-20 end end;local item={id=uid('ISO13'),patientCid=patientCid,score=math.max(0,score),status=score>=80 and'compliant'or'corrective_action',createdAt=os.time()};store.isolation[item.id]=item;return true,item end)

exports('GetV13DiseaseBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); print('[dpn-medical-disease] v13 continuum-command operations active') end)
