local VERSION = '12.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function core(name, ...)
    local args = table.pack(...)
    local ok, a, b = pcall(function()
        local proxy = exports['dpn-medical-core']
        local fn = proxy and proxy[name]
        if type(fn) ~= 'function' then error(('missing core export %s'):format(name)) end
        return fn(proxy, table.unpack(args, 1, args.n))
    end)
    return ok, a, b
end
local function clamp(v, lo, hi) v=tonumber(v) or lo; if v<lo then return lo elseif v>hi then return hi else return v end end

local reviews, windows, learning, evidence = {}, {}, {}, {}
exports('CreateForensicPhysiologyReviewV12',function(target,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('FOR12'),target=tonumber(target),actor=actor,physiology={risk=twin.v12.integratedRisk,cardiovascular=twin.cardiovascularV12,ventilation=twin.ventilationV12,organSupport=twin.organSupportV12},status='open',createdAt=os.time()};reviews[item.id]=item;return true,item end)
exports('EstimateDeathWindowV12',function(target,lastKnownAlive,foundAt,environment)local duration=math.max(0,(tonumber(foundAt)or os.time())-(tonumber(lastKnownAlive)or os.time()));local uncertainty=math.max(60,math.floor(duration*.25));local item={id=uid('TOD12'),target=tonumber(target),estimatedAt=(tonumber(foundAt)or os.time())-math.floor(duration*.5),uncertaintySeconds=uncertainty,environment=environment or{},status='estimate_only',createdAt=os.time()};windows[item.id]=item;return true,item end)
exports('CreateMortalityLearningCaseV12',function(target,preventability,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('MORT12'),target=tonumber(target),preventability=preventability or'undetermined',actor=actor,careGaps=twin.v12Recommendations,confidence=twin.dataQualityV12.confidence,status='review',createdAt=os.time()};learning[item.id]=item;return true,item end)
exports('RecordForensicEvidenceV12',function(caseId,evidenceType,custodian,metadata)local item={id=uid('EVID12'),caseId=caseId,evidenceType=evidenceType,custodian=custodian,metadata=metadata or{},chain={{event='collected',by=custodian,at=os.time()}},createdAt=os.time()};evidence[item.id]=item;return true,item end)
exports('GetV12CoronerBoard',function()return{version=VERSION,reviews=reviews,windows=windows,learning=learning,evidence=evidence,generatedAt=os.time()}end)
CreateThread(function()Wait(7600);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-coroner',VERSION,{'forensic_physiology','death_window_estimation','mortality_learning','evidence_chain'})end);print('[dpn-medical-coroner] v12 forensic physiology and mortality learning active')end)
