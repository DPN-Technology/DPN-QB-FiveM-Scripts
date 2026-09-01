local VERSION='11.0.0'
local bedPlans, commandCenters, surgeForecasts, transfers = {}, {}, {}, {}
local function uid(p)return('%s-%s-%04d'):format(p,os.time(),math.random(0,9999))end
local function core(name,...)local a=table.pack(...);local ok,x,y=pcall(function()local p=exports['dpn-medical-core'];return p[name](p,table.unpack(a,1,a.n))end);return ok,x,y end
exports('OptimizeBedAssignmentV11',function(target,capacity,staffing)
 local ok,twin=core('GetV11Twin',target);if not ok then return false,'Patient unavailable.'end;capacity=type(capacity)=='table'and capacity or{};staffing=type(staffing)=='table'and staffing or{}
 local ward=twin.v11.predictedLevelOfCare;local bed=ward=='resuscitation'and'resuscitation_bay'or ward=='intensive_care'and'icu'or ward=='monitored_acute'and'telemetry'or ward=='inpatient'and'medical_surgical'or'observation'
 local item={id=uid('BED11'),target=tonumber(target),recommendedBed=bed,priority=twin.v11.clinicalPriority,resourceIntensity=twin.v11.resourceIntensity,staffingNeed=math.max(1,math.ceil(twin.v11.resourceIntensity/25)),isolation=twin.infection.isolationPriority>=50,capacity=capacity,staffing=staffing,status='recommended',createdAt=os.time()};bedPlans[item.id]=item;return true,item
end)
exports('CreateDigitalHospitalCommandV11',function(capacity,staffing,incoming,supplies)
 capacity=type(capacity)=='table'and capacity or{};staffing=type(staffing)=='table'and staffing or{};incoming=type(incoming)=='table'and incoming or{};supplies=type(supplies)=='table'and supplies or{}
 local occupancy=(tonumber(capacity.occupied)or 0)/math.max(1,tonumber(capacity.total)or 1);local staff=(tonumber(staffing.available)or 0)/math.max(1,tonumber(staffing.required)or 1);local supply=tonumber(supplies.readiness)or 100;local pressure=math.min(100,occupancy*55+(1-staff)*35+#incoming*3+math.max(0,75-supply)*.4)
 local item={id=uid('HCC11'),pressure=math.floor(pressure),status=pressure>=85 and'crisis'or pressure>=65 and'surge'or pressure>=40 and'heightened'or'normal',actions={},createdAt=os.time()};if item.status~='normal'then item.actions={'open_surge_beds','rebalance_staff','expedite_discharges','activate_supply_command','coordinate_mutual_aid'}end;commandCenters[item.id]=item;return item
end)
exports('ForecastHospitalSurgeV11',function(arrivalRate,dischargeRate,acuityMix,hours)local net=(tonumber(arrivalRate)or 0)-(tonumber(dischargeRate)or 0);local critical=tonumber(acuityMix and acuityMix.critical)or 0;local demand=net*(tonumber(hours)or 6)+critical*2;local item={id=uid('SURGE11'),projectedDemand=math.floor(demand),hours=tonumber(hours)or 6,status=demand>=20 and'critical'or demand>=10 and'high'or demand>=4 and'moderate'or'controlled',createdAt=os.time()};surgeForecasts[item.id]=item;return item end)
exports('CreateInterfacilityTransferV11',function(target,fromFacility,toFacility,capability,actor)local ok,twin=core('GetV11Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('IFT11'),target=tonumber(target),fromFacility=fromFacility,toFacility=toFacility,requiredCapability=capability,actor=actor,transportPriority=twin.v11.clinicalPriority,resourceIntensity=twin.v11.resourceIntensity,status='requested',createdAt=os.time()};transfers[item.id]=item;return true,item end)
exports('GetV11HospitalBoard',function()return{version=VERSION,bedPlans=bedPlans,commandCenters=commandCenters,surgeForecasts=surgeForecasts,transfers=transfers,generatedAt=os.time()}end)
CreateThread(function()Wait(7100);print('[dpn-medical-hospital] v11 bed optimization and digital hospital command active')end)
