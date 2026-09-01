local ADV_RESOURCE = GetCurrentResourceName()
local ADV_VERSION = GetResourceMetadata(ADV_RESOURCE, 'version', 0) or 'unknown'
CreateThread(function()
    Wait(1800)
    pcall(function()
        exports['dpn-medical-core']:RegisterModule(ADV_RESOURCE, ADV_VERSION, {
            'medication_safety',
            'interaction_checks',
            'mar',
            'controlled_substances',
            'dose_tracking'
        })
    end)
    while true do
        TriggerEvent('dpn-medical-core:server:moduleHeartbeat',ADV_RESOURCE,ADV_VERSION,{status='operational'})
        Wait(60000)
    end
end)

local interactions={morphine={naloxone='antagonist',ibuprofen='monitor'},epinephrine={morphine='monitor'},amoxicillin={}}
exports('CheckMedicationSafety',function(target,drugId)
 local state=exports['dpn-medical-core']:GetPatientState(tonumber(target)); if not state then return false,{'Patient not found'} end; local alerts={}; local allergy=(state.profile and state.profile.allergies or {})[tostring(drugId):lower()]; if allergy then alerts[#alerts+1]='Documented allergy' end
 for _,med in ipairs(state.medications or {}) do local relation=interactions[drugId] and interactions[drugId][med.id]; if relation then alerts[#alerts+1]=('Interaction with %s: %s'):format(med.id,relation) end end
 if drugId=='morphine' and ((state.vitals.rr or 0)<10 or (state.vitals.spo2 or 0)<90) then alerts[#alerts+1]='Respiratory depression risk' end
 return #alerts==0,alerts
end)
exports('AdministerMedication',function(src,target,drugId,dose,route)
 target=tonumber(target); local safe,alerts=exports['dpn-medical-pharmacy']:CheckMedicationSafety(target,drugId); if not safe then return false,table.concat(alerts,'; ') end
 local p=exports['qb-core']:GetCoreObject().Functions.GetPlayer(tonumber(src)); local by=p and p.PlayerData.citizenid or tostring(src); local ok=exports['dpn-medical-core']:AddMedication(target,drugId,{dose=dose,route=route,by=by,time=os.time(),expiresAt=os.time()+3600}); if ok then pcall(function() MySQL.insert('INSERT INTO dpn_medical_medication_administration (patient_id,drug_id,dose,route,administered_by,safety_alerts) VALUES (?,?,?,?,?,?)',{target,drugId,dose,route,by,json.encode(alerts)}) end); exports['dpn-medical-core']:AddClinicalEvent(target,'medication_administered',{drug=drugId,dose=dose,route=route},by) end; return ok,alerts
end)

