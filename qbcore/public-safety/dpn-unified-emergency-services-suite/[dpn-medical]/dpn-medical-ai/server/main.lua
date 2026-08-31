local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    Wait(1000)
    exports['dpn-medical-core']:RegisterModule('dpn-medical-ai','2.0.0',{'clinical_ai','deterioration_score','recommendations'})
end)

local function assess(state)
    local v,s=state.vitals,state.status; local score=0; local rec={}
    if v.spo2<90 then score=score+3; rec[#rec+1]='Administer oxygen and assess airway' end
    if v.systolic<90 then score=score+3; rec[#rec+1]='Treat shock; establish IV access' end
    if v.blood<3000 then score=score+4; rec[#rec+1]='Control hemorrhage and consider blood products' end
    if s.cardiacArrest then score=score+6; rec[#rec+1]='Begin resuscitation and defibrillator protocol' end
    if s.pain>70 then score=score+2; rec[#rec+1]='Reassess injuries and analgesia' end
    for part,p in pairs(state.body) do if p.internalBleeding then score=score+3; rec[#rec+1]='Urgent surgical evaluation: '..part end end
    if #rec==0 then rec[1]='Continue observation and repeat vitals' end
    return math.min(20,score),rec
end
exports('AssessPatient',function(target)
    local state=exports['dpn-medical-core']:GetPatientState(tonumber(target)); if not state then return nil end
    local score,rec=assess(state); return {score=score,risk=score>=10 and 'critical' or (score>=6 and 'high' or (score>=3 and 'moderate' or 'low')),recommendations=rec}
end)
QBCore.Commands.Add('medai','Run clinical decision support',{{name='id'}},true,function(src,args)
    local p=QBCore.Functions.GetPlayer(src); local j=p and p.PlayerData.job or {}; if not Config.AllowedJobs[j.name] and not QBCore.Functions.HasPermission(src,'admin') then return end
    local result=exports['dpn-medical-ai']:AssessPatient(args[1]); if not result then return end
    TriggerClientEvent('chat:addMessage',src,{args={'DPN Medical AI',('Risk %s | Score %s | %s'):format(result.risk,result.score,table.concat(result.recommendations,'; '))}})
    local patient=QBCore.Functions.GetPlayer(tonumber(args[1])); if patient then MySQL.insert('INSERT INTO dpn_medical_ai_assessments (patient_cid,score,risk,recommendations) VALUES (?,?,?,?)',{patient.PlayerData.citizenid,result.score,result.risk,json.encode(result.recommendations)}) end
end)
