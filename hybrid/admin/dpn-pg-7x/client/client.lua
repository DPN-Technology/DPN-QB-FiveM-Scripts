local isAdmin = false
local portalMode = false
local destinations = {}
local activePortals = {}
local portalDisplayCache = {}
local portalDisplayResolving = {}
local selectedDestination = nil
local postalDestination = nil
local postalStatus = { ready = false, count = 0, resource = nil, file = nil }
local postalSearchResults = {}
local currentPostal = nil
local uiOpen = false
local nuiReady = false
local nuiVisible = false
local lastUiOpenAttempt = 0
local gunObject = nil
local lastPortalEnter = 0

local FirePortal

-- ================================================================
-- Utility
-- ================================================================

local function Notify(msg, msgType)
    msgType = msgType or 'primary'
    if GetResourceState('qb-core') == 'started' then
        local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
        if ok and QBCore and QBCore.Functions and QBCore.Functions.Notify then
            QBCore.Functions.Notify(msg, msgType)
            return
        end
    end

    TriggerEvent('chat:addMessage', {
        color = { 0, 255, 80 },
        multiline = true,
        args = { 'DPN PG-7X', msg }
    })
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, false)
end

local function DrawText2D(x, y, scale, text)
    SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextColour(0, 255, 80, 230)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function HelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function RotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }

    return {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
end

local function RaycastFromCamera(distance)
    local cameraRotation = GetGameplayCamRot(2)
    local cameraCoord = GetGameplayCamCoord()
    local direction = RotationToDirection(cameraRotation)
    local destination = {
        x = cameraCoord.x + direction.x * distance,
        y = cameraCoord.y + direction.y * distance,
        z = cameraCoord.z + direction.z * distance
    }

    local rayHandle = StartShapeTestRay(
        cameraCoord.x, cameraCoord.y, cameraCoord.z,
        destination.x, destination.y, destination.z,
        -1,
        PlayerPedId(),
        0
    )

    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
    return hit == 1, endCoords, surfaceNormal, entityHit
end

local function HeadingFromNormal(normal)
    if not normal then return GetEntityHeading(PlayerPedId()) end
    if math.abs(normal.z or 0.0) > 0.75 then
        return GetEntityHeading(PlayerPedId())
    end
    local heading = math.deg(math.atan(normal.x or 0.0, normal.y or 0.0))
    return (heading + 180.0) % 360.0
end

local function TableKeys(t)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

local function NormalizeKey(name)
    if not name then return nil end
    name = tostring(name):gsub('^%s+', ''):gsub('%s+$', '')
    name = name:gsub('[^%w%s%-%_]', '')
    name = name:gsub('%s+', '_')
    name = name:lower()
    if name == '' then return nil end
    return name
end

local function NormalizePostal(code)
    if not code then return nil end
    code = tostring(code):gsub('^%s+', ''):gsub('%s+$', '')
    code = code:gsub('[^%w%-%_]', '')
    if code == '' then return nil end
    return code:upper()
end

local function RequestModelBlocking(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(10)
    end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function Vec3Distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function Vec2Distance(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function HeadingToForward(heading)
    local r = math.rad(heading or 0.0)
    return { x = -math.sin(r), y = math.cos(r), z = 0.0 }
end

local function HeadingToRight(heading)
    local r = math.rad((heading or 0.0) + 90.0)
    return { x = -math.sin(r), y = math.cos(r), z = 0.0 }
end

local function MakeVec3(x, y, z)
    return { x = tonumber(x) or 0.0, y = tonumber(y) or 0.0, z = tonumber(z) or 0.0 }
end

-- ================================================================
-- Postal Helpers
-- ================================================================

local function GetCurrentPostal()
    if not Config.Postal or not Config.Postal.Enabled then return nil end

    for _, res in ipairs(Config.Postal.AutoDetectResources or {}) do
        if GetResourceState(res) == 'started' then
            for _, exportName in ipairs(Config.Postal.CurrentPostalExports or {}) do
                local ok, result = pcall(function()
                    if exports[res] and exports[res][exportName] then
                        return exports[res][exportName]()
                    end
                    return nil
                end)
                if ok and result ~= nil and tostring(result) ~= '' then
                    return NormalizePostal(result)
                end
            end
        end
    end

    return nil
end

local function IsSelectedDestinationValid()
    if not selectedDestination then return false end
    if destinations[selectedDestination] then return true end
    if postalDestination and selectedDestination == postalDestination.key then return true end
    return false
end

local function SelectedDestinationLabel()
    if selectedDestination and destinations[selectedDestination] then
        return destinations[selectedDestination].label or selectedDestination
    end
    if postalDestination and selectedDestination == postalDestination.key then
        return postalDestination.label or postalDestination.key
    end
    return 'NONE'
end

local function BuildDestinationList()
    local list = {}
    for key, dest in pairs(destinations or {}) do
        list[#list + 1] = {
            key = key,
            label = dest.label or key,
            type = dest.type or 'saved',
            postal = dest.postal,
            coords = dest.coords,
            heading = dest.heading,
            selected = selectedDestination == key
        }
    end

    if postalDestination then
        list[#list + 1] = {
            key = postalDestination.key,
            label = postalDestination.label,
            type = 'temporary_postal',
            postal = postalDestination.postal,
            coords = postalDestination.coords,
            heading = postalDestination.heading,
            selected = selectedDestination == postalDestination.key
        }
    end

    table.sort(list, function(a, b)
        return tostring(a.label or a.key) < tostring(b.label or b.key)
    end)

    return list
end

local function ActivePortalCount()
    local c = 0
    for _ in pairs(activePortals or {}) do c = c + 1 end
    return c
end

-- ================================================================
-- NUI
-- ================================================================

local function SendUiState(extra)
    local payload = extra or {}
    payload.action = payload.action or 'state'
    payload.uiOpen = uiOpen
    payload.isAdmin = isAdmin
    payload.portalMode = portalMode
    payload.selectedKey = selectedDestination
    payload.selectedLabel = SelectedDestinationLabel()
    payload.destinations = BuildDestinationList()
    payload.activePortalCount = ActivePortalCount()
    payload.currentPostal = currentPostal
    payload.postalStatus = postalStatus
    payload.postalSearchResults = postalSearchResults
    SendNUIMessage(payload)
end

local function PushUiOpenMessage()
    SendUiState({ action = 'open' })
    -- Send it again a moment later. Some FiveM clients load the NUI page after focus is already set,
    -- which caused the mouse cursor to appear over a hidden UI.
    CreateThread(function()
        Wait(125)
        if uiOpen then SendUiState({ action = 'open' }) end
        Wait(375)
        if uiOpen then SendUiState({ action = 'open' }) end
    end)
end

local function SetNuiFocusKeepInputSafe(enabled)
    if SetNuiFocusKeepInput then
        pcall(SetNuiFocusKeepInput, enabled)
    end
end

local function SetNuiFocusSafe(hasFocus, hasCursor)
    pcall(SetNuiFocus, hasFocus, hasCursor)
end

local function ReleaseNuiFocus(repeatRelease)
    SetNuiFocusSafe(false, false)
    SetNuiFocusKeepInputSafe(false)
    SendNUIMessage({ action = 'close' })

    if repeatRelease then
        CreateThread(function()
            for _ = 1, 12 do
                SetNuiFocusSafe(false, false)
                SetNuiFocusKeepInputSafe(false)
                SendNUIMessage({ action = 'close' })
                Wait(150)
            end
        end)
    end
end

local function OpenUi()
    -- OpenUi is only called after the server confirms admin access.
    -- First clear any old/half-loaded NUI focus so a broken previous open cannot trap the cursor.
    ReleaseNuiFocus(false)
    Wait(75)

    uiOpen = true
    nuiVisible = false
    lastUiOpenAttempt = GetGameTimer()
    isAdmin = true
    currentPostal = GetCurrentPostal() or currentPostal
    TriggerServerEvent('dpn-pg7x:server:requestDestinations')

    SetNuiFocusSafe(true, true)
    -- Keep game input available so ESC/F8 emergency reset still works even if the browser page fails.
    SetNuiFocusKeepInputSafe(true)
    PushUiOpenMessage()

    -- Failsafe: if the browser never confirms it displayed the panel, release the mouse.
    CreateThread(function()
        local attempt = lastUiOpenAttempt
        Wait(7000)
        if uiOpen and not nuiVisible and attempt == lastUiOpenAttempt then
            uiOpen = false
            ReleaseNuiFocus(true)
            Notify('PG-7X UI did not answer after 7 seconds, so focus was released. Use /pgui again or /pguifix.', 'error')
        end
    end)

    -- Second safety window for slow clients.
    CreateThread(function()
        local attempt = lastUiOpenAttempt
        Wait(12000)
        if uiOpen and not nuiVisible and attempt == lastUiOpenAttempt then
            uiOpen = false
            ReleaseNuiFocus(true)
        end
    end)
end

local function CloseUi()
    uiOpen = false
    nuiVisible = false
    ReleaseNuiFocus(true)
end

local function ForceCloseUi()
    uiOpen = false
    nuiVisible = false
    ReleaseNuiFocus(true)
    Notify('PG-7X UI focus reset.', 'primary')
end

RegisterCommand(Config.UICommand, function()
    if uiOpen then
        CloseUi()
    else
        TriggerServerEvent('dpn-pg7x:server:openUiRequest')
    end
end, false)

RegisterCommand('pg7xui', function()
    ExecuteCommand(Config.UICommand)
end, false)

RegisterCommand('pguifix', function()
    ForceCloseUi()
end, false)

RegisterCommand('pguireset', function()
    ForceCloseUi()
end, false)

RegisterKeyMapping(Config.UICommand, 'Open DPN PG-7X Portal UI', 'keyboard', Config.UIKey or 'F7')
RegisterKeyMapping('pguifix', 'Force close/reset DPN PG-7X UI focus', 'keyboard', Config.UIResetKey or 'F8')

RegisterNUICallback('close', function(_, cb)
    CloseUi()
    cb({ ok = true })
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    if uiOpen then
        PushUiOpenMessage()
    else
        SendUiState()
    end
    cb({ ok = true })
end)

RegisterNUICallback('opened', function(_, cb)
    nuiVisible = true
    cb({ ok = true })
end)

RegisterNUICallback('forceClose', function(_, cb)
    ForceCloseUi()
    cb({ ok = true })
end)

RegisterNUICallback('toggleMode', function(_, cb)
    TriggerServerEvent('dpn-pg7x:server:toggleRequest')
    cb({ ok = true })
end)

RegisterNUICallback('selectDestination', function(data, cb)
    local key = data and tostring(data.key or '') or ''
    if destinations[key] or (postalDestination and postalDestination.key == key) then
        selectedDestination = key
        Notify(('Selected destination: %s'):format(SelectedDestinationLabel()), 'success')
        SendUiState()
    else
        Notify('Destination not found.', 'error')
    end
    cb({ ok = true })
end)

RegisterNUICallback('saveHere', function(data, cb)
    local name = data and tostring(data.name or '') or ''
    if name == '' then
        Notify('Enter a destination name first.', 'error')
    else
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        TriggerServerEvent('dpn-pg7x:server:saveDestination', name, { x = coords.x, y = coords.y, z = coords.z }, heading)
    end
    cb({ ok = true })
end)

RegisterNUICallback('deleteDestination', function(data, cb)
    local key = data and tostring(data.key or '') or ''
    if key ~= '' then TriggerServerEvent('dpn-pg7x:server:deleteDestination', key) end
    cb({ ok = true })
end)

RegisterNUICallback('selectPostal', function(data, cb)
    local code = NormalizePostal(data and data.postal)
    if not code then
        Notify('Enter a postal code first.', 'error')
    else
        TriggerServerEvent('dpn-pg7x:server:lookupPostal', code)
    end
    cb({ ok = true })
end)

RegisterNUICallback('useCurrentPostal', function(_, cb)
    local code = GetCurrentPostal()
    currentPostal = code
    if not code then
        Notify('Current postal export not available. Type a postal manually instead.', 'error')
    else
        TriggerServerEvent('dpn-pg7x:server:lookupPostal', code)
    end
    SendUiState()
    cb({ ok = true })
end)

RegisterNUICallback('savePostal', function(data, cb)
    local code = NormalizePostal(data and data.postal)
    local name = data and tostring(data.name or '') or ''
    if not code then
        Notify('Enter a postal code to save.', 'error')
    else
        TriggerServerEvent('dpn-pg7x:server:savePostalDestination', name, code)
    end
    cb({ ok = true })
end)

RegisterNUICallback('searchPostals', function(data, cb)
    local q = NormalizePostal(data and data.query)
    if q then
        TriggerServerEvent('dpn-pg7x:server:searchPostals', q)
    else
        postalSearchResults = {}
        SendUiState()
    end
    cb({ ok = true })
end)

RegisterNUICallback('firePortal', function(_, cb)
    if FirePortal then FirePortal() end
    cb({ ok = true })
end)

RegisterNUICallback('closePortal', function(_, cb)
    TriggerServerEvent('dpn-pg7x:server:closeMyPortals')
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    currentPostal = GetCurrentPostal()
    TriggerServerEvent('dpn-pg7x:server:requestAuth')
    SendUiState()
    cb({ ok = true })
end)

-- ================================================================
-- NUI Emergency Input Guard
-- ================================================================

CreateThread(function()
    while true do
        if uiOpen then
            Wait(0)

            -- Prevent player actions while the UI is focused, but leave emergency close controls readable.
            DisableControlAction(0, 1, true)   -- look left/right
            DisableControlAction(0, 2, true)   -- look up/down
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)  -- aim
            DisableControlAction(0, 30, true)  -- move left/right
            DisableControlAction(0, 31, true)  -- move forward/back
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            -- Backspace/Esc/F8 will hard close even when the NUI page does not load.
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322) or IsControlJustPressed(0, 169) then
                ForceCloseUi()
            end
        else
            Wait(500)
        end
    end
end)

-- ================================================================
-- Portal Gun Prop
-- ================================================================

local function DeleteGunProp()
    if gunObject and DoesEntityExist(gunObject) then
        DeleteEntity(gunObject)
    end
    gunObject = nil
end

local function CreateGunProp()
    DeleteGunProp()

    local ped = PlayerPedId()
    local hash = RequestModelBlocking(Config.GunProp)
    if not hash then
        Notify('PG-7X prop model failed to load. Portal mode still works.', 'error')
        return
    end

    local coords = GetEntityCoords(ped)
    gunObject = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, false)
    SetEntityCollision(gunObject, false, false)

    local a = Config.GunAttach
    AttachEntityToEntity(
        gunObject,
        ped,
        GetPedBoneIndex(ped, a.bone),
        a.x, a.y, a.z,
        a.rx, a.ry, a.rz,
        true, true, false, true, 1, true
    )

    SetModelAsNoLongerNeeded(hash)
