exports('AdmitPatient', function(targetSrc, hospitalId, admittedBy, ward, minutes, reason)
    return AdmitPatient(targetSrc, hospitalId, admittedBy, ward, minutes, reason)
end)

exports('DischargePatient', function(citizenId, dischargedBy, force, reason)
    return DischargePatient(citizenId, dischargedBy, force == true, reason)
end)

exports('TransferPatient', function(citizenId, hospitalId, ward, changedBy)
    return TransferPatient(citizenId, hospitalId, ward, changedBy)
end)

exports('UpdateAdmissionState', function(citizenId, newState, changedBy)
    return UpdateAdmissionState(citizenId, newState, changedBy)
end)

exports('GetAdmissionByCitizenId', function(citizenId)
    return DPNAdmissions[citizenId]
end)

exports('GetBeds', function(publicOnly)
    return publicOnly and GetPublicBeds() or DPNHospitalBeds
end)

exports('GetAvailableBed', function(hospitalId, ward, allowFallback)
    return GetAvailableBed(hospitalId, ward, allowFallback)
end)

exports('ReleaseBed', function(bedId, reason)
    return ReleaseBed(bedId, reason)
end)
