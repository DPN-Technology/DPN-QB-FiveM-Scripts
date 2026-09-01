local QBCore = exports['qb-core']:GetCoreObject()

local function create(target,amount,reason,category,issuer)
    target=tonumber(target); amount=math.max(0,math.floor(tonumber(amount) or 0)); local p=QBCore.Functions.GetPlayer(target); if not p or amount<=0 then return false end
    local covered,patientAmount=0,amount; local invoiceId=MySQL.insert.await('INSERT INTO dpn_medical_invoices (patient_cid,issuer_cid,category,reason,total_amount,covered_amount,patient_amount,status) VALUES (?,?,?,?,?,?,?,?)',{p.PlayerData.citizenid,issuer,category or 'medical',reason or 'Medical services',amount,0,amount,'unpaid'})
    if GetResourceState('dpn-medical-insurance')=='started' then local claim,cov,patient=exports['dpn-medical-insurance']:SubmitClaim(target,invoiceId,amount,category or 'medical'); covered,patientAmount=cov,patient; MySQL.update('UPDATE dpn_medical_invoices SET covered_amount=?,patient_amount=? WHERE id=?',{covered,patientAmount,invoiceId}) end
    TriggerClientEvent('QBCore:Notify',target,('Medical invoice #%s: $%s after coverage'):format(invoiceId,patientAmount),'primary',8000); return invoiceId,patientAmount
end
exports('CreateInvoice',create)
exports('PayInvoice',function(target,invoiceId)
    target=tonumber(target); local p=QBCore.Functions.GetPlayer(target); local row=MySQL.single.await('SELECT * FROM dpn_medical_invoices WHERE id=? AND patient_cid=? AND status=?',{invoiceId,p and p.PlayerData.citizenid,'unpaid'}); if not row then return false end
    local amount=tonumber(row.patient_amount) or 0; local ok=p.Functions.RemoveMoney(Config.PayAccount,amount,'dpn-medical-invoice'); if not ok and Config.AllowCashFallback then ok=p.Functions.RemoveMoney('cash',amount,'dpn-medical-invoice') end
    if ok then MySQL.update('UPDATE dpn_medical_invoices SET status=?,paid_at=NOW() WHERE id=?',{'paid',invoiceId}) end; return ok
end)
QBCore.Commands.Add('medbill','Create a medical invoice',{{name='id'},{name='amount'},{name='reason'}},true,function(src,args)
    local provider=QBCore.Functions.GetPlayer(src); local job=provider and provider.PlayerData.job or {}; if not exports['dpn-medical-core']:IsMedicalJob(src,'ems') and not QBCore.Functions.HasPermission(src,'admin') then return end
    local id,amount=create(args[1],args[2],table.concat(args,' ',3),'medical',provider and provider.PlayerData.citizenid); TriggerClientEvent('QBCore:Notify',src,id and ('Invoice created; patient owes $'..amount) or 'Invoice failed.',id and 'success' or 'error')
end)
QBCore.Commands.Add('paymedbill','Pay a medical invoice',{{name='invoice'}},true,function(src,args) local ok=exports['dpn-medical-billing-plus']:PayInvoice(src,tonumber(args[1])); TriggerClientEvent('QBCore:Notify',src,ok and 'Invoice paid.' or 'Payment failed.',ok and 'success' or 'error') end)
