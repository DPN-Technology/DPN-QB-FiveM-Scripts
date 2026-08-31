local ADV_RESOURCE = 'dpn-medical-billing-plus'
local ADV_VERSION = '2.0.0'
CreateThread(function()
    Wait(1800)
    pcall(function() exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE,ADV_VERSION,'itemized_charges','estimates','payment_plans','financial_assistance','revenue_cycle') end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

exports('AddCharge',function(invoiceId,code,description,amount,quantity)
 quantity=tonumber(quantity) or 1; amount=math.max(0,tonumber(amount) or 0); MySQL.insert('INSERT INTO dpn_medical_invoice_charges (invoice_id,charge_code,description,unit_amount,quantity,total_amount) VALUES (?,?,?,?,?,?)',{invoiceId,code,description,amount,quantity,amount*quantity}); MySQL.update('UPDATE dpn_medical_invoices SET total_amount=total_amount+?,patient_amount=patient_amount+? WHERE id=?',{amount*quantity,amount*quantity,invoiceId}); return true
end)
exports('CreatePaymentPlan',function(target,invoiceId,installments)
 installments=math.max(2,math.min(24,tonumber(installments) or 4)); local p=exports['qb-core']:GetCoreObject().Functions.GetPlayer(tonumber(target)); local row=p and MySQL.single.await('SELECT patient_amount FROM dpn_medical_invoices WHERE id=? AND patient_cid=?',{invoiceId,p.PlayerData.citizenid}); if not row then return false end; local payment=math.ceil((tonumber(row.patient_amount) or 0)/installments); local id=MySQL.insert.await('INSERT INTO dpn_medical_payment_plans (invoice_id,patient_cid,installments,installment_amount,status) VALUES (?,?,?,?,?)',{invoiceId,p.PlayerData.citizenid,installments,payment,'active'}); return id,payment
end)

