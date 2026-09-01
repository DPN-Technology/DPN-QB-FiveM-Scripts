local VERSION='9.0.0'
local pathways, results, followups = {}, {}, {}
local function uid(p)return('%s-%s-%04d'):format(p,os.time(),math.random(0,9999))end
local function core(name,...)local a=table.pack(...);local ok,x,y=pcall(function()local p=exports['dpn-medical-core'];return p[name](p,table.unpack(a,1,a.n))end);return ok,x,y end
exports('CreateAdaptiveDiagnosticPathway',function(target,question,modalities)
 local ok,twin=core('GetV9Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end;modalities=type(modalities)=='table'and modalities or{'ct'}
 local ranked={};for _,m in ipairs(modalities)do local score=50;if m=='ct'and twin.v9.networkPriority<=2 then score=score+35 end;if m=='mri'and twin.v9.trajectory=='critical_decline'then score=score-30 end;if m=='ultrasound'and twin.v9.networkPriority<=2 then score=score+20 end;ranked[#ranked+1]={modality=m,score=score}end;table.sort(ranked,function(a,b)return a.score>b.score end)
 local item={id=uid('DXPATH'),target=tonumber(target),question=question,ranked=ranked,selected=ranked[1]and ranked[1].modality,priority=twin.v9.networkPriority,createdAt=os.time()};pathways[item.id]=item;return true,item
end)
exports('PublishStructuredResultV9',function(orderId,target,findings,impression,critical)local item={id=uid('RADR'),orderId=orderId,target=tonumber(target),findings=findings,impression=impression,critical=critical==true,status=critical and'critical_unacknowledged'or'final',createdAt=os.time()};results[item.id]=item;if item.critical then followups[item.id]={resultId=item.id,status='open',createdAt=os.time()}end;return true,item end)
exports('CloseCriticalResultLoopV9',function(resultId,recipient,action)local item=followups[tostring(resultId)];if not item then return false,'Critical follow-up not found.'end;item.status='closed';item.recipient=recipient;item.action=action;item.closedAt=os.time();return true,item end)
exports('GetV9RadiologyBoard',function()return{version=VERSION,pathways=pathways,results=results,followups=followups,generatedAt=os.time()}end)
CreateThread(function()Wait(5300);print('[dpn-medical-radiology] v9 adaptive diagnostic pathway and closed-loop results active')end)
