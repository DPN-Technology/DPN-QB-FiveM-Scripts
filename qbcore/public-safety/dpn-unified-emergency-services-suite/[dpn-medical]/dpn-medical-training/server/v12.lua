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

local simulations, scores, remediation, credentials = {}, {}, {}, {}
exports('CreateAdaptiveCriticalSimulationV12',function(scenario,participants,objectives,actor)local item={id=uid('SIM12'),scenario=scenario,participants=participants or{},objectives=objectives or{},actor=actor,status='active',timeline={},createdAt=os.time()};simulations[item.id]=item;return true,item end)
exports('ScoreClinicalDecisionPathV12',function(simulationId,actions,expected)local total=math.max(1,#(expected or{}));local matched=0;for _,e in ipairs(expected or{})do for _,a in ipairs(actions or{})do if a==e then matched=matched+1 break end end end;local item={id=uid('SCORE12'),simulationId=simulationId,score=math.floor(clamp(matched/total*100,0,100)),matched=matched,total=total,status='complete',createdAt=os.time()};scores[item.id]=item;return true,item end)
exports('CreateRemediationPlanV12',function(provider,deficits,educator)local steps={};for _,d in ipairs(deficits or{})do steps[#steps+1]={deficit=d,activity='targeted_simulation',status='assigned'}end;local item={id=uid('REM12'),provider=provider,educator=educator,steps=steps,status='active',createdAt=os.time()};remediation[item.id]=item;return true,item end)
exports('ValidateSpecialPopulationCredentialV12',function(provider,population,records)local valid=false;for _,r in ipairs(records or{})do if r.population==population and r.status=='active'then valid=true break end end;local item={id=uid('CRED12'),provider=provider,population=population,valid=valid,status=valid and'validated'or'missing',createdAt=os.time()};credentials[item.id]=item;return valid,item end)
exports('GetV12TrainingBoard',function()return{version=VERSION,simulations=simulations,scores=scores,remediation=remediation,credentials=credentials,generatedAt=os.time()}end)
CreateThread(function()Wait(7800);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-training',VERSION,{'adaptive_critical_simulations','decision_path_scoring','remediation_plans','special_population_credentials'})end);print('[dpn-medical-training] v12 adaptive critical-care simulation active')end)
