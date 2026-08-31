local VERSION='10.0.0'
local readiness, missions, defects = {}, {}, {}
local function uid(p)return('%s-%s-%04d'):format(p,os.time(),math.random(0,9999))end
exports('CalculateCriticalTransportReadinessV10',function(unit,crew,equipment)local score=100-(tonumber(unit and unit.maintenanceRisk)or 0)*.4-(tonumber(crew and crew.fatigue)or 0)*.35-(tonumber(equipment and equipment.missing)or 0)*12;local item={id=tostring(unit and unit.id or uid('UNIT10')),score=math.max(0,math.floor(score)),status=score>=80 and'ready'or score>=55 and'limited'or'out_of_service',unit=unit,crew=crew,equipment=equipment,calculatedAt=os.time()};readiness[item.id]=item;return item end)
exports('AssignCriticalTransportMissionV10',function(unitId,callId,requirements)local item={id=uid('TX10'),unitId=unitId,callId=callId,requirements=requirements or{},status='assigned',timeline={{event='assigned',at=os.time()}},createdAt=os.time()};missions[item.id]=item;return item.id,item end)
exports('ReportMedicalEquipmentDefectV10',function(unitId,equipment,severity,actor)local item={id=uid('DEF10'),unitId=unitId,equipment=equipment,severity=severity,actor=actor,status='open',createdAt=os.time()};defects[item.id]=item;return item.id,item end)
exports('GetV10AmbulanceBoard',function()return{version=VERSION,readiness=readiness,missions=missions,defects=defects,generatedAt=os.time()}end)
CreateThread(function()Wait(8000);print('[dpn-medical-ambulance] v10 critical transport readiness and fleet command active')end)
