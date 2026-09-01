local ADV_RESOURCE = GetCurrentResourceName()
local ADV_VERSION = GetResourceMetadata(ADV_RESOURCE, 'version', 0) or 'unknown'
CreateThread(function()
    Wait(1800)
    pcall(function()
        exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE, ADV_VERSION, {
            'batch_tracking',
            'expiration',
            'stockrooms',
            'par_levels',
            'recall'
        })
    end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

exports('RegisterBatch',function(item,batch,expiresAt,quantity,location) local id=MySQL.insert.await('INSERT INTO dpn_medical_inventory_batches (item_name,batch_number,expires_at,quantity,location,status) VALUES (?,?,FROM_UNIXTIME(?),?,?,?)',{item,batch,expiresAt,quantity,location,'active'}); return id end)
exports('ConsumeBatch',function(item,amount,location)
 amount=tonumber(amount) or 1; local row=MySQL.single.await('SELECT * FROM dpn_medical_inventory_batches WHERE item_name=? AND location=? AND status=? AND quantity>=? AND (expires_at IS NULL OR expires_at>NOW()) ORDER BY expires_at ASC,id ASC LIMIT 1',{item,location,'active',amount}); if not row then return false,'No unexpired stock' end; MySQL.update('UPDATE dpn_medical_inventory_batches SET quantity=quantity-?,status=IF(quantity-?<=0,?,status) WHERE id=?',{amount,amount,'depleted',row.id}); return true,row.batch_number
end)
exports('GetStockAlerts',function() return MySQL.query.await('SELECT item_name,location,SUM(quantity) quantity FROM dpn_medical_inventory_batches WHERE status=? GROUP BY item_name,location HAVING SUM(quantity)<5',{'active'}) or {} end)

