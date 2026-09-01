local QBCore = exports['qb-core']:GetCoreObject()

local function auth(src) local p=QBCore.Functions.GetPlayer(src); return p and p.PlayerData.job and Config.Jobs[p.PlayerData.job.name] and p.PlayerData.job.onduty~=false end
local function notify(s,m,t) TriggerClientEvent('QBCore:Notify',s,m,t or 'primary',5000) end
local function near(a,b) local x,y=GetPlayerPed(a),GetPlayerPed(b); return x>0 and y>0 and #(GetEntityCoords(x)-GetEntityCoords(y))<=6.0 end
local function perform(src,target,procedureId,part)
    local proc=Config.Procedures[procedureId]; target=tonumber(target)
    if not auth(src) or not target or not proc or not near(src,target) then return false,'Surgery denied' end
    local admission=nil
    if GetResourceState('dpn-medical-hospital')=='started' then pcall(function() admission=exports['dpn-medical-hospital']:GetAdmissionByCitizenId(QBCore.Functions.GetPlayer(target).PlayerData.citizenid) end) end
    if admission and admission.ward~='or' and admission.status~='in_surgery' then return false,'Patient must be in the operating room' end
    part=part or proc.part or 'chest'; local provider=QBCore.Functions.GetPlayer(src).PlayerData.citizenid
    local ok=exports['dpn-medical-core']:TreatPatient(target,part,'surgical_repair',provider)
    if not ok then return false,'Procedure could not repair the selected region' end
    local patient=QBCore.Functions.GetPlayer(target); local cid=patient.PlayerData.citizenid
    MySQL.insert('INSERT INTO dpn_medical_surgeries (patient_cid,surgeon_cid,procedure_id,body_part,status,details) VALUES (?,?,?,?,?,?)',{cid,provider,procedureId,part,'completed',json.encode({minutes=proc.minutes})})
    if GetResourceState('dpn-medical-records')=='started' then pcall(function() exports['dpn-medical-records']:AddEntry(target,'surgery',{procedure=procedureId,part=part,surgeon=provider}) end) end
    if GetResourceState('dpn-medical-billing-plus')=='started' then pcall(function() exports['dpn-medical-billing-plus']:CreateInvoice(target,proc.cost,proc.label,'surgery') end) end
    if GetResourceState('dpn-medical-rehab')=='started' then TriggerEvent('dpn-medical-rehab:server:createAutomaticPlan',target,part,procedureId) end
    return true,proc.label
end
exports('PerformSurgery',perform)
QBCore.Commands.Add('surgery','Perform a configured surgical procedure',{{name='id'},{name='procedure'},{name='part'}},true,function(src,args)
    local ok,msg=perform(src,args[1],args[2],args[3]); notify(src,msg,ok and 'success' or 'error')
end)
