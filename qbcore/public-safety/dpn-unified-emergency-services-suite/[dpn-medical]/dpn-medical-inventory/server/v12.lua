local VERSION = '12.0.0'
local function uid(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(0,9999)) end
local function core(name, ...)
    local args = table.pack(...)
    local ok, a, b = pcall(function()
        local proxy = exports['dpn-medical-core']
        local fn = proxy and proxy[name]
        if type(fn) ~= 'function' then error(('missing core export %s'):format(name)) end
        return fn(proxy, table.unpack(args, 1, args.n))
    end)
    return ok, a, b
end
local function clamp(v, lo, hi) v=tonumber(v) or lo; if v<lo then return lo elseif v>hi then return hi else return v end end

local packs, forecasts, transfers, recalls = {}, {}, {}, {}
exports('ReserveCriticalCarePackV12',function(target,location,inventory,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local required={'airway_kit','vascular_access','monitoring'};for _,support in ipairs(twin.organSupportV12.recommendedSupports or{})do required[#required+1]=support end;local missing={};for _,item in ipairs(required)do if not(inventory and inventory[item]and inventory[item]>0)then missing[#missing+1]=item end end;local row={id=uid('PACK12'),target=tonumber(target),location=location,actor=actor,required=required,missing=missing,status=#missing==0 and'reserved'or'partial',createdAt=os.time()};packs[row.id]=row;return #missing==0,row end)
exports('ForecastBloodProductDemandV12',function(patients,hours)local units=0;for _,p in ipairs(patients or{})do units=units+math.ceil((tonumber(p.massiveTransfusionNeed)or 0)/20)end;local item={id=uid('BLOOD12'),hours=tonumber(hours)or 6,projectedUnits=units,status=units>=30 and'critical_shortage_risk'or units>=15 and'high_demand'or'normal',createdAt=os.time()};forecasts[item.id]=item;return item end)
exports('CreateRegionalSupplyTransferV12',function(itemName,amount,fromLocation,toLocation,actor)local item={id=uid('XFER12'),item=itemName,amount=tonumber(amount)or 0,fromLocation=fromLocation,toLocation=toLocation,actor=actor,status='requested',createdAt=os.time()};transfers[item.id]=item;return true,item end)
exports('CreateLotRecallV12',function(lot,itemName,reason,actor)local item={id=uid('RECALL12'),lot=lot,item=itemName,reason=reason,actor=actor,status='active',createdAt=os.time()};recalls[item.id]=item;return true,item end)
exports('GetV12InventoryBoard',function()return{version=VERSION,packs=packs,forecasts=forecasts,transfers=transfers,recalls=recalls,generatedAt=os.time()}end)
CreateThread(function()Wait(8600);print('[dpn-medical-inventory] v12 critical-care supply and blood forecasting active')end)
