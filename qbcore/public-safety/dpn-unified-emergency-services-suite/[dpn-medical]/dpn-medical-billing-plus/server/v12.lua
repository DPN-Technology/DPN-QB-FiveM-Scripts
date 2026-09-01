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

local episodes, capture, payerRisk, estimates = {}, {}, {}, {}
exports('CreateComplexCareEpisodeV12',function(target,services,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('EP12'),target=tonumber(target),services=services or{},actor=actor,acuity=twin.v12.commandLevel,resourceDemand=twin.v12.resourceDemand,supports=twin.organSupportV12.recommendedSupports,status='open',createdAt=os.time()};episodes[item.id]=item;return true,item end)
exports('ValidateClinicalChargeCaptureV12',function(episodeId,charges,documentation)local missing={};for _,charge in ipairs(charges or{})do if not(documentation and documentation[charge.code])then missing[#missing+1]=charge.code end end;local item={id=uid('CAP12'),episodeId=episodeId,missingDocumentation=missing,score=math.floor(clamp(100-#missing*15,0,100)),status=#missing==0 and'clean'or'query_required',createdAt=os.time()};capture[item.id]=item;return true,item end)
exports('ForecastPayerRiskV12',function(target,payer,coverage)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local coverageScore=tonumber(coverage and coverage.score)or 50;local risk=clamp(twin.v12.resourceDemand*.45+(100-coverageScore)*.4+#(twin.organSupportV12.recommendedSupports or{})*5,0,100);local item={id=uid('PAY12'),target=tonumber(target),payer=payer,risk=math.floor(risk),status=risk>=70 and'high_denial_risk'or risk>=40 and'review'or'low',createdAt=os.time()};payerRisk[item.id]=item;return true,item end)
exports('CreatePatientEstimateV12',function(target,rates,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;rates=type(rates)=='table'and rates or{};local total=(tonumber(rates.base)or 1000)+twin.v12.resourceDemand*(tonumber(rates.intensity)or 50)+#(twin.organSupportV12.recommendedSupports or{})*(tonumber(rates.support)or 2500);local item={id=uid('EST12'),target=tonumber(target),actor=actor,estimatedTotal=math.floor(total),disclaimer='Estimate only; final charges depend on actual services.',createdAt=os.time()};estimates[item.id]=item;return true,item end)
exports('GetV12BillingBoard',function()return{version=VERSION,episodes=episodes,capture=capture,payerRisk=payerRisk,estimates=estimates,generatedAt=os.time()}end)
CreateThread(function()Wait(8700);print('[dpn-medical-billing-plus] v12 complex-care revenue integrity active')end)
