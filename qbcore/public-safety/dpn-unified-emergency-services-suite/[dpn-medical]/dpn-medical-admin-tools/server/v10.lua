local VERSION='10.0.0'
local reports={}
local function permitted(src)
 if src==0 then return true end
 if IsPlayerAceAllowed(src,'dpn.medical.admin')then return true end
 local ok,core=pcall(function()return exports['qb-core']:GetCoreObject()end)
 return ok and core and core.Functions.HasPermission and(core.Functions.HasPermission(src,'admin')or core.Functions.HasPermission(src,'god'))or false
end
local function call(resource,name,...)
 local args=table.pack(...);local ok,a,b=pcall(function()local proxy=exports[resource];return proxy[name](proxy,table.unpack(args,1,args.n))end);return ok,a,b
end
exports('RunCriticalCommandTestV10',function(actor)
 local resources={'dpn-medical-core','dpn-medical-ems','dpn-medical-hospital','dpn-medical-surgery','dpn-medical-radiology','dpn-medical-pharmacy','dpn-medical-records','dpn-medical-coroner','dpn-medical-insurance','dpn-medical-training','dpn-medical-disease','dpn-medical-ambulance','dpn-medical-ai','dpn-medical-dispatch','dpn-medical-icu','dpn-medical-rehab','dpn-medical-lifepak','dpn-medical-inventory','dpn-medical-billing-plus','dpn-medical-admin-tools'}
 local report={id=('V10TEST-%s'):format(os.time()),actor=actor,modules={},passed=0,failed=0,startedAt=os.time()}
 for _,name in ipairs(resources)do local started=GetResourceState(name)=='started';local version=GetResourceMetadata(name,'version',0);report.modules[#report.modules+1]={name=name,started=started,version=version};if started and tostring(version)=='10.0.0'then report.passed=report.passed+1 else report.failed=report.failed+1 end end
 local ok,self=call('dpn-medical-core','RunV10SelfTest');report.core=ok and self or{passed=false,error=tostring(self)};if not report.core.passed then report.failed=report.failed+1 end;report.completedAt=os.time();reports[report.id]=report;return report
end)
exports('GetCriticalCommandOperationsV10',function()local ok,data=call('dpn-medical-core','GetV10OperationalDashboard');return ok and data or{version=VERSION,patients={},critical=0,imminentArrest=0,careGaps=0,activeCommands=0}end)
RegisterCommand('medv10test',function(src)if not permitted(src)then return end;local r=exports['dpn-medical-admin-tools']:RunCriticalCommandTestV10(src);local msg=('v10 command test: %s passed, %s failed, core=%s'):format(r.passed,r.failed,tostring(r.core and r.core.passed));if src==0 then print(msg)else TriggerClientEvent('chat:addMessage',src,{args={'DPN Medical v10',msg}})end end,false)
