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

local isolation, outbreaks, exposures, stewardship = {}, {}, {}, {}
exports('CreateSpecialPopulationIsolationPlanV12',function(target,pathogen,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('ISO12'),target=tonumber(target),pathogen=pathogen,actor=actor,population=twin.populationV12.group,priority=twin.v12.networkPriority,precautions={'standard','contact','droplet'},status='active',createdAt=os.time()};isolation[item.id]=item;return true,item end)
exports('ForecastOutbreakPressureV12',function(cases,beds,staff,hours)local caseCount=#(cases or{});local capacity=math.max(1,tonumber(beds)or 1);local staffRatio=clamp(tonumber(staff)or 1,0,2);local pressure=clamp(caseCount/capacity*60+(1-staffRatio)*30+(tonumber(hours)or 24)/24*10,0,100);local item={id=uid('OUT12'),pressure=math.floor(pressure),status=pressure>=80 and'critical'or pressure>=60 and'high'or pressure>=35 and'moderate'or'controlled',projectedHours=tonumber(hours)or 24,createdAt=os.time()};outbreaks[item.id]=item;return item end)
exports('CreateExposureResponseV12',function(indexCase,contacts,pathogen,actor)local item={id=uid('EXP12'),indexCase=indexCase,contacts=contacts or{},pathogen=pathogen,actor=actor,status='active',actions={'notify','risk_stratify','test','monitor','isolate_if_indicated'},createdAt=os.time()};exposures[item.id]=item;return true,item end)
exports('CreateAntimicrobialCommandV12',function(target,agent,indication,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('AMS12'),target=tonumber(target),agent=agent,indication=indication,actor=actor,infectionProbability=twin.infection and twin.infection.probability or 0,status='pending_culture_review',createdAt=os.time()};stewardship[item.id]=item;return true,item end)
exports('GetV12DiseaseBoard',function()return{version=VERSION,isolation=isolation,outbreaks=outbreaks,exposures=exposures,stewardship=stewardship,generatedAt=os.time()}end)
CreateThread(function()Wait(7900);print('[dpn-medical-disease] v12 isolation and outbreak command active')end)
