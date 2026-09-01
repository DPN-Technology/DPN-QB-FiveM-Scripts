local VERSION='9.0.0'
local reports={}
local function permitted(src)
 if src==0 then return true end;if IsPlayerAceAllowed(src,'dpn.medical.admin')then return true end
 local ok,core=pcall(function()return exports['qb-core']:GetCoreObject()end);return ok and core and core.Functions.HasPermission and(core.Functions.HasPermission(src,'admin')or core.Functions.HasPermission(src,'god'))or false
end
exports('RunAdaptiveNetworkTestV9',function(actor)
 local resources={'dpn-medical-core','dpn-medical-ems','dpn-medical-hospital','dpn-medical-surgery','dpn-medical-radiology','dpn-medical-pharmacy','dpn-medical-records','dpn-medical-coroner','dpn-medical-insurance','dpn-medical-training','dpn-medical-disease','dpn-medical-ambulance','dpn-medical-ai','dpn-medical-dispatch','dpn-medical-icu','dpn-medical-rehab','dpn-medical-lifepak','dpn-medical-inventory','dpn-medical-billing-plus','dpn-medical-admin-tools'}
 local report={id=('V9TEST-%s'):format(os.time()),actor=actor,modules={},passed=0,failed=0,startedAt=os.time()}
 for _,name in ipairs(resources)do local started=GetResourceState(name)=='started';local version=GetResourceMetadata(name,'version',0);report.modules[#report.modules+1]={name=name,started=started,version=version};if started and tostring(version)=='9.0.0'then report.passed=report.passed+1 else report.failed=report.failed+1 end end
 local ok,self=pcall(function()return exports['dpn-medical-core']:RunV9SelfTest()end);report.core=ok and self or{passed=false,error=tostring(self)};if not report.core.passed then report.failed=report.failed+1 end;report.completedAt=os.time();reports[report.id]=report;return report
end)
exports('GetAdaptiveOperationsV9',function()local ok,data=pcall(function()return exports['dpn-medical-core']:GetV9OperationalDashboard()end);return ok and data or{version=VERSION,patients={},critical=0,declining=0,resilienceQueueDepth=0}end)
RegisterCommand('medv9test',function(src)if not permitted(src)then return end;local r=exports['dpn-medical-admin-tools']:RunAdaptiveNetworkTestV9(src);local msg=('v9 network test: %s passed, %s failed, core=%s'):format(r.passed,r.failed,tostring(r.core and r.core.passed));if src==0 then print(msg)else TriggerClientEvent('chat:addMessage',src,{args={'DPN Medical v9',msg}})end end,false)
