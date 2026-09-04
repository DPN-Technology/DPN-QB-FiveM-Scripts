local VERSION='10.0.0'
local escalations, mutualAid, commandChannels = {}, {}, {}
local function uid(p)return('%s-%s-%04d'):format(p,os.time(),math.random(0,9999))end
local function core(name,...)local a=table.pack(...);local ok,x,y=pcall(function()local p=exports['dpn-medical-core'];return p[name](p,table.unpack(a,1,a.n))end);return ok,x,y end
local function bridge(event,payload)
    local router=DPNMedicalDispatchCompatBridge
    if router and type(router.Route)=='function' then
        return router.Route(event,payload)
    end
    TriggerEvent('dpn-dispatch-system:server:'..event,payload)
    return false,'legacy-fallback'
end
exports('EscalateMedicalIncidentV10',function(callId,target,reason)local ok,twin=core('GetV10Twin',target);local item={id=uid('ESC10'),callId=callId,target=tonumber(target),reason=reason,commandRisk=ok and twin.v10.commandRisk or 0,arrestMinutes=ok and twin.v10.predictedArrestMinutes or -1,level=ok and twin.v10.commandRisk>=85 and'critical_command'or'priority_escalation',status='active',createdAt=os.time()};escalations[item.id]=item;bridge('medicalCommandEscalation',item);return true,item end)
exports('RequestMedicalMutualAidV10',function(callId,capabilities,area,actor)local item={id=uid('MA10'),callId=callId,capabilities=capabilities or{},area=area,actor=actor,status='requested',createdAt=os.time()};mutualAid[item.id]=item;bridge('medicalMutualAid',item);return item.id,item end)
exports('CreateMedicalCommandChannelV10',function(callId,participants)local item={id=uid('CHAN10'),callId=callId,participants=participants or{},messages={},status='open',createdAt=os.time()};commandChannels[item.id]=item;return item.id,item end)
exports('GetV10DispatchBoard',function()return{version=VERSION,escalations=escalations,mutualAid=mutualAid,commandChannels=commandChannels,generatedAt=os.time()}end)
CreateThread(function()Wait(8200);print('[dpn-medical-dispatch] v10 incident escalation and medical mutual-aid command active')end)
