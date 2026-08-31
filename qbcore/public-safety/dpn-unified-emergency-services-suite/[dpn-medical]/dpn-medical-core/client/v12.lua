local latestV12

RegisterNetEvent('dpn-medical-core:client:v12Snapshot', function(snapshot)
    latestV12 = type(snapshot) == 'table' and snapshot or nil
end)

RegisterNetEvent('dpn-medical-core:client:v12Summary', function(message)
    TriggerEvent('chat:addMessage', { args = { 'DPN Medical v12', tostring(message or 'No data.') } })
end)

exports('GetLocalV12Snapshot', function() return latestV12 end)

RegisterCommand('medicalv12', function()
    TriggerServerEvent('dpn-medical-core:server:requestV12Snapshot')
end, false)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    TriggerEvent('chat:addSuggestion', '/medicalv12', 'Show the local DPN Medical v12 integrated critical-care summary')
end)
