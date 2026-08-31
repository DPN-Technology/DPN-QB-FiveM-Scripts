local VERSION='8.0.0'
local readiness, restocks, defects = {}, {}, {}
local function uid(prefix)return('%s-%s-%04d'):format(prefix,os.time(),math.random(0,9999))end
exports('CalculateUnitReadiness',function(unitId,data)data=type(data)=='table'and data or{};local score=100-(tonumber(data.criticalDefects)or 0)*30-(tonumber(data.expiredItems)or 0)*5-(tonumber(data.missingItems)or 0)*4;if(data.fuelPercent or 100)<25 then score=score-15 end;score=math.max(0,math.min(100,score));local item={unitId=unitId,score=score,status=score>=85 and'ready'or(score>=60 and'limited'or'out_of_service'),data=data,updatedAt=os.time()};readiness[tostring(unitId)]=item;return item end)
exports('RecordAmbulanceRestock',function(unitId,items,actor)local item={id=uid('RESTOCK'),unitId=unitId,items=items or{},actor=actor,createdAt=os.time()};restocks[item.id]=item;return item.id,item end)
exports('ReportAmbulanceDefect',function(unitId,kind,severity,actor)local item={id=uid('DEFECT'),unitId=unitId,kind=kind,severity=severity or'moderate',actor=actor,status='open',createdAt=os.time()};defects[item.id]=item;return item.id,item end)
exports('GetAmbulanceV8Board',function()return{readiness=readiness,restocks=restocks,defects=defects,generatedAt=os.time()}end)
CreateThread(function()Wait(3000);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-ambulance',VERSION,{'unit_readiness','smart_restock','defect_management','fleet_resilience'})end);print('[dpn-medical-ambulance] v8 fleet readiness and resilient operations active')end)
