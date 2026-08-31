local VERSION = '6.0.0'
local QBCore = exports['qb-core']:GetCoreObject()
local orders, observations, alerts, handoffs = {}, {}, {}, {}
local quality = { ordersCreated = 0, observationsRecorded = 0, alertsRaised = 0, alertsAcknowledged = 0, handoffsCreated = 0 }
local lastAlertAt = {}

local function targetId(value) value = tonumber(value); return value and value > 0 and value or nil end
local function player(target) return QBCore.Functions.GetPlayer(targetId(target)) end
local function cid(target)
    local p = player(target)
    return p and p.PlayerData and p.PlayerData.citizenid or (DPNMedicalServer.CitizenId and DPNMedicalServer.CitizenId(target))
end
local function actorCid(sourceValue)
    if type(sourceValue) == 'string' then return sourceValue:sub(1,64) end
    local p = player(sourceValue)
    return p and p.PlayerData and p.PlayerData.citizenid or ('source:%s'):format(tostring(sourceValue or 'system'))
end
local function uuid(prefix, target)
    return ('%s-%s-%s-%04d'):format(prefix, os.date('%Y%m%d%H%M%S'), tostring(target or 0), math.random(0,9999))
end
local function encode(value) local ok,result=pcall(json.encode,value or {}); return ok and result or '{}' end
local function persist(query, params)
    CreateThread(function() pcall(function() MySQL.insert.await(query, params) end) end)
end
local function stateFor(target)
    target=targetId(target); if not target then return nil end
    local state=DPNMedicalServer.EnsureState(target); if state then DPN_MED.EnsureV6Schema(state); DPN_MED.CalculateV6Metrics(state) end
    return state
end
local function commit(target,state,eventType,data)
    local patientCid=cid(target); if not state or not patientCid then return false end
    if DPN_MED.AddTimelineEvent then DPN_MED.AddTimelineEvent(state,eventType,data,'clinical-operations') end
    DPNMedicalServer.Commit(target,patientCid,state,eventType,data or {})
    return true
end

local function createOrder(target, orderType, code, data, author)
    target=targetId(target); local state=stateFor(target); if not state then return false,'Patient not found' end
    data=type(data)=='table' and data or {}
    local id=uuid('ORD',target)
    local order={
        id=id, patient=target, patientCid=cid(target), type=tostring(orderType or 'general'):sub(1,40),
        code=tostring(code or 'unspecified'):sub(1,80), status='active', priority=tonumber(data.priority) or 3,
        author=actorCid(author or 'system'), createdAt=os.time(), dueAt=tonumber(data.dueAt), instructions=data.instructions,
        reason=data.reason, module=data.module, metadata=data.metadata or {}, result=nil
    }
    orders[target]=orders[target] or {}; orders[target][id]=order; state.activeOrders[id]=order
    quality.ordersCreated=quality.ordersCreated+1
    commit(target,state,'clinical_order_created',order)
    persist('INSERT INTO dpn_medical_v6_orders (order_id,patient_cid,order_type,order_code,status,priority,author_cid,due_at,order_data) VALUES (?,?,?,?,?,?,?,?,?)',
        {id,order.patientCid,order.type,order.code,order.status,order.priority,order.author,order.dueAt and os.date('%Y-%m-%d %H:%M:%S',order.dueAt) or nil,encode(order)})
    TriggerEvent('dpn-medical:v6:orderChanged',target,order.patientCid,order)
    return id,order
end

local function updateOrder(target, orderId, status, result, actor)
    target=targetId(target); local list=orders[target] or {}; local order=list[tostring(orderId or '')]
    if not order then return false,'Order not found' end
    status=tostring(status or order.status):sub(1,24)
    local allowed={active=true,in_progress=true,completed=true,cancelled=true,held=true}
    if not allowed[status] then return false,'Invalid order status' end
    order.status=status; order.result=result; order.updatedAt=os.time(); order.updatedBy=actorCid(actor or 'system')
    if status=='completed' or status=='cancelled' then order.closedAt=os.time() end
    local state=stateFor(target); if state and state.activeOrders[order.id] then state.activeOrders[order.id]=order; commit(target,state,'clinical_order_updated',order) end
    CreateThread(function() pcall(function() MySQL.update.await('UPDATE dpn_medical_v6_orders SET status=?,result_data=?,updated_at=NOW(),closed_at=IF(? IN (\'completed\',\'cancelled\'),NOW(),closed_at) WHERE order_id=?',{status,encode(result),status,order.id}) end) end)
    TriggerEvent('dpn-medical:v6:orderChanged',target,order.patientCid,order)
    return true,order
end

