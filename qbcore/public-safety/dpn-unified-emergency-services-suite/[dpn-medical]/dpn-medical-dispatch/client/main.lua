local QBCore = exports['qb-core']:GetCoreObject()
local calls = {}
local blips = {}

local function notify(message, kind)
    QBCore.Functions.Notify(tostring(message), kind or 'primary', 6000)
end

local function removeCallBlip(id)
    local data = blips[tostring(id)]
    if not data then return end
    if data.main and DoesBlipExist(data.main) then RemoveBlip(data.main) end
    if data.radius and DoesBlipExist(data.radius) then RemoveBlip(data.radius) end
    blips[tostring(id)] = nil
end

local function createBlip(call)
    if type(call.coords) ~= 'table' or not tonumber(call.coords.x) then return end
    removeCallBlip(call.id)

    local main = AddBlipForCoord(call.coords.x + 0.0, call.coords.y + 0.0, call.coords.z + 0.0)
    SetBlipSprite(main, tonumber(Config.Blip.sprite) or 153)
    SetBlipColour(main, tonumber(Config.Blip.colour) or 1)
    SetBlipScale(main, tonumber(Config.Blip.scale) or 0.95)
    SetBlipAsShortRange(main, false)
    if Config.Blip.flash ~= false then SetBlipFlashes(main, true) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('EMS Call #%s - %s'):format(call.id, call.title or 'Medical Emergency'))
    EndTextCommandSetBlipName(main)

    local radius = AddBlipForRadius(
        call.coords.x + 0.0,
        call.coords.y + 0.0,
        call.coords.z + 0.0,
        tonumber(Config.Blip.radius) or 55.0
    )
    SetBlipColour(radius, tonumber(Config.Blip.colour) or 1)
    SetBlipAlpha(radius, 75)
    blips[tostring(call.id)] = { main = main, radius = radius }

    SetTimeout(tonumber(Config.Blip.durationMs) or 300000, function()
        removeCallBlip(call.id)
    end)
end

RegisterNetEvent('dpn-medical-dispatch:client:newCall', function(call)
    if type(call) ~= 'table' then return end
    calls[tostring(call.id)] = call
    createBlip(call)

    local message = ('Priority %s medical call #%s: %s | /emsrespond %s enroute'):format(
        tostring(call.priority or '?'),
        tostring(call.id),
        tostring(call.description or call.message or 'Medical emergency'),
        tostring(call.id)
    )
    TriggerEvent('chat:addMessage', { color = { 255, 90, 90 }, args = { 'DPN EMS Dispatch', message } })
    notify(message, tonumber(call.priority) == 1 and 'error' or 'primary')

    if Config.Audio and Config.Audio.enabled ~= false then
        PlaySoundFrontend(-1, Config.Audio.soundName or 'TIMER_STOP', Config.Audio.soundSet or 'HUD_MINI_GAME_SOUNDSET', true)
    end
end)

RegisterNetEvent('dpn-medical-dispatch:client:routeToCall', function(call)
    if type(call) ~= 'table' or type(call.coords) ~= 'table' then return end
    SetNewWaypoint(call.coords.x + 0.0, call.coords.y + 0.0)
    notify(('GPS route set to medical call #%s.'):format(tostring(call.id)), 'success')
end)

RegisterNetEvent('dpn-medical-dispatch:client:callUpdated', function(call)
    if type(call) ~= 'table' then return end
    calls[tostring(call.id)] = call
    if call.status == 'closed' or call.status == 'expired' then removeCallBlip(call.id) end
end)

RegisterCommand('emsrespond', function(_, args)
    local id = args and args[1]
    if not id then
        notify('Usage: /emsrespond <call id> <accepted|enroute|onscene|transporting|clear>', 'error')
        return
    end
    TriggerServerEvent('dpn-medical-dispatch:server:respond', id, (args and args[2]) or 'enroute')
end, false)

RegisterCommand('emscalls', function()
    local count = 0
    for _, call in pairs(calls) do
        if call.status ~= 'closed' and call.status ~= 'expired' then
            count = count + 1
            TriggerEvent('chat:addMessage', {
                args = { 'DPN EMS Dispatch', ('#%s P%s %s - %s'):format(call.id, call.priority, call.status, call.title) }
            })
        end
    end
    if count == 0 then notify('No active local medical calls.', 'primary') end
end, false)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(blips) do removeCallBlip(id) end
end)
