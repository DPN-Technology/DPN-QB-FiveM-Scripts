local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local function fallbackDispatchResource()
    local external = Config and Config.ExternalDispatch or nil
    local resources = external and external.resources or nil
    if type(resources) == 'table' then
        for _, resource in ipairs(resources) do
            if type(resource) == 'string' and resource ~= '' then
                return resource
            end
        end
    end
    return 'dpn-dispatch-system'
end
local function bridge(event,payload)
    local router = DPNMedicalDispatchCompatBridge
    if router and type(router.Route) == 'function' then
        return router.Route(event, payload)
    end
    local fallback = fallbackDispatchResource()
    TriggerEvent(('%s:server:%s'):format(fallback, tostring(event)), payload)
    return false, 'legacy-fallback'
end
local store = { plans={}, handoffs={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('CreateContinuumCommandCallV13', function(target,location,caller) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('CAD13'),target=tonumber(target),location=location,caller=caller,priority=twin.v13.networkPriority,risk=twin.v13.continuumRisk,destination=twin.v13.recommendedDestination,team=twin.v13.recommendedTeam,status='pending',createdAt=os.time()};store.calls[item.id]=item;bridge('medicalContinuumCall',item);return true,item end)

exports('RecommendContinuumAssetsV13', function(callId,units) local call=store.calls[tostring(callId)];if not call then return false,'Call not found.'end;local ranked={};for _,u in ipairs(units or{})do local score=clamp((tonumber(u.readiness)or 0)*.45+(tonumber(u.capability)or 0)*.35+(100-math.min(100,(tonumber(u.etaMinutes)or 30)*3))*.2,0,100);ranked[#ranked+1]={unit=u.unit,score=math.floor(score),etaMinutes=u.etaMinutes}end;table.sort(ranked,function(a,b)return a.score>b.score end);local item={id=uid('AST13'),callId=callId,ranked=ranked,createdAt=os.time()};store.assets[item.id]=item;return true,item end)

exports('EscalateRegionalSurgeV13', function(region,level,reason,actor) local item={id=uid('SUR13'),region=region,level=level or'regional',reason=reason,actor=actor,status='active',createdAt=os.time()};store.surges[item.id]=item;bridge('medicalSurge',item);return true,item end)

exports('GetV13DispatchBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); print('[dpn-medical-dispatch] v13 continuum-command operations active') end)
