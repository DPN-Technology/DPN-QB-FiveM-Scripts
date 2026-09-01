local ADV_RESOURCE = GetCurrentResourceName()
local ADV_VERSION = GetResourceMetadata(ADV_RESOURCE, 'version', 0) or 'unknown'
CreateThread(function()
    Wait(1800)
    pcall(function()
        exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE, ADV_VERSION, {
            'preauthorization',
            'deductible_tracking',
            'claim_rules',
            'appeals',
            'coverage_network'
        })
    end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

exports('RequestAuthorization',function(target,service,estimatedCost,urgency)
 local p=exports['qb-core']:GetCoreObject().Functions.GetPlayer(tonumber(target)); if not p then return false end; local policy=exports['dpn-medical-insurance']:GetPolicy(target); local status=(urgency=='emergency' or policy) and 'approved' or 'denied'; local id=MySQL.insert.await('INSERT INTO dpn_medical_insurance_authorizations (citizenid,policy_id,service,estimated_cost,urgency,status) VALUES (?,?,?,?,?,?)',{p.PlayerData.citizenid,policy and policy.id or nil,service,estimatedCost,urgency,status}); return id,status
end)
exports('GetFinancialEstimate',function(target,charges)
 local total=0; for _,c in ipairs(charges or {}) do total=total+(tonumber(c.amount) or 0) end; local covered,patient,policy=exports['dpn-medical-insurance']:CalculateCoverage(target,total); return {total=total,covered=covered,patient=patient,insured=policy~=nil,policy=policy}
end)