end

local function SetPortalMode(state)
    if state and not isAdmin then
        Notify('Access denied. PG-7X is admin-only.', 'error')
        return
    end

    portalMode = state
    if portalMode then
        CreateGunProp()
        Notify('PG-7X armed. Select a destination/postal, aim, then press E.', 'success')
    else
        DeleteGunProp()
        Notify('PG-7X disarmed.', 'primary')
    end
    SendUiState()
end

-- ================================================================
-- Commands
-- ================================================================

RegisterCommand(Config.ToggleCommand, function()
    TriggerServerEvent('dpn-pg7x:server:toggleRequest')
end, false)

RegisterCommand(Config.CloseCommand, function()
    TriggerServerEvent('dpn-pg7x:server:closeMyPortals')
end, false)

RegisterCommand(Config.PostalCommand, function(_, args)
    if not isAdmin then
        Notify('Access denied. PG-7X postal destinations are admin-only.', 'error')
        return
    end

    local code = args[1]
    if not code or code == '' then
        Notify('/' .. Config.PostalCommand .. ' postal_code | current', 'primary')
        return
    end

    if string.lower(code) == 'current' then
        code = GetCurrentPostal()
        currentPostal = code
        if not code then
            Notify('Current postal export not available. Type the postal manually.', 'error')
            return
        end
    end

    TriggerServerEvent('dpn-pg7x:server:lookupPostal', code)
end, false)

