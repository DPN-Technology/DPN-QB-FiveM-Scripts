local VERSION='8.0.0'
local functionalScores, plans = {}, {}
local function uid(prefix)return('%s-%s-%04d'):format(prefix,os.time(),math.random(0,9999))end
exports('ScoreFunctionalIndependence',function(target,domains,actor)domains=type(domains)=='table'and domains or{};local total,count=0,0;for _,score in pairs(domains)do total=total+(tonumber(score)or 0);count=count+1 end;local average=count>0 and total/count or 0;local item={id=uid('FIM'),target=target,domains=domains,average=average,actor=actor,createdAt=os.time()};functionalScores[item.id]=item;return average,item end)
exports('CreateRehabDischargePlan',function(target,data,actor)data=type(data)=='table'and data or{};local item={id=uid('REHABPLAN'),target=target,goals=data.goals or{},equipment=data.equipment or{},homeServices=data.homeServices or{},barriers=data.barriers or{},actor=actor,status='active',createdAt=os.time()};plans[item.id]=item;return item.id,item end)
exports('GetRehabV8Board',function()return{scores=functionalScores,plans=plans,generatedAt=os.time()}end)
CreateThread(function()Wait(3000);print('[dpn-medical-rehab] v8 functional outcomes and discharge readiness active')end)
