local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local store = { plans={}, handoffs={}, acknowledgments={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('BuildDiagnosticSequenceV13', function(target,question,actor) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local sequence={};if twin.hemostasisV13.hemorrhageRisk>=60 then sequence={'FAST','CT_angiography','interventional_radiology'}elseif twin.immuneV13.infectionProbability>=55 then sequence={'source_ultrasound','contrast_CT'}else sequence={'targeted_xray','CT_as_indicated'}end;local item={id=uid('DX13'),target=tonumber(target),question=question,actor=actor,sequence=sequence,transportRisk=twin.v13.transferRisk,status='ordered',createdAt=os.time()};store.sequences[item.id]=item;return true,item end)

exports('ScoreContrastSafetyV13', function(target,contrastType) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local risk=clamp((twin.pharmacologyV13.renalAccumulationRisk or 0)*.65+(twin.v13.transferRisk or 0)*.35,0,100);return true,{target=tonumber(target),contrastType=contrastType,risk=math.floor(risk),approved=risk<65,createdAt=os.time()} end)

exports('CloseCriticalResultLoopV13', function(resultId,recipient,readBack) local item={id=uid('ACK13'),resultId=resultId,recipient=recipient,readBack=readBack,status='acknowledged',createdAt=os.time()};store.acknowledgments[item.id]=item;return true,item end)

exports('GetV13RadiologyBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); print('[dpn-medical-radiology] v13 continuum-command operations active') end)
