--[[
    DPN Technology — Phase 3E Medical Core Authority

    Establishes one explicit server-side authority surface for canonical patient
    state while preserving every historical feature layer until parity is proven.
    This module delegates to the hardened Medical Core implementation from
    server/main.lua; it does not create a second state cache or persistence owner.
]]

if not DPNMedicalServer or not DPNMedicalServer.EnsureState or not DPNMedicalServer.Commit then
    error('[dpn-medical-core] Phase 3E authority loaded before Medical Core server/main.lua')
end

DPNMedicalAuthority = DPNMedicalAuthority or {}

local Authority = DPNMedicalAuthority
local Core = DPNMedicalServer
local RESOURCE = GetCurrentResourceName()
local VERSION = GetResourceMetadata(RESOURCE, 'version', 0) or 'unknown'

local function invokingResource()
    local caller = GetInvokingResource and GetInvokingResource() or nil
    return caller or RESOURCE
end

local function snapshot(state)
    if type(state) ~= 'table' then return nil end
    local ok, encoded = pcall(json.encode, state)
    if not ok then return nil end
    local decodeOk, copy = pcall(json.decode, encoded)
    if not decodeOk then return nil end
    return copy
end

function Authority.GetInfo()
    return {
        resource = RESOURCE,
        version = VERSION,
        stateOwner = 'server/main.lua',
        persistenceOwner = 'server/persistence.lua',
        authorityLayer = 'server/authority.lua',
        phase = '3E'
    }
end

function Authority.GetState(sourceId)
    local state = Core.EnsureState(tonumber(sourceId))
    return snapshot(state)
end

function Authority.CommitState(sourceId, state, eventType, data)
    sourceId = tonumber(sourceId)
    if not sourceId or type(state) ~= 'table' then return false, 'invalid-state-commit' end

    local _, citizenId = Core.EnsureState(sourceId)
    if not citizenId then return false, 'patient-not-found' end

    Core.Commit(sourceId, citizenId, state, eventType or 'authority_commit', type(data) == 'table' and data or {
        sourceResource = invokingResource()
    })
    return true, Authority.GetState(sourceId)
end

function Authority.SetLifeState(sourceId, lifeState, details)
    return Core.SetLifeState(tonumber(sourceId), lifeState, details or {}, invokingResource())
end

function Authority.ResetPatient(sourceId, reason, preserveHistory)
    return Core.ResetPatient(tonumber(sourceId), reason or invokingResource(), preserveHistory == true)
end

function Authority.RevivePatient(sourceId, options)
    options = type(options) == 'table' and options or {}
    options.by = options.by or invokingResource()
    return Core.RevivePatient(tonumber(sourceId), options)
end

exports('GetMedicalAuthorityInfo', function()
    return Authority.GetInfo()
end)

exports('GetCanonicalMedicalState', function(sourceId)
    return Authority.GetState(sourceId)
end)

exports('CommitCanonicalMedicalState', function(sourceId, state, eventType, data)
    return Authority.CommitState(sourceId, state, eventType, data)
end)

exports('SetCanonicalLifeState', function(sourceId, lifeState, details)
    return Authority.SetLifeState(sourceId, lifeState, details)
end)

exports('ResetCanonicalPatient', function(sourceId, reason, preserveHistory)
    return Authority.ResetPatient(sourceId, reason, preserveHistory)
end)

exports('ReviveCanonicalPatient', function(sourceId, options)
    return Authority.RevivePatient(sourceId, options)
end)

print(('[dpn-medical-core] Phase 3E canonical Medical Core authority active (v%s)'):format(VERSION))
