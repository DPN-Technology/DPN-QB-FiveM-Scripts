local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local store = { plans={}, handoffs={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('ScoreContinuumTransportReadinessV13', function(unit,equipment,crew,fuel) local score=clamp((tonumber(equipment)or 0)*.35+(tonumber(crew)or 0)*.35+(tonumber(fuel)or 0)*.15+15,0,100);local item={id=uid('AMB13'),unit=unit,score=math.floor(score),status=score>=85 and'ready'or score>=65 and'limited'or'out_of_service',createdAt=os.time()};store.readiness[item.id]=item;return item end)

exports('CreateCriticalTransportMissionV13', function(target,unit,destination,actor) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('TX13'),target=tonumber(target),unit=unit,destination=destination or twin.v13.recommendedDestination,actor=actor,transferRisk=twin.v13.transferRisk,team=twin.v13.recommendedTeam,status='assigned',createdAt=os.time()};store.missions[item.id]=item;return true,item end)

exports('RecordFleetDefectV13', function(unit,defect,severity,actor) local item={id=uid('DEF13'),unit=unit,defect=defect,severity=severity or'moderate',actor=actor,status='open',createdAt=os.time()};store.defects[item.id]=item;return true,item end)

exports('GetV13AmbulanceBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); print('[dpn-medical-ambulance] v13 continuum-command operations active') end)
