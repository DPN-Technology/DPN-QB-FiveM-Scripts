local QBCore = exports['qb-core']:GetCoreObject()
local lastState = nil

RegisterNetEvent('dpn-emergency-network:client:stateChanged', function(state)
    lastState = state
    TriggerEvent('dpn-le-operations:client:networkChanged', state)
end)

RegisterNetEvent('dpn-emergency-network:client:criticalSignal', function(signal)
    if type(signal) ~= 'table' then return end
    local message = signal.title or signal.eventType or 'DPN emergency-network alert'
    QBCore.Functions.Notify(message, Number(signal.severity or 3) <= 1 and 'error' or 'primary', 6500)
end)

RegisterCommand('dpnnetworkstatus', function()
    TriggerServerEvent('dpn-emergency-network:server:requestState')
end, false)

RegisterNetEvent('dpn-emergency-network:client:state', function(state)
    lastState = state
    local summary = state and state.summary or {}
    QBCore.Functions.Notify(('DPN Network: %s online, %s degraded, %s offline'):format(summary.online or 0, summary.degraded or 0, summary.offline or 0), (summary.criticalOffline or 0) > 0 and 'error' or 'success', 6500)
end)

exports('PublishEvent', function(eventType, payload)
    TriggerServerEvent('dpn-emergency-network:server:publish', eventType, payload or {})
end)

exports('GetCachedState', function()
    return lastState
end)
