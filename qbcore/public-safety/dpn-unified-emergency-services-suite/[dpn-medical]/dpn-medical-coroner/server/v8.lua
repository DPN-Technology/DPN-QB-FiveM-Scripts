local VERSION='8.0.0'
local reviews, evidence = {}, {}
local function uid(prefix)return('%s-%s-%04d'):format(prefix,os.time(),math.random(0,9999))end
exports('CreateMortalityReview',function(target,caseId,data,actor)data=type(data)=='table'and data or{};local item={id=uid('MORT'),target=target,caseId=caseId,cause=data.cause,manner=data.manner,preventability=data.preventability or'undetermined',careConcerns=data.careConcerns or{},actor=actor,status='open',createdAt=os.time()};reviews[item.id]=item;return item.id,item end)
exports('TransferCoronerEvidence',function(caseId,evidenceId,to,actor)local item={id=uid('COC'),caseId=caseId,evidenceId=evidenceId,to=to,actor=actor,at=os.time()};evidence[#evidence+1]=item;return true,item end)
exports('GetCoronerV8Board',function()return{mortalityReviews=reviews,chainOfCustody=evidence,generatedAt=os.time()}end)
CreateThread(function()Wait(3000);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-coroner',VERSION,{'mortality_review','preventability_analysis','evidence_chain','death_quality'})end);print('[dpn-medical-coroner] v8 mortality review and evidence governance active')end)
