local VERSION='9.0.0'
local plans, escalations, mutualAid = {}, {}, {}
local function uid(p)return('%s-%s-%04d'):format(p,os.time(),math.random(0,9999))end
local function core(name,...)local a=table.pack(...);local ok,x,y=pcall(function()local p=exports['dpn-medical-core'];return p[name](p,table.unpack(a,1,a.n))end);return ok,x,y end
exports('OptimizeMedicalResponseV9',function(call,units)
 call=type(call)=='table'and call or{};units=type(units)=='table'and units or{};local twin=nil;if call.patientId then local ok,x=core('GetV9Twin',call.patientId);if ok then twin=x end end;local best,bestScore=nil,-9999
 for _,u in ipairs(units)do if u.available~=false then local score=(tonumber(u.readiness)or 80)-(tonumber(u.etaMinutes)or 15)*3-(tonumber(u.activeCalls)or 0)*12;if twin and twin.v9.networkPriority<=2 and u.als then score=score+35 end;if score>bestScore then best,bestScore=u,score end end end
 local item={id=uid('RESP'),callId=call.id,patientId=call.patientId,unit=best,score=bestScore,priority=twin and twin.v9.networkPriority or call.priority or 3,createdAt=os.time()};plans[item.id]=item;return best~=nil,item
end)
exports('EscalateDispatchSLAV9',function(callId,elapsed,targetSla)local item={id=uid('SLA'),callId=callId,elapsed=elapsed,targetSla=targetSla,breached=(tonumber(elapsed)or 0)>(tonumber(targetSla)or 0),status='recorded',createdAt=os.time()};escalations[item.id]=item;if item.breached then TriggerEvent('dpn-dispatch-system:server:medicalEscalation',{callId=callId,elapsed=elapsed,targetSla=targetSla,source='dpn-medical-dispatch-v9'})end;return true,item end)
exports('CreateMedicalMutualAidV9',function(callId,agencies,reason)local item={id=uid('MUTUAL'),callId=callId,agencies=agencies or{},reason=reason,status='requested',createdAt=os.time()};mutualAid[item.id]=item;TriggerEvent('dpn-dispatch-system:server:mutualAid',{medical=true,callId=callId,agencies=item.agencies,reason=reason,requestId=item.id});return item.id,item end)
exports('GetV9DispatchBoard',function()return{version=VERSION,plans=plans,escalations=escalations,mutualAid=mutualAid,generatedAt=os.time()}end)
CreateThread(function()Wait(6200);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-dispatch',VERSION,{'adaptive_unit_allocation','sla_escalation','medical_mutual_aid','trajectory_priority'})end);print('[dpn-medical-dispatch] v9 adaptive response allocation and escalation active')end)
