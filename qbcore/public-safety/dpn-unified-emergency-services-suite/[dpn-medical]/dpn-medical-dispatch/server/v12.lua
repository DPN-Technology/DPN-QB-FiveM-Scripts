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

local incidents, assets, command, sla = {}, {}, {}, {}
local function bridge(event,payload) TriggerEvent('dpn-dispatch-system:server:'..event,payload);TriggerEvent('dpn-dispatch:server:'..event,payload) end
exports('CreateRegionalMedicalIncidentV12',function(target,location,caller)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('CAD12'),target=tonumber(target),location=location,caller=caller,priority=twin.v12.networkPriority,commandLevel=twin.v12.commandLevel,risk=twin.v12.integratedRisk,population=twin.populationV12.group,special=twin.populationV12.specialPopulations,requiredCapabilities=twin.organSupportV12.recommendedSupports,destination=twin.v12.recommendedDestination,status='pending',createdAt=os.time()};incidents[item.id]=item;bridge('regionalMedicalIncident',item);return true,item end)
exports('RecommendRegionalAssetsV12',function(incidentId,units,facilities)local incident=incidents[tostring(incidentId)];if not incident then return false,'Incident not found.'end;local rankedUnits={};for _,u in ipairs(units or{})do local score=clamp((tonumber(u.readiness)or 0)*.35+(tonumber(u.capabilityMatch)or 0)*.35+(100-math.min(100,(tonumber(u.etaMinutes)or 30)*3))*.3,0,100);rankedUnits[#rankedUnits+1]={unit=u.unit,score=math.floor(score),etaMinutes=u.etaMinutes}end;table.sort(rankedUnits,function(a,b)return a.score>b.score end);local item={id=uid('ASSET12'),incidentId=incidentId,units=rankedUnits,facilities=facilities or{},createdAt=os.time()};assets[item.id]=item;return true,item end)
exports('EscalateRegionalMedicalCommandV12',function(incidentId,level,reason,actor)local item={id=uid('CMD12'),incidentId=incidentId,level=level or'regional',reason=reason,actor=actor,status='active',channels={'medical_command','hospital_coordination','mutual_aid'},createdAt=os.time()};command[item.id]=item;bridge('regionalMedicalCommand',item);return true,item end)
exports('TrackMedicalSLAV12',function(incidentId,timestamps)local t=timestamps or{};local response=(tonumber(t.arrived)or os.time())-(tonumber(t.created)or os.time());local transport=(tonumber(t.departed)or os.time())-(tonumber(t.arrived)or os.time());local item={id=uid('SLA12'),incidentId=incidentId,responseSeconds=math.max(0,response),sceneSeconds=math.max(0,transport),status=response<=480 and'within_standard'or'escalation_required',createdAt=os.time()};sla[item.id]=item;return true,item end)
exports('GetV12DispatchBoard',function()return{version=VERSION,incidents=incidents,assets=assets,command=command,sla=sla,generatedAt=os.time()}end)
CreateThread(function()Wait(8200);print('[dpn-medical-dispatch] v12 regional medical command and asset matching active')end)
