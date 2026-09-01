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

local missions, pediatric, obstetric, handoffs = {}, {}, {}, {}

exports('CreateIntegratedTransportPlanV12', function(target, unit, options)
    local ok, twin = core('GetV12Twin', target); if not ok or type(twin) ~= 'table' then return false, 'Patient unavailable.' end
    options = type(options) == 'table' and options or {}
    local destination = options.destination or twin.v12.recommendedDestination
    local capabilities = {}
    for _, support in ipairs(twin.organSupportV12.recommendedSupports or {}) do capabilities[#capabilities+1] = support end
    if twin.populationV12.group == 'child' or twin.populationV12.group == 'infant' or twin.populationV12.group == 'neonate' then capabilities[#capabilities+1] = 'pediatric_transport' end
    if #(twin.populationV12.specialPopulations or {}) > 0 then capabilities[#capabilities+1] = 'special_population_team' end
    local item = { id=uid('EMS12'), target=tonumber(target), unit=unit, destination=destination,
        priority=twin.v12.networkPriority, commandLevel=twin.v12.commandLevel, risk=twin.v12.integratedRisk,
        requiredCapabilities=capabilities, decompensationMinutes=twin.v12.decompensationMinutes,
        dataConfidence=twin.dataQualityV12.confidence, status='planned', createdAt=os.time() }
    missions[item.id]=item; return true,item
end)

exports('CreatePediatricResuscitationCardV12', function(target, actor)
    local ok,twin=core('GetV12Twin',target); if not ok or type(twin)~='table' then return false,'Patient unavailable.' end
    local p=twin.populationV12; local weight=tonumber(twin.demographics and twin.demographics.weightKg) or 20
    local item={id=uid('PED12'),target=tonumber(target),actor=actor,population=p.group,weightKg=weight,
        hypotensionThreshold=p.referenceRanges and p.referenceRanges.sbpCritical or 70,
        estimatedBloodVolumeMl=p.estimatedBloodVolumeMl,shockIndex=p.adjustedShockIndex,
        medicationWeightBasisKg=weight,criticalCareNeed=twin.organSupportV12.pediatricCriticalCareNeed,
        status='active',createdAt=os.time()}; pediatric[item.id]=item; return true,item
end)

exports('CreateObstetricEmergencyHandoffV12', function(target, unit, destination, actor)
    local ok,twin=core('GetV12Twin',target); if not ok or type(twin)~='table' then return false,'Patient unavailable.' end
    local item={id=uid('OB12'),target=tonumber(target),unit=unit,destination=destination or 'obstetric_receiving',actor=actor,
        pregnancyWeeks=twin.populationV12.pregnancyWeeks,postpartumHours=twin.populationV12.postpartumHours,
        emergencyNeed=twin.organSupportV12.obstetricEmergencyNeed,risk=twin.v12.integratedRisk,
        requiredTeams={'obstetrics','anesthesia','blood_bank','neonatal'},readBackRequired=true,readBackComplete=false,
        createdAt=os.time()}; obstetric[item.id]=item; return true,item
end)

exports('CreateRegionalClinicalHandoffV12', function(target, fromUnit, toFacility, actor)
    local ok,twin=core('GetV12Twin',target); if not ok or type(twin)~='table' then return false,'Patient unavailable.' end
    local item={id=uid('HOF12'),target=tonumber(target),fromUnit=fromUnit,toFacility=toFacility,actor=actor,
        situation={risk=twin.v12.integratedRisk,command=twin.v12.commandLevel,decompensationMinutes=twin.v12.decompensationMinutes},
        background={population=twin.populationV12.group,special=twin.populationV12.specialPopulations},
        assessment={supports=twin.organSupportV12.recommendedSupports,confidence=twin.dataQualityV12.confidence},
        recommendation={destination=twin.v12.recommendedDestination,team=twin.v12.recommendedTeam},status='sent',createdAt=os.time()}
    handoffs[item.id]=item; return true,item
end)

exports('GetV12EMSBoard', function() return {version=VERSION,missions=missions,pediatric=pediatric,obstetric=obstetric,handoffs=handoffs,generatedAt=os.time()} end)
CreateThread(function() Wait(7000); print('[dpn-medical-ems] v12 integrated transport and special-population response active') end)
