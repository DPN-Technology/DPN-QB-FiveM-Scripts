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

local readiness, crews, loadouts, missions = {}, {}, {}, {}
exports('ScoreCriticalTransportReadinessV12',function(unit,vehicle,equipment,crew)local vehicleScore=tonumber(vehicle and vehicle.readiness)or 0;local equipmentScore=tonumber(equipment and equipment.readiness)or 0;local crewScore=tonumber(crew and crew.readiness)or 0;local fatigue=tonumber(crew and crew.fatigue)or 0;local score=clamp(vehicleScore*.3+equipmentScore*.35+crewScore*.35-fatigue*.25,0,100);local item={id=uid('READY12'),unit=unit,score=math.floor(score),status=score>=80 and'ready_critical'or score>=60 and'ready_limited'or'out_of_service',vehicle=vehicle or{},equipment=equipment or{},crew=crew or{},createdAt=os.time()};readiness[item.id]=item;return true,item end)
exports('AssignSpecialtyCrewV12',function(unit,call,crewPool,requirements)local selected={};for _,member in ipairs(crewPool or{})do for _,req in ipairs(requirements or{})do if member.credentials and member.credentials[req]then selected[#selected+1]=member;break end end end;local item={id=uid('CREW12'),unit=unit,call=call,selected=selected,requirements=requirements or{},status=#selected>0 and'assigned'or'staffing_shortage',createdAt=os.time()};crews[item.id]=item;return item.status=='assigned',item end)
exports('CreateCriticalEquipmentLoadoutV12',function(unit,supports,inventory)local required={'monitor','airway','oxygen','hemorrhage_control'};for _,s in ipairs(supports or{})do required[#required+1]=s end;local missing={};for _,item in ipairs(required)do if not(inventory and inventory[item])then missing[#missing+1]=item end end;local row={id=uid('LOAD12'),unit=unit,required=required,missing=missing,status=#missing==0 and'ready'or'incomplete',createdAt=os.time()};loadouts[row.id]=row;return #missing==0,row end)
exports('CreateCriticalTransportMissionV12',function(target,unit,destination,actor)local ok,twin=core('GetV12Twin',target);if not ok then return false,'Patient unavailable.'end;local item={id=uid('MISSION12'),target=tonumber(target),unit=unit,destination=destination or twin.v12.recommendedDestination,actor=actor,risk=twin.v12.integratedRisk,decompensationMinutes=twin.v12.decompensationMinutes,supports=twin.organSupportV12.recommendedSupports,status='assigned',createdAt=os.time()};missions[item.id]=item;return true,item end)
exports('GetV12AmbulanceBoard',function()return{version=VERSION,readiness=readiness,crews=crews,loadouts=loadouts,missions=missions,generatedAt=os.time()}end)
CreateThread(function()Wait(8000);print('[dpn-medical-ambulance] v12 fleet and critical transport readiness active')end)
