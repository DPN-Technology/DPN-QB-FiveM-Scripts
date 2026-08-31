local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local store = { plans={}, handoffs={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('CreateDamageControlSequenceV13', function(target,actor) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('DCS13'),target=tonumber(target),actor=actor,priority=twin.v13.networkPriority,hemorrhage=twin.hemostasisV13.hemorrhageRisk,clot=twin.hemostasisV13.clotStrength,phases={'hemorrhage_control','contamination_control','temporary_closure','icu_resuscitation','definitive_repair'},status='planned',createdAt=os.time()};store.sequences[item.id]=item;return true,item end)

exports('CalculateOperativeRiskV13', function(target,procedure) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local risk=clamp(twin.v13.continuumRisk*.45+(100-twin.v13.resilienceScore)*.25+twin.hemostasisV13.hemorrhageRisk*.3,0,100);return true,{target=tonumber(target),procedure=procedure,risk=math.floor(risk),classification=risk>=80 and'extreme'or risk>=60 and'high'or risk>=35 and'moderate'or'low',createdAt=os.time()} end)

exports('RecordSurgicalCheckpointV13', function(caseId,checkpoint,actor,data) local item={id=uid('CHK13'),caseId=caseId,checkpoint=checkpoint,actor=actor,data=data or{},createdAt=os.time()};store.checkpoints[item.id]=item;return true,item end)

exports('GetV13SurgeryBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); pcall(function() exports['dpn-medical-core']:RegisterModule('dpn-medical-surgery', VERSION, {'CreateDamageControlSequenceV13','CalculateOperativeRiskV13','RecordSurgicalCheckpointV13'}) end); print('[dpn-medical-surgery] v13 continuum-command operations active') end)
