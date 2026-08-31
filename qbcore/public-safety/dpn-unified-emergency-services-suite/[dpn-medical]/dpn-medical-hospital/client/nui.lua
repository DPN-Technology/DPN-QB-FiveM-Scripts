RegisterNUICallback('close', function(_, cb)
    if DPNHospitalUI and DPNHospitalUI.Close then
        DPNHospitalUI.Close()
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ action = 'forceClose' })
    end
    cb({ ok = true })
end)

RegisterNUICallback('discharge', function(_, cb)
    TriggerServerEvent('dpn-hospital:server:dischargeSelf')
    cb({ ok = true })
end)

RegisterNUICallback('payBill', function(data, cb)
    local admissionId = data and tonumber(data.id) or nil
    if admissionId then TriggerServerEvent('dpn-hospital:server:payBill', admissionId) end
    cb({ ok = admissionId ~= nil })
end)
