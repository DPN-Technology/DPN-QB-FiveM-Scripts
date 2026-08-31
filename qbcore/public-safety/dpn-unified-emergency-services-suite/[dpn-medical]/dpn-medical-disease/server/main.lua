local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    Wait(1000)
    exports['dpn-medical-core']:RegisterModule('dpn-medical-disease','2.0.0',{'disease','infection','symptoms','contagion'})
end)

local function infect(target,diseaseId,severity)
    target=tonumber(target); local d=Config.Diseases[diseaseId]; if not target or not d then return false end
    local p=QBCore.Functions.GetPlayer(target); if not p then return false end
    MySQL.insert('INSERT INTO dpn_medical_diseases (patient_cid,disease_id,severity,status) VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE severity=GREATEST(severity,VALUES(severity)),status=?',{p.PlayerData.citizenid,diseaseId,tonumber(severity) or 10,'active','active'})
    return exports['dpn-medical-core']:AddCondition(target,diseaseId,{label=d.label,severity=severity or 10,contagious=d.contagious,stage='active'})
end
exports('InfectPatient',infect)
exports('CurePatient',function(target,diseaseId)
    target=tonumber(target); local p=QBCore.Functions.GetPlayer(target); if not p then return false end
    MySQL.update('UPDATE dpn_medical_diseases SET status=? WHERE patient_cid=? AND disease_id=?',{'resolved',p.PlayerData.citizenid,diseaseId})
    return exports['dpn-medical-core']:RemoveCondition(target,diseaseId)
end)
QBCore.Commands.Add('infect','Apply a disease for testing/admin',{{name='id'},{name='disease'},{name='severity'}},true,function(src,args)
    if not QBCore.Functions.HasPermission(src,'admin') then return end
    local ok=infect(args[1],args[2],args[3]); TriggerClientEvent('QBCore:Notify',src,ok and 'Disease applied.' or 'Invalid disease. ',ok and 'success' or 'error')
end,'admin')
CreateThread(function()
    while true do
        Wait(math.max(1,Config.TickMinutes)*60000)
        for _,sid in ipairs(GetPlayers()) do
            local src=tonumber(sid); local state=exports['dpn-medical-core']:GetPatientState(src)
            if state then
                for id,c in pairs(state.conditions or {}) do
                    local d=Config.Diseases[id]
                    if d then
                        local nextSeverity=math.min(d.max,(c.severity or 0)+d.progression)
                        exports['dpn-medical-core']:AddCondition(src,id,{label=d.label,severity=nextSeverity,contagious=d.contagious,stage=nextSeverity>70 and 'severe' or 'active',startedAt=c.startedAt})
                        if id=='sepsis' and nextSeverity>75 then exports['dpn-medical-core']:ApplyInjury(src,'chest',{type='sepsis',damage=2,pain=2,source='disease'}) end
                    end
                end
            end
        end
    end
end)
