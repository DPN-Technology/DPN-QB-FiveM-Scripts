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

local dosing, envelopes, reconciliation, antidotes = {}, {}, {}, {}
exports('CalculatePopulationDoseV12',function(target,medication,dosePerKg,route,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local weight=tonumber(twin.demographics and twin.demographics.weightKg)or 80;local dose=weight*(tonumber(dosePerKg)or 0);local renalFactor=clamp(1-twin.organSupportV12.crrtNeed/140,.25,1);local item={id=uid('DOSE12'),target=tonumber(target),medication=medication,route=route or'iv',actor=actor,weightKg=weight,calculatedDose=math.floor(dose*renalFactor*100)/100,renalFactor=renalFactor,population=twin.populationV12.group,requiresPharmacistApproval=true,createdAt=os.time()};dosing[item.id]=item;return true,item end)
exports('CreateInfusionSafetyEnvelopeV12',function(target,medication,rate,limits,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;limits=type(limits)=='table'and limits or{};local hardMin=tonumber(limits.min)or 0;local hardMax=tonumber(limits.max)or math.huge;local value=tonumber(rate)or 0;local item={id=uid('ENV12'),target=tonumber(target),medication=medication,rate=value,actor=actor,hardMin=hardMin,hardMax=hardMax,status=(value<hardMin or value>hardMax)and'blocked'or'approved',risk=twin.v12.integratedRisk,monitoring=twin.ventilationV12.respiratorySupportLevel,createdAt=os.time()};envelopes[item.id]=item;return item.status=='approved',item end)
exports('ReconcileCriticalMedicationsV12',function(target,medications,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local findings={};for _,m in ipairs(medications or{})do local cls=tostring(m.class or''):lower();if twin.ventilationV12.respiratorySupportLevel~='none'and(cls=='opioid'or cls=='sedative')then findings[#findings+1]={severity='high',medication=m.name,reason='respiratory_support_conflict'}end;if twin.organSupportV12.crrtNeed>=55 and m.renalClearance==true then findings[#findings+1]={severity='high',medication=m.name,reason='renal_clearance_adjustment'}end end;local item={id=uid('REC12'),target=tonumber(target),actor=actor,findings=findings,status=#findings==0 and'clear'or'pharmacist_review',createdAt=os.time()};reconciliation[item.id]=item;return true,item end)
exports('CreateAntidoteCommandV12',function(target,toxin,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('ANT12'),target=tonumber(target),toxin=toxin,actor=actor,priority=twin.v12.networkPriority,monitoring={'ecg','spo2','etco2','blood_pressure'},status='requested',createdAt=os.time()};antidotes[item.id]=item;return true,item end)
exports('GetV12PharmacyBoard',function()return{version=VERSION,dosing=dosing,envelopes=envelopes,reconciliation=reconciliation,antidotes=antidotes,generatedAt=os.time()}end)
CreateThread(function()Wait(7400);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-pharmacy',VERSION,{'population_dosing','infusion_safety_envelopes','critical_medication_reconciliation','antidote_command'})end);print('[dpn-medical-pharmacy] v12 population dosing and infusion guardrails active')end)
