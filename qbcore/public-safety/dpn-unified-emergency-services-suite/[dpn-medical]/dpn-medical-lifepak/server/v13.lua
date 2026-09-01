local VERSION = '13.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function clamp(v,lo,hi)v=tonumber(v)or lo;if v<lo then return lo elseif v>hi then return hi else return v end end
local function core(name, ...)
    local args=table.pack(...);local ok,a,b=pcall(function()local p=exports['dpn-medical-core'];local fn=p and p[name];if type(fn)~='function'then error(('missing core export %s'):format(name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b
end
local store = { plans={}, handoffs={}, readiness={}, capacity={}, destinations={}, virtualWards={}, sequences={}, checkpoints={}, reviews={}, controlled={}, summaries={}, seals={}, consents={}, evidence={}, authorizations={}, appeals={}, cases={}, scores={}, remediation={}, sourceControl={}, clusters={}, isolation={}, missions={}, defects={}, recommendations={}, bias={}, calls={}, assets={}, surges={}, liberation={}, rounds={}, milestones={}, sessions={}, cpr={}, kits={}, forecasts={}, recalls={}, estimates={}, coding={} }

exports('StartContinuumTelemetryV13', function(target,device,actor) local ok,twin=core('GetV13Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('TEL13'),target=tonumber(target),device=device or'LIFEPAK',actor=actor,risk=twin.v13.continuumRisk,alarms={},status='active',createdAt=os.time()};store.sessions[item.id]=item;return true,item end)

exports('AnalyzeRhythmTrendV13', function(sessionId,samples) local item=store.sessions[tostring(sessionId)];if not item then return false,'Telemetry session not found.'end;local alarms={};for _,s in ipairs(samples or{})do if tonumber(s.hr)and(s.hr<40 or s.hr>150)then alarms[#alarms+1]={type='rate',value=s.hr}end end;item.alarms=alarms;item.lastAnalyzed=os.time();return true,item end)

exports('RecordCPRQualityV13', function(target,rate,depth,fraction) local score=clamp((100-math.abs((tonumber(rate)or 110)-110)*2)*.35+clamp((tonumber(depth)or 5.5)/5.5*100,0,100)*.35+clamp((tonumber(fraction)or .8)*100,0,100)*.3,0,100);local item={id=uid('CPR13'),target=tonumber(target),score=math.floor(score),rate=rate,depth=depth,fraction=fraction,createdAt=os.time()};store.cpr[item.id]=item;return true,item end)

exports('GetV13LifepakBoard', function() return { version=VERSION, passed=true, store=store, generatedAt=os.time() } end)

CreateThread(function() Wait(7036); print('[dpn-medical-lifepak] v13 continuum-command operations active') end)