local function recordObservation(target, observationType, value, unit, data, author)
    target=targetId(target); local state=stateFor(target); if not state then return false,'Patient not found' end
    data=type(data)=='table' and data or {}
    local obs={id=uuid('OBS',target),patient=target,patientCid=cid(target),type=tostring(observationType or 'note'):sub(1,64),value=value,unit=unit,author=actorCid(author or 'system'),recordedAt=os.time(),metadata=data}
    observations[target]=observations[target] or {}; local list=observations[target]; list[#list+1]=obs; while #list>250 do table.remove(list,1) end
    state.observationTrends[obs.type]=state.observationTrends[obs.type] or {}; local trend=state.observationTrends[obs.type]; trend[#trend+1]=obs; while #trend>50 do table.remove(trend,1) end
    local numeric=tonumber(value)
    local vitalMap={heart_rate='hr',respiratory_rate='rr',oxygen_saturation='spo2',systolic='systolic',diastolic='diastolic',temperature='temp',etco2='etco2',blood_volume='blood'}
    local labMap={hemoglobin='hemoglobin',hematocrit='hematocrit',platelets='platelets',inr='inr',sodium='sodium',potassium='potassium',glucose='glucose',creatinine='creatinine',bilirubin='bilirubin',wbc='wbc',ph='ph',pco2='pco2',hco3='hco3'}
    if numeric and vitalMap[obs.type] then state.vitals[vitalMap[obs.type]]=numeric end
    if numeric and labMap[obs.type] then state.labs[labMap[obs.type]]=numeric end
    if obs.type=='urine_output' and numeric then state.fluids.urineMlHr=numeric end
    DPN_MED.CalculateV6Metrics(state); quality.observationsRecorded=quality.observationsRecorded+1
    commit(target,state,'observation_recorded',obs)
    persist('INSERT INTO dpn_medical_v6_observations (observation_id,patient_cid,observation_type,observation_value,unit,author_cid,observation_data) VALUES (?,?,?,?,?,?,?)',
        {obs.id,obs.patientCid,obs.type,tostring(value),unit,obs.author,encode(obs)})
    TriggerEvent('dpn-medical:v6:observationRecorded',target,obs.patientCid,obs)
    return obs.id,obs
end

local function raiseAlert(target, alertType, severity, message, data, sourceName)
    target=targetId(target); if not target then return false end
    alerts[target]=alerts[target] or {}
    local dedupe=tostring(alertType)..':'..tostring(sourceName or 'core')
    for _,item in pairs(alerts[target]) do
        if item.status=='active' and item.dedupe==dedupe then item.updatedAt=os.time(); item.data=data or item.data; return item.id,item end
    end
    local item={id=uuid('ALT',target),patient=target,patientCid=cid(target),type=tostring(alertType):sub(1,64),severity=tostring(severity or 'warning'):sub(1,16),message=tostring(message or alertType):sub(1,255),status='active',source=tostring(sourceName or 'core'):sub(1,64),dedupe=dedupe,createdAt=os.time(),data=data or {}}
    alerts[target][item.id]=item; quality.alertsRaised=quality.alertsRaised+1
    local state=stateFor(target); if state then state.safetyAlerts[item.id]=item; commit(target,state,'safety_alert',item) end
    persist('INSERT INTO dpn_medical_v6_safety_alerts (alert_id,patient_cid,alert_type,severity,status,source_resource,message,alert_data) VALUES (?,?,?,?,?,?,?,?)',
        {item.id,item.patientCid,item.type,item.severity,item.status,item.source,item.message,encode(item.data)})
    TriggerEvent('dpn-medical:v6:safetyAlert',target,item.patientCid,item)
    return item.id,item
end

local function acknowledgeAlert(target, alertId, actor, note)
    target=targetId(target); local item=alerts[target] and alerts[target][tostring(alertId or '')]
    if not item then return false,'Alert not found' end
    item.status='acknowledged'; item.acknowledgedAt=os.time(); item.acknowledgedBy=actorCid(actor); item.note=note
    quality.alertsAcknowledged=quality.alertsAcknowledged+1
    local state=stateFor(target); if state and state.safetyAlerts[item.id] then state.safetyAlerts[item.id]=item; commit(target,state,'safety_alert_acknowledged',item) end
    CreateThread(function() pcall(function() MySQL.update.await('UPDATE dpn_medical_v6_safety_alerts SET status=?,acknowledged_by=?,acknowledged_at=NOW(),resolution_note=? WHERE alert_id=?',{'acknowledged',item.acknowledgedBy,note,item.id}) end) end)
    return true,item
end

local function createHandoff(target, destination, data, author)
    target=targetId(target); local state=stateFor(target); if not state then return false,'Patient not found' end
    data=type(data)=='table' and data or {}
    local twin=DPN_MED.BuildDigitalTwin(state)
    local item={id=uuid('HOF',target),patient=target,patientCid=cid(target),destination=tostring(destination or 'unspecified'):sub(1,80),author=actorCid(author or 'system'),createdAt=os.time(),situation=data.situation or ('Patient is '..tostring(state.status.lifeState)),background=data.background or data.history,assessment=data.assessment or twin,recommendation=data.recommendation or twin.recommendedOrders,readBack=data.readBack==true,status='sent',metadata=data.metadata or {}}
    handoffs[target]=handoffs[target] or {}; handoffs[target][item.id]=item; quality.handoffsCreated=quality.handoffsCreated+1
    commit(target,state,'structured_handoff',item)
    persist('INSERT INTO dpn_medical_v6_handoffs (handoff_id,patient_cid,destination,author_cid,status,handoff_data) VALUES (?,?,?,?,?,?)',{item.id,item.patientCid,item.destination,item.author,item.status,encode(item)})
    TriggerEvent('dpn-medical:v6:handoffCreated',target,item.patientCid,item)
    return item.id,item
end

local function evaluatePatient(target)
    local state=stateFor(target); if not state then return end
    local now=os.time(); local cooldown=30
    local function alert(key,severity,message,data)
        local stamp=tostring(target)..':'..key
        if now-(lastAlertAt[stamp] or 0)>=cooldown then lastAlertAt[stamp]=now; raiseAlert(target,key,severity,message,data,'dpn-medical-core') end
    end
    if state.advanced.map < 60 then alert('critical_hypotension','critical','Mean arterial pressure is below 60 mmHg.',{map=state.advanced.map}) end
    if state.vitals.spo2 < 88 then alert('critical_hypoxemia','critical','Oxygen saturation is below 88%.',{spo2=state.vitals.spo2}) end
    if state.labs.potassium < 2.8 or state.labs.potassium > 6.0 then alert('critical_potassium','critical','Potassium is in a life-threatening range.',{potassium=state.labs.potassium}) end
    if state.labs.glucose < 50 or state.labs.glucose > 400 then alert('critical_glucose','critical','Glucose is in a critical range.',{glucose=state.labs.glucose}) end
    if state.labs.ph < 7.20 or state.labs.ph > 7.60 then alert('critical_ph','critical','Blood pH is in a critical range.',{ph=state.labs.ph}) end
    if state.v6.sofa >= 10 then alert('multiple_organ_dysfunction','critical','High organ dysfunction score requires ICU review.',{sofa=state.v6.sofa}) end
    if state.v6.massiveTransfusion then alert('massive_hemorrhage','critical','Massive transfusion protocol criteria are met.',{blood=state.vitals.blood,shockIndex=state.advanced.shockIndex}) end
    if state.v6.sepsisBundleDue then alert('sepsis_bundle_due','high','Sepsis bundle is due.',{qsofa=state.advanced.qsofa,sofa=state.v6.sofa}) end
end

exports('GetDigitalTwin',function(target) local state=stateFor(target); return state and DPN_MED.BuildDigitalTwin(state) or nil end)
exports('CreateClinicalOrder',createOrder)
exports('UpdateClinicalOrder',updateOrder)
exports('GetClinicalOrders',function(target,includeClosed) local out={}; for _,order in pairs(orders[targetId(target)] or {}) do if includeClosed or (order.status~='completed' and order.status~='cancelled') then out[#out+1]=order end end; table.sort(out,function(a,b) if a.priority==b.priority then return a.createdAt<b.createdAt end return a.priority<b.priority end); return out end)
exports('CreateRecommendedOrderSet',function(target,author) local state=stateFor(target); if not state then return false end; local ids={}; for _,item in ipairs(DPN_MED.GetRecommendedOrders(state)) do local id=createOrder(target,item.type,item.code,{priority=item.priority,reason=item.reason,module='clinical_decision_support'},author); ids[#ids+1]=id end; return ids end)
exports('RecordObservation',recordObservation)
exports('GetObservationTrend',function(target,observationType,limit) local list=(observations[targetId(target)] or {}); local out={}; for i=#list,1,-1 do if not observationType or list[i].type==observationType then out[#out+1]=list[i]; if #out>=(tonumber(limit) or 25) then break end end end; return out end)
exports('RaiseSafetyAlert',raiseAlert)
exports('AcknowledgeSafetyAlert',acknowledgeAlert)
exports('GetActiveSafetyAlerts',function(target) local out={}; for _,item in pairs(alerts[targetId(target)] or {}) do if item.status=='active' then out[#out+1]=item end end; table.sort(out,function(a,b)return a.createdAt>b.createdAt end); return out end)
exports('CreateStructuredHandoff',createHandoff)
exports('GetHandoffs',function(target) local out={}; for _,item in pairs(handoffs[targetId(target)] or {}) do out[#out+1]=item end; table.sort(out,function(a,b)return a.createdAt>b.createdAt end); return out end)
exports('SetLabResult',function(target,test,value,unit,author) return recordObservation(target,tostring(test),value,unit or '',{category='laboratory'},author) end)
exports('AddFluidBalance',function(target,intake,output,bloodProducts,author)
    local state=stateFor(target); if not state then return false end
    state.fluids.intakeMl=state.fluids.intakeMl+(tonumber(intake) or 0); state.fluids.outputMl=state.fluids.outputMl+(tonumber(output) or 0); state.fluids.bloodProductsMl=state.fluids.bloodProductsMl+(tonumber(bloodProducts) or 0); state.fluids.lastUpdated=os.time(); DPN_MED.CalculateV6Metrics(state); commit(target,state,'fluid_balance_updated',{intake=intake,output=output,bloodProducts=bloodProducts,actor=actorCid(author)}); return state.v6.fluidBalance
end)
exports('SetOrganSupport',function(target,support,enabled,data,author)
    local state=stateFor(target); if not state or state.organSupport[support]==nil then return false end
    state.organSupport[support]=enabled==true; state.devices['support:'..tostring(support)]={active=enabled==true,data=data or {},updatedAt=os.time(),actor=actorCid(author)}; DPN_MED.CalculateV6Metrics(state); return commit(target,state,'organ_support_changed',{support=support,enabled=enabled,data=data})
end)
exports('ValidateBloodProduct',function(target,donorType) local state=stateFor(target); if not state then return false,'Patient not found' end; local recipient=state.profile.bloodType or 'UNKNOWN'; local ok=DPN_MED.IsBloodCompatible(recipient,donorType); return ok,ok and 'compatible' or ('Incompatible blood product: recipient '..recipient..' donor '..tostring(donorType)) end)
exports('GetOperationalDashboard',function()
    local patients={}; for _,sid in ipairs(GetPlayers()) do local target=tonumber(sid); local state=stateFor(target); if state then patients[#patients+1]={id=target,citizenid=cid(target),twin=DPN_MED.BuildDigitalTwin(state),orders=#(exports['dpn-medical-core']:GetClinicalOrders(target,true)),alerts=#(exports['dpn-medical-core']:GetActiveSafetyAlerts(target))} end end
    return {version=VERSION,generatedAt=os.time(),patients=patients,quality=quality,moduleHealth=exports['dpn-medical-core']:GetSystemHealth()}
end)
exports('GetQualityMetrics',function() return quality end)

AddEventHandler(DPN_MED.Events.StateChanged,function(target) evaluatePatient(tonumber(target)) end)

CreateThread(function()
    Wait(2000)
    print('[dpn-medical-core] v6.0.0 clinical operations, digital twin, orders, observations, safety alerts and structured handoffs active')
    while true do Wait(10000); for _,sid in ipairs(GetPlayers()) do evaluatePatient(tonumber(sid)) end end
end)

local function allowed(src)
    if src==0 then return true end
    local p=player(src); return DPNMedicalServer.HasAdminPermission(src) or (p and DPNMedicalServer.IsMedicalJob(p,'doctor'))
end
QBCore.Commands.Add('meddigital','Show the v6 digital twin summary',{{name='id'}},true,function(src,args)
    if not allowed(src) then return end; local target=tonumber(args[1]); local twin=exports['dpn-medical-core']:GetDigitalTwin(target); if not twin then return end
    TriggerClientEvent('chat:addMessage',src,{args={'DPN Digital Twin',('SOFA %s | %s | Acid-base %s | Fluid %+d mL | Disposition %s'):format(twin.v6.sofa,twin.v6.organFailureRisk,twin.v6.acidBase,twin.v6.fluidBalance,twin.v6.disposition)}})
end)
QBCore.Commands.Add('medorder','Create a clinical order',{{name='id'},{name='type'},{name='code'}},true,function(src,args)
    if not allowed(src) then return end; local id,message=createOrder(tonumber(args[1]),args[2],args[3],{priority=2,module='command'},src); TriggerClientEvent('QBCore:Notify',src,id and ('Order created: '..id) or tostring(message),id and 'success' or 'error')
end)
QBCore.Commands.Add('medobs','Record an observation or lab',{{name='id'},{name='type'},{name='value'},{name='unit'}},true,function(src,args)
    if not allowed(src) then return end; local id,message=recordObservation(tonumber(args[1]),args[2],args[3],args[4],{},src); TriggerClientEvent('QBCore:Notify',src,id and ('Observation recorded: '..id) or tostring(message),id and 'success' or 'error')
end)
QBCore.Commands.Add('medhandoff','Generate an SBAR handoff',{{name='id'},{name='destination'}},true,function(src,args)
    if not allowed(src) then return end; local id,message=createHandoff(tonumber(args[1]),args[2],{},src); TriggerClientEvent('QBCore:Notify',src,id and ('Handoff generated: '..id) or tostring(message),id and 'success' or 'error')
end)
