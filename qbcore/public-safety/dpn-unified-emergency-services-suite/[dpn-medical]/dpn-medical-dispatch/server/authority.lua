--[[
    DPN Technology — Phase 3F Medical Dispatch Authority

    Establishes one explicit canonical authority surface for medical-dispatch
    call creation, call mutation, responder state lookup, and authority metadata.
    This layer delegates to the existing hardened server/main.lua exports and
    intentionally does not own a second call cache, responder cache, or database
    writer. Historical vN layers remain loaded until parity is proven.
]]

DPNMedicalDispatchAuthority = DPNMedicalDispatchAuthority or {}

local Authority = DPNMedicalDispatchAuthority
local RESOURCE = GetCurrentResourceName()
local VERSION = GetResourceMetadata(RESOURCE, 'version', 0) or 'unknown'

local function dispatchExport(name, ...)
    local args = table.pack(...)
    local ok, a, b = pcall(function()
        local proxy = exports[RESOURCE]
        local fn = proxy and proxy[name]
        if type(fn) ~= 'function' then error(('missing canonical dispatch export %s'):format(name)) end
        return fn(proxy, table.unpack(args, 1, args.n))
    end)
    if not ok then return false, tostring(a) end
    return true, a, b
end

function Authority.GetInfo()
    return {
        resource = RESOURCE,
        version = VERSION,
        phase = '3F',
        callOwner = 'server/main.lua',
        responderOwner = 'server/main.lua',
        persistenceOwner = 'server/main.lua',
        authorityLayer = 'server/authority.lua'
    }
end

function Authority.CreateCall(data)
    local ok, call, extra = dispatchExport('CreateMedicalCall', data)
    if not ok then return false, call end
    return call ~= false and call ~= nil, call, extra
end

function Authority.UpdateCall(callId, status, note)
    local ok, updated, call = dispatchExport('UpdateMedicalCall', callId, status, note)
    if not ok then return false, updated end
    return updated == true, call
end

function Authority.GetCalls()
    local ok, calls = dispatchExport('GetActiveMedicalCalls')
    if not ok or type(calls) ~= 'table' then return {} end
    return calls
end

function Authority.GetResponder(sourceId)
    local ok, responder = dispatchExport('GetResponderStatus', tonumber(sourceId))
    if not ok then return nil end
    return responder
end

function Authority.GetBridgeHealth()
    local ok, health = dispatchExport('GetDispatchBridgeHealth')
    if not ok or type(health) ~= 'table' then return {} end
    return health
end

exports('GetMedicalDispatchAuthorityInfo', function()
    return Authority.GetInfo()
end)

exports('CreateCanonicalMedicalCall', function(data)
    return Authority.CreateCall(type(data) == 'table' and data or {})
end)

exports('UpdateCanonicalMedicalCall', function(callId, status, note)
    return Authority.UpdateCall(callId, status, note)
end)

exports('GetCanonicalMedicalCalls', function()
    return Authority.GetCalls()
end)

exports('GetCanonicalResponderStatus', function(sourceId)
    return Authority.GetResponder(sourceId)
end)

exports('GetCanonicalMedicalDispatchHealth', function()
    return Authority.GetBridgeHealth()
end)

print(('[dpn-medical-dispatch] Phase 3F canonical dispatch authority active (v%s)'):format(VERSION))