RegisterCommand(Config.DestinationCommand, function(_, args)
    local action = args[1] and string.lower(args[1]) or nil

    if not isAdmin then
        Notify('Access denied. PG-7X destinations are admin-only.', 'error')
        return
    end

    if not action then
        Notify('/' .. Config.DestinationCommand .. ' save name | postal code | select name | list | delete name | reload', 'primary')
        return
    end

    if action == 'save' or action == 'here' or action == 'add' then
        local name = table.concat(args, ' ', 2)
        if name == '' then
            Notify('Usage: /' .. Config.DestinationCommand .. ' save destination_name', 'error')
            return
        end
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        TriggerServerEvent('dpn-pg7x:server:saveDestination', name, { x = coords.x, y = coords.y, z = coords.z }, heading)
        return
    end

    if action == 'postal' or action == 'post' then
        local code = args[2]
        if not code or code == '' then
            Notify('Usage: /' .. Config.DestinationCommand .. ' postal postal_code', 'error')
            return
        end
        TriggerServerEvent('dpn-pg7x:server:lookupPostal', code)
        return
    end

    if action == 'delete' or action == 'del' or action == 'remove' then
        local name = table.concat(args, ' ', 2)
        TriggerServerEvent('dpn-pg7x:server:deleteDestination', name)
        return
    end

    if action == 'select' or action == 'set' then
        local name = table.concat(args, ' ', 2)
        local key = NormalizeKey(name)
        if key and destinations[key] then
            selectedDestination = key
            Notify(('Selected destination: %s'):format(destinations[key].label or key), 'success')
            SendUiState()
        else
            Notify('Destination not found. Use /' .. Config.DestinationCommand .. ' list or /' .. Config.UICommand .. '.', 'error')
        end
        return
    end

    if action == 'list' then
        local keys = TableKeys(destinations)
        if #keys == 0 then
            Notify('No saved destinations. Use /' .. Config.DestinationCommand .. ' save name or /' .. Config.UICommand .. '.', 'error')
            return
        end
        Notify('Destinations: ' .. table.concat(keys, ', '), 'primary')
        return
    end

    if action == 'reload' or action == 'refresh' then
        TriggerServerEvent('dpn-pg7x:server:requestDestinations')
        Notify('Requested latest PG-7X destinations and postals.', 'primary')
        return
    end

    Notify('Unknown PG-7X destination action.', 'error')
end, false)

