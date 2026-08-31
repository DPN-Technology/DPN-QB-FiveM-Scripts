local precision = nil

RegisterNetEvent('dpn-medical-core:client:precisionSnapshot', function(data)
    precision = type(data) == 'table' and data or nil
end)

RegisterCommand('medprecisionhud', function()
    if not precision then
        TriggerServerEvent('dpn-medical-core:server:requestState')
        return
    end
    local risk = precision.v8 and precision.v8.precisionRisk or 0
    TriggerEvent('chat:addMessage', { args = { 'DPN Precision', ('Current precision risk: %s%%'):format(risk) } })
end, false)

CreateThread(function()
    Wait(3000)
    print('[dpn-medical-core] client v8 precision telemetry ready')
end)
