local VERSION='10.0.0'
local missions, sceneCommands, handoffs = {}, {}, {}
local function uid(p)return('%s-%s-%04d'):format(p,os.time(),math.random(0,9999))end
local function core(name,...)local a=table.pack(...);local ok,x,y=pcall(function()local p=exports['dpn-medical-core'];return p[name](p,table.unpack(a,1,a.n))end);return ok,x,y end
exports('CreateCriticalCareMissionV10',function(target,unit,scene)
 local ok,twin=core('GetV10Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end
 local mission={id=uid('CCM'),target=tonumber(target),unit=unit,scene=scene or{},priority=twin.v10.commandRisk>=85 and 1 or twin.v10.commandRisk>=65 and 2 or 3,arrestMinutes=twin.v10.predictedArrestMinutes,requiredCapabilities={},checklist={'scene_safe','primary_survey','hemorrhage_control','airway_plan','transport_decision'},status='assigned',createdAt=os.time()}
 if twin.circulation.hemorrhageRateMlMin+twin.circulation.internalHemorrhageRateMlMin>=30 then mission.requiredCapabilities[#mission.requiredCapabilities+1]='blood_products'end
 if twin.bloodGas.oxygenationFailure or twin.bloodGas.ventilationFailure then mission.requiredCapabilities[#mission.requiredCapabilities+1]='advanced_airway'end
 if twin.toxicity.totalBurden>=35 then mission.requiredCapabilities[#mission.requiredCapabilities+1]='toxicology_antidotes'end
 missions[mission.id]=mission;return true,mission
end)
exports('CreateSceneMedicalCommandV10',function(callId,commander,hazards,patients)local item={id=uid('SCENE'),callId=callId,commander=commander,hazards=hazards or{},patients=patients or{},sectors={},status='active',timeline={{event='command_established',at=os.time()}},createdAt=os.time()};sceneCommands[item.id]=item;return item.id,item end)
exports('GenerateCriticalCareHandoffV10',function(target,destination,crew)local ok,twin=core('GetV10Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end;local item={id=uid('H10'),target=tonumber(target),destination=destination,crew=crew,summary={risk=twin.v10.commandRisk,arrestMinutes=twin.v10.predictedArrestMinutes,hemorrhage=twin.circulation.hemorrhageRateMlMin+twin.circulation.internalHemorrhageRateMlMin,abg=twin.bloodGas.acidBase,toxidrome=twin.toxicity.dominantToxidrome,careGaps=twin.careGaps},acknowledged=false,createdAt=os.time()};handoffs[item.id]=item;return true,item end)
exports('GetV10EMSBoard',function()return{version=VERSION,missions=missions,sceneCommands=sceneCommands,handoffs=handoffs,generatedAt=os.time()}end)
CreateThread(function()Wait(7000);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-ems',VERSION,{'critical_care_missions','scene_medical_command','v10_handoff','arrest_prediction_transport'})end);print('[dpn-medical-ems] v10 critical-care missions and scene medical command active')end)