CreateThread(function()
    Wait(1500)
    if not Config.UI or Config.UI.ShowCommandHelp ~= false then
        TriggerEvent('chat:addSuggestion', '/' .. Config.ToggleCommand, 'Toggle the DPN PG-7X admin portal gun.')
        TriggerEvent('chat:addSuggestion', '/' .. Config.UICommand, 'Open the DPN PG-7X admin UI.')
        TriggerEvent('chat:addSuggestion', '/' .. Config.PostalCommand, 'Select a postal as your portal destination.', {
            { name = 'postal', help = 'Postal code or current' }
        })
        TriggerEvent('chat:addSuggestion', '/' .. Config.CloseCommand, 'Close your active PG-7X portal.')
        TriggerEvent('chat:addSuggestion', '/' .. Config.DestinationCommand, 'Manage PG-7X portal destinations.', {
            { name = 'action', help = 'save/postal/select/list/delete/reload' },
            { name = 'name', help = 'Destination name or postal code' }
        })
    end
end)

-- ================================================================
-- Events
-- ================================================================

RegisterNetEvent('dpn-pg7x:client:notify', function(msg, msgType)
    Notify(msg, msgType)
end)

RegisterNetEvent('dpn-pg7x:client:setAuth', function(state)
    isAdmin = state == true
    if not isAdmin and portalMode then
        SetPortalMode(false)
    end
    SendUiState()
end)

RegisterNetEvent('dpn-pg7x:client:openUiAuthorized', function(serverDestinations, serverPostalStatus)
    isAdmin = true
    if serverDestinations then destinations = serverDestinations end
    if serverPostalStatus then postalStatus = serverPostalStatus end
    OpenUi()
end)

RegisterNetEvent('dpn-pg7x:client:toggleMode', function()
    SetPortalMode(not portalMode)
end)

RegisterNetEvent('dpn-pg7x:client:syncDestinations', function(serverDestinations)
    destinations = serverDestinations or {}

    if selectedDestination and not destinations[selectedDestination] and not (postalDestination and postalDestination.key == selectedDestination) then
        selectedDestination = nil
    end

    if not selectedDestination then
        local keys = TableKeys(destinations)
        if #keys > 0 then selectedDestination = keys[1] end
    end

    SendUiState()
end)

RegisterNetEvent('dpn-pg7x:client:postalStatus', function(status)
    postalStatus = status or { ready = false, count = 0 }
    SendUiState()
end)

RegisterNetEvent('dpn-pg7x:client:postalSelected', function(data)
    if not data or not data.key then return end
    postalDestination = data
    selectedDestination = data.key
    Notify(('Selected postal destination: %s'):format(data.label or data.key), 'success')
    SendUiState()
end)

RegisterNetEvent('dpn-pg7x:client:postalSearchResults', function(results)
    postalSearchResults = results or {}
    SendUiState()
end)

RegisterNetEvent('dpn-pg7x:client:syncPortals', function(portals)
    activePortals = portals or {}
    portalDisplayCache = {}
    portalDisplayResolving = {}
    SendUiState()
end)

RegisterNetEvent('dpn-pg7x:client:addPortal', function(portal)
    if not portal or not portal.id then return end
    activePortals[portal.id] = portal
    portalDisplayCache[portal.id] = nil
    portalDisplayResolving[portal.id] = nil
    SendUiState()
end)

