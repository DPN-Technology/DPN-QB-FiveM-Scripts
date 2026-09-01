local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local store = { plans={}, handoffs={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('ReserveContinuumKitV13', function(target,kit,location,actor) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('KIT13'),target=tonumber(target),kit=kit or'critical_care',location=location or'main',actor=actor,risk=twin.v13.continuumRisk,status='reserved',createdAt=os.time()};store.kits[item.id]=item;return true,item end)

exports('ForecastSupplyBurnV13', function(census,hours,usage) local demand={};for item,rate in pairs(usage or{})do demand[item]=math.ceil((tonumber(rate)or 0)*(tonumber(census)or 0)*(tonumber(hours)or 1))end;local result={id=uid('SUP13'),census=census,hours=hours,demand=demand,createdAt=os.time()};store.forecasts[result.id]=result;return result end)

exports('CreateRecallActionV13', function(lot,item,locations,actor) local row={id=uid('RCL13'),lot=lot,item=item,locations=locations or{},actor=actor,status='active',createdAt=os.time()};store.recalls[row.id]=row;return true,row end)

exports('GetV13InventoryBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); print('[dpn-medical-inventory] v13 continuum-command operations active') end)
