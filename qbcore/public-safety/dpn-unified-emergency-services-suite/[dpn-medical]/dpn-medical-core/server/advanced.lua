local QBCore = exports['qb-core']:GetCoreObject()
local activeEpisodes, lastRisk, lastAlerts, moduleHealth = {}, {}, {}, {}

local function player(target) return QBCore.Functions.GetPlayer(tonumber(target)) end
local function cid(target)
    local p = player(target)
    return p and p.PlayerData and p.PlayerData.citizenid or (DPNMedicalServer.CitizenId and DPNMedicalServer.CitizenId(target))
end
local function commit(target, state, eventType, data)
    local _, patientCid = DPNMedicalServer.EnsureState(tonumber(target))
    if not patientCid then return false end
    DPNMedicalServer.Commit(tonumber(target), patientCid, state, eventType, data or {})
    return true
end
local function clinicalEvent(target, eventType, data, actor)
    target = tonumber(target)
    local state = DPNMedicalServer.EnsureState(target)
    if not state then return false end
    DPN_MED.AddTimelineEvent(state, eventType, data, actor)
    commit(target, state, 'clinical_event', { eventType=eventType, data=data, actor=actor })
    TriggerEvent(DPN_MED.Events.ClinicalEvent, target, cid(target), eventType, data or {}, actor or 'system')
    pcall(function()
        MySQL.insert('INSERT INTO dpn_medical_clinical_events (patient_cid,event_type,actor_cid,event_data) VALUES (?,?,?,?)', { cid(target), tostring(eventType):sub(1,64), actor, json.encode(data or {}) })
    end)
    return true