RegisterNetEvent('dpn-pg7x:client:removePortal', function(portalId, reason)
    activePortals[portalId] = nil
    portalDisplayCache[portalId] = nil
    portalDisplayResolving[portalId] = nil
    if reason == 'expired' then
        Notify('A PG-7X portal collapsed.', 'primary')
    end
    SendUiState()
end)

local function FindClosestRoadCoord(x, y, z)
    local teleportCfg = Config.Teleport or {}
    if teleportCfg.UseClosestVehicleNode == false then return nil, nil end

    local ok, found, nodeCoords, nodeHeading = pcall(function()
        return GetClosestVehicleNodeWithHeading(x + 0.0, y + 0.0, (z or 50.0) + 0.0, 1, 3.0, 0)
    end)

    if ok and found and nodeCoords then
        return { x = nodeCoords.x, y = nodeCoords.y, z = nodeCoords.z }, nodeHeading
    end

    return nil, nil
end

local function LoadTeleportArea(x, y, z)
    local teleportCfg = Config.Teleport or {}
    local timeout = GetGameTimer() + (teleportCfg.CollisionTimeoutMs or 8000)

    SetFocusPosAndVel(x, y, z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(x, y, z)
    NewLoadSceneStart(x, y, z, x, y, z, 80.0, 0)

    while GetGameTimer() < timeout do
        RequestCollisionAtCoord(x, y, z)
        if IsNewLoadSceneLoaded() then break end
        Wait(50)
    end

    NewLoadSceneStop()
end

local function GetGroundSafeCoords(x, y, incomingZ, heading, forceResolve)
    local teleportCfg = Config.Teleport or {}
    local offset = teleportCfg.GroundOffset or Config.MinimumDestinationZOffset or 0.85
    local z = tonumber(incomingZ) or 0.0
    local shouldResolve = forceResolve == true or z <= (teleportCfg.ResolveGroundWhenBelowZ or 10.0)

    -- Postal coordinates are usually raw X/Y only. First move them to the nearest road node so the
    -- player lands on pavement instead of under bridges, rooftops, or unloaded terrain.
    if shouldResolve then
        local roadCoord, roadHeading = FindClosestRoadCoord(x, y, z)
        if roadCoord then
            x, y, z = roadCoord.x, roadCoord.y, roadCoord.z
            heading = roadHeading or heading
        end
    end

    LoadTeleportArea(x, y, math.max(z, 75.0))

    if not shouldResolve then
        return { x = x, y = y, z = z + offset, heading = heading }, true
    end

    local heights = teleportCfg.GroundProbeHeights or { 1200.0, 1000.0, 850.0, 700.0, 550.0, 400.0, 300.0, 200.0, 150.0, 100.0, 75.0, 50.0, 30.0 }

    for _, height in ipairs(heights) do
        RequestCollisionAtCoord(x, y, height)
        Wait(90)
        local found, groundZ = GetGroundZFor_3dCoord(x, y, height, false)
        if found and groundZ and groundZ > -100.0 then
            return { x = x, y = y, z = groundZ + offset, heading = heading }, true
        end
    end

    -- Last-resort fallback: keep the user above the area instead of under the map.
    return { x = x, y = y, z = (teleportCfg.FallbackZ or 75.0), heading = heading }, false
end

RegisterNetEvent('dpn-pg7x:client:teleport', function(dest)
    if not dest or not dest.x or not dest.y then return end

    local ped = PlayerPedId()
    local entity = ped

    if Config.AllowVehicleTeleport and IsPedInAnyVehicle(ped, false) then
        entity = GetVehiclePedIsIn(ped, false)
    end

    FreezeEntityPosition(entity, true)
    DoScreenFadeOut(220)
    while not IsScreenFadedOut() do Wait(10) end

    local safe, foundGround
    if dest.exactZ == true and dest.resolveGround ~= true then
        safe = {
            x = tonumber(dest.x) or 0.0,
            y = tonumber(dest.y) or 0.0,
            z = tonumber(dest.z) or 0.0,
            heading = dest.heading or GetEntityHeading(entity)
        }
        LoadTeleportArea(safe.x, safe.y, safe.z)
        foundGround = true
    else
        safe, foundGround = GetGroundSafeCoords(dest.x, dest.y, tonumber(dest.z) or 0.0, dest.heading or GetEntityHeading(entity), dest.resolveGround == true)
    end

    -- Cache the actual client-resolved portal display point for postal/ground-resolved endpoints.
    -- Without this, a return portal can be drawn at a shifted road node while the server/client
    -- still think the visible endpoint is the raw postal XY/Z=0 coordinate.
    if dest.portalId and dest.toSide and dest.resolveGround == true then
        local groundOffset = ((Config.Teleport and Config.Teleport.GroundOffset) or 0.95)
        local centerOffset = tonumber(Config.PortalCenterZOffset or 1.05) or 1.05
        local key = tostring(dest.portalId) .. ':' .. tostring(dest.toSide or 'b')
        portalDisplayCache[key] = {
            x = safe.x,
            y = safe.y,
            z = safe.z + (centerOffset - groundOffset),
            heading = safe.heading or dest.heading or 0.0,
            foundGround = foundGround == true
        }
        portalDisplayResolving[key] = nil
    end

    RequestCollisionAtCoord(safe.x, safe.y, safe.z)
    SetEntityCoordsNoOffset(entity, safe.x, safe.y, safe.z + 1.0, false, false, false)
    SetEntityHeading(entity, safe.heading or GetEntityHeading(entity))

    local timeout = GetGameTimer() + ((Config.Teleport and Config.Teleport.CollisionTimeoutMs) or 8000)
    while GetGameTimer() < timeout and not HasCollisionLoadedAroundEntity(entity) do
        RequestCollisionAtCoord(safe.x, safe.y, safe.z)
        Wait(50)
    end

    if entity ~= ped then
        SetEntityCoordsNoOffset(entity, safe.x, safe.y, safe.z + 0.6, false, false, false)
        SetVehicleOnGroundProperly(entity)
    else
        ClearPedTasksImmediately(ped)
        SetEntityCoordsNoOffset(ped, safe.x, safe.y, safe.z, false, false, false)
    end

    Wait(250)
    FreezeEntityPosition(entity, false)
    ClearFocus()

    Wait(180)
    DoScreenFadeIn(350)

    if foundGround then
        Notify(('Portal jump complete: %s'):format(dest.destLabel or 'destination'), 'success')
    else
        Notify(('Portal jump complete, but ground Z used fallback. Save this postal/destination manually if needed: %s'):format(dest.destLabel or 'destination'), 'primary')
    end
end)

-- ================================================================
-- Portal Creation Logic
-- ================================================================

local function BuildPortalPlacement(hitCoords, normal)
    local ped = PlayerPedId()
    local heading = HeadingFromNormal(normal)
    local centerOffset = tonumber(Config.PortalCenterZOffset or 1.05) or 1.05
    local forwardOffset = tonumber(Config.PortalExitForwardOffset or 1.15) or 1.15
    local portalCoords = { x = hitCoords.x, y = hitCoords.y, z = hitCoords.z }
    local teleportCoords = { x = hitCoords.x, y = hitCoords.y, z = hitCoords.z + (Config.MinimumDestinationZOffset or 0.65) }

    -- Ground placement: always raise the marker center so the doorway is vertical and walk-through.
    if normal and (normal.z or 0.0) > 0.65 then
        heading = GetEntityHeading(ped)
        portalCoords.z = hitCoords.z + centerOffset

        local fwd = HeadingToForward(heading)
        teleportCoords.x = hitCoords.x + fwd.x * forwardOffset
        teleportCoords.y = hitCoords.y + fwd.y * forwardOffset
        teleportCoords.z = hitCoords.z + (Config.MinimumDestinationZOffset or 0.65)
    else
        -- Wall/prop placement: nudge the portal and landing point away from the surface.
        local nx = normal and normal.x or 0.0
        local ny = normal and normal.y or 0.0
        local nz = normal and normal.z or 0.0
        portalCoords.x = portalCoords.x + (nx * 0.08)
        portalCoords.y = portalCoords.y + (ny * 0.08)
        portalCoords.z = portalCoords.z + (nz * 0.08)

        teleportCoords.x = portalCoords.x + (nx * forwardOffset)
        teleportCoords.y = portalCoords.y + (ny * forwardOffset)
        teleportCoords.z = portalCoords.z
    end

    return portalCoords, {
        x = normal and normal.x or 0.0,
        y = normal and normal.y or 0.0,
        z = normal and normal.z or 1.0
    }, heading, teleportCoords
end

FirePortal = function()
    if not IsSelectedDestinationValid() then
        Notify('No PG-7X destination selected. Open /' .. Config.UICommand .. ' or use /' .. Config.PostalCommand .. ' postal_code.', 'error')
        return
    end

    local ped = PlayerPedId()
    if Config.BlockPortalInsideVehicleIfPassenger and IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(veh, -1) ~= ped then
            Notify('Passengers cannot fire the PG-7X from a vehicle.', 'error')
            return
        end
    end

    local hit, hitCoords, normal = RaycastFromCamera(Config.MaxCreateDistance)
    if not hit then
        Notify('No valid portal surface found.', 'error')
        return
    end

    local portalCoords, surfaceNormal, portalHeading, portalTeleportCoords = BuildPortalPlacement(hitCoords, normal)
    TriggerServerEvent('dpn-pg7x:server:createPortal', selectedDestination, portalCoords, surfaceNormal, portalHeading, portalTeleportCoords)
end

CreateThread(function()
    Wait(1000)
    TriggerServerEvent('dpn-pg7x:server:requestAuth')

    while true do
        local sleep = 750

        if portalMode then
            sleep = 0
            DisableControlAction(0, 140, true) -- melee light
            DisableControlAction(0, 141, true) -- melee heavy
            DisableControlAction(0, 142, true) -- melee alternate

            DrawText2D(0.5, 0.88, 0.36, ('DPN PG-7X | Destination: %s | E: Open | F7: UI | G: Close | Backspace: Disarm'):format(SelectedDestinationLabel()))
            HelpText('~g~PG-7X Armed~s~ | Aim at a surface and press ~INPUT_CONTEXT~ to open a green portal.')

            if IsControlJustPressed(0, Config.Controls.FirePortal) then
                FirePortal()
            end

            if IsControlJustPressed(0, Config.Controls.ClosePortal) then
                TriggerServerEvent('dpn-pg7x:server:closeMyPortals')
            end

            if IsControlJustPressed(0, Config.Controls.ExitMode) then
                SetPortalMode(false)
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(1800)
        if uiOpen or portalMode then
            local latest = GetCurrentPostal()
            if latest ~= currentPostal then
                currentPostal = latest
                SendUiState()
            end
        end
    end
end)

-- ================================================================
-- Portal Render + Walk-In Detection
-- ================================================================

local function PortalEndpointCacheKey(portalId, side)
    return tostring(portalId) .. ':' .. tostring(side or 'a')
end

local function ResolvePortalEndpointForDisplay(portalId, side, endpoint, playerCoords)
    if not endpoint or not endpoint.coords then return nil end

    local c = endpoint.coords
    local teleportCfg = Config.Teleport or {}
    local resolveBelow = teleportCfg.ResolveGroundWhenBelowZ or 10.0
    local needsGround = endpoint.resolveGround == true or (tonumber(c.z) or 0.0) <= resolveBelow

    if not needsGround then
        return MakeVec3(c.x, c.y, c.z)
    end

    local key = PortalEndpointCacheKey(portalId, side)
    if portalDisplayCache[key] then
        return portalDisplayCache[key]
    end

    -- Only resolve far postal/destination endpoints when the player is actually close to that XY area.
    -- This avoids forcing every client to stream every active portal endpoint across the map.
    local drawDistance = Config.PortalDrawDistance or 120.0
    if playerCoords and Vec2Distance(playerCoords, c) > drawDistance then
        return nil
    end

    if portalDisplayResolving[key] then return nil end
    portalDisplayResolving[key] = true

    CreateThread(function()
        local x = tonumber(c.x) or 0.0
        local y = tonumber(c.y) or 0.0
        local z = tonumber(c.z) or 0.0
        local heading = tonumber(endpoint.heading) or 0.0
        local centerOffset = tonumber(Config.PortalCenterZOffset or 1.05) or 1.05

        local roadCoord, roadHeading = FindClosestRoadCoord(x, y, z)
        if roadCoord then
            x, y, z = roadCoord.x, roadCoord.y, roadCoord.z
            heading = roadHeading or heading
        end

        LoadTeleportArea(x, y, math.max(z, 75.0))

        local foundGround = false
        local groundZ = z
        local heights = teleportCfg.GroundProbeHeights or { 1200.0, 1000.0, 850.0, 700.0, 550.0, 400.0, 300.0, 200.0, 150.0, 100.0, 75.0, 50.0, 30.0 }
        for _, height in ipairs(heights) do
            RequestCollisionAtCoord(x, y, height)
            Wait(65)
            local found, gz = GetGroundZFor_3dCoord(x, y, height, false)
            if found and gz and gz > -100.0 then
                foundGround = true
                groundZ = gz
                break
            end
        end

        if not foundGround then
            groundZ = math.max(z, (teleportCfg.FallbackZ or 75.0))
        end

        portalDisplayCache[key] = {
            x = x,
            y = y,
            z = groundZ + centerOffset,
            heading = heading,
            foundGround = foundGround
        }
        portalDisplayResolving[key] = nil
    end)

    return nil
end

local function DrawPortalRingPoint(x, y, z, scale, alpha, color)
    DrawMarker(
        28,
        x, y, z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        scale, scale, scale,
        color.r, color.g, color.b, alpha,
        false, true, 2, false, nil, nil, false
    )
end

local function DrawPortal(portal, endpoint, drawCoords)
    if not portal or not endpoint or not drawCoords then return end

    local color = Config.PortalColor or { r = 0, g = 255, b = 80, a = 185 }
    local c = drawCoords
    local heading = tonumber(drawCoords.heading or endpoint.heading or portal.heading or 0.0) or 0.0
    local t = GetGameTimer()
    local spin = (t / 225.0) % 360.0
    local counterSpin = (t / 310.0) % 360.0
    local pulse = 0.055 * math.sin(t / 115.0)
    local width = tonumber(Config.PortalWidth or 1.70) or 1.70
    local height = tonumber(Config.PortalHeight or 2.85) or 2.85
    local thickness = tonumber(Config.PortalThickness or 0.09) or 0.09
    local right = HeadingToRight(heading)
    local fwd = HeadingToForward(heading)

    DrawLightWithRange(c.x, c.y, c.z, color.r, color.g, color.b, Config.PortalLightRange or 10.0, Config.PortalLightIntensity or 5.0)

    -- Transparent doorway core. The dotted geometry below makes the portal read as a vertical
    -- oval even on older FiveM clients where marker rotation can be inconsistent.
    DrawMarker(
        Config.PortalMarkerType,
        c.x, c.y, c.z,
        0.0, 0.0, 0.0,
        90.0, 0.0, heading,
        width + pulse, thickness, height + pulse,
        0, 255, 90, 105,
        false, true, 2, false, nil, nil, false
    )

    DrawMarker(
        Config.PortalMarkerType,
        c.x + fwd.x * 0.030, c.y + fwd.y * 0.030, c.z,
        0.0, 0.0, 0.0,
        90.0, 0.0, heading - counterSpin,
        width * 0.76, thickness, height * 0.76,
        165, 255, 80, 92,
        false, true, 2, false, nil, nil, false
    )

    DrawMarker(
        Config.PortalMarkerType,
        c.x - fwd.x * 0.030, c.y - fwd.y * 0.030, c.z,
        0.0, 0.0, 0.0,
        90.0, 0.0, heading + spin,
        width * 0.50, thickness, height * 0.50,
        40, 255, 130, 80,
        false, true, 2, false, nil, nil, false
    )

    -- Ragged glowing outer oval.
    local points = Config.PortalRingPoints or 48
    for layer = 1, 3 do
        local layerScale = 1.0 + (layer - 2) * 0.055
        local layerAlpha = layer == 2 and 235 or 150
        for i = 1, points do
            local ang = ((i / points) * math.pi * 2.0) + math.rad(spin * (layer == 1 and 1.0 or -0.55))
            local noise = 1.0 + (0.060 * math.sin((t / 95.0) + (i * 1.7) + layer))
            local rx = math.cos(ang) * (width * 0.56) * layerScale * noise
            local rz = math.sin(ang) * (height * 0.54) * layerScale * noise
            local wobble = 0.060 * math.sin((t / 85.0) + (i * 0.9) + layer)
            local px = c.x + right.x * rx + fwd.x * wobble
            local py = c.y + right.y * rx + fwd.y * wobble
            local pz = c.z + rz
            local scale = (layer == 2 and 0.128 or 0.083) + pulse
            DrawPortalRingPoint(px, py, pz, scale, layerAlpha, { r = 105 + (layer * 35), g = 255, b = 65 })
        end
    end

    -- Bright lime inner spiral arms.
    local arms = Config.PortalSwirlArms or 4
    local steps = Config.PortalSwirlSteps or 28
    for arm = 1, arms do
        local armOffset = ((arm - 1) / arms) * math.pi * 2.0
        for step = 1, steps do
            local r = step / steps
            local ang = armOffset + math.rad(spin * 1.85) + (r * math.pi * 2.35)
            local rx = math.cos(ang) * (width * 0.45) * r
            local rz = math.sin(ang) * (height * 0.42) * r
            local depth = 0.075 * math.sin((t / 130.0) + step + arm)
            local px = c.x + right.x * rx + fwd.x * depth
            local py = c.y + right.y * rx + fwd.y * depth
            local pz = c.z + rz
            local alpha = 185 - math.floor(r * 65)
            local scale = 0.035 + (0.050 * (1.0 - r))
            DrawPortalRingPoint(px, py, pz, scale, alpha, { r = 190, g = 255, b = 75 })
        end
    end

    -- Edge sparks/orbs that jitter around the rim for the messy animated portal look.
    local sparks = Config.PortalEdgeSparks or 18
    for i = 1, sparks do
        local seed = i * 13.37
        local ang = (seed + (t / (180.0 + i * 4.0))) % (math.pi * 2.0)
        local jump = 1.0 + 0.14 * math.sin((t / 70.0) + i)
        local rx = math.cos(ang) * (width * 0.62) * jump
        local rz = math.sin(ang) * (height * 0.58) * jump
        local forwardJitter = 0.12 * math.sin((t / 55.0) + i)
        local px = c.x + right.x * rx + fwd.x * forwardJitter
        local py = c.y + right.y * rx + fwd.y * forwardJitter
        local pz = c.z + rz
        DrawPortalRingPoint(px, py, pz, 0.045 + (0.020 * math.sin((t / 80.0) + i)), 185, { r = 210, g = 255, b = 90 })
    end

    -- Small green floor glow to help players see where to walk through.
    if Config.ShowDestinationBeam then
        DrawMarker(
            1,
            c.x, c.y, c.z - ((Config.PortalCenterZOffset or 1.05) + 0.06),
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            width * 0.95, width * 0.95, 0.10,
            0, 255, 80, 72,
            false, true, 2, false, nil, nil, false
        )
    end
end


local function IsPlayerInsidePortal(playerCoords, drawCoords, heading)
    if not playerCoords or not drawCoords then return false end

    local width = tonumber(Config.PortalWidth or 1.70) or 1.70
    local height = tonumber(Config.PortalHeight or 2.85) or 2.85
    local fwd = HeadingToForward(heading or 0.0)
    local right = HeadingToRight(heading or 0.0)
    local dx = playerCoords.x - drawCoords.x
    local dy = playerCoords.y - drawCoords.y
    local dz = playerCoords.z - drawCoords.z

    local forwardDistance = math.abs((dx * fwd.x) + (dy * fwd.y))
    local sideDistance = math.abs((dx * right.x) + (dy * right.y))
    local verticalDistance = math.abs(dz)

    return forwardDistance <= (Config.EnterDistance or 1.35)
        and sideDistance <= ((width * 0.56) + 0.35)
        and verticalDistance <= ((height * 0.56) + 0.55)
end

local function GetPortalEndpoints(portal)
    if portal and portal.endpoints then return portal.endpoints end
    if portal and portal.coords then
        return {
            a = {
                side = 'a',
                label = portal.destLabel or 'Portal',
                coords = portal.coords,
                teleport = portal.coords,
                heading = portal.heading or 0.0,
                resolveGround = false
            }
        }
    end
    return {}
end

CreateThread(function()
    while true do
        local sleep = 750
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        local playerCoords = { x = pcoords.x, y = pcoords.y, z = pcoords.z }
        local now = GetGameTimer()
        local drawDistance = Config.PortalDrawDistance or 120.0

        for id, portal in pairs(activePortals) do
            local endpoints = GetPortalEndpoints(portal)
            for side, endpoint in pairs(endpoints) do
                if endpoint and endpoint.coords then
                    local rawDist = Vec2Distance(playerCoords, endpoint.coords)
                    local drawCoords = nil

                    if rawDist < drawDistance then
                        drawCoords = ResolvePortalEndpointForDisplay(id, side, endpoint, playerCoords)
                    end

                    if drawCoords then
                        local dist = Vec3Distance(playerCoords, drawCoords)
                        if dist < drawDistance then
                            sleep = 0
                            DrawPortal(portal, endpoint, drawCoords)
                        end

                        if IsPlayerInsidePortal(playerCoords, drawCoords, drawCoords.heading or endpoint.heading or portal.heading or 0.0) and now > lastPortalEnter then
                            lastPortalEnter = now + (Config.TeleportCooldown * 1000)
                            TriggerServerEvent('dpn-pg7x:server:enterPortal', id, side, {
                                x = drawCoords.x,
                                y = drawCoords.y,
                                z = drawCoords.z
                            })
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    DeleteGunProp()
    ReleaseNuiFocus(true)
end)
