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

local sequences, physiology, resources, recovery = {}, {}, {}, {}
exports('CreateDamageControlSequenceV12',function(target,actor)local ok,twin=core('GetV12Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end;local need=twin.organSupportV12.damageControlResuscitationNeed;local steps={'hemorrhage_control','contamination_control','temporary_closure','critical_care_resuscitation','planned_relook'};local item={id=uid('DCS12'),target=tonumber(target),actor=actor,need=need,steps=steps,status=need>=55 and'activated'or'candidate',createdAt=os.time()};sequences[item.id]=item;return true,item end)
exports('CalculateOperativePhysiologyV12',function(target,procedure)local ok,twin=core('GetV12Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end;local risk=clamp(twin.v12.integratedRisk*.55+twin.organSupportV12.massiveTransfusionNeed*.2+twin.cardiovascularV12.cardiacReserve*-0.15+30,0,100);local item={id=uid('OP12'),target=tonumber(target),procedure=procedure or'unspecified',operativeRisk=math.floor(risk),damageControlRecommended=twin.organSupportV12.damageControlResuscitationNeed>=55,requiredSupports=twin.organSupportV12.recommendedSupports,dataConfidence=twin.dataQualityV12.confidence,createdAt=os.time()};physiology[item.id]=item;return true,item end)
exports('CreatePerioperativeResourcePlanV12',function(target,rooms,staff,blood,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('RES12'),target=tonumber(target),rooms=rooms or{},staff=staff or{},blood=blood or{},actor=actor,required={'surgeon','anesthesia','nursing','blood_bank','critical_care'},priority=twin.v12.networkPriority,status='reserved',createdAt=os.time()};resources[item.id]=item;return true,item end)
exports('CreatePostoperativeCriticalPlanV12',function(target,procedure,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('PACU12'),target=tonumber(target),procedure=procedure,actor=actor,destination=twin.v12.recommendedDestination,monitoring={'hemodynamics','ventilation','bleeding','pain','neuro'},supports=twin.organSupportV12.recommendedSupports,status='planned',createdAt=os.time()};recovery[item.id]=item;return true,item end)
exports('GetV12SurgeryBoard',function()return{version=VERSION,sequences=sequences,physiology=physiology,resources=resources,recovery=recovery,generatedAt=os.time()}end)
CreateThread(function()Wait(7200);print('[dpn-medical-surgery] v12 damage-control and operative physiology active')end)
