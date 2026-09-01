local QBCore = exports['qb-core']:GetCoreObject()

local function auth(src) local p=QBCore.Functions.GetPlayer(src); return p and p.PlayerData.job and Config.Jobs[p.PlayerData.job.name] end
local function prescribe(src,target,drugId,dose)
    target=tonumber(target); local drug=Config.Drugs[drugId]
    if not auth(src) or not target or not drug then return false,'Prescription denied' end
    local provider=QBCore.Functions.GetPlayer(src); local patient=QBCore.Functions.GetPlayer(target); if not patient then return false,'Patient offline' end
    local rx=MySQL.insert.await('INSERT INTO dpn_medical_prescriptions (patient_cid,prescriber_cid,drug_id,dose,route,status) VALUES (?,?,?,?,?,?)',{patient.PlayerData.citizenid,provider.PlayerData.citizenid,drugId,dose or drug.dose,drug.route,'active'})
    exports['dpn-medical-core']:AddMedication(target,drugId,{dose=dose or drug.dose,route=drug.route,by=provider.PlayerData.citizenid,metadata={prescriptionId=rx}})
    if drugId=='amoxicillin' then exports['dpn-medical-core']:TreatPatient(target,nil,'antibiotics',provider.PlayerData.citizenid) end
    if GetResourceState('dpn-medical-inventory')=='started' then pcall(function() exports['dpn-medical-inventory']:GiveMedicalItem(target,drug.item,1,{prescriptionId=rx}) end) end
    if GetResourceState('dpn-medical-billing-plus')=='started' then pcall(function() exports['dpn-medical-billing-plus']:CreateInvoice(target,drug.cost,drug.label,'pharmacy') end) end
    return true,('Prescription #%s issued for %s'):format(rx,drug.label)
end
exports('Prescribe',prescribe)
QBCore.Commands.Add('prescribe','Issue a medication prescription',{{name='id'},{name='drug'},{name='dose'}},true,function(src,args)
    local ok,msg=prescribe(src,args[1],args[2],args[3]); TriggerClientEvent('QBCore:Notify',src,msg,ok and 'success' or 'error',5000)
end)
