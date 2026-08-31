local VERSION='8.0.0'
local doseReviews, controlledLog = {}, {}
local function uid(prefix)return('%s-%s-%04d'):format(prefix,os.time(),math.random(0,9999))end
local function core(name,...)local args=table.pack(...);local ok,a,b,c=pcall(function()local p=exports['dpn-medical-core'];return p[name](p,table.unpack(args,1,args.n))end);return ok,a,b,c end
exports('ReviewPrecisionDose',function(target,medication,dose,route,actor)
    local ok,safe,message,assessment=core('ValidatePrecisionMedication',target,medication,dose,route);if not ok then return false,'Core unavailable.'end
    local item={id=uid('RXREV'),target=target,medication=medication,dose=dose,route=route,safe=safe,message=message,assessment=assessment,actor=actor,createdAt=os.time()};doseReviews[item.id]=item;return safe,item
end)
exports('AdministerPrecisionMedication',function(target,medication,dose,route,actor,context)local ok,result,message,item=core('RecordPrecisionMedication',target,medication,dose,route,actor,context);if not ok then return false,'Core unavailable.'end;if result and(context and context.controlled)then controlledLog[item.id]=item end;return result,message,item end)
exports('GetPharmacyV8Board',function()return{reviews=doseReviews,controlled=controlledLog,generatedAt=os.time()}end)
CreateThread(function()Wait(3000);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-pharmacy',VERSION,{'precision_dose_review','renal_adjustment','controlled_substance_audit','medication_governance'})end);print('[dpn-medical-pharmacy] v8 precision medication governance active')end)
