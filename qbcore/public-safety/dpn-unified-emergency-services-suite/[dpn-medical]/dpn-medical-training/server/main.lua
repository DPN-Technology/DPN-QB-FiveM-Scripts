local QBCore = exports['qb-core']:GetCoreObject()

local function cid(target) if type(target)=='string' then return target end local p=QBCore.Functions.GetPlayer(tonumber(target)); return p and p.PlayerData.citizenid end
exports('HasCertification',function(target,cert)
    local id=cid(target); if not id then return false end
    local row=MySQL.single.await('SELECT id FROM dpn_medical_certifications WHERE citizenid=? AND certification=? AND status=? AND (expires_at IS NULL OR expires_at>NOW()) LIMIT 1',{id,cert,'active'})
    return row~=nil
end)
QBCore.Commands.Add('medcert','Grant a medical certification',{{name='id'},{name='cert'}},true,function(src,args)
    if not QBCore.Functions.HasPermission(src,'admin') then return end
    local target=tonumber(args[1]); local cert=Config.Certifications[args[2]]; local p=QBCore.Functions.GetPlayer(target); if not cert or not p then return end
    local expires=os.time()+(cert.validDays*86400)
    MySQL.insert('INSERT INTO dpn_medical_certifications (citizenid,certification,issued_by,status,expires_at) VALUES (?,?,?,?,FROM_UNIXTIME(?)) ON DUPLICATE KEY UPDATE issued_by=VALUES(issued_by),status=VALUES(status),expires_at=VALUES(expires_at)',{p.PlayerData.citizenid,args[2],tostring(src),'active',expires})
    TriggerClientEvent('QBCore:Notify',src,'Certification granted.','success')
end,'admin')
