local VERSION='4.0.0'
local QBCore=exports['qb-core']:GetCoreObject()
local function permitted(src)
    if src==0 then return true end
    if IsPlayerAceAllowed(src,'dpn.medical.admin') then return true end
    return QBCore.Functions.HasPermission and (QBCore.Functions.HasPermission(src,'admin') or QBCore.Functions.HasPermission(src,'god')) or false
end
exports('GetMedicalCommandCenter',function()
    local ok,data=pcall(function()return exports['dpn-medical-core']:GetOperationalDashboard()end)
    return ok and data or {version='unavailable',patients={},quality={}}
end)
exports('RunMedicalSystemAudit',function()
    local modules={};local names={'dpn-medical-core','dpn-medical-ems','dpn-medical-hospital','dpn-medical-surgery','dpn-medical-radiology','dpn-medical-pharmacy','dpn-medical-records','dpn-medical-coroner','dpn-medical-insurance','dpn-medical-training','dpn-medical-disease','dpn-medical-ambulance','dpn-medical-ai','dpn-medical-dispatch','dpn-medical-icu','dpn-medical-rehab','dpn-medical-lifepak','dpn-medical-inventory','dpn-medical-billing-plus','dpn-medical-admin-tools'};local healthy=0
    for _,name in ipairs(names)do local state=GetResourceState(name);modules[#modules+1]={name=name,state=state,version=GetResourceMetadata(name,'version',0)};if state=='started'then healthy=healthy+1 end end
    return {healthy=healthy,total=#names,modules=modules,generatedAt=os.time()}
end)
RegisterCommand('medcommand',function(src)
    if not permitted(src)then return end;local data=exports['dpn-medical-admin-tools']:GetMedicalCommandCenter();local message=('Patients %s | Orders %s | Alerts raised %s | Handoffs %s'):format(#(data.patients or{}),data.quality and data.quality.ordersCreated or 0,data.quality and data.quality.alertsRaised or 0,data.quality and data.quality.handoffsCreated or 0);if src==0 then print('[DPN Medical Command] '..message)else TriggerClientEvent('chat:addMessage',src,{args={'DPN Medical Command',message}})end
end,false)
RegisterCommand('medsystemaudit',function(src)
    if not permitted(src)then return end;local data=exports['dpn-medical-admin-tools']:RunMedicalSystemAudit();local message=('Medical modules healthy: %s/%s'):format(data.healthy,data.total);if src==0 then print(message)else TriggerClientEvent('chat:addMessage',src,{args={'DPN Medical Audit',message}})end
end,false)
CreateThread(function()Wait(2500);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-admin-tools',VERSION,{'native_mouse_dashboard','secured_actions','clinical_command_center','system_audit','quality_metrics'})end);print('[dpn-medical-admin-tools] v4.0.0 clinical command-center and v6 secured actions active')end)
