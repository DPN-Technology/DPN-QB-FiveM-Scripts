local ADV_RESOURCE = GetCurrentResourceName()
local ADV_VERSION = GetResourceMetadata(ADV_RESOURCE, 'version', 0) or 'unknown'
CreateThread(function()
    Wait(1800)
    pcall(function()
        exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE, ADV_VERSION, {
            'capacity_command',
            'risk_routing',
            'escalation',
            'multidisciplinary_care_plans',
            'ward_monitoring'
        })
    end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

local QBCoreAdv=exports['qb-core']:GetCoreObject()
local escalations={}
local function recommend(target)
 local s=exports['dpn-medical-core']:GetClinicalSnapshot(tonumber(target)); if not s then return nil end
 if s.cardiacArrest or s.risk=='critical' then return 'icu','Immediate critical-care admission' end
 if s.severeInjuries and s.severeInjuries>0 and (s.bleeding or s.lactate>=4) then return 'or','Trauma surgery evaluation' end
 if s.risk=='high' then return 'icu','High deterioration risk' end
 if s.risk=='moderate' then return 'er','Monitored emergency care' end
 return 'recovery','Routine observation and recovery'
end
exports('RecommendWard',recommend)
exports('GetCapacitySnapshot',function()
 local beds=exports['dpn-medical-hospital']:GetBeds() or {}; local byWard={}; local total,occupied=0,0
 for id,b in pairs(beds) do local ward=b.ward or b.type or 'unknown'; byWard[ward]=byWard[ward] or {total=0,occupied=0,available=0}; byWard[ward].total=byWard[ward].total+1; total=total+1; if b.occupied then byWard[ward].occupied=byWard[ward].occupied+1; occupied=occupied+1 else byWard[ward].available=byWard[ward].available+1 end end
 return {total=total,occupied=occupied,available=total-occupied,occupancy=total>0 and math.floor(occupied/total*100) or 0,wards=byWard}
end)
exports('BuildAdmissionPlan',function(target,reason)
 target=tonumber(target); local ward,rationale=recommend(target); if not ward then return nil end
 local snapshot=exports['dpn-medical-core']:GetClinicalSnapshot(target); local tasks={}
 if snapshot.bleeding then tasks[#tasks+1]='Hemorrhage reassessment every 5 minutes' end
 if snapshot.spo2<94 then tasks[#tasks+1]='Continuous oxygen saturation monitoring' end
 if snapshot.risk=='high' or snapshot.risk=='critical' then tasks[#tasks+1]='Continuous cardiac monitoring' end
 for _,label in ipairs(tasks) do exports['dpn-medical-core']:AddCarePlanTask(target,{label=label,priority=1}) end
 return {ward=ward,rationale=rationale,risk=snapshot.risk,tasks=tasks,reason=reason}
end)
AddEventHandler('dpn-medical:server:criticalAlert',function(target,citizenId,snapshot)
 local admission=DPNAdmissions and DPNAdmissions[citizenId]; if not admission then return end
 if admission.ward~='icu' and snapshot.recommendedCare=='icu' and not escalations[target] then
  escalations[target]=os.time(); pcall(function() MySQL.insert('INSERT INTO dpn_medical_hospital_escalations (patient_cid,admission_id,from_ward,recommended_ward,reason,snapshot) VALUES (?,?,?,?,?,?)',{citizenId,admission.id,admission.ward,'icu','Automated deterioration alert',json.encode(snapshot)}) end)
  for _,sid in ipairs(GetPlayers()) do local p=QBCoreAdv.Functions.GetPlayer(tonumber(sid)); local j=p and p.PlayerData.job or {}; if Config.JobAccess and Config.JobAccess[j.name] then TriggerClientEvent('QBCore:Notify',tonumber(sid),('Hospital escalation: patient %s requires ICU review.'):format(target),'error',9000) end end
 end
end)
QBCoreAdv.Commands.Add('hospitalcapacity','Show hospital capacity',{},false,function(src)
 local c=exports['dpn-medical-hospital']:GetCapacitySnapshot(); TriggerClientEvent('chat:addMessage',src,{args={'DPN Hospital',('Beds %s/%s occupied (%s%%)'):format(c.occupied,c.total,c.occupancy)}})
end)

