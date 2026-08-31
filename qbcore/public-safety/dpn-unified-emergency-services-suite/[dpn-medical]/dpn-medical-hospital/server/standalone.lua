local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    print('[dpn-medical-hospital] v2.0.2 brown-screen repair active')
    Wait(1000)
    exports['dpn-medical-core']:RegisterModule('dpn-medical-hospital','3.0.0',{'admissions','beds','recovery','emergency_respawn'})
end)

local function emergencyRespawn(src, reason)
    src = tonumber(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end
    local ok, admission = AdmitPatient(src, 'pillbox', 'system', 'er', 8, reason or 'Emergency hospital respawn')
    if not ok then return false end
    local hospital = Config.Hospitals[admission.hospital] or Config.Hospitals.pillbox
    local bed = admission.bed_id and DPNHospitalBeds[admission.bed_id] or nil
    local coords = bed and bed.coords or hospital.discharge
    exports['dpn-medical-core']:ResetPatient(src, 'hospital respawn')
    exports['dpn-medical-core']:SetFlag(src, 'admitted', true)
    exports['dpn-medical-core']:RevivePatient(src, { fullHeal = true, by = 'hospital', coords = {x=coords.x,y=coords.y,z=coords.z,w=coords.w} })
    TriggerClientEvent('dpn-hospital:client:forceBed', src, coords)
    return true
end

exports('EmergencyRespawn', emergencyRespawn)

AddEventHandler('dpn-medical:server:lifeStateChanged', function(src, citizenid, fromState, toState)
    if toState == 'dead' then
        -- The admission is created only when the player elects to respawn, not at the instant of death.
        return
    end
    if toState == 'alive' then
        local admission = DPNAdmissions[citizenid]
        if admission then exports['dpn-medical-core']:SetFlag(src, 'admitted', true) end
    end
end)
