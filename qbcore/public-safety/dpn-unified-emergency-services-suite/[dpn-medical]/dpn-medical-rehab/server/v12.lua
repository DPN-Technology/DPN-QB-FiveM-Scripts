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

local recovery, functionScores, discharge, followup = {}, {}, {}, {}
exports('CreatePostCriticalRecoveryPlanV12',function(target,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('RECOV12'),target=tonumber(target),actor=actor,population=twin.populationV12.group,frailty=twin.recovery and twin.recovery.frailty or 0,resourceDemand=twin.v12.resourceDemand,domains={'mobility','cognition','respiratory','nutrition','self_care'},status='active',createdAt=os.time()};recovery[item.id]=item;return true,item end)
exports('ForecastFunctionalRecoveryV12',function(target,baseline,current,days)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local reserve=twin.cardiovascularV12.cardiacReserve;local score=clamp((tonumber(current)or 0)+(tonumber(days)or 7)*(reserve/100)*3-(twin.recovery and twin.recovery.frailty or 0)*.2,0,100);local item={id=uid('FUNC12'),target=tonumber(target),baseline=baseline,current=current,days=days,predicted=math.floor(score),createdAt=os.time()};functionScores[item.id]=item;return true,item end)
exports('CreateDischargeNetworkPlanV12',function(target,destination,services,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('DIS12'),target=tonumber(target),destination=destination or'home',services=services or{'primary_care','rehab_followup'},actor=actor,barrierScore=twin.recovery and twin.recovery.dischargeBarrierScore or 0,status='planning',createdAt=os.time()};discharge[item.id]=item;return true,item end)
exports('CreateLongitudinalFollowupV12',function(target,schedule,actor)local item={id=uid('FU12'),target=tonumber(target),schedule=schedule or{},actor=actor,status='scheduled',createdAt=os.time()};followup[item.id]=item;return true,item end)
exports('GetV12RehabBoard',function()return{version=VERSION,recovery=recovery,functionScores=functionScores,discharge=discharge,followup=followup,generatedAt=os.time()}end)
CreateThread(function()Wait(8400);print('[dpn-medical-rehab] v12 post-critical recovery and discharge network active')end)
