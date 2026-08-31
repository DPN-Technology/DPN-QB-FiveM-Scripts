local latest
RegisterNetEvent('dpn-medical-core:client:v10Snapshot', function(snapshot) latest = snapshot end)
exports('GetV10ClientSnapshot', function() return latest end)
RegisterCommand('medv10local', function()
    TriggerServerEvent('dpn-medical-core:server:requestV10Snapshot')
end, false)
RegisterNetEvent('dpn-medical-core:client:v10Summary', function(message)
    TriggerEvent('chat:addMessage', { args = { 'DPN Medical v10', tostring(message) } })
end)
