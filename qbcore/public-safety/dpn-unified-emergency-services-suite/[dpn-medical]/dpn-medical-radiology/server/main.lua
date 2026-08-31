local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    Wait(1000)
    exports['dpn-medical-core']:RegisterModule('dpn-medical-radiology','2.0.0',{'xray','ct','mri','ultrasound','diagnostics'})
end)

local function auth(src) local p=QBCore.Functions.GetPlayer(src); return p and p.PlayerData.job and Config.Jobs[p.PlayerData.job.name] and p.PlayerData.job.onduty~=false end
local function findings(state,study,part)
    local rows={}; local function scan(name,p)
        if (p.damage or 0)>0 then rows[#rows+1]=('%s trauma %s%%'):format(name,math.floor(p.damage)) end
        if p.fracture and p.fracture~='none' then rows[#rows+1]=('%s fracture: %s'):format(name,p.fracture) end
        if p.internalBleeding then rows[#rows+1]=('%s internal bleeding'):format(name) end
        for organ,value in pairs(p.organs or {}) do if value>0 then rows[#rows+1]=('%s damage %s%%'):format(organ,math.floor(value)) end end
    end
    if part and state.body[part] then scan(part,state.body[part]) else for name,p in pairs(state.body) do scan(name,p) end end
    if #rows==0 then return 'No acute abnormality detected.' end
    return table.concat(rows,'; ')
end
local function order(src,target,study,part)
    target=tonumber(target); study=tostring(study or 'xray')
    if not auth(src) or not target or not Config.Costs[study] then return false,'Order denied' end
    local state=exports['dpn-medical-core']:GetPatientState(target); if not state then return false,'Patient not found' end
    local result=findings(state,study,part); local provider=QBCore.Functions.GetPlayer(src).PlayerData.citizenid; local patient=QBCore.Functions.GetPlayer(target)
    local id=MySQL.insert.await('INSERT INTO dpn_medical_radiology_orders (patient_cid,ordered_by,study_type,body_part,status,findings) VALUES (?,?,?,?,?,?)',{patient.PlayerData.citizenid,provider,study,part,'final',result})
    exports['dpn-medical-core']:SetDiagnostic(target,('radiology_%s'):format(id),{type=study,findings=result,result='final',orderedBy=provider})
    if GetResourceState('dpn-medical-records')=='started' then pcall(function() exports['dpn-medical-records']:AddEntry(target,'radiology',{study=study,part=part,findings=result}) end) end
    if GetResourceState('dpn-medical-billing-plus')=='started' then pcall(function() exports['dpn-medical-billing-plus']:CreateInvoice(target,Config.Costs[study],study..' imaging','radiology') end) end
    return true,result
end
exports('OrderStudy',order)
QBCore.Commands.Add('radiology','Order xray/ct/mri/ultrasound',{{name='id'},{name='study'},{name='part'}},true,function(src,args)
    local ok,msg=order(src,args[1],args[2],args[3]); TriggerClientEvent('chat:addMessage',src,{args={'DPN Radiology',msg}})
end)
