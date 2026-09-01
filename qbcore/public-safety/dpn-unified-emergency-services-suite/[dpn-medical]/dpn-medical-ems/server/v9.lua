local VERSION='9.0.0'
local transportPlans, communications, crewReadiness = {}, {}, {}
local function uid(p) return ('%s-%s-%04d'):format(p,os.time(),math.random(0,9999)) end
local function core(name,...) local a=table.pack(...);local ok,x,y=pcall(function()local p=exports['dpn-medical-core'];return p[name](p,table.unpack(a,1,a.n))end);return ok,x,y end
exports('CreateAdaptiveTransportPlan',function(target,facilities,unit)
    local ok,twin=core('GetV9Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end
    local trajectory=twin.trajectory30 or{};local best,bestScore=nil,-9999
    for _,f in ipairs(type(facilities)=='table'and facilities or{})do
        local capabilities=f.capabilities or{};local score=100-(tonumber(f.occupancy)or 0)-(tonumber(f.etaMinutes)or 15)*2
        if capabilities[twin.v9.disposition]or capabilities.icu and twin.v9.networkPriority<=2 then score=score+55 end
        if f.divert==true then score=score-100 end
        if score>bestScore then best,bestScore=f,score end
    end
    local plan={id=uid('V9TX'),target=tonumber(target),unit=unit,destination=best,score=bestScore,priority=twin.v9.networkPriority,trajectory=trajectory,requiredCapabilities=twin.v9.disposition,createdAt=os.time()};transportPlans[plan.id]=plan
    return best~=nil,plan
end)
exports('RecordClosedLoopCommunication',function(callId,sender,receiver,message,acknowledged)
    local item={id=uid('V9COM'),callId=callId,sender=sender,receiver=receiver,message=tostring(message or ''):sub(1,500),acknowledged=acknowledged==true,createdAt=os.time()};communications[item.id]=item;return true,item
end)
exports('CalculateCrewClinicalReadiness',function(crew)
    crew=type(crew)=='table'and crew or{};local score=100-(tonumber(crew.fatigue)or 0)*0.45-(tonumber(crew.openCalls)or 0)*8-(tonumber(crew.missingEquipment)or 0)*12
    if crew.alsQualified==false then score=score-20 end;score=math.max(0,math.min(100,math.floor(score)))
    local item={crewId=crew.id or'unknown',score=score,status=score>=80 and'ready'or score>=55 and'limited'or'out_of_service',calculatedAt=os.time()};crewReadiness[item.crewId]=item;return item
end)
exports('GetV9EMSBoard',function()return{version=VERSION,transportPlans=transportPlans,communications=communications,crewReadiness=crewReadiness,generatedAt=os.time()}end)
CreateThread(function()Wait(5000);print('[dpn-medical-ems] v9 adaptive transport and closed-loop EMS coordination active')end)
