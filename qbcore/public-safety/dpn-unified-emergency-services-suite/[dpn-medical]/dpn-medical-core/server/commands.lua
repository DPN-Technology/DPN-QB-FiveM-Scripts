local QBCore = exports['qb-core']:GetCoreObject()
local function notify(src, msg, kind) TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary', 5000) end

QBCore.Commands.Add('medstate', 'View a patient medical summary', {{name='id',help='Player ID'}}, false, function(src,args)
    local target = tonumber(args[1]) or src; local state = exports['dpn-medical-core']:GetPatientState(target)
    if not state then return notify(src,'No patient state found.','error') end
    local v,s=state.vitals,state.status
    TriggerClientEvent('chat:addMessage',src,{color={80,170,255},args={'DPN Medical',('Patient %s | %s | Blood %s | BP %s/%s | HR %s | RR %s | SpO2 %s%% | Pain %s | Shock %s | Triage %s'):format(target,s.lifeState,v.blood,v.systolic,v.diastolic,v.hr,v.rr,v.spo2,s.pain,s.shock,s.triage)}})
end,'admin')

QBCore.Commands.Add('injure','Apply a controlled test injury',{{name='id'},{name='part'},{name='damage'},{name='type'}},true,function(src,args)
    local target,part,damage=tonumber(args[1]),tostring(args[2] or ''),math.max(1,math.min(100,tonumber(args[3]) or 10))
    if not target or not Config.BodyParts[part] then return notify(src,'Invalid player or body part.','error') end
    local ok=exports['dpn-medical-core']:ApplyInjury(target,part,{type=args[4] or 'admin_test',damage=damage,pain=damage,bleeding=damage>=50 and 'arterial' or (damage>=25 and 'venous' or 'capillary'),fracture=damage>=55 and 'closed' or nil,source='admin_command'})
    notify(src,ok and 'Test injury applied.' or 'Unable to apply injury.',ok and 'success' or 'error')
end,'admin')

QBCore.Commands.Add('healcore','Completely reset a DPN medical state',{{name='id'}},false,function(src,args)
    local target=tonumber(args[1]) or src; local ok=exports['dpn-medical-core']:ResetPatient(target,'admin command')
    if ok then exports['dpn-medical-core']:RevivePatient(target,{fullHeal=true,by='admin'}) end
    notify(src,ok and 'Medical state reset.' or 'Unable to reset patient.',ok and 'success' or 'error')
end,'admin')

QBCore.Commands.Add('revivecore','Revive without removing all injuries',{{name='id'}},false,function(src,args)
    local target=tonumber(args[1]) or src; local ok=exports['dpn-medical-core']:RevivePatient(target,{fullHeal=false,by='admin'})
    notify(src,ok and 'Patient revived.' or 'Unable to revive patient.',ok and 'success' or 'error')
end,'admin')

QBCore.Commands.Add('medmodules','List registered DPN medical modules',{},false,function(src)
    local modules=exports['dpn-medical-core']:GetModules(); local list={}
    for name,data in pairs(modules) do list[#list+1]=('%s v%s'):format(name,data.version) end
    table.sort(list); TriggerClientEvent('chat:addMessage',src,{args={'DPN Modules',#list>0 and table.concat(list,', ') or 'No modules registered'}})
end,'admin')
