DPNMedicalDispatchCompatBridge = DPNMedicalDispatchCompatBridge or {}

local Bridge = DPNMedicalDispatchCompatBridge
local stats = {
    routed = 0,
    fallbackBroadcasts = 0,
    lastResource = nil,
    lastFallbackResource = nil,
    lastEvent = nil,
}

local function configuredResources()
    local external = Config and Config.ExternalDispatch or nil
    local resources = external and external.resources or nil
    if type(resources) == 'table' and #resources > 0 then
        return resources
    end
    return { 'dpn-dispatch-system', 'dpn-dispatch' }
end

local function eventName(resource, event)
    return ('%s:server:%s'):format(resource, tostring(event))
end

local function fallbackResource(resources)
    for _, resource in ipairs(resources or {}) do
        if type(resource) == 'string' and resource ~= '' then
            return resource
        end
    end
    return 'dpn-dispatch-system'
end

function Bridge.Route(event, payload)
    local resources = configuredResources()

    for _, resource in ipairs(resources) do
        if GetResourceState(resource) == 'started' then
            TriggerEvent(eventName(resource, event), payload)
            stats.routed = stats.routed + 1
            stats.lastResource = resource
            stats.lastFallbackResource = nil
            stats.lastEvent = event
            return true, resource
        end
    end

    -- Preserve legacy event-only compatibility with one deterministic owner.
    -- Configuration order is the fallback priority, matching active routing order
    -- and preventing one logical compatibility event from fan-out to two namespaces.
    local fallback = fallbackResource(resources)
    TriggerEvent(eventName(fallback, event), payload)
    stats.fallbackBroadcasts = stats.fallbackBroadcasts + 1
    stats.lastResource = nil
    stats.lastFallbackResource = fallback
    stats.lastEvent = event
    return false, 'legacy-fallback'
end

function Bridge.GetStats()
    return {
        routed = stats.routed,
        fallbackBroadcasts = stats.fallbackBroadcasts,
        lastResource = stats.lastResource,
        lastFallbackResource = stats.lastFallbackResource,
        lastEvent = stats.lastEvent,
    }
end

exports('RouteMedicalDispatchCompatEvent', Bridge.Route)
exports('GetMedicalDispatchCompatBridgeStats', Bridge.GetStats)
