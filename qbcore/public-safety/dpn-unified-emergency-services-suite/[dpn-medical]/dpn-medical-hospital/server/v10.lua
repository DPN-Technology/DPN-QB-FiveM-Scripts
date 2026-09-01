local VERSION='10.0.0'
local commandBoard, acuityPlans, flowPredictions = {}, {}, {}
local function uid(p)return('%s-%s-%04d'):format(p,os.time(),math.random(0,9999))end
local function core(name,...)local a=table.pack(...);local ok,x,y=pcall(function()local p=exports['dpn-medical-core'];return p[name](p,table.unpack(a,1,a.n))end);return ok,x,y end
exports('CreateAcuityPlacementPlanV10',function(target,capacity)
 local ok,twin=core('GetV10Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end;capacity=type(capacity)=='table'and capacity or{}
 local ward=twin.v10.commandRisk>=85 and'resuscitation'or twin.v10.predictedICUNeed>=65 and'icu'or twin.v10.commandRisk>=45 and'monitored_acute'or'emergency'
 local item={id=uid('ACP'),target=tonumber(target),ward=ward,commandRisk=twin.v10.commandRisk,careGaps=twin.careGaps,staffingNeed=math.ceil(twin.v10.commandRisk/25),isolation=twin.toxicity.dominantToxidrome=='cholinergic',capacity=capacity,status='planned',createdAt=os.time()};acuityPlans[item.id]=item;return true,item
end)
exports('BuildHospitalCommandBoardV10',function(capacity,staffing,incoming)
 capacity=type(capacity)=='table'and capacity or{};staffing=type(staffing)=='table'and staffing or{};incoming=type(incoming)=='table'and incoming or{}
 local load=(#incoming+(tonumber(capacity.boarded)or 0))/math.max(1,tonumber(capacity.openBeds)or 1);local staffRatio=(tonumber(staffing.available)or 1)/math.max(1,tonumber(staffing.required)or 1)
 local item={id=uid('HCMD'),load=load,staffRatio=staffRatio,status=(load>=1.4 or staffRatio<.55)and'crisis'or(load>=1 or staffRatio<.8)and'surge'or'normal',actions={},createdAt=os.time()}
 if item.status~='normal'then item.actions={'activate_command_center','open_surge_capacity','rebalance_staff','expedite_patient_flow','notify_mutual_aid'}end;commandBoard[item.id]=item;return item
end)
exports('ForecastPatientFlowV10',function(arrivals,discharges,hours)local projected=(tonumber(arrivals)or 0)-(tonumber(discharges)or 0);local item={id=uid('FLOW'),hours=tonumber(hours)or 6,netDemand=projected,status=projected>=10 and'critical'or projected>=5 and'high'or'controlled',createdAt=os.time()};flowPredictions[item.id]=item;return item end)
exports('GetV10HospitalBoard',function()return{version=VERSION,commandBoard=commandBoard,acuityPlans=acuityPlans,flowPredictions=flowPredictions,generatedAt=os.time()}end)
CreateThread(function()Wait(7100);print('[dpn-medical-hospital] v10 acuity placement and hospital command center active')end)
