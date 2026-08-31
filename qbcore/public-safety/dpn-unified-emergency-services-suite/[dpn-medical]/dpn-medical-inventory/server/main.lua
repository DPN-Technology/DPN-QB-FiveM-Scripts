local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    Wait(1000)
    exports['dpn-medical-core']:RegisterModule('dpn-medical-inventory','2.0.0',{'medical_inventory','item_bridge','supply_tracking'})
end)

local function player(target) return QBCore.Functions.GetPlayer(tonumber(target)) end
exports('HasMedicalItem',function(target,item,amount)
    local p=player(target); if not p or not Config.Items[item] then return false end; local found=p.Functions.GetItemByName(item); return found and (found.amount or 0)>=(tonumber(amount) or 1) or false
end)
exports('RemoveMedicalItem',function(target,item,amount)
    local p=player(target); if not p or not Config.Items[item] then return false end; local ok=p.Functions.RemoveItem(item,tonumber(amount) or 1); if ok then MySQL.insert('INSERT INTO dpn_medical_inventory_log (citizenid,item,amount,action) VALUES (?,?,?,?)',{p.PlayerData.citizenid,item,amount or 1,'remove'}) end; return ok
end)
exports('GiveMedicalItem',function(target,item,amount,info)
    local p=player(target); if not p or not Config.Items[item] then return false end; local ok=p.Functions.AddItem(item,tonumber(amount) or 1,false,info or {}); if ok then MySQL.insert('INSERT INTO dpn_medical_inventory_log (citizenid,item,amount,action,metadata) VALUES (?,?,?,?,?)',{p.PlayerData.citizenid,item,amount or 1,'give',json.encode(info or {})}) end; return ok
end)
QBCore.Commands.Add('medgive','Give a configured medical item',{{name='id'},{name='item'},{name='amount'}},true,function(src,args)
    if not QBCore.Functions.HasPermission(src,'admin') then return end; local ok=exports['dpn-medical-inventory']:GiveMedicalItem(args[1],args[2],args[3] or 1,{issuedBy=src}); TriggerClientEvent('QBCore:Notify',src,ok and 'Medical item issued.' or 'Unable to issue item.',ok and 'success' or 'error')
end,'admin')
