local VERSION = '4.0.0'
local RESOURCE = GetCurrentResourceName()
local QBCore = exports['qb-core']:GetCoreObject()
local function encode(value) local ok,result=pcall(json.encode,value or {}); return ok and result or '{}' end
local function targetPlayer(target) return QBCore.Functions.GetPlayer(tonumber(target)) end
local function citizen(target) local p=targetPlayer(target); return p and p.PlayerData and p.PlayerData.citizenid or nil end
local function actor(sourceValue) if type(sourceValue)=='string' then return sourceValue:sub(1,64) end; local p=targetPlayer(sourceValue); return p and p.PlayerData and p.PlayerData.citizenid or ('source:%s'):format(tostring(sourceValue or 'system')) end
local function uid(prefix,target) return ('%s-%s-%s-%04d'):format(prefix,os.date('%Y%m%d%H%M%S'),tostring(target or 0),math.random(0,9999)) end
local function asyncInsert(query,params) CreateThread(function() pcall(function() MySQL.insert.await(query,params) end) end) end
local function asyncUpdate(query,params) CreateThread(function() pcall(function() MySQL.update.await(query,params) end) end) end
local function core(method,...)
    local args=table.pack(...)
    local ok,a,b,c=pcall(function() local proxy=exports['dpn-medical-core']; local fn=proxy and proxy[method]; if type(fn)~='function' then error('missing core export '..tostring(method)) end; return fn(proxy,table.unpack(args,1,args.n)) end)
    if not ok then return false,nil,tostring(a) end
    return true,a,b,c
end
local function heartbeat(capabilities)
    CreateThread(function()
        Wait(2500)
        pcall(function() exports['dpn-medical-core']:RegisterModule(RESOURCE,VERSION,capabilities) end)
        while true do Wait(60000); TriggerEvent('dpn-medical-core:server:moduleHeartbeat',RESOURCE,VERSION,{online=true,time=os.time()}) end
    end)
end

local staffing, edBoard, transfers = {}, {}, {}
local surgeMode = {active=false,level=0,reason=nil,updatedAt=0}

local function hospitalCapacity()
    local ok,data=pcall(function() return exports['dpn-medical-hospital']:GetCapacitySnapshot() end)
    return ok and type(data)=='table' and data or {}
end
exports('SetDepartmentStaffing',function(department,onDuty,minimum,sourceValue)
    department=tostring(department or 'er'):lower(); staffing[department]={onDuty=tonumber(onDuty) or 0,minimum=tonumber(minimum) or 1,updatedBy=actor(sourceValue),updatedAt=os.time()};
    asyncInsert('INSERT INTO dpn_medical_v6_hospital_staffing (department,on_duty,minimum_required,updated_by) VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE on_duty=VALUES(on_duty),minimum_required=VALUES(minimum_required),updated_by=VALUES(updated_by),updated_at=NOW()',{department,staffing[department].onDuty,staffing[department].minimum,staffing[department].updatedBy}); return true
end)
exports('SetSurgeMode',function(active,level,reason,sourceValue) surgeMode={active=active==true,level=tonumber(level) or 0,reason=reason,updatedBy=actor(sourceValue),updatedAt=os.time()};TriggerEvent('dpn-medical:v6:hospitalSurgeChanged',surgeMode);return surgeMode end)
exports('QueueEDPatient',function(target,arrivalMode,chiefComplaint,sourceValue)
    local ok,twin=core('GetDigitalTwin',target); if not ok or not twin then return false,'Patient unavailable' end
    local id=uid('ED',target); local item={id=id,target=tonumber(target),patientCid=citizen(target),arrivalMode=arrivalMode or 'walk_in',chiefComplaint=chiefComplaint or 'Medical complaint',acuity=twin.triage or 'green',risk=twin.v6 and twin.v6.organFailureRisk or 'low',status='waiting',queuedAt=os.time(),queuedBy=actor(sourceValue),recommended=twin.v6 and twin.v6.disposition or 'routine'};edBoard[id]=item
    asyncInsert('INSERT INTO dpn_medical_v6_ed_board (board_id,patient_cid,status,acuity,arrival_mode,chief_complaint,board_data) VALUES (?,?,?,?,?,?,?)',{id,item.patientCid,item.status,item.acuity,item.arrivalMode,item.chiefComplaint,encode(item)}); return id,item
end)
exports('UpdateEDPatient',function(boardId,status,location,provider)
    local item=edBoard[tostring(boardId)];if not item then return false,'Board entry not found'end;item.status=tostring(status or item.status);item.location=location;item.provider=actor(provider);item.updatedAt=os.time();asyncUpdate('UPDATE dpn_medical_v6_ed_board SET status=?,location=?,provider_cid=?,board_data=?,updated_at=NOW() WHERE board_id=?',{item.status,location,item.provider,encode(item),item.id});return true,item
end)
exports('RequestInterfacilityTransfer',function(target,destination,service,reason,sourceValue)
    local id=uid('TXF',target);local item={id=id,target=tonumber(target),patientCid=citizen(target),destination=destination,service=service or 'medicine',reason=reason,status='requested',requestedBy=actor(sourceValue),requestedAt=os.time()};transfers[id]=item;asyncInsert('INSERT INTO dpn_medical_v6_transfers (transfer_id,patient_cid,destination,service,status,requested_by,transfer_data) VALUES (?,?,?,?,?,?,?)',{id,item.patientCid,destination,item.service,item.status,item.requestedBy,encode(item)});return id,item
end)
exports('UpdateTransfer',function(id,status,acceptingProvider,bed) local item=transfers[tostring(id)];if not item then return false end;item.status=status;item.acceptingProvider=acceptingProvider;item.bed=bed;item.updatedAt=os.time();asyncUpdate('UPDATE dpn_medical_v6_transfers SET status=?,accepting_provider=?,bed_assignment=?,transfer_data=?,updated_at=NOW() WHERE transfer_id=?',{status,acceptingProvider,bed,encode(item),item.id});return true,item end)
exports('GetHospitalCommandCenter',function()
    local waiting,critical=0,0;for _,item in pairs(edBoard)do if item.status~='discharged' then waiting=waiting+1;if item.risk=='critical'or item.acuity=='red'then critical=critical+1 end end end
    local staffRisk={};for dept,data in pairs(staffing)do staffRisk[dept]={short=(data.onDuty or 0)<(data.minimum or 1),onDuty=data.onDuty,minimum=data.minimum}end
    return {generatedAt=os.time(),capacity=hospitalCapacity(),staffing=staffing,staffRisk=staffRisk,edBoard=edBoard,waiting=waiting,critical=critical,surge=surgeMode,transfers=transfers}
end)
exports('GetEDBoard',function()return edBoard end)
exports('GetTransfers',function()return transfers end)
heartbeat({'ed_tracking_board','staffing_command','surge_capacity','transfer_center','boarding_risk','hospital_command_center'})
QBCore.Commands.Add('hospitalcommand','Show hospital command-center status',{},false,function(src)local data=exports['dpn-medical-hospital']:GetHospitalCommandCenter();TriggerClientEvent('chat:addMessage',src,{args={'Hospital Command',('Waiting %s | Critical %s | Surge %s L%s'):format(data.waiting,data.critical,tostring(data.surge.active),data.surge.level)}})end)
