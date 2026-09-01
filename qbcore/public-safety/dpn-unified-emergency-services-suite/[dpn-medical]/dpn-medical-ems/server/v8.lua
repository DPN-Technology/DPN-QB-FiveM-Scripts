local VERSION='8.0.0'
local protocolReviews, refusals, destinationDecisions = {}, {}, {}
local function uid(prefix) return ('%s-%s-%04d'):format(prefix,os.time(),math.random(0,9999)) end
local function core(name,...) local args=table.pack(...); local ok,a,b=pcall(function() local p=exports['dpn-medical-core']; local f=p and p[name]; if type(f)~='function'then error('missing core export '..name)end; return f(p,table.unpack(args,1,args.n)) end); return ok,a,b end
exports('ScorePrehospitalProtocol',function(target,performed)
    local ok,twin=core('GetPrecisionTwin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end
    performed=type(performed)=='table'and performed or{};local required={};for _,r in ipairs(twin.recommendations or{})do required[r.code]=true end
    local matched,total=0,0;for code in pairs(required)do total=total+1;if performed[code]then matched=matched+1 end end
    local score=total==0 and 100 or math.floor(matched/total*100);local review={id=uid('PCRQA'),target=target,score=score,required=required,performed=performed,precisionRisk=twin.v8.precisionRisk,createdAt=os.time()};protocolReviews[review.id]=review;return true,review
end)
exports('RecommendDestination',function(target,facilities)
    local ok,twin=core('GetPrecisionTwin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end
    facilities=type(facilities)=='table'and facilities or{};local best,bestScore=nil,-999
    for _,facility in ipairs(facilities)do local score=100-(tonumber(facility.occupancy)or 0);if facility.capabilities and facility.capabilities[twin.v8.recommendedDestination]then score=score+50 end;score=score-(tonumber(facility.etaMinutes)or 10)*2;if score>bestScore then best,bestScore=facility,score end end
    local decision={id=uid('DEST'),target=target,recommended=best,score=bestScore,clinicalNeed=twin.v8.recommendedDestination,createdAt=os.time()};destinationDecisions[decision.id]=decision;return best~=nil,decision
end)
exports('DocumentAMARefusal',function(target,data,actor) data=type(data)=='table'and data or{};local item={id=uid('AMA'),target=target,capacityAssessed=data.capacityAssessed==true,risksExplained=data.risksExplained==true,witness=data.witness,signature=data.signature,actor=actor,createdAt=os.time()};refusals[item.id]=item;return item.capacityAssessed and item.risksExplained,item end)
exports('GetEMSPrecisionBoard',function()return{protocolReviews=protocolReviews,refusals=refusals,destinations=destinationDecisions,generatedAt=os.time()}end)
CreateThread(function()Wait(3000);print('[dpn-medical-ems] v8 precision EMS protocol and destination intelligence active')end)
