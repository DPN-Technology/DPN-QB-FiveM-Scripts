local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local store = { plans={}, handoffs={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('ForecastContinuumCapacityV13', function(facilities,incoming,staffing) local total,occupied=0,0;for _,f in ipairs(facilities or{})do total=total+(tonumber(f.totalBeds)or 0);occupied=occupied+(tonumber(f.occupiedBeds)or 0)end;local occupancy=occupied/math.max(1,total);local staff=(tonumber(staffing and staffing.available)or 0)/math.max(1,tonumber(staffing and staffing.required)or 1);local pressure=clamp(occupancy*60+(1-staff)*25+#(incoming or{})*3,0,100);local item={id=uid('CAP13'),pressure=math.floor(pressure),status=pressure>=85 and'crisis'or pressure>=65 and'surge'or pressure>=40 and'heightened'or'normal',projectedBeds=math.max(0,total-occupied-#(incoming or{})),createdAt=os.time()};store.capacity[item.id]=item;return item end)

exports('MatchContinuumDestinationV13', function(target,facilities) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local ranked={};for _,f in ipairs(facilities or{})do local score=clamp((tonumber(f.capability)or 0)*.45+(tonumber(f.capacity)or 0)*.3+(100-math.min(100,(tonumber(f.etaMinutes)or 60)*2))*.25-(twin.v13.transferRisk or 0)*.15,0,100);ranked[#ranked+1]={facility=f.facility,score=math.floor(score),etaMinutes=f.etaMinutes}end;table.sort(ranked,function(a,b)return a.score>b.score end);local item={id=uid('DST13'),target=tonumber(target),recommended=twin.v13.recommendedDestination,ranked=ranked,createdAt=os.time()};store.destinations[item.id]=item;return true,item end)

exports('CreateVirtualWardV13', function(name,capacity,criteria) local item={id=uid('VWR13'),name=name or'virtual_ward',capacity=tonumber(capacity)or 10,criteria=criteria or{},patients={},status='active',createdAt=os.time()};store.virtualWards[item.id]=item;return true,item end)

exports('GetV13HospitalBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); print('[dpn-medical-hospital] v13 continuum-command operations active') end)
