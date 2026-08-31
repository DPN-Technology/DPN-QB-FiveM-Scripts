local VERSION = '3.0.0'
local RESOURCE = GetCurrentResourceName()
local QBCore = exports['qb-core']:GetCoreObject()
local function encode(value) local ok,result=pcall(json.encode,value or {}); return ok and result or '{}' end
local function targetPlayer(target) return QBCore.Functions.GetPlayer(tonumber(target)) end
local function citizen(target) local p=targetPlayer(target); return p and p.PlayerData and p.PlayerData.citizenid or nil end
local function actor(sourceValue) if type(sourceValue)=='string' then return sourceValue:sub(1,64) end; local p=targetPlayer(sourceValue); return p and p.PlayerData and p.PlayerData.citizenid or ('source:%s'):format(tostring(sourceValue or 'system')) end
local function uid(prefix,target) return ('%s-%s-%s-%04d'):format(prefix,os.date('%Y%m%d%H%M%S'),tostring(target or 0),math.random(0,9999)) end
local function asyncInsert(query,params) CreateThread(function() pcall(function() MySQL.insert.await(query,params) end) end) end
local function asyncUpdate(query,params) CreateThread(function() pcall(function() MySQL.update.await(query,params) end) end) end
local function core(method,...)
    local args=table.pack(...)
    local ok,a,b,c=pcall(function() local proxy=exports['dpn-medical-core']; local fn=proxy and proxy[method]; if type(fn)~='function' then error('missing core export '..tostring(method)) end; return fn(proxy,table.unpack(args,1,args.n)) end)
    if not ok then return false,nil,tostring(a) end
    return true,a,b,c
end
local function heartbeat(capabilities)
    CreateThread(function()
        Wait(2500)
        pcall(function() exports['dpn-medical-core']:RegisterModule(RESOURCE,VERSION,capabilities) end)
        while true do Wait(60000); TriggerEvent('dpn-medical-core:server:moduleHeartbeat',RESOURCE,VERSION,{online=true,time=os.time()}) end
    end)
end

local parLevels, recalls, cycleCounts = {}, {}, {}
exports('SetParLevel',function(sourceValue,location,itemName,minimum,target) parLevels[location]=parLevels[location]or{};local item={location=location,item=itemName,minimum=tonumber(minimum)or 0,target=tonumber(target)or tonumber(minimum)or 0,updatedBy=actor(sourceValue),updatedAt=os.time()};parLevels[location][itemName]=item;asyncInsert('INSERT INTO dpn_medical_v6_par_levels (location,item_name,minimum_quantity,target_quantity,updated_by) VALUES (?,?,?,?,?) ON DUPLICATE KEY UPDATE minimum_quantity=VALUES(minimum_quantity),target_quantity=VALUES(target_quantity),updated_by=VALUES(updated_by),updated_at=NOW()',{location,itemName,item.minimum,item.target,item.updatedBy});return true,item end)
exports('TransferMedicalStock',function(sourceValue,itemName,quantity,fromLocation,toLocation,lot) local id=uid('STX',sourceValue);local item={id=id,item=itemName,quantity=tonumber(quantity)or 0,from=fromLocation,to=toLocation,lot=lot,transferredBy=actor(sourceValue),transferredAt=os.time(),status='completed'};asyncInsert('INSERT INTO dpn_medical_v6_inventory_transfers (transfer_id,item_name,quantity,from_location,to_location,lot_number,transferred_by,transfer_data) VALUES (?,?,?,?,?,?,?,?)',{id,itemName,item.quantity,fromLocation,toLocation,lot,item.transferredBy,encode(item)});return id,item end)
exports('RecallMedicalLot',function(sourceValue,itemName,lot,reason) local id=uid('RCL',sourceValue);local item={id=id,item=itemName,lot=lot,reason=reason,status='active',issuedBy=actor(sourceValue),issuedAt=os.time()};recalls[id]=item;asyncInsert('INSERT INTO dpn_medical_v6_inventory_recalls (recall_id,item_name,lot_number,status,reason,issued_by,recall_data) VALUES (?,?,?,?,?,?,?)',{id,itemName,lot,item.status,reason,item.issuedBy,encode(item)});return id,item end)
exports('RecordCycleCount',function(sourceValue,location,itemName,expected,actual) local item={id=uid('CNT',sourceValue),location=location,item=itemName,expected=tonumber(expected)or 0,actual=tonumber(actual)or 0,variance=(tonumber(actual)or 0)-(tonumber(expected)or 0),countedBy=actor(sourceValue),countedAt=os.time()};cycleCounts[item.id]=item;asyncInsert('INSERT INTO dpn_medical_v6_cycle_counts (count_id,location,item_name,expected_quantity,actual_quantity,variance,counted_by,count_data) VALUES (?,?,?,?,?,?,?,?)',{item.id,location,itemName,item.expected,item.actual,item.variance,item.countedBy,encode(item)});return item.id,item end)
exports('GetSupplyCommandCenter',function()return {parLevels=parLevels,recalls=recalls,cycleCounts=cycleCounts,generatedAt=os.time()}end)
heartbeat({'par_levels','stock_transfers','lot_recalls','cycle_counts','expiry_tracking','controlled_supply_accountability'})
