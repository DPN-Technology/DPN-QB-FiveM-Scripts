local QBCore = exports['qb-core']:GetCoreObject()
local activeCalls, distressCooldowns, responders = {}, {}, {}
local fallbackSequence = 0

local function log(message)
    if Config.Debug then print(('[dpn-medical-dispatch] %s'):format(tostring(message))) end
end

local function player(src) return QBCore.Functions.GetPlayer(tonumber(src)) end
local function playerName(src,p)
    p=p or player(src);local data=p and p.PlayerData or{};local info=type(data.charinfo)=='table' and data.charinfo or{}
    local name=(('%s %s'):format(info.firstname or '',info.lastname or '')):gsub('^%s+',''):gsub('%s+$','')
    return name~='' and name or GetPlayerName(tonumber(src)) or ('Player '..tostring(src))
end
local function jobAllowed(p)
    local job=p and p.PlayerData and p.PlayerData.job or{}
    return Config.Jobs[job.name]==true and (Config.NotifyOffDuty==true or job.onduty~=false)
end
local function isResponder(src)
    local p=player(src);if not p then return false end
    local job=p.PlayerData.job or{};return Config.DispatcherJobs[job.name]==true and (Config.NotifyOffDuty==true or job.onduty~=false)
end
local function serverCoords(src)
    local ped=GetPlayerPed(tonumber(src));if not ped or ped<=0 then return nil end
    local c=GetEntityCoords(ped);return {x=c.x+0.0,y=c.y+0.0,z=c.z+0.0}
end
local function encode(value)local ok,result=pcall(json.encode,value or{});return ok and result or '{}'end
local function callExport(resourceName,exportName,...)
    if GetResourceState(resourceName)~='started' then return false,nil,'not started' end
    local args=table.pack(...)
    local ok,a,b=pcall(function()
        local proxy=exports[resourceName];local fn=proxy and proxy[exportName]
        if type(fn)~='function' then error('missing export '..exportName) end
        return fn(proxy,table.unpack(args,1,args.n))
    end)
    return ok,a,b or (ok and nil or tostring(a))
end
local function coreExport(name,...)
    return callExport('dpn-medical-core',name,...)
end
local function nextFallbackId()
    fallbackSequence=fallbackSequence+1
    return ('MED-%s-%04d'):format(os.date('%H%M%S'),fallbackSequence%10000)
end
local function insertCall(call)
    local ok,id=pcall(function()
        return MySQL.insert.await('INSERT INTO dpn_medical_dispatch_calls (caller_cid,call_type,priority,message,coords,status) VALUES (?,?,?,?,?,?)',{
            call.callerCid,call.type,call.priority,call.description,encode(call.coords),'open'
        })
    end)
    if ok and id then return id,true end
    log('database insert unavailable; continuing with in-memory call: '..tostring(id))
    return nextFallbackId(),false
end
local function externalPayload(call)
    return {
        id=call.id,externalId=call.externalId,originResource='dpn-medical-dispatch',source=call.source,
        departments={'ems','fire'},primaryDepartment='ems',code=call.code or 'MED-1',priority=call.priority,
        title=call.title,description=call.description,message=call.description,callType=call.type,
        incidentClass=call.incidentClass or 'medical_emergency',responseLevel=call.priority==1 and 'critical' or 'emergency',
        coords=call.coords,location=call.location or 'GPS Location',caller=call.caller,patient=call.patient,
        riskFlags=call.riskFlags or{},tags=call.tags or{'medical','distress'},unitsRequested=call.unitsRequested or{'Medic','EMS Supervisor'},
        recommendedResponse=call.recommendedResponse or{},status=call.status,createdAt=call.createdAt,
        meta={medicalCallId=call.id,clinical=call.clinical,origin='dpn-medical-dispatch'}
    }
