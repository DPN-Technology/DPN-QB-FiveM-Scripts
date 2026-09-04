DPNMedicalDispatchCompatBridge = DPNMedicalDispatchCompatBridge or {}

local Bridge = DPNMedicalDispatchCompatBridge
local stats = {
    routed = 0,
    fallbackBroadcasts = 0,
    lastResource = nil,
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

function Bridge.Route(event, payload)
    local resources = configuredResources()

    for _, resource in ipairs(resources) do
        if GetResourceState(resource) == 'started' then
            TriggerEvent(eventName(resource, event), payload)
            stats.routed = stats.routed + 1
            stats.lastResource = resource
            stats.lastEvent = event
            return true, resource
        end
    end

    -- Preserve legacy event-only compatibility when neither configured dispatch
    -- resource is started. This retains historical listeners without broadcasting
    -- into two active dispatch resources at the same time.
    for _, resource in ipairs(resources) do
        TriggerEvent(eventName(resource, event), payload)
    end
    stats.fallbackBroadcasts = stats.fallbackBroadcasts + 1
    stats.lastResource = nil
    stats.lastEvent = event
    return false, 'legacy-fallback'
end

function Bridge.GetStats()
    return {
        routed = stats.routed,
        fallbackBroadcasts = stats.fallbackBroadcasts,
        lastResource = stats.lastResource,
        lastEvent = stats.lastEvent,
    }
end

exports('RouteMedicalDispatchCompatEvent', Bridge.Route)
exports('GetMedicalDispatchCompatBridgeStats', Bridge.GetStats)
