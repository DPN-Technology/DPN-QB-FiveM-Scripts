local QBCore = exports['qb-core']:GetCoreObject()
local statusRequestRate = {}

local function allowStatusRequest(src)
    if src <= 0 then return true end
    local nowMs = GetGameTimer()
    local cooldown = math.max(250, math.floor(tonumber(Config.StatusRequestCooldownMs) or 1000))
    local last = statusRequestRate[src] or 0
    if nowMs - last < cooldown then return false end
    statusRequestRate[src] = nowMs
    return true
end

local function isAdmin(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, Config.AdminAce) then return true end

    local ok, result = pcall(function()
        return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
    end)

    return ok and result == true
end

RegisterNetEvent('dpn-real-traffic:server:requestStatus', function()
    local src = source
    if not allowStatusRequest(src) then return end
    local tsState = GetResourceState(Config.TrafficLights.ResourceName)
    TriggerClientEvent('dpn-real-traffic:client:status', src, {
        debug = Config.Debug,
        trafficlights = Config.TrafficLights.Enabled,
        tsResource = Config.TrafficLights.ResourceName,
        tsState = tsState,
        density = Config.Density.Enabled,
        emergency = Config.Emergency.Enabled
    })
end)

RegisterCommand(Config.Commands.ToggleDebug, function(source)
    if not isAdmin(source) then
        TriggerClientEvent('QBCore:Notify', source, 'You do not have permission to use this command.', 'error')
        return
    end

    TriggerClientEvent('dpn-real-traffic:client:toggleDebug', source)
end, false)

RegisterCommand(Config.Commands.Status, function(source)
    if source == 0 then
        print(('[dpn-real-traffic] ts resource %s state: %s'):format(Config.TrafficLights.ResourceName, GetResourceState(Config.TrafficLights.ResourceName)))
        return
    end

    TriggerClientEvent('dpn-real-traffic:client:requestStatus', source)
end, false)

AddEventHandler('playerDropped', function()
    statusRequestRate[source] = nil
end)

CreateThread(function()
    print('^2[dpn-real-traffic]^7 Loaded. Advanced AI traffic active for QBCore.')
    print(('^2[dpn-real-traffic]^7 ts_Trafficlights state: %s'):format(GetResourceState(Config.TrafficLights.ResourceName)))
end)
