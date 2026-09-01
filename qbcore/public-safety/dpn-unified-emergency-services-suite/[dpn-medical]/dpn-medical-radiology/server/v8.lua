local VERSION='8.0.0'
local appropriateness, discrepancies = {}, {}
local function uid(prefix)return('%s-%s-%04d'):format(prefix,os.time(),math.random(0,9999))end
exports('ScoreImagingAppropriateness',function(target,modality,bodyPart,indication)
    local score=50;modality=tostring(modality or''):lower();bodyPart=tostring(bodyPart or''):lower();indication=tostring(indication or''):lower()
    if modality=='ct'and(indication:find('trauma',1,true)or indication:find('bleed',1,true))then score=90 end
    if modality=='mri'and indication:find('unstable',1,true)then score=20 end
    if modality=='xray'and(bodyPart:find('arm',1,true)or bodyPart:find('leg',1,true))then score=85 end
    local item={id=uid('IMGAPP'),target=target,modality=modality,bodyPart=bodyPart,indication=indication,score=score,appropriate=score>=60,createdAt=os.time()};appropriateness[item.id]=item;return item.appropriate,item
end)
exports('RecordReportDiscrepancy',function(studyId,original,final,severity,actor)local item={id=uid('DISC'),studyId=studyId,original=original,final=final,severity=severity or'minor',actor=actor,createdAt=os.time(),acknowledged=false};discrepancies[item.id]=item;return item.id,item end)
exports('AcknowledgeReportDiscrepancy',function(id,actor)local item=discrepancies[tostring(id)];if not item then return false end;item.acknowledged=true;item.acknowledgedBy=actor;item.acknowledgedAt=os.time();return true,item end)
exports('GetRadiologyV8Board',function()return{appropriateness=appropriateness,discrepancies=discrepancies,generatedAt=os.time()}end)
CreateThread(function()Wait(3000);print('[dpn-medical-radiology] v8 imaging appropriateness and quality review active')end)
