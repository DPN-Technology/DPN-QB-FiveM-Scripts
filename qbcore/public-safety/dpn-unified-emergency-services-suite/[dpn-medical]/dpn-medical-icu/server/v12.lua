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

local matrices, ventilation, support, rounds = {}, {}, {}, {}
exports('CreateAdvancedSupportMatrixV12',function(target,team)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('SUP12'),target=tonumber(target),team=team or{},supports=twin.organSupportV12.recommendedSupports,cardiovascular=twin.cardiovascularV12,ventilation=twin.ventilationV12,risk=twin.v12.integratedRisk,status='active',createdAt=os.time()};matrices[item.id]=item;return true,item end)
exports('ConfigureProtectiveVentilationV12',function(target,settings,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;settings=type(settings)=='table'and settings or{};local pbw=twin.ventilationV12.predictedBodyWeightKg;local item={id=uid('VENT12'),target=tonumber(target),actor=actor,mode=settings.mode or'volume_control',tidalVolumeMl=settings.tidalVolumeMl or math.floor(pbw*6),peep=settings.peep or math.max(5,math.min(16,math.floor((200-twin.ventilationV12.pfRatio)/20)+5)),fio2=settings.fio2 or(twin.ventilationV12.pfRatio<100 and 1.0 or.6),plateauTarget=30,drivingPressureTarget=15,status='recommended',createdAt=os.time()};ventilation[item.id]=item;return true,item end)
exports('EvaluateECMOCRRTV12',function(target,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('EVAL12'),target=tonumber(target),actor=actor,ecmoNeed=twin.organSupportV12.ecmoNeed,crrtNeed=twin.organSupportV12.crrtNeed,mcsNeed=twin.organSupportV12.mechanicalCirculatorySupportNeed,ecmoCandidate=twin.organSupportV12.ecmoNeed>=65,crrtCandidate=twin.organSupportV12.crrtNeed>=55,status='specialist_review',createdAt=os.time()};support[item.id]=item;return true,item end)
exports('CreateIntegratedCriticalRoundsV12',function(target,team,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('ROUND12'),target=tonumber(target),team=team or{},actor=actor,goals={'organ_support_review','ventilator_safety','medication_reconciliation','device_review','nutrition','mobility','family_communication'},careGaps=twin.v12Recommendations,status='active',createdAt=os.time()};rounds[item.id]=item;return true,item end)
exports('GetV12ICUBoard',function()return{version=VERSION,matrices=matrices,ventilation=ventilation,support=support,rounds=rounds,generatedAt=os.time()}end)
CreateThread(function()Wait(8300);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-icu',VERSION,{'advanced_support_matrix','protective_ventilation','ecmo_crrt_evaluation','integrated_rounds'})end);print('[dpn-medical-icu] v12 advanced organ support and protective ventilation active')end)
