RegisterNetEvent('dpn-medical-lifepak:client:snapshot',function(target,state)
    local v=state.vitals; TriggerEvent('chat:addMessage',{color={0,220,180},args={'LIFEPAK',('Patient %s | HR %s | BP %s/%s | RR %s | SpO2 %s%% | Rhythm %s'):format(target,v.hr,v.systolic,v.diastolic,v.rr,v.spo2,state.status.cardiacArrest and 'ARREST' or 'SINUS')}})
end)
