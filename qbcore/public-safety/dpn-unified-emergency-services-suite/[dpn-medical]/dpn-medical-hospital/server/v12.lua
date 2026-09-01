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

local beds, regionalCapacity, pathways, transfers = {}, {}, {}, {}

exports('MatchIntegratedCriticalCareBedV12', function(target, facilities)
    local ok,twin=core('GetV12Twin',target); if not ok or type(twin)~='table' then return false,'Patient unavailable.' end
    facilities=type(facilities)=='table' and facilities or {}
    local required={}; for _,v in ipairs(twin.organSupportV12.recommendedSupports or{}) do required[#required+1]=v end
    local rows={}
    for _,f in ipairs(facilities) do
        local capability=tonumber(f.capabilityMatch) or 0; local capacity=tonumber(f.capacityScore) or 0; local eta=tonumber(f.etaMinutes) or 60
        local score=clamp(capability*.45+capacity*.30+(100-math.min(100,eta*3))*.25,0,100)
        rows[#rows+1]={facility=f.facility,score=math.floor(score),etaMinutes=eta,available=f.available~=false}
    end
    table.sort(rows,function(a,b)return a.score>b.score end)
    local item={id=uid('BED12'),target=tonumber(target),requiredCapabilities=required,recommended=twin.v12.recommendedDestination,
        population=twin.populationV12.group,rankedFacilities=rows,status='recommended',createdAt=os.time()}; beds[item.id]=item; return true,item
end)

exports('CreateRegionalCapacityCommandV12', function(facilities, incoming, staffing, supplies)
    facilities=type(facilities)=='table' and facilities or{}; incoming=type(incoming)=='table' and incoming or{}
    staffing=type(staffing)=='table' and staffing or{}; supplies=type(supplies)=='table' and supplies or{}
    local total,occupied,criticalBeds=0,0,0
    for _,f in ipairs(facilities) do total=total+(tonumber(f.totalBeds)or 0);occupied=occupied+(tonumber(f.occupiedBeds)or 0);criticalBeds=criticalBeds+(tonumber(f.criticalBedsAvailable)or 0) end
    local occupancy=occupied/math.max(1,total); local staffRatio=(tonumber(staffing.available)or 0)/math.max(1,tonumber(staffing.required)or 1)
    local supply=tonumber(supplies.readiness)or 100; local pressure=clamp(occupancy*55+(1-staffRatio)*25+#incoming*4+math.max(0,70-supply)*.35,0,100)
    local item={id=uid('REG12'),pressure=math.floor(pressure),status=pressure>=85 and'regional_crisis'or pressure>=65 and'surge'or pressure>=40 and'heightened'or'normal',
        totalBeds=total,occupiedBeds=occupied,criticalBedsAvailable=criticalBeds,actions={},createdAt=os.time()}
    if item.status~='normal' then item.actions={'regional_bed_balance','mutual_aid','staff_recall','supply_reallocation','expedited_transfer_center'} end
    regionalCapacity[item.id]=item; return item
end)

exports('ActivateSpecialPopulationPathwayV12', function(target, pathwayType, actor)
    local ok,twin=core('GetV12Twin',target); if not ok or type(twin)~='table' then return false,'Patient unavailable.' end
    local item={id=uid('PATH12'),target=tonumber(target),pathway=pathwayType or twin.populationV12.group,actor=actor,
        population=twin.populationV12.group,special=twin.populationV12.specialPopulations,
        requiredTeams={twin.v12.recommendedTeam,'pharmacy','diagnostics','case_management'},risk=twin.v12.integratedRisk,
        status='active',createdAt=os.time()}; pathways[item.id]=item; return true,item
end)

exports('CreateRegionalTransferV12', function(target, fromFacility, toFacility, capability, actor)
    local ok,twin=core('GetV12Twin',target); if not ok or type(twin)~='table' then return false,'Patient unavailable.' end
    local item={id=uid('IFT12'),target=tonumber(target),fromFacility=fromFacility,toFacility=toFacility,capability=capability,
        actor=actor,priority=twin.v12.networkPriority,commandLevel=twin.v12.commandLevel,transportRisk=twin.v12.integratedRisk,
        decompensationMinutes=twin.v12.decompensationMinutes,status='requested',createdAt=os.time()};transfers[item.id]=item;return true,item
end)

exports('GetV12HospitalBoard',function()return{version=VERSION,beds=beds,regionalCapacity=regionalCapacity,pathways=pathways,transfers=transfers,generatedAt=os.time()}end)
CreateThread(function()Wait(7100);print('[dpn-medical-hospital] v12 regional capacity and integrated bed command active')end)
