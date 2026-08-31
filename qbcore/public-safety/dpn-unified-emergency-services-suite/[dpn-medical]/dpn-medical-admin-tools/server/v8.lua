local VERSION='8.0.0'
local batchTests={}
local function permitted(src)
    if src==0 then return true end
    if IsPlayerAceAllowed(src,'dpn.medical.admin')then return true end
    local core=exports['qb-core']:GetCoreObject();return core.Functions.HasPermission and(core.Functions.HasPermission(src,'admin')or core.Functions.HasPermission(src,'god'))or false
end
exports('GetPrecisionOperations',function()
    local ok,data=pcall(function()return exports['dpn-medical-core']:GetV8OperationalDashboard()end)
    return ok and data or{version=VERSION,patients={},highRisk=0,simulationsActive=0,circuit={}}
end)
exports('RunPrecisionSystemTest',function(actor)
    local result={id=('V8TEST-%s'):format(os.time()),actor=actor,startedAt=os.time(),modules={},passed=0,failed=0}
    local resources={'dpn-medical-core','dpn-medical-ems','dpn-medical-hospital','dpn-medical-surgery','dpn-medical-radiology','dpn-medical-pharmacy','dpn-medical-records','dpn-medical-coroner','dpn-medical-insurance','dpn-medical-training','dpn-medical-disease','dpn-medical-ambulance','dpn-medical-ai','dpn-medical-dispatch','dpn-medical-icu','dpn-medical-rehab','dpn-medical-lifepak','dpn-medical-inventory','dpn-medical-billing-plus','dpn-medical-admin-tools'}
    for _,name in ipairs(resources)do local started=GetResourceState(name)=='started';result.modules[#result.modules+1]={name=name,started=started,version=GetResourceMetadata(name,'version',0)};if started then result.passed=result.passed+1 else result.failed=result.failed+1 end end
    local ok,selfTest=pcall(function()return exports['dpn-medical-core']:RunV8SelfTest()end);result.coreSelfTest=ok and selfTest or{passed=false,error=tostring(selfTest)};if not result.coreSelfTest.passed then result.failed=result.failed+1 end;result.completedAt=os.time();batchTests[result.id]=result;return result
end)
RegisterCommand('medv8test',function(src)
    if not permitted(src)then return end;local result=exports['dpn-medical-admin-tools']:RunPrecisionSystemTest(src);local message=('v8 test: %s module(s) passed, %s failed, core=%s'):format(result.passed,result.failed,tostring(result.coreSelfTest and result.coreSelfTest.passed));if src==0 then print(message)else TriggerClientEvent('chat:addMessage',src,{args={'DPN Medical v8',message}})end
end,false)
CreateThread(function()Wait(3500);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-admin-tools',VERSION,{'native_mouse_dashboard','precision_operations','batch_self_test','simulation_control','quality_command'})end);print('[dpn-medical-admin-tools] v8 precision operations and full-system self-test active')end)
