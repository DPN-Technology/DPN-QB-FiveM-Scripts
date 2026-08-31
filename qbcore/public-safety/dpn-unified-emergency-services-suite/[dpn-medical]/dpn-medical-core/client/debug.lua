RegisterCommand('medsummary', function()
    if not LocalMedicalState then
        TriggerEvent('chat:addMessage', { args = { 'DPN Medical', 'Medical state has not loaded yet.' } })
        return
    end
    local v, s = LocalMedicalState.vitals, LocalMedicalState.status
    TriggerEvent('chat:addMessage', {
        color = { 80, 170, 255 },
        args = { 'DPN Medical', ('Blood %s ml | BP %s/%s | HR %s | RR %s | SpO2 %s%% | Pain %s | Shock %s | Triage %s'):format(v.blood, v.systolic, v.diastolic, v.hr, v.rr, v.spo2, s.pain, s.shock, s.triage) }
    })
end, false)
