local VERSION='13.0.0'
local reports={}
local function permitted(src)if src==0 then return true end;if IsPlayerAceAllowed(src,'dpn.medical.admin')then return true end;local ok,c=pcall(function()return exports['qb-core']:GetCoreObject()end);return ok and c and c.Functions and c.Functions.HasPermission and(c.Functions.HasPermission(src,'admin')or c.Functions.HasPermission(src,'god'))or false end
local function call(resource,name,...)local args=table.pack(...);local ok,a,b=pcall(function()local p=exports[resource];local fn=p and p[name];if type(fn)~='function'then error(('missing export %s:%s'):format(resource,name))end;return fn(p,table.unpack(args,1,args.n))end);return ok,a,b end
local tests={
{'dpn-medical-core','RunV13SelfTest'},{'dpn-medical-ems','GetV13EMSBoard'},{'dpn-medical-hospital','GetV13HospitalBoard'},
{'dpn-medical-surgery','GetV13SurgeryBoard'},{'dpn-medical-radiology','GetV13RadiologyBoard'},{'dpn-medical-pharmacy','GetV13PharmacyBoard'},
{'dpn-medical-records','GetV13RecordsBoard'},{'dpn-medical-coroner','GetV13CoronerBoard'},{'dpn-medical-insurance','GetV13InsuranceBoard'},
{'dpn-medical-training','GetV13TrainingBoard'},{'dpn-medical-disease','GetV13DiseaseBoard'},{'dpn-medical-ambulance','GetV13AmbulanceBoard'},
{'dpn-medical-ai','GetV13AIBoard'},{'dpn-medical-dispatch','GetV13DispatchBoard'},{'dpn-medical-icu','GetV13ICUBoard'},
{'dpn-medical-rehab','GetV13RehabBoard'},{'dpn-medical-lifepak','GetV13LifepakBoard'},{'dpn-medical-inventory','GetV13InventoryBoard'},
{'dpn-medical-billing-plus','GetV13BillingBoard'} }
exports('RunContinuumNetworkTestV13',function(actor)local report={id=('V13TEST-%s-%04d'):format(os.time(),math.random(0,9999)),actor=actor,modules={},passed=0,failed=0,startedAt=os.time()};for _,t in ipairs(tests)do local resource,name=t[1],t[2];local started=GetResourceState(resource)=='started';local ok,result,detail=false,nil,nil;if started then ok,result,detail=call(resource,name)end;local pass=started and ok and type(result)=='table'and result.passed~=false;report.modules[#report.modules+1]={resource=resource,exportName=name,started=started,passed=pass,version=GetResourceMetadata(resource,'version',0),detail=pass and nil or tostring(detail or result)};if pass then report.passed=report.passed+1 else report.failed=report.failed+1 end end;report.completedAt=os.time();report.success=report.failed==0;reports[report.id]=report;return report end)
exports('GetContinuumNetworkOperationsV13',function()local ok,data=call('dpn-medical-core','GetV13OperationalDashboard');return ok and type(data)=='table'and data or{version=VERSION,patients={},critical=0,lowConfidence=0,coagulopathy=0,toxicity=0,infection=0,prolongedCare=0}end)
exports('GetContinuumNetworkTestReportsV13',function()return reports end)
RegisterCommand('medv13systemtest',function(src)if not permitted(src)then return end;local report=exports['dpn-medical-admin-tools']:RunContinuumNetworkTestV13(src);local msg=('v13 continuum network test: %s passed, %s failed, success=%s'):format(report.passed,report.failed,tostring(report.success));if src==0 then print(msg)else TriggerClientEvent('chat:addMessage',src,{args={'DPN Medical v13',msg}})end end,false)
