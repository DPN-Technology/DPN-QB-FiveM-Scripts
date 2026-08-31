local v9Snapshot = nil

RegisterNetEvent('dpn-medical-core:client:v9Telemetry', function(snapshot)
    if type(snapshot) == 'table' then v9Snapshot = snapshot end
end)

exports('GetV9ClientSnapshot', function() return v9Snapshot end)

RegisterCommand('medv9status', function()
    local state = exports['dpn-medical-core']:GetLocalMedicalState()
    local v9 = state and state.v9 or nil
    if not v9 then
        TriggerEvent('chat:addMessage', { args = { 'DPN Medical v9', 'Adaptive metrics are not available yet.' } })
        return
    end
    TriggerEvent('chat:addMessage', { args = { 'DPN Medical v9', ('Risk %s%% | Recovery %s%% | %s | Disposition %s'):format(v9.adaptiveRisk or 0, v9.recoveryProbability or 0, v9.trajectory or 'unknown', v9.disposition or 'unknown') } })
end, false)
