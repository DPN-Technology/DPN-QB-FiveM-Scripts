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

local consensus, explanations, calibration, governance = {}, {}, {}, {}
exports('CreateClinicalConsensusV12',function(target,models,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local votes={};for _,m in ipairs(models or{})do votes[#votes+1]={model=m.name or'unknown',risk=tonumber(m.risk)or twin.v12.integratedRisk,confidence=tonumber(m.confidence)or 50}end;local weighted,total=0,0;for _,v in ipairs(votes)do weighted=weighted+v.risk*v.confidence;total=total+v.confidence end;local risk=total>0 and weighted/total or twin.v12.integratedRisk;local item={id=uid('AI12'),target=tonumber(target),actor=actor,votes=votes,consensusRisk=math.floor(risk),coreRisk=twin.v12.integratedRisk,disagreement=math.floor(math.abs(risk-twin.v12.integratedRisk)),status='advisory',createdAt=os.time()};consensus[item.id]=item;return true,item end)
exports('ExplainV12Risk',function(target,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local factors={{name='organ_support',value=#(twin.organSupportV12.recommendedSupports or{})*15},{name='cardiovascular',value=100-twin.cardiovascularV12.cardiacReserve},{name='ventilation',value=twin.ventilationV12.ventilatorInjuryRisk},{name='special_population',value=twin.v12.specialPopulationRisk},{name='data_uncertainty',value=100-twin.dataQualityV12.confidence}};table.sort(factors,function(a,b)return a.value>b.value end);local item={id=uid('EXP12'),target=tonumber(target),actor=actor,risk=twin.v12.integratedRisk,factors=factors,recommendations=twin.v12Recommendations,status='explainable',createdAt=os.time()};explanations[item.id]=item;return true,item end)
exports('CalibrateV12Outcome',function(caseId,predicted,observed,actor)local errorValue=math.abs((tonumber(predicted)or 0)-(tonumber(observed)or 0));local item={id=uid('CAL12'),caseId=caseId,predicted=predicted,observed=observed,error=errorValue,actor=actor,status='recorded',createdAt=os.time()};calibration[item.id]=item;return true,item end)
exports('CreateAIGovernanceReviewV12',function(recommendationId,reviewer,decision,notes)local item={id=uid('GOV12'),recommendationId=recommendationId,reviewer=reviewer,decision=decision,notes=notes,status='complete',createdAt=os.time()};governance[item.id]=item;return true,item end)
exports('GetV12AIBoard',function()return{version=VERSION,consensus=consensus,explanations=explanations,calibration=calibration,governance=governance,generatedAt=os.time()}end)
CreateThread(function()Wait(8100);print('[dpn-medical-ai] v12 consensus, explainability and governance active')end)
