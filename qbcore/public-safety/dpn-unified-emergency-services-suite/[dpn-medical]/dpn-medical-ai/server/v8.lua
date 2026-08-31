local VERSION='8.0.0'
local recommendations, outcomes, governance = {}, {}, {enabled=true,minimumConfidence=0.65,advisoryOnly=true}
local function uid(prefix)return('%s-%s-%04d'):format(prefix,os.time(),math.random(0,9999))end
exports('GeneratePrecisionRecommendation',function(target)
    local ok,twin=pcall(function()return exports['dpn-medical-core']:GetPrecisionTwin(tonumber(target))end);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end
    local confidence=math.max(0.5,math.min(0.98,0.7+(twin.v8.precisionRisk or 0)/500));local item={id=uid('AIREC'),target=target,risk=twin.v8.precisionRisk,confidence=confidence,destination=twin.v8.recommendedDestination,recommendations=twin.recommendations,explanation={oxygenDebt=twin.metabolism.oxygenDebt,cardiacOutput=twin.hemodynamics.cardiacOutputLpm,sofa=twin.v6 and twin.v6.sofa},advisoryOnly=true,createdAt=os.time()};recommendations[item.id]=item;return true,item
end)
exports('RecordAIOutcome',function(recommendationId,outcome,correct,actor)local item={id=uid('AIOUT'),recommendationId=recommendationId,outcome=outcome,correct=correct==true,actor=actor,createdAt=os.time()};outcomes[item.id]=item;return item.id,item end)
exports('SetAIGovernance',function(data)for k,v in pairs(type(data)=='table'and data or{})do if governance[k]~=nil then governance[k]=v end end;return governance end)
exports('GetAIV8Board',function()return{recommendations=recommendations,outcomes=outcomes,governance=governance,generatedAt=os.time()}end)
CreateThread(function()Wait(3000);print('[dpn-medical-ai] v8 governed precision decision support active')end)
