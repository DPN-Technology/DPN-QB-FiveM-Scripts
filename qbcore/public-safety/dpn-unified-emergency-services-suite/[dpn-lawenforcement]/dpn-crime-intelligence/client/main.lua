local uiOpen = false

local function openUi()
    if uiOpen then return end
    TriggerServerEvent('dpn-crime-intelligence:server:open')
end

RegisterCommand(Config.Command, openUi, false)
RegisterKeyMapping(Config.Command, 'Open DPN Crime Intelligence', 'keyboard', Config.OpenKey)

RegisterNetEvent('dpn-crime-intelligence:client:data', function(data)
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action='open', data=data or {} })
end)
RegisterNetEvent('dpn-crime-intelligence:client:searchResults', function(data)
    SendNUIMessage({ action='searchResults', data=data or {} })
end)

RegisterNUICallback('close', function(_, cb)
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action='close' })
    cb({ok=true})
end)
RegisterNUICallback('search', function(data, cb) TriggerServerEvent('dpn-crime-intelligence:server:search', data.query); cb({ok=true}) end)
RegisterNUICallback('createReport', function(data, cb) TriggerServerEvent('dpn-crime-intelligence:server:createReport', data); cb({ok=true}) end)
RegisterNUICallback('addWatchlist', function(data, cb) TriggerServerEvent('dpn-crime-intelligence:server:addWatchlist', data); cb({ok=true}) end)
RegisterNUICallback('clearWatchlist', function(data, cb) TriggerServerEvent('dpn-crime-intelligence:server:clearWatchlist', data.id); cb({ok=true}) end)
RegisterNUICallback('addLink', function(data, cb) TriggerServerEvent('dpn-crime-intelligence:server:addLink', data); cb({ok=true}) end)
RegisterNUICallback('dispatchAlert', function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    data.coords = {x=coords.x,y=coords.y,z=coords.z}
    TriggerServerEvent('dpn-crime-intelligence:server:alert', data)
    cb({ok=true})
end)

