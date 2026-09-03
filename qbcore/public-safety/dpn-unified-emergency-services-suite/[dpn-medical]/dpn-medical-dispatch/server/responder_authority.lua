-- DPN Technology — Phase 3F responder lifecycle authority
DPNMedicalResponderAuthority = DPNMedicalResponderAuthority or {}

local Authority = DPNMedicalResponderAuthority

local TRANSITIONS = {
    available = { accepted = true, unavailable = true },
    accepted = { enroute = true, unavailable = true, clear = true },
    enroute = { onscene = true, unavailable = true, clear = true },
    onscene = { transporting = true, clear = true, unavailable = true },
    transporting = { onscene = true, clear = true, unavailable = true },
    clear = { available = true, accepted = true, unavailable = true },
    unavailable = { available = true }
}

local function normalize(status)
    status = tostring(status or ''):lower():gsub('%s+', '')
    if status == 'en_route' or status == 'en-route' then return 'enroute' end
    if status == 'on_scene' or status == 'on-scene' then return 'onscene' end
    if status == 'cleared' then return 'clear' end
    return status
end

function Authority.GetAllowedTransitions(status)
    status = normalize(status)
    local allowed = TRANSITIONS[status] or {}
    local result = {}
    for nextStatus in pairs(allowed) do result[#result + 1] = nextStatus end
    table.sort(result)
    return result
end

function Authority.ValidateTransition(currentStatus, nextStatus)
    currentStatus = normalize(currentStatus)
    nextStatus = normalize(nextStatus)
    if currentStatus == '' then currentStatus = 'available' end
    if nextStatus == '' then return false, 'missing-next-status' end
    if currentStatus == nextStatus then return true, nextStatus, 'idempotent' end
    local allowed = TRANSITIONS[currentStatus]
    if not allowed then return false, nextStatus, 'unknown-current-status' end
    if allowed[nextStatus] ~= true then return false, nextStatus, 'invalid-transition' end
    return true, nextStatus, 'allowed'
end

function Authority.GetInfo()
    return {
        phase = '3F',
        owner = 'server/main.lua',
        guard = 'server/responder_authority.lua',
        serverAuthoritative = true,
        transitionStates = { 'available', 'accepted', 'enroute', 'onscene', 'transporting', 'clear', 'unavailable' }
    }
end

exports('ValidateCanonicalResponderTransition', function(currentStatus, nextStatus)
    return Authority.ValidateTransition(currentStatus, nextStatus)
end)

exports('GetCanonicalResponderTransitions', function(status)
    return Authority.GetAllowedTransitions(status)
end)

exports('GetMedicalResponderAuthorityInfo', function()
    return Authority.GetInfo()
end)
