local QBCore = nil
local hasAccess, isAdmin = false, false
local menuOpen = false

CreateThread(function()
    while GetResourceState('qb-core') ~= 'started' do
        Wait(500)
    end
    QBCore = exports['qb-core']:GetCoreObject()

    while not QBCore.Functions.GetPlayerData() or not QBCore.Functions.GetPlayerData().job do
        Wait(500)
    end

    RefreshMIBAccess()
    CreateAgencyBlip()
end)

function DebugPrint(msg)
    if Config.Debug then print(('[dpn-mib] %s'):format(msg)) end
end

function Notify(msg, nType, length)
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(msg, nType or 'primary', length or 5000)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, false)
    end
end

function RefreshMIBAccess(cb)
    if not QBCore then return cb and cb(false, false) end
    local answered = false
    QBCore.Functions.TriggerCallback('dpn-mib:server:hasAccess', function(ok, admin)
        answered = true
        hasAccess = ok == true
        isAdmin = admin == true
        if cb then cb(hasAccess, isAdmin) end
    end)
    SetTimeout(2500, function()
        if not answered then
            DebugPrint('Access callback timed out. Server side likely failed to start or callback missing.')
            Notify('MIB server callback timed out. Check server console for dpn-mib errors.', 'error', 9000)
            if cb then cb(false, false) end
        end
    end)
end

function CreateAgencyBlip()
    if not Config.AgencyBlip or not Config.AgencyBlip.Enabled then return end
    local c = Config.AgencyBlip.Coords
    local b = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(b, Config.AgencyBlip.Sprite)
    SetBlipColour(b, Config.AgencyBlip.Color)
    SetBlipScale(b, Config.AgencyBlip.Scale)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.AgencyBlip.Label)
    EndTextCommandSetBlipName(b)
end

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    RefreshMIBAccess()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    RefreshMIBAccess()
end)

RegisterNetEvent('dpn-mib:client:threatLevel', function(level, label, reason)
    Notify(('MIB Threat Level: %s | %s'):format(label or level, reason or 'No reason'), 'primary', 9000)
    if menuOpen then
        SendNUIMessage({ action = 'threatUpdate', threat = level, threatLabel = label })
    end
end)

local function ForceCloseMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end

function OpenMIBMenu()
    if not QBCore then
        Notify('MIB menu loading. Try again in a second.', 'error')
        return
    end

    RefreshMIBAccess(function(ok, admin)
        if not ok then
            Notify('MIB/admin access required. Set your job to mib/admin or grant ace permission dpn.mib.', 'error', 8500)
            return
        end

        local dashAnswered = false
        QBCore.Functions.TriggerCallback('dpn-mib:server:getDashboard', function(data)
            dashAnswered = true
            data = data or {}
            menuOpen = true
            SetNuiFocus(true, true)
            SetNuiFocusKeepInput(false)
            SendNUIMessage({
                action = 'open',
                dashboard = data,
                isAdmin = admin,
                colors = Config.DepartmentColors,
                neuralizer = Config.Neuralizer.Classes,
                resource = GetCurrentResourceName()
            })
            DebugPrint('Menu opened')
        end)
        SetTimeout(2500, function()
            if not dashAnswered then
                Notify('MIB dashboard callback timed out. Opening fallback menu.', 'error', 8500)
                menuOpen = true
                SetNuiFocus(true, true)
                SetNuiFocusKeepInput(false)
                SendNUIMessage({
                    action = 'open',
                    dashboard = { threat='green', threatLabel='GREEN / FALLBACK', cases={}, locations=Config.BlacksiteLocations or {} },
                    isAdmin = admin,
                    colors = Config.DepartmentColors or {},
                    neuralizer = (Config.Neuralizer and Config.Neuralizer.Classes) or {},
                    resource = GetCurrentResourceName()
                })
            end
        end)
    end)
end


