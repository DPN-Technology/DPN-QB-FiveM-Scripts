local latestV11

RegisterNetEvent('dpn-medical-core:client:v11Snapshot', function(snapshot)
    latestV11 = type(snapshot) == 'table' and snapshot or nil
end)

RegisterNetEvent('dpn-medical-core:client:v11Summary', function(message)
    TriggerEvent('chat:addMessage', { args = { 'DPN Medical v11', tostring(message or 'No data.') } })
end)

exports('GetLocalV11Snapshot', function()
    return latestV11
end)

RegisterCommand('medicalv11', function()
    TriggerServerEvent('dpn-medical-core:server:requestV11Snapshot')
end, false)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    TriggerEvent('chat:addSuggestion', '/medicalv11', 'Show the local DPN Medical v11 autonomous-care summary')
end)