end
local function createEpisode(target, episodeType, data)
    target = tonumber(target); data = type(data)=='table' and data or {}
    local state = DPNMedicalServer.EnsureState(target); if not state then return false end
    local id = ('EP-%s-%s-%04d'):format(os.date('%Y%m%d'), target, math.random(0,9999))
    local episode = { id=id, type=tostring(episodeType or 'medical'), status='active', acuity=data.acuity or state.status.triage, openedAt=os.time(), openedBy=data.openedBy or 'system', source=data.source, metadata=data }
    activeEpisodes[target] = episode
    state.episodes[#state.episodes+1] = episode
    while #state.episodes > 25 do table.remove(state.episodes,1) end
    state.flags.activeEpisodeId = id
    commit(target,state,'episode_opened',episode)
    pcall(function() MySQL.insert('INSERT INTO dpn_medical_care_episodes (episode_id,patient_cid,episode_type,acuity,status,opened_by,metadata) VALUES (?,?,?,?,?,?,?)',{id,cid(target),episode.type,episode.acuity,'active',episode.openedBy,json.encode(data)}) end)
    TriggerEvent(DPN_MED.Events.EpisodeChanged,target,cid(target),episode)
    return id,episode
end
local function closeEpisode(target, disposition, data)
    target=tonumber(target); local episode=activeEpisodes[target]; if not episode then return false end
    episode.status='closed'; episode.closedAt=os.time(); episode.disposition=disposition or 'completed'; episode.closeData=data or {}
    local state=DPNMedicalServer.EnsureState(target); if state then state.flags.activeEpisodeId=nil; commit(target,state,'episode_closed',episode) end
    pcall(function() MySQL.update('UPDATE dpn_medical_care_episodes SET status=?,disposition=?,closed_at=NOW(),metadata=? WHERE episode_id=?',{'closed',episode.disposition,json.encode(episode.closeData),episode.id}) end)
    activeEpisodes[target]=nil; TriggerEvent(DPN_MED.Events.EpisodeChanged,target,cid(target),episode); return true
end

exports('GetClinicalSnapshot',function(target) local s=DPNMedicalServer.EnsureState(tonumber(target)); return s and DPN_MED.GetClinicalSnapshot(s) or nil end)
exports('CheckTreatmentSafety',function(target,treatment,part,context) local s=DPNMedicalServer.EnsureState(tonumber(target)); if not s then return false,'Patient not found',{} end return DPN_MED.CheckTreatmentSafety(s,treatment,part,context) end)
exports('GetProtocolRecommendations',function(target) local s=DPNMedicalServer.EnsureState(tonumber(target)); return s and DPN_MED.GetProtocolRecommendations(s) or {} end)
exports('CreateCareEpisode',createEpisode)
exports('CloseCareEpisode',closeEpisode)
exports('GetActiveEpisode',function(target) return activeEpisodes[tonumber(target)] end)
exports('AddClinicalEvent',clinicalEvent)
exports('AddCarePlanTask',function(target,task)
    target=tonumber(target); local state=DPNMedicalServer.EnsureState(target); if not state then return false end
    local updated,id=DPN_MED.AddCarePlanTask(state,task); commit(target,updated,'care_plan_task_added',{taskId=id,task=task}); TriggerEvent(DPN_MED.Events.CarePlanChanged,target,cid(target),updated.carePlan); return id
end)
exports('CompleteCarePlanTask',function(target,taskId,actor)
    target=tonumber(target); local state=DPNMedicalServer.EnsureState(target); if not state then return false end
    local updated,ok=DPN_MED.CompleteCarePlanTask(state,taskId,actor); if ok then commit(target,updated,'care_plan_task_completed',{taskId=taskId,actor=actor}); TriggerEvent(DPN_MED.Events.CarePlanChanged,target,cid(target),updated.carePlan) end; return ok
end)
exports('GetCarePlan',function(target) local s=DPNMedicalServer.EnsureState(tonumber(target)); return s and s.carePlan or nil end)
exports('AddProcedure',function(target,procedure) target=tonumber(target); local s=DPNMedicalServer.EnsureState(target); if not s then return false end; DPN_MED.AddProcedure(s,procedure); return commit(target,s,'procedure',procedure) end)
exports('AddAllergy',function(target,allergy) target=tonumber(target); local s=DPNMedicalServer.EnsureState(target); if not s then return false end; s.profile.allergies[tostring(allergy):lower()]=true; return commit(target,s,'allergy_added',{allergy=allergy}) end)
exports('RemoveAllergy',function(target,allergy) target=tonumber(target); local s=DPNMedicalServer.EnsureState(target); if not s then return false end; s.profile.allergies[tostring(allergy):lower()]=nil; return commit(target,s,'allergy_removed',{allergy=allergy}) end)
exports('SetBloodType',function(target,bloodType) target=tonumber(target); local s=DPNMedicalServer.EnsureState(target); if not s then return false end; local valid={['A+']=true,['A-']=true,['B+']=true,['B-']=true,['AB+']=true,['AB-']=true,['O+']=true,['O-']=true,UNKNOWN=true}; bloodType=tostring(bloodType or 'unknown'):upper(); if not valid[bloodType] then return false end; s.profile.bloodType=bloodType; return commit(target,s,'blood_type',{bloodType=bloodType}) end)
exports('SetCodeStatus',function(target,status) target=tonumber(target); local s=DPNMedicalServer.EnsureState(target); if not s then return false end; status=tostring(status or 'full_code'); if status~='full_code' and status~='dnr' and status~='limited' then return false end; s.profile.codeStatus=status; return commit(target,s,'code_status',{status=status}) end)
exports('SetDevice',function(target,deviceId,data) target=tonumber(target); local s=DPNMedicalServer.EnsureState(target); if not s then return false end; deviceId=tostring(deviceId or ''):sub(1,64); if deviceId=='' then return false end; if data==false then s.devices[deviceId]=nil else s.devices[deviceId]=type(data)=='table' and data or {active=true}; s.devices[deviceId].updatedAt=os.time() end; return commit(target,s,'device_changed',{device=deviceId,data=data}) end)
exports('GetSystemHealth',function() return { version='6.0.0', modules=moduleHealth, activeEpisodes=activeEpisodes, players=#GetPlayers(), time=os.time() } end)

RegisterNetEvent(DPN_MED.Events.ModuleHeartbeat,function(name,version,metrics)
    name=tostring(name or ''):sub(1,64); if name=='' then return end
    moduleHealth[name]={version=tostring(version or 'unknown'),metrics=type(metrics)=='table' and metrics or {},lastSeen=os.time(),state=GetResourceState(name)}
    pcall(function() MySQL.insert('INSERT INTO dpn_medical_module_health (resource_name,version,health_data,last_seen) VALUES (?,?,?,NOW()) ON DUPLICATE KEY UPDATE version=VALUES(version),health_data=VALUES(health_data),last_seen=NOW()',{name,tostring(version or 'unknown'),json.encode(metrics or {})}) end)
end)

AddEventHandler(DPN_MED.Events.StateChanged,function(target,patientCid,state,eventType,data)
    if Config.Advanced.autoCreateEpisodes and eventType=='injury' and not activeEpisodes[tonumber(target)] then createEpisode(target,'trauma',{source='automatic',acuity=state.status.triage}) end
end)

CreateThread(function()
    Wait(2500)
    print('[dpn-medical-core] v6.0.0 advanced physiology, care episodes, protocols, care plans and clinical event bus active')
    while true do
        Wait(math.max(5,tonumber(Config.Advanced.physiologyTickSeconds) or 5)*1000)
        local current=os.time()
        for _,sid in ipairs(GetPlayers()) do
            local target=tonumber(sid); local state=DPNMedicalServer.EnsureState(target)
            if state then
                local snapshot=DPN_MED.GetClinicalSnapshot(state); local previous=lastRisk[target]
                if previous~=snapshot.risk then
                    lastRisk[target]=snapshot.risk
                    clinicalEvent(target,'risk_changed',{from=previous,to=snapshot.risk,deterioration=snapshot.deterioration},'medical-core')
                end
                if snapshot.risk=='critical' or snapshot.cardiacArrest then
                    if current-(lastAlerts[target] or 0)>=(Config.Advanced.criticalAlertCooldownSeconds or 45) then
                        lastAlerts[target]=current
                        TriggerEvent(DPN_MED.Events.CriticalAlert,target,cid(target),snapshot)
                        if GetResourceState('dpn-medical-dispatch')=='started' then pcall(function() exports['dpn-medical-dispatch']:CreateMedicalCall({citizenid=cid(target),type='clinical_deterioration',priority=1,message=('Critical medical deterioration for patient ID %s'):format(target),patient=target,snapshot=snapshot}) end) end
                    end
                end
            end
        end
    end
end)

QBCore.Commands.Add('medprofile','Set blood type or code status',{{name='id'},{name='field'},{name='value'}},true,function(src,args)
    if not DPNMedicalServer.HasAdminPermission(src) and not DPNMedicalServer.IsMedicalJob(player(src),'doctor') then return end
    local target=tonumber(args[1]); local field=tostring(args[2] or ''); local value=tostring(args[3] or '')
    local ok=false; if field=='blood' then ok=exports['dpn-medical-core']:SetBloodType(target,value) elseif field=='code' then ok=exports['dpn-medical-core']:SetCodeStatus(target,value) elseif field=='allergy' then ok=exports['dpn-medical-core']:AddAllergy(target,value) end
    TriggerClientEvent('QBCore:Notify',src,ok and 'Patient profile updated.' or 'Profile update failed.',ok and 'success' or 'error')
end)