RegisterCommand('mibdebug', function()
    print('[dpn-mib] CLIENT DEBUG resource='..GetCurrentResourceName())
    print('[dpn-mib] qb-core state='..GetResourceState('qb-core'))
    print('[dpn-mib] Config.MenuCommand='..tostring(Config and Config.MenuCommand))
    Notify('DPN MIB debug printed to F8/client console. qb-core: '..GetResourceState('qb-core'), 'primary', 8000)
end, false)

RegisterCommand('mibforce', function()
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action='open', dashboard={ threat='green', threatLabel='FORCE OPEN', cases={}, locations=Config.BlacksiteLocations or {} }, isAdmin=true, colors=Config.DepartmentColors or {}, neuralizer=(Config.Neuralizer and Config.Neuralizer.Classes) or {}, resource=GetCurrentResourceName() })
    Notify('Force-opened MIB NUI. If this works, your issue is permissions/server callback. If not, issue is NUI path/client load.', 'primary', 10000)
end, false)

RegisterCommand(Config.MenuCommand or 'mib', OpenMIBMenu, false)
RegisterCommand('mibmenu', OpenMIBMenu, false)
RegisterCommand('openmib', OpenMIBMenu, false)
RegisterCommand('mibclose', ForceCloseMenu, false)

CreateThread(function()
    Wait(1000)
    RegisterKeyMapping(Config.MenuCommand or 'mib', 'Open DPN MIB Admin Menu', 'keyboard', Config.MenuKey or 'F7')
end)

RegisterNUICallback('ready', function(_, cb)
    cb({ ok = true, resource = GetCurrentResourceName() })
end)

RegisterNUICallback('close', function(_, cb)
    ForceCloseMenu()
    cb('ok')
end)

RegisterNUICallback('action', function(data, cb)
    data = data or {}
    local a = data.actionName
    local reason = data.reason or ''
    local target = tonumber(data.target or 0)

    if a == 'neuralizer' then
        TriggerEvent('dpn-mib:client:useNeuralizer', data.class or 'beta', reason)
    elseif a == 'scan' then
        TriggerEvent('dpn-mib:client:scanNearest')
    elseif a == 'freeze' then
        TriggerServerEvent('dpn-mib:server:toolAction', 'freeze', target > 0 and target or GetClosestPlayerServerId(Config.Tools.freeze.range), { reason = reason })
    elseif a == 'cloak' then
        TriggerEvent('dpn-mib:client:cloak')
    elseif a == 'vehicle_scan' then
        TriggerEvent('dpn-mib:client:vehicleScan')
    elseif a == 'emergency_ping' then
        TriggerServerEvent('dpn-mib:server:toolAction', 'emergency_ping', nil, { message = data.message or 'MIB requesting support.', reason = reason })
    elseif a == 'loadout' then
        TriggerServerEvent('dpn-mib:server:toolAction', 'loadout', nil, { rank = data.rank or 'agent', reason = reason })
    elseif a == 'wipe_scene' then
        TriggerServerEvent('dpn-mib:server:toolAction', 'wipe_scene', nil, { reason = reason })
    elseif a == 'teleport' then
        local loc = Config.BlacksiteLocations[tonumber(data.locationIndex or 1)]
        if loc then SafeTeleport(loc.coords) end
    elseif a == 'create_case' then
        TriggerServerEvent('dpn-mib:server:toolAction', 'create_case', nil, { title = data.title, threat = data.threat, reason = reason })
    elseif a == 'threat' then
        TriggerServerEvent('dpn-mib:server:toolAction', 'threat', nil, { level = data.level, reason = reason })
    elseif a == 'goto_player' or a == 'bring' or a == 'spectate' or a == 'revive' then
        if not target or target <= 0 then Notify('Enter a valid target server ID.', 'error') else TriggerServerEvent('dpn-mib:server:toolAction', a, target, { reason = reason }) end
    elseif a == 'armor' then
        TriggerServerEvent('dpn-mib:server:toolAction', 'armor', nil, { reason = reason })
    elseif a == 'lockdown' then
        TriggerServerEvent('dpn-mib:server:toolAction', 'lockdown', nil, { reason = reason })
    elseif a == 'set_bucket' then
        if not target or target <= 0 then Notify('Enter a valid target server ID.', 'error') else TriggerServerEvent('dpn-mib:server:toolAction', 'set_bucket', target, { bucket = data.bucket, reason = reason }) end
    elseif a == 'kick' then
        if not target or target <= 0 then Notify('Enter a valid target server ID.', 'error') else TriggerServerEvent('dpn-mib:server:toolAction', 'kick', target, { reason = reason }) end
    elseif a == 'cleanup' then
        TriggerEvent('dpn-mib:client:cleanupArea')
    elseif a == 'admin_client' then
        TriggerServerEvent('dpn-mib:server:devAction', 'admin_client', nil, { clientAction = data.clientAction, reason = reason })
    elseif a == 'developer_client' then
        TriggerServerEvent('dpn-mib:server:devAction', 'developer_client', nil, { clientAction = data.clientAction, reason = reason })
    elseif a == 'pg7x_destination' then
        TriggerServerEvent('dpn-mib:server:devAction', 'pg7x_destination', nil, { index = data.index or 1, reason = reason })
    elseif a == 'pg7x_aim' then
        TriggerServerEvent('dpn-mib:server:devAction', 'pg7x_aim', nil, { reason = reason })
    elseif a == 'advanced_neuralizer' then
        local t = target > 0 and target or GetClosestPlayerServerId((Config.AdvancedNeuralizer.Classes[data.mode or 'beta'] or {}).radius or 8.0)
        TriggerServerEvent('dpn-mib:server:advancedNeuralizer', data.mode or 'beta', t, reason)
    elseif a == 'announce' or a == 'weather' or a == 'time' or a == 'cleanup_world' or a == 'resource_status' then
        TriggerServerEvent('dpn-mib:server:devAction', a, nil, data)
    end

    cb('ok')
end)

