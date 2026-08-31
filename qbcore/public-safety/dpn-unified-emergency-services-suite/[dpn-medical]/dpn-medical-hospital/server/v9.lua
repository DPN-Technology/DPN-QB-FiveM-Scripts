local VERSION='9.0.0'
local placements, rapidResponses, forecasts, transfers = {}, {}, {}, {}
local function uid(p) return ('%s-%s-%04d'):format(p,os.time(),math.random(0,9999)) end
local function core(name,...) local a=table.pack(...);local ok,x,y=pcall(function()local p=exports['dpn-medical-core'];return p[name](p,table.unpack(a,1,a.n))end);return ok,x,y end
exports('OptimizeAdaptiveBedPlacement',function(target,beds)
    local ok,twin=core('GetV9Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end
    local best,bestScore=nil,-9999
    for _,bed in ipairs(type(beds)=='table'and beds or{})do
        if bed.available~=false then local score=100-(tonumber(bed.distance)or 0)*2-(tonumber(bed.workload)or 0)
            if bed.ward==twin.v9.disposition then score=score+60 end
            if twin.v9.networkPriority<=2 and(bed.ward=='icu'or bed.ward=='resuscitation')then score=score+35 end
            if bed.isolation and twin.immune and twin.immune.inflammatoryLoad>50 then score=score+15 end
            if score>bestScore then best,bestScore=bed,score end
        end
    end
    local item={id=uid('BEDOPT'),target=tonumber(target),bed=best,score=bestScore,clinical=twin.v9,createdAt=os.time()};placements[item.id]=item;return best~=nil,item
end)
exports('StartRapidResponseV9',function(target,location,reason,actor)
    local item={id=uid('RRT'),target=tonumber(target),location=location,reason=reason,actor=actor,status='activated',team={},timeline={{event='activated',at=os.time()}},createdAt=os.time()};rapidResponses[item.id]=item;return item.id,item
end)
exports('UpdateRapidResponseV9',function(id,status,data)
    local item=rapidResponses[tostring(id)];if not item then return false,'Rapid response not found.'end;item.status=tostring(status or item.status);item.timeline[#item.timeline+1]={event=item.status,data=data,at=os.time()};item.updatedAt=os.time();return true,item
end)
exports('ForecastHospitalCapacityV9',function(current,arrivals,staff)
    current=type(current)=='table'and current or{};arrivals=type(arrivals)=='table'and arrivals or{};staff=type(staff)=='table'and staff or{}
    local demand=#arrivals+(tonumber(current.boarded)or 0);local capacity=math.max(1,(tonumber(current.openBeds)or 0)+(tonumber(current.expectedDischarges)or 0));local staffFactor=math.max(.35,math.min(1,(tonumber(staff.available)or 1)/math.max(1,tonumber(staff.required)or 1)))
    local load=demand/(capacity*staffFactor);local result={id=uid('CAP'),load=load,status=load>=1.4 and'crisis'or load>=1 and'surge'or load>=.75 and'busy'or'normal',recommendedActions={},createdAt=os.time()}
    if load>=1 then result.recommendedActions={'open_surge_beds','expedite_discharges','request_mutual_aid','rebalance_staff'}end;forecasts[result.id]=result;return result
end)
exports('CreateInterfacilityTransferV9',function(target,origin,destination,requirements)
    local item={id=uid('IFT'),target=tonumber(target),origin=origin,destination=destination,requirements=requirements or{},status='requested',createdAt=os.time()};transfers[item.id]=item;return item.id,item
end)
exports('GetV9HospitalBoard',function()return{version=VERSION,placements=placements,rapidResponses=rapidResponses,forecasts=forecasts,transfers=transfers,generatedAt=os.time()}end)
CreateThread(function()Wait(5100);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-hospital',VERSION,{'adaptive_bed_placement','rapid_response','capacity_forecasting','interfacility_transfer'})end);print('[dpn-medical-hospital] v9 adaptive patient flow and rapid-response command active')end)