end
local function bridgeCreate(call)
    if not Config.ExternalDispatch or Config.ExternalDispatch.enabled~=true then return false,'disabled' end
    local payload=externalPayload(call);local successes={}
    for _,resourceName in ipairs(Config.ExternalDispatch.resources or{}) do
        if GetResourceState(resourceName)=='started' then
            for _,exportName in ipairs(Config.ExternalDispatch.exports or{}) do
                local ok,result=callExport(resourceName,exportName,payload)
                if ok and result~=false then
                    successes[#successes+1]={resource=resourceName,method='export:'..exportName,result=result}
                    call.externalId=type(result)=='table' and (result.id or result.callId) or result
                    if Config.ExternalDispatch.mode=='first_success' then break end
                end
            end
        end
        if #successes>0 and Config.ExternalDispatch.mode=='first_success' then break end
    end
    -- Emit event fallbacks only when no export accepted the incident, unless the
    -- server explicitly opts into both paths. This prevents duplicate CAD calls.
    if #successes == 0 or Config.ExternalDispatch.emitEventsAfterExport == true then
        for _, eventName in ipairs(Config.ExternalDispatch.events or {}) do
            TriggerEvent(eventName, payload)
        end
    end
    TriggerEvent('dpn-medical:dispatch:externalBridge', payload, successes)
    CreateThread(function()
        pcall(function()
            MySQL.insert.await('INSERT INTO dpn_medical_v7_dispatch_bridge_log (medical_call_id, external_resource, external_reference, success, payload_data) VALUES (?, ?, ?, ?, ?)', {
                tostring(call.id),
                successes[1] and successes[1].resource or 'event-broadcast',
                call.externalId and tostring(call.externalId) or nil,
                #successes > 0 and 1 or 0,
                encode({ payload = payload, successes = successes })
            })
        end)
    end)
    return #successes > 0, successes
end
local function bridgeUpdate(call,update)
    if not Config.ExternalDispatch or Config.ExternalDispatch.enabled~=true then return end
    local payload=externalPayload(call);payload.update=update
    for _,eventName in ipairs(Config.ExternalDispatch.updateEvents or{}) do TriggerEvent(eventName,payload) end
    TriggerEvent('dpn-medical:dispatch:externalUpdate',payload)
end
local function clinicalData(src)
    local ok,state=coreExport('GetPatientState',src);if not ok or type(state)~='table' then return {} end
    local v=state.vitals or{};local s=state.status or{}
    local okTwin,twin=coreExport('GetDigitalTwin',src)
    return {lifeState=s.lifeState,triage=s.triage,blood=v.blood,hr=v.hr,rr=v.rr,spo2=v.spo2,bp={v.systolic,v.diastolic},pain=s.pain,shock=s.shock,digitalTwin=okTwin and twin or nil}
end
local function calculatePriority(clinical)
    if clinical.lifeState=='dead' or clinical.triage=='black' or clinical.triage=='red' or (tonumber(clinical.spo2)or 100)<85 or (tonumber(clinical.blood)or 5000)<2800 then return 1 end
    if clinical.lifeState=='incapacitated' or (tonumber(clinical.shock)or 0)>=60 then return 1 end
    return 2
end
local function notifyResponders(call)
    local count=0
    for _,sid in ipairs(GetPlayers()) do
        local src=tonumber(sid);local p=player(src)
        if jobAllowed(p) then
            count=count+1;TriggerClientEvent('dpn-medical-dispatch:client:newCall',src,call)
        end
    end
    return count
end
local function lifeStateAllowed(src)
    if Config.RequireIncapacitatedForDistress~=true then return true end
    local ok,state=coreExport('GetPatientState',src)
    local life=ok and type(state)=='table' and state.status and state.status.lifeState or nil
    return life=='incapacitated' or (Config.AllowDeadDistress==true and life=='dead'),life
end
local function createCall(src,data)
    data=type(data)=='table' and data or{}
    local p=src and src>0 and player(src) or nil
    local clinical=src and src>0 and clinicalData(src) or type(data.clinical)=='table' and data.clinical or{}
    local coords=(src and src>0 and serverCoords(src)) or data.coords or{}
    local priority=math.max(1,math.min(5,tonumber(data.priority) or calculatePriority(clinical)))
    local callerCid=p and p.PlayerData.citizenid or data.citizenid
    local call={
        source=src,callerCid=callerCid,type=tostring(data.type or 'distress'):sub(1,32),priority=priority,
        code=data.code or(priority==1 and 'MED-1' or 'MED-2'),title=data.title or(priority==1 and 'Critical Medical Distress' or 'Medical Assistance Requested'),
        description=tostring(data.message or 'Incapacitated patient distress alert'):sub(1,500),coords=coords,status='open',createdAt=os.time(),
        caller={source=src,citizenid=callerCid,name=p and playerName(src,p) or data.callerName or 'Unknown'},
        patient={source=src,citizenid=callerCid,name=p and playerName(src,p) or data.patientName or 'Unknown',clinical=clinical},
        clinical=clinical,riskFlags=data.riskFlags or{},tags=data.tags or{'medical','distress'},responders={},timeline={}
    }
    call.id,call.persisted=insertCall(call);activeCalls[tostring(call.id)]=call
    local okCad,cadId=callExport('dpn-medical-dispatch','CreateCADIncident',src or ' medical-dispatch',{type=call.type,priority=call.priority,location=call.coords,caller=call.caller,patient=call.patient,notes={{text=call.description,at=os.time()}}})
    if okCad then call.cadId=cadId end
    local bridged,bridge=bridgeCreate(call);call.externalBridge=bridge
    local units=notifyResponders(call);call.notifiedUnits=units
    call.timeline[#call.timeline+1]={event='created',at=os.time(),unitsNotified=units,externalBridged=bridged}
    TriggerEvent('dpn-medical:dispatch:callCreated',call)
    return call
end

RegisterNetEvent('dpn-medical-dispatch:server:distress',function(clientData)
    local src=source;local now=os.time();local cooldown=tonumber(Config.DistressCooldownSeconds)or 60
    if now-(distressCooldowns[src]or 0)<cooldown then
        local remaining=cooldown-(now-(distressCooldowns[src]or 0))
        return TriggerClientEvent('dpn-medical-dispatch:client:distressResult',src,{ok=false,message=('Distress cooldown active for %s more seconds.'):format(remaining)})
    end
    local allowed,life=lifeStateAllowed(src)
    if not allowed then
        return TriggerClientEvent('dpn-medical-dispatch:client:distressResult',src,{ok=false,message=('Distress denied because medical life state is %s.'):format(tostring(life or 'unknown'))})
    end
    distressCooldowns[src]=now
    local call=createCall(src,{type='distress',priority=1,message='Incapacitated patient activated the emergency distress beacon',riskFlags={'patient_down','unknown_scene_safety'},tags={'medical','distress','patient-do wn'}})
    local message=call.notifiedUnits>0 and ('EMS distress sent as call #%s to %s on-duty responder(s).'):format(call.id,call.notifiedUnits) or ('EMS distress call #%s created; no on-duty DPN EMS units were detected, but external dispatch escalation was attempted.'):format(call.id)
    TriggerClientEvent('dpn-medical-dispatch:client:distressResult',src,{ok=true,callId=call.id,units=call.notifiedUnits,message=message})
end)

RegisterNetEvent('dpn-medical-dispatch:server:respond',function(callId,status)
    local src=source;if not isResponder(src) then return end
    local call=activeCalls[tostring(callId)];if not call then return TriggerClientEvent('QBCore:Notify',src,'Medical call not found or expired.','error',5000) end
    local allowed={accepted=true,enroute=true,onscene=true,transporting=true,clear=true,unavailable=true};status=tostring(status or 'accepted'):lower();if not allowed[status] then status='accepted' end
    responders[src]=responders[src] or{};responders[src].status=status;responders[src].callId=call.id;responders[src].updatedAt=os.time()
    call.responders[tostring(src)]={source=src,name=playerName(src),status=status,updatedAt=os.time()};call.timeline[#call.timeline+1]={event='unit_status',unit=src,status=status,at=os.time()}
    if status=='accepted' or status=='enroute' then call.status='assigned';TriggerClientEvent('dpn-medical-dispatch:client:routeToCall',src,call) end
    if status=='onscene' then call.status='onscene' end
    if status=='transporting' then call.status='transporting' end
    if status=='clear' then call.status='closed' end
    if type(call.id)=='number' then pcall(function()MySQL.update.await('UPDATE dpn_medical_dispatch_calls SET status=? WHERE id=?',{call.status,call.id})end) end
    bridgeUpdate(call,{unit=src,status=status})
    for _,sid in ipairs(GetPlayers())do local unit=tonumber(sid);if jobAllowed(player(unit))then TriggerClientEvent('dpn-medical-dispatch:client:callUpdated',unit,call)end end
    TriggerEvent('dpn-medical:dispatch:unitStatusChanged',call,src,status)
    TriggerClientEvent('QBCore:Notify',src,('Call #%s status set to %s.'):format(call.id,status),'success',5000)
end)

QBCore.Commands.Add('emsalert','Create a medical dispatch call',{{name='message'}},false,function(src,args)
    local message=table.concat(args or{},' ');if message==''then message='Medical assistance requested'end
    local call=createCall(src,{type='medical',priority=2,message=message,tags={'medical','manual-call'}})
    TriggerClientEvent('QBCore:Notify',src,('Medical call #%s created.'):format(call.id),'success',5000)
end)
exports('CreateMedicalCall',function(data)return createCall(tonumber(data and data.source)or 0,data)end)
exports('GetActiveMedicalCalls',function()return activeCalls end)
exports('GetResponderStatus',function(sourceId)return responders[tonumber(sourceId)]end)
exports('GetDispatchBridgeHealth', function()
    local resources = {}
    for _, resourceName in ipairs((Config.ExternalDispatch and Config.ExternalDispatch.resources) or {}) do
        resources[#resources + 1] = { name = resourceName, state = GetResourceState(resourceName) }
    end
    return {
        activeCalls = activeCalls,
        responders = responders,
        externalEnabled = Config.ExternalDispatch and Config.ExternalDispatch.enabled == true,
        externalResources = resources,
        createEvents = (Config.ExternalDispatch and Config.ExternalDispatch.events) or {},
        updateEvents = (Config.ExternalDispatch and Config.ExternalDispatch.updateEvents) or {},
        generatedAt = os.time()
    }
end)
exports('UpdateMedicalCall',function(callId,status,note)
    local call=activeCalls[tostring(callId)];if not call then return false end;call.status=status or call.status;call.timeline[#call.timeline+1]={event='external_update',status=call.status,note=note,at=os.time()};bridgeUpdate(call,{status=call.status,note=note});return true,call
end)

AddEventHandler('playerDropped',function()distressCooldowns[source]=nil;responders[source]=nil end)
CreateThread(function()
    Wait(1000);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-dispatch','4.0.0',{'medical_dispatch','distress_key','call_queue','external_dispatch_bridge','responder_status','gps_routing','cad'})end)
    print('[dpn-medical-dispatch] v4.0.0 distress, responder coordination and DPN Dispatch bridge active')
    while true do
        Wait(60000);local cutoff=os.time()-((tonumber(Config.CallExpiryMinutes)or 30)*60)
        for id,call in pairs(activeCalls)do if call.createdAt<cutoff and call.status~='closed'then call.status='expired';activeCalls[id]=nil end end
    end
end)