function GetClosestPlayerServerId(range)
    if not QBCore then return nil end
    local players = QBCore.Functions.GetPlayersFromCoords(GetEntityCoords(PlayerPedId()), range or 3.0)
    local closest, dist = nil, range or 3.0
    for _, p in pairs(players) do
        if p ~= PlayerId() then
            local d = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(GetPlayerPed(p)))
            if d < dist then closest, dist = GetPlayerServerId(p), d end
        end
    end
    return closest
end

function SafeTeleport(v4)
    local ped = PlayerPedId()
    local x, y, z, h = v4.x, v4.y, v4.z, v4.w or 0.0
    if Config.SafeTeleport.Fade then DoScreenFadeOut(300); Wait(350) end
    RequestCollisionAtCoord(x, y, z)
    if Config.SafeTeleport.Enabled then
        for _ = 1, Config.SafeTeleport.GroundProbeTries do
            local found, gz = GetGroundZFor_3dCoord(x, y, z + 30.0, false)
            if found then z = gz + Config.SafeTeleport.ZOffset break end
            Wait(20)
        end
    end
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, h)
    if Config.SafeTeleport.Fade then Wait(250); DoScreenFadeIn(500) end
end

RegisterNetEvent('dpn-mib:client:teleportToCoords', function(coords)
    if coords then SafeTeleport(vector4(coords.x, coords.y, coords.z, GetEntityHeading(PlayerPedId()))) end
end)

RegisterNetEvent('dpn-mib:client:emergencyPing', function(coords, message)
    Notify(message or 'MIB support request received.', 'primary', 8000)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, 487); SetBlipColour(b, 0); SetBlipScale(b, 1.2)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentString('MIB Support Request'); EndTextCommandSetBlipName(b)
    SetTimeout(180000, function() RemoveBlip(b) end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then ForceCloseMenu() end
end)
