local VERSION='8.0.0'
local quarantines, forecasts, transfers = {}, {}, {}
local function uid(prefix)return('%s-%s-%04d'):format(prefix,os.time(),math.random(0,9999))end
exports('QuarantineMedicalLot',function(item,lot,reason,actor)local q={id=uid('QUAR'),item=item,lot=lot,reason=reason,actor=actor,status='quarantined',createdAt=os.time()};quarantines[q.id]=q;TriggerEvent('dpn-medical:inventory:lotQuarantined',q);return q.id,q end)
exports('ForecastMedicalSupply',function(item,current,onHandUsePerDay,leadDays,safetyDays)local demand=(tonumber(onHandUsePerDay)or 0)*((tonumber(leadDays)or 0)+(tonumber(safetyDays)or 0));local reorder=math.max(0,math.ceil(demand-(tonumber(current)or 0)));local itemData={id=uid('FORECAST'),item=item,current=current,demand=demand,reorderQuantity=reorder,createdAt=os.time()};forecasts[itemData.id]=itemData;return itemData end)
exports('TransferMedicalStock',function(item,quantity,from,to,actor)local t={id=uid('STOCKMOVE'),item=item,quantity=tonumber(quantity)or 0,from=from,to=to,actor=actor,createdAt=os.time()};transfers[t.id]=t;return t.id,t end)
exports('GetInventoryV8Board',function()return{quarantines=quarantines,forecasts=forecasts,transfers=transfers,generatedAt=os.time()}end)
CreateThread(function()Wait(3000);print('[dpn-medical-inventory] v8 supply resilience and recall controls active')end)
