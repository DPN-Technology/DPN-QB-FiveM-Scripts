local QBCore = exports[Config.CoreName]:GetCoreObject()

local function BuildUiConfig()
    return {
        title = Config.UI.title,
        unitLabel = Config.UI.unitLabel,
        showPlate = Config.UI.showPlate,
        showOfficer = Config.UI.showOfficer,
        showDistance = Config.UI.showDistance,
        cooldown = Config.Fire.cooldownSeconds,
        lifetime = Config.Tracker.lifetimeSeconds,
        controls = Config.Controls or {},
        lockOn = Config.LockOn or {},
        commands = Config.Commands or {}
    }
end

RegisterNetEvent('dpn-starchase:client:openRemote', function(trackers)
    UiOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'open',
        trackers = trackers or {},
        config = BuildUiConfig()
    })
end)

local function CloseRemote()
    UiOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    CloseRemote()
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    QBCore.Functions.TriggerCallback('dpn-starchase:server:getTrackers', function(resp)
        if resp and resp.ok then
            TriggerEvent('dpn-starchase:client:syncTrackers', resp.trackers or {})
        end
        cb(resp or { ok = false, message = 'No response.' })
    end)
end)

RegisterNUICallback('fireTracker', function(_, cb)
    DPNStarChase_AttemptLaunch(function(ok, message, tracker)
        cb({ ok = ok, message = message, tracker = tracker })
    end)
end)

RegisterNUICallback('removeTracker', function(data, cb)
    local id = data and data.id
    if not id then cb({ ok = false, message = 'Missing tracker ID.' }) return end
    QBCore.Functions.TriggerCallback('dpn-starchase:server:removeTracker', function(resp)
        if resp and resp.ok then
            -- Local cleanup is intentionally immediate, so the officer never keeps a stale blip
            -- if the server broadcast arrives late or is swallowed by another resource issue.
            TriggerEvent('dpn-starchase:client:trackerRemoved', id, data.reason or 'remote_removed')
            if resp.trackers then
                TriggerEvent('dpn-starchase:client:syncTrackers', resp.trackers)
            end
        end
        cb(resp or { ok = false, message = 'No response.' })
    end, id, data.reason or 'remote_removed')
end)

RegisterNUICallback('routeTracker', function(data, cb)
    local id = data and data.id
    if not id or not LocalTrackers or not LocalTrackers[id] then
        cb({ ok = false, message = 'Tracker not found.' })
        return
    end

    if RouteTrackerId and LocalTrackers[RouteTrackerId] and LocalTrackers[RouteTrackerId].blip then
        SetBlipRoute(LocalTrackers[RouteTrackerId].blip, false)
    end

    if RouteTrackerId == id then
        RouteTrackerId = nil
        cb({ ok = true, message = 'GPS route disabled.' })
        return
    end

    RouteTrackerId = id
    local tracker = LocalTrackers[id]
    if tracker.blip and DoesBlipExist(tracker.blip) then
        SetBlipRoute(tracker.blip, true)
        SetBlipRouteColour(tracker.blip, Config.Blip.routeColor)
    end
    cb({ ok = true, message = 'GPS route enabled.' })
end)

RegisterNUICallback('pingTracker', function(data, cb)
    local id = data and data.id
    local tracker = id and LocalTrackers and LocalTrackers[id]
    if not tracker or not tracker.coords then
        cb({ ok = false, message = 'Tracker not found.' })
        return
    end
    local pos = vector3(tracker.coords.x, tracker.coords.y, tracker.coords.z)
    SetNewWaypoint(pos.x, pos.y)
    cb({ ok = true, message = 'Waypoint set to last GPS ping.' })
end)

RegisterNUICallback('panicClose', function(_, cb)
    CloseRemote()
    cb({ ok = true })
end)

RegisterCommand(Config.Commands.remote, function()
    TriggerServerEvent('dpn-starchase:server:requestOpenRemote')
end, false)

if Config.Controls and Config.Controls.openRemote and Config.Controls.openRemote.enabled then
    RegisterKeyMapping(Config.Controls.openRemote.command or Config.Commands.remote or 'starchase', Config.Controls.openRemote.description or 'Open DPN StarChase Remote', 'keyboard', Config.Controls.openRemote.defaultKey or 'F10')
elseif Config.Keybind and Config.Keybind.enabled then
    RegisterKeyMapping(Config.Keybind.command, Config.Keybind.description, 'keyboard', Config.Keybind.defaultKey)
end
