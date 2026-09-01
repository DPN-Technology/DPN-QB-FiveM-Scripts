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

local authorizations, forecasts, packets, appeals = {}, {}, {}, {}
exports('CreateComplexCareAuthorizationV12',function(target,service,payer,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('AUTH12'),target=tonumber(target),service=service,payer=payer,actor=actor,medicalNecessity=twin.v12.integratedRisk,levelOfCare=twin.v12.recommendedDestination,supports=twin.organSupportV12.recommendedSupports,status=twin.v12.integratedRisk>=60 and'approved_emergent'or'clinical_review',createdAt=os.time()};authorizations[item.id]=item;return true,item end)
exports('ForecastComplexEpisodeCostV12',function(target,rates)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;rates=type(rates)=='table'and rates or{};local base=tonumber(rates.base)or 1500;local estimate=base+twin.v12.resourceDemand*(tonumber(rates.perIntensity)or 80)+#(twin.organSupportV12.recommendedSupports or{})*(tonumber(rates.perSupport)or 5000);local item={id=uid('COST12'),target=tonumber(target),estimate=math.floor(estimate),resourceDemand=twin.v12.resourceDemand,supports=twin.organSupportV12.recommendedSupports,createdAt=os.time()};forecasts[item.id]=item;return true,item end)
exports('CreateMedicalNecessityPacketV12',function(target,service,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('NEC12'),target=tonumber(target),service=service,actor=actor,evidence={risk=twin.v12.integratedRisk,command=twin.v12.commandLevel,destination=twin.v12.recommendedDestination,recommendations=twin.v12Recommendations,confidence=twin.dataQualityV12.confidence},status='ready',createdAt=os.time()};packets[item.id]=item;return true,item end)
exports('CreateUtilizationAppealV12',function(authorizationId,reason,actor)local item={id=uid('APL12'),authorizationId=authorizationId,reason=reason,actor=actor,status='submitted',createdAt=os.time()};appeals[item.id]=item;return true,item end)
exports('GetV12InsuranceBoard',function()return{version=VERSION,authorizations=authorizations,forecasts=forecasts,packets=packets,appeals=appeals,generatedAt=os.time()}end)
CreateThread(function()Wait(7700);print('[dpn-medical-insurance] v12 complex-care authorization and utilization management active')end)
