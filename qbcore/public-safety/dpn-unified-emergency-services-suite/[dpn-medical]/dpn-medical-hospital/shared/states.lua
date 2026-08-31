HospitalStates = {
    WAITING = 'waiting',
    ADMITTED = 'admitted',
    TREATING = 'treating',
    SURGERY_REQUIRED = 'surgery_required',
    IN_SURGERY = 'in_surgery',
    RECOVERY = 'recovery',
    DISCHARGED = 'discharged'
}

HospitalStateLabels = {
    [HospitalStates.WAITING] = 'Waiting for Treatment',
    [HospitalStates.ADMITTED] = 'Admitted',
    [HospitalStates.TREATING] = 'Receiving Treatment',
    [HospitalStates.SURGERY_REQUIRED] = 'Surgery Required',
    [HospitalStates.IN_SURGERY] = 'In Surgery',
    [HospitalStates.RECOVERY] = 'Recovery',
    [HospitalStates.DISCHARGED] = 'Discharged'
}

WardTypes = {
    ER = 'er',
    ICU = 'icu',
    OPERATING_ROOM = 'or',
    RECOVERY = 'recovery'
}

-- "or" is a reserved Lua keyword, so it must use bracket notation.
WardLabels = {
    [WardTypes.ER] = 'Emergency Room',
    [WardTypes.ICU] = 'Intensive Care Unit',
    [WardTypes.OPERATING_ROOM] = 'Operating Room',
    [WardTypes.RECOVERY] = 'Recovery Ward'
}

HospitalStateTransitions = {
    [HospitalStates.WAITING] = {
        [HospitalStates.ADMITTED] = true,
        [HospitalStates.DISCHARGED] = true
    },
    [HospitalStates.ADMITTED] = {
        [HospitalStates.TREATING] = true,
        [HospitalStates.SURGERY_REQUIRED] = true,
        [HospitalStates.RECOVERY] = true,
        [HospitalStates.DISCHARGED] = true
    },
    [HospitalStates.TREATING] = {
        [HospitalStates.SURGERY_REQUIRED] = true,
        [HospitalStates.IN_SURGERY] = true,
        [HospitalStates.RECOVERY] = true,
        [HospitalStates.DISCHARGED] = true
    },
    [HospitalStates.SURGERY_REQUIRED] = {
        [HospitalStates.IN_SURGERY] = true,
        [HospitalStates.TREATING] = true,
        [HospitalStates.DISCHARGED] = true
    },
    [HospitalStates.IN_SURGERY] = {
        [HospitalStates.RECOVERY] = true,
        [HospitalStates.DISCHARGED] = true
    },
    [HospitalStates.RECOVERY] = {
        [HospitalStates.TREATING] = true,
        [HospitalStates.DISCHARGED] = true
    },
    [HospitalStates.DISCHARGED] = {}
}

function IsValidHospitalState(state)
    return type(state) == 'string' and HospitalStateLabels[state] ~= nil
end

function IsValidWard(ward)
    return type(ward) == 'string' and WardLabels[string.lower(ward)] ~= nil
end

function NormalizeWard(ward)
    if type(ward) ~= 'string' then return nil end
    ward = string.lower(ward)
    return IsValidWard(ward) and ward or nil
end

function CanTransitionHospitalState(fromState, toState)
    if fromState == toState then return true end
    return HospitalStateTransitions[fromState] and HospitalStateTransitions[fromState][toState] == true or false
end

function GetWardLabel(ward)
    local normalized = NormalizeWard(ward)
    return normalized and WardLabels[normalized] or 'Unknown Ward'
end

function GetHospitalStateLabel(state)
    return HospitalStateLabels[state] or 'Unknown Status'
end
