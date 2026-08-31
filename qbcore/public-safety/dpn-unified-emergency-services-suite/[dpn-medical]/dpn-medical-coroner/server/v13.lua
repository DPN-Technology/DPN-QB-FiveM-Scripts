local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local store = { plans={}, handoffs={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('CreateCausalMortalityReviewV13', function(target,actor) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('MOR13'),target=tonumber(target),actor=actor,causalGraph=twin.causalGraphV13,continuumRisk=twin.v13.continuumRisk,preventability=twin.uncertaintyV13.confidence>=70 and'clinical_review_required'or'insufficient_data',status='open',createdAt=os.time()};store.reviews[item.id]=item;return true,item end)

exports('EstimateDeathWindowV13', function(target,lastKnownAlive) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local minutes=math.max(1,math.floor((100-twin.v13.resilienceScore)*.6));return true,{target=tonumber(target),earliest=(tonumber(lastKnownAlive)or os.time())+minutes*30,latest=(tonumber(lastKnownAlive)or os.time())+minutes*90,confidence=twin.uncertaintyV13.confidence,createdAt=os.time()} end)

exports('AuditEvidenceChainV13', function(caseId,evidence) local item={id=uid('EVD13'),caseId=caseId,evidence=evidence or{},status='verified',createdAt=os.time()};store.evidence[item.id]=item;return true,item end)

exports('GetV13CoronerBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); pcall(function() exports['dpn-medical-core']:RegisterModule('dpn-medical-coroner', VERSION, {'CreateCausalMortalityReviewV13','EstimateDeathWindowV13','AuditEvidenceChainV13'}) end); print('[dpn-medical-coroner] v13 continuum-command operations active') end)
