local VERSION='9.0.0'
local reconciliations, optimizations, pumps = {}, {}, {}
local function uid(p)return('%s-%s-%04d'):format(p,os.time(),math.random(0,9999))end
local function core(name,...)local a=table.pack(...);local ok,x,y=pcall(function()local p=exports['dpn-medical-core'];return p[name](p,table.unpack(a,1,a.n))end);return ok,x,y end
exports('ReconcileMedicationListV9',function(target,home,current,actor)
 local ok,twin=core('GetV9Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end;home=type(home)=='table'and home or{};current=type(current)=='table'and current or{};local discrepancies={}
 local seen={};for _,m in ipairs(current)do seen[tostring(m.name or m.medication):lower()]=true end;for _,m in ipairs(home)do local name=tostring(m.name or m.medication):lower();if not seen[name]then discrepancies[#discrepancies+1]={type='omission',medication=name}end end
 local item={id=uid('MEDREC'),target=tonumber(target),discrepancies=discrepancies,clearanceRisk=twin.v9.medicationAccumulationRisk,actor=actor,status=#discrepancies==0 and'clean'or'review_required',createdAt=os.time()};reconciliations[item.id]=item;return true,item
end)
exports('OptimizeMedicationDoseV9',function(target,medication,dose,route)
 local ok,twin=core('GetV9Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end;local factor=1.0;if twin.renal and(tonumber(twin.renal.estimatedGfr)or 100)<30 then factor=factor*.6 end;if twin.v9.hepaticRisk>=50 then factor=factor*.65 end;local recommendation={id=uid('DOSE'),target=tonumber(target),medication=medication,requestedDose=tonumber(dose)or 0,recommendedDose=math.floor((tonumber(dose)or 0)*factor*100)/100,route=route,factor=factor,warnings={},createdAt=os.time()};if twin.v9.qtRisk>=35 then recommendation.warnings[#recommendation.warnings+1]='Elevated QT risk.'end;if twin.v9.medicationAccumulationRisk>=30 then recommendation.warnings[#recommendation.warnings+1]='Existing accumulation risk.'end;optimizations[recommendation.id]=recommendation;return true,recommendation
end)
exports('CreateSmartPumpGuardrailV9',function(target,drug,rate,limits)local min=tonumber(limits and limits.min)or 0;local max=tonumber(limits and limits.max)or 9999;local item={id=uid('PUMP'),target=tonumber(target),drug=drug,rate=tonumber(rate)or 0,min=min,max=max,status=(tonumber(rate)or 0)<min or(tonumber(rate)or 0)>max and'blocked'or'approved',createdAt=os.time()};if item.rate<min or item.rate>max then item.status='blocked'end;pumps[item.id]=item;return item.status=='approved',item end)
exports('GetV9PharmacyBoard',function()return{version=VERSION,reconciliations=reconciliations,optimizations=optimizations,pumps=pumps,generatedAt=os.time()}end)
CreateThread(function()Wait(5400);print('[dpn-medical-pharmacy] v9 medication reconciliation and clearance-aware dosing active')end)
