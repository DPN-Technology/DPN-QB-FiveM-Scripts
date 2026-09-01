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

local pathways, transport, contrast, closedLoop = {}, {}, {}, {}
exports('CreateCriticalImagingSequenceV12',function(target,indication,actor)local ok,twin=core('GetV12Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end;local sequence={};if twin.organSupportV12.neurocriticalNeed>=55 then sequence={'noncontrast_head_ct','cta_head_neck'}elseif twin.organSupportV12.damageControlResuscitationNeed>=55 then sequence={'trauma_ct_or_or_based_on_stability'}else sequence={'targeted_imaging'}end;local item={id=uid('IMG12'),target=tonumber(target),indication=indication,actor=actor,sequence=sequence,transportRisk=twin.v12.integratedRisk,priority=twin.v12.networkPriority,status='ordered',createdAt=os.time()};pathways[item.id]=item;return true,item end)
exports('CalculateImagingTransportRiskV12',function(target,destination)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local risk=clamp(twin.v12.integratedRisk*.65+math.max(0,70-twin.cardiovascularV12.cardiacReserve)*.35+math.max(0,80-twin.dataQualityV12.confidence)*.2,0,100);local item={id=uid('TRN12'),target=tonumber(target),destination=destination,risk=math.floor(risk),portableRecommended=risk>=70,requiredEscort=risk>=70 and'critical_care_team'or'clinical_transport',createdAt=os.time()};transport[item.id]=item;return true,item end)
exports('CreateContrastSafetyPlanV12',function(target,contrastType,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local renal=twin.organSupportV12.crrtNeed;local risk=clamp(renal*.75+(twin.v11 and twin.v11.endocrineRisk or 0)*.15,0,100);local item={id=uid('CON12'),target=tonumber(target),contrastType=contrastType or'iodinated',actor=actor,renalRisk=math.floor(risk),status=risk>=70 and'hold_for_specialist_review'or'approved_with_monitoring',actions={'verify_allergy','review_renal_function','document_risk_benefit'},createdAt=os.time()};contrast[item.id]=item;return true,item end)
exports('CreateClosedLoopCriticalResultV12',function(target,result,recipient,actor)local item={id=uid('CLR12'),target=tonumber(target),result=result,recipient=recipient,actor=actor,status='sent',readBackRequired=true,readBackComplete=false,createdAt=os.time()};closedLoop[item.id]=item;return true,item end)
exports('GetV12RadiologyBoard',function()return{version=VERSION,pathways=pathways,transport=transport,contrast=contrast,closedLoop=closedLoop,generatedAt=os.time()}end)
CreateThread(function()Wait(7300);print('[dpn-medical-radiology] v12 critical imaging and transport safety active')end)
