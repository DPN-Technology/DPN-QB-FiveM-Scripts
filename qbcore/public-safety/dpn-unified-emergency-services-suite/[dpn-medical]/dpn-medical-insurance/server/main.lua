local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    Wait(1000)
    exports['dpn-medical-core']:RegisterModule('dpn-medical-insurance','2.0.0',{'policies','coverage','claims'})
end)

local function cid(target) if type(target)=='string' then return target end local p=QBCore.Functions.GetPlayer(tonumber(target)); return p and p.PlayerData.citizenid end
local function policy(target)
    local id=cid(target); if not id then return nil end
    return MySQL.single.await('SELECT * FROM dpn_medical_insurance_policies WHERE citizenid=? AND status=? ORDER BY id DESC LIMIT 1',{id,'active'})
end
exports('GetPolicy',policy)
exports('CalculateCoverage',function(target,amount)
    amount=math.max(0,tonumber(amount) or 0); local row=policy(target); if not row then return 0,amount,nil end
    local plan=Config.Plans[row.plan_id]; if not plan then return 0,amount,row end
    local eligible=math.max(0,amount-plan.deductible); local covered=math.floor(eligible*plan.coverage); return covered,amount-covered,row
end)
exports('SubmitClaim',function(target,invoiceId,amount,category)
    local id=cid(target); local covered,patientAmount,row=exports['dpn-medical-insurance']:CalculateCoverage(target,amount)
    local claim=MySQL.insert.await('INSERT INTO dpn_medical_insurance_claims (citizenid,policy_id,invoice_id,category,amount,covered_amount,patient_amount,status) VALUES (?,?,?,?,?,?,?,?)',{id,row and row.id or nil,invoiceId,category,amount,covered,patientAmount,row and 'approved' or 'uninsured'})
    return claim,covered,patientAmount
end)
QBCore.Commands.Add('insurance','Select a medical insurance plan',{{name='plan'}},true,function(src,args)
    local plan=Config.Plans[args[1]]; local p=QBCore.Functions.GetPlayer(src); if not plan or not p then return TriggerClientEvent('QBCore:Notify',src,'Plans: basic, standard, premium','error') end
    MySQL.update('UPDATE dpn_medical_insurance_policies SET status=? WHERE citizenid=? AND status=?',{'cancelled',p.PlayerData.citizenid,'active'})
    MySQL.insert('INSERT INTO dpn_medical_insurance_policies (citizenid,plan_id,premium,status) VALUES (?,?,?,?)',{p.PlayerData.citizenid,args[1],plan.premium,'active'})
    TriggerClientEvent('QBCore:Notify',src,('Enrolled in %s insurance.'):format(plan.label),'success')
end)
