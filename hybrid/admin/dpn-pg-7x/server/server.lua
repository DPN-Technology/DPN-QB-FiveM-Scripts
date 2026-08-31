local ResourceName = GetCurrentResourceName()
local Destinations = {}
local ActivePortals = {}
local Cooldowns = {}
local TeleportCooldowns = {}
local PostalIndex = {}
local PostalStatus = { ready = false, count = 0, resource = nil, file = nil }
local QBCore = nil

math.randomseed(os.time())

local function Print(msg)
    print(('^2[%s]^7 %s'):format(ResourceName, msg))
end

local function Debug(msg)
    if Config.Postal and Config.Postal.Debug then
        Print(('POSTAL DEBUG: %s'):format(msg))
    end
end

local function SafeDecode(data)
    if not data or data == '' then return {} end
    local ok, decoded = pcall(json.decode, data)
    if ok and type(decoded) == 'table' then return decoded end
    return {}
end

local function CountTable(t)
    local c = 0
    for _ in pairs(t or {}) do c = c + 1 end
    return c
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

local function IsValidCoord(c)
    return type(c) == 'table'
        and type(c.x) == 'number'
        and type(c.y) == 'number'
        and type(c.z) == 'number'
        and c.x == c.x and c.y == c.y and c.z == c.z
end

local function FormatNumber(n)
    return tonumber(('%0.3f'):format(tonumber(n) or 0.0))
end

local function CompactCoord(c)
    return {
        x = FormatNumber(c.x),
        y = FormatNumber(c.y),
        z = FormatNumber(c.z)
    }
end

local function LoadDestinations()
    local raw = LoadResourceFile(ResourceName, Config.SaveFile)
    Destinations = SafeDecode(raw)
    Print(('Loaded %d saved destination(s).'):format(CountTable(Destinations)))
end

local function SaveDestinations()
    SaveResourceFile(ResourceName, Config.SaveFile, json.encode(Destinations), -1)
end

local function IsAdmin(src)
    if src == 0 then return true end

    if IsPlayerAceAllowed(src, Config.AcePermission) then
        return true
    end

    local ids = GetPlayerIdentifiers(src)
    for _, id in ipairs(ids) do
        for _, allowed in ipairs(Config.AdminIdentifiers or {}) do
            if id == allowed then return true end
        end
    end

    if Config.EnableQBCoreItem and GetResourceState('qb-core') == 'started' then
        if not QBCore then
            local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
            if ok then QBCore = obj end
        end

        if QBCore and QBCore.Functions and QBCore.Functions.HasPermission then
            local ok, hasPerm = pcall(function()
                return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
            end)
            if ok and hasPerm then return true end
        end
    end

    return false
end

local function Notify(src, msg, msgType)
    TriggerClientEvent('dpn-pg7x:client:notify', src, msg, msgType or 'primary')
end

local function SyncDestinations(src)
    TriggerClientEvent('dpn-pg7x:client:syncDestinations', src, Destinations)
end

local function SyncDestinationsToAdmins()
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        if target and IsAdmin(target) then
            SyncDestinations(target)
        end
    end
end

local function SyncPostalStatus(src)
    TriggerClientEvent('dpn-pg7x:client:postalStatus', src, PostalStatus)
end

local function SyncPostalStatusToAdmins()
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        if target and IsAdmin(target) then
            SyncPostalStatus(target)
        end
    end
end

local function RemovePortal(portalId, reason)
    if not ActivePortals[portalId] then return end
    ActivePortals[portalId] = nil
    TriggerClientEvent('dpn-pg7x:client:removePortal', -1, portalId, reason or 'closed')
end

local function RemoveOwnerPortals(src)
    for id, portal in pairs(ActivePortals) do
        if portal.owner == src then
            RemovePortal(id, 'replaced')
        end
    end
end

local function PlayerNearCoord(src, c, maxDist)
    if not IsValidCoord(c) then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return false end
    local pcoords = GetEntityCoords(ped)
    local dx, dy, dz = pcoords.x - c.x, pcoords.y - c.y, pcoords.z - c.z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    return dist <= maxDist
end

local function PlayerNearPortalEndpoint(src, endpoint, maxDist, clientDisplayCoords)
    if not endpoint or not IsValidCoord(endpoint.coords) then return false end

    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return false end

    local pcoords = GetEntityCoords(ped)
    local c = endpoint.coords
    local dx, dy, dz = pcoords.x - c.x, pcoords.y - c.y, pcoords.z - c.z
    local resolveBelow = ((Config.Teleport and Config.Teleport.ResolveGroundWhenBelowZ) or 10.0)
    local isResolvedEndpoint = endpoint.resolveGround == true or (tonumber(c.z) or 0.0) <= resolveBelow

    -- Postal/auto-ground endpoints usually have raw server Z = 0.0 and can be shifted client-side
    -- to the nearest road node. If the client reports the visible portal center, accept it only
    -- when that center is still near the raw postal/destination XY, then validate the player
    -- against the visible center. This fixes the return portal rejecting valid entries.
    if isResolvedEndpoint then
        local tolerance = ((Config.Teleport and Config.Teleport.ResolveEndpointServerTolerance) or 95.0)

        if IsValidCoord(clientDisplayCoords) then
            local cdx = (tonumber(clientDisplayCoords.x) or 0.0) - c.x
            local cdy = (tonumber(clientDisplayCoords.y) or 0.0) - c.y
            local clientFromRaw = math.sqrt(cdx * cdx + cdy * cdy)

            if clientFromRaw <= tolerance then
                local pdx = pcoords.x - (tonumber(clientDisplayCoords.x) or 0.0)
                local pdy = pcoords.y - (tonumber(clientDisplayCoords.y) or 0.0)
                local pdz = pcoords.z - (tonumber(clientDisplayCoords.z) or pcoords.z)
                local playerFromVisible = math.sqrt(pdx * pdx + pdy * pdy + pdz * pdz)
                local playerFlatFromVisible = math.sqrt(pdx * pdx + pdy * pdy)

                if playerFromVisible <= (maxDist + 3.0) or playerFlatFromVisible <= (maxDist + 2.0) then
                    return true
                end
            end
        end

        -- Fallback for old clients that do not send the visible center. Wider than the normal
        -- hitbox, but still locked to the raw postal/destination area.
        local flatDist = math.sqrt(dx * dx + dy * dy)
        return flatDist <= math.max(maxDist, math.min(tolerance, 25.0))
    end

    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    return dist <= maxDist
end

local function GetObjectValue(obj, keys)
    for _, key in ipairs(keys) do
        if obj[key] ~= nil then return obj[key] end
    end
    return nil
end

local function PostalFromEntry(key, entry)
    if type(entry) ~= 'table' then return nil end

    local code = NormalizePostal(GetObjectValue(entry, { 'code', 'postal', 'id', 'name', 'label' }) or key)
    if not code then return nil end

    local x = tonumber(entry.x or entry.X)
    local y = tonumber(entry.y or entry.Y)
    local z = tonumber(entry.z or entry.Z or 0.0)

    if entry.coords and type(entry.coords) == 'table' then
        x = tonumber(entry.coords.x or entry.coords.X or x)
        y = tonumber(entry.coords.y or entry.coords.Y or y)
        z = tonumber(entry.coords.z or entry.coords.Z or z or 0.0)
    end

    if entry.location and type(entry.location) == 'table' then
        x = tonumber(entry.location.x or entry.location.X or x)
        y = tonumber(entry.location.y or entry.location.Y or y)
        z = tonumber(entry.location.z or entry.location.Z or z or 0.0)
    end

    if not x or not y then return nil end

    return {
        code = code,
        label = ('Postal %s'):format(code),
        coords = { x = x, y = y, z = z or 0.0 },
        heading = tonumber(entry.heading or entry.h or Config.Postal.DefaultHeading or 0.0) or 0.0
    }
end

local function IndexPostalData(data)
    local count = 0
    PostalIndex = {}

    if type(data) ~= 'table' then return 0 end

    for key, entry in pairs(data) do
        local postal = PostalFromEntry(key, entry)
        if postal then
            PostalIndex[postal.code] = postal
            count = count + 1
        end
    end

    return count
end

local function CandidatePostalResources()
    local list = {}
    local seen = {}
    local function add(name)
        if name and name ~= '' and not seen[name] then
            seen[name] = true
            list[#list + 1] = name
        end
    end

    if Config.Postal then
        add(Config.Postal.PrimaryResource)
        for _, name in ipairs(Config.Postal.AutoDetectResources or {}) do add(name) end
    end

    return list
end

local function CandidatePostalFiles(resource)
    local list = {}
    local seen = {}
    local function add(file)
        if file and file ~= '' and not seen[file] then
            seen[file] = true
            list[#list + 1] = file
        end
    end

    local metadataFile = GetResourceMetadata(resource, 'postal_file', 0)
    add(metadataFile)

    for _, file in ipairs((Config.Postal and Config.Postal.PostalFiles) or {}) do add(file) end

    return list
end

local function LoadPostalData()
    PostalIndex = {}
    PostalStatus = { ready = false, count = 0, resource = nil, file = nil }

    if not Config.Postal or not Config.Postal.Enabled then
        Print('Postal integration disabled in config.')
        return
    end

    for _, resource in ipairs(CandidatePostalResources()) do
        local state = GetResourceState(resource)
        if state == 'started' or state == 'starting' then
            for _, file in ipairs(CandidatePostalFiles(resource)) do
                local raw = LoadResourceFile(resource, file)
                if raw and raw ~= '' then
                    local data = SafeDecode(raw)
                    local count = IndexPostalData(data)
                    if count > 0 then
                        PostalStatus = { ready = true, count = count, resource = resource, file = file }
                        Print(('Loaded %d postal destination(s) from %s/%s.'):format(count, resource, file))
                        SyncPostalStatusToAdmins()
                        return
                    end
                    Debug(('File found but no supported postal entries parsed: %s/%s'):format(resource, file))
                end
            end
        else
            Debug(('Postal resource not started: %s (%s)'):format(resource, state or 'unknown'))
        end
    end

    Print('Postal integration could not find a started postal resource or readable postal JSON. Saved destinations still work.')
    SyncPostalStatusToAdmins()
end

local function ResolvePostal(code)
    code = NormalizePostal(code)
    if not code then return nil end
    return PostalIndex[code]
end

local function ResolveDestination(destKey)
    if not destKey then return nil, nil end
    destKey = tostring(destKey)

    if destKey:sub(1, 7) == 'postal:' then
        if not Config.Postal.AllowTemporaryPostalDestinations then return nil, nil end
        local code = NormalizePostal(destKey:sub(8))
        local postal = ResolvePostal(code)
        if not postal then return nil, nil end
        return {
            label = postal.label,
            coords = CompactCoord(postal.coords),
            heading = postal.heading or Config.Postal.DefaultHeading or 0.0,
            postal = postal.code,
            type = 'postal',
            resolveGround = true
        }, ('postal:%s'):format(postal.code)
    end

    local key = NormalizeKey(destKey)
    if not key or not Destinations[key] then return nil, nil end
    return Destinations[key], key
end

local function AddPortalCenterOffset(c)
    local centerOffset = tonumber(Config.PortalCenterZOffset or 1.05) or 1.05
    return {
        x = FormatNumber(c.x),
        y = FormatNumber(c.y),
        z = FormatNumber((tonumber(c.z) or 0.0) + centerOffset)
    }
end

local function BuildEndpoint(side, label, displayCoords, teleportCoords, normal, heading, resolveGround, kind)
    return {
        side = side,
        label = label or side,
        kind = kind or 'portal',
        coords = CompactCoord(displayCoords),
        teleport = CompactCoord(teleportCoords or displayCoords),
        normal = IsValidCoord(normal) and CompactCoord(normal) or { x = 0.0, y = 0.0, z = 1.0 },
        heading = FormatNumber(heading or 0.0),
        resolveGround = resolveGround == true
    }
end

local function PortalPayload(src, portalId, destKey, dest, portalCoords, portalTeleportCoords, surfaceNormal, portalHeading, now)
    local destCoords = dest.coords
    local destResolveGround = dest.resolveGround == true or dest.type == 'postal' or (destCoords and (tonumber(destCoords.z) or 0.0) <= ((Config.Teleport and Config.Teleport.ResolveGroundWhenBelowZ) or 10.0))

    local entryEndpoint = BuildEndpoint(
        'a',
        'Entry Portal',
        portalCoords,
        portalTeleportCoords or portalCoords,
        surfaceNormal,
        portalHeading,
        false,
        'entry'
    )

    local exitDisplayCoords = destResolveGround and CompactCoord(destCoords) or AddPortalCenterOffset(destCoords)
    local exitEndpoint = BuildEndpoint(
        'b',
        dest.label or destKey or 'Destination Portal',
        exitDisplayCoords,
        destCoords,
        { x = 0.0, y = 0.0, z = 1.0 },
        dest.heading or 0.0,
        destResolveGround,
        dest.type or 'destination'
    )

    entryEndpoint.linkedSide = 'b'
    entryEndpoint.exactZ = true
    exitEndpoint.linkedSide = 'a'

    return {
        id = portalId,
        owner = src,
        ownerName = GetPlayerName(src) or ('ID ' .. src),
        destKey = destKey,
        destLabel = dest.label or destKey,
        dest = dest,
        coords = entryEndpoint.coords, -- compatibility with older client builds
        normal = entryEndpoint.normal,
        heading = entryEndpoint.heading,
        twoWay = true,
        endpoints = {
            a = entryEndpoint,
            b = exitEndpoint
        },
        createdAt = now,
        expiresAt = now + Config.PortalDuration
    }
end

CreateThread(function()
    Wait(500)
    LoadDestinations()
    LoadPostalData()

    if Config.EnableQBCoreItem then
        Wait(1000)
        if GetResourceState('qb-core') == 'started' then
            local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
            if ok and obj then
                QBCore = obj
                QBCore.Functions.CreateUseableItem(Config.ItemName, function(src)
                    if not IsAdmin(src) then
                        Notify(src, 'Access denied. PG-7X is admin-only.', 'error')
                        return
                    end
                    TriggerClientEvent('dpn-pg7x:client:toggleMode', src)
                    SyncDestinations(src)
                    SyncPostalStatus(src)
                end)
                Print(('Registered QBCore usable item: %s'):format(Config.ItemName))
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for id, portal in pairs(ActivePortals) do
            if portal.expiresAt and portal.expiresAt <= now then
                RemovePortal(id, 'expired')
            end
        end
    end
end)

RegisterNetEvent('dpn-pg7x:server:requestAuth', function()
    local src = source
    local admin = IsAdmin(src)
    TriggerClientEvent('dpn-pg7x:client:setAuth', src, admin)
    if admin then
        SyncDestinations(src)
        SyncPostalStatus(src)
    end
    TriggerClientEvent('dpn-pg7x:client:syncPortals', src, ActivePortals)
end)

RegisterNetEvent('dpn-pg7x:server:toggleRequest', function()
    local src = source
    if not IsAdmin(src) then
        Notify(src, 'Access denied. PG-7X is admin-only.', 'error')
        return
    end
    TriggerClientEvent('dpn-pg7x:client:toggleMode', src)
    SyncDestinations(src)
    SyncPostalStatus(src)
end)

RegisterNetEvent('dpn-pg7x:server:openUiRequest', function()
    local src = source
    if not IsAdmin(src) then
        Notify(src, 'Access denied. PG-7X UI is admin-only.', 'error')
        return
    end
    TriggerClientEvent('dpn-pg7x:client:openUiAuthorized', src, Destinations, PostalStatus)
    TriggerClientEvent('dpn-pg7x:client:syncPortals', src, ActivePortals)
end)

RegisterNetEvent('dpn-pg7x:server:saveDestination', function(name, coords, heading)
    local src = source
    if not IsAdmin(src) then
        Notify(src, 'Access denied. Only admins can save portal destinations.', 'error')
        return
    end

    local key = NormalizeKey(name)
    if not key then
        Notify(src, 'Usage: /' .. Config.DestinationCommand .. ' save destination_name', 'error')
        return
    end

    if not IsValidCoord(coords) then
        Notify(src, 'Invalid coordinates. Destination was not saved.', 'error')
        return
    end

    Destinations[key] = {
        label = tostring(name),
        coords = CompactCoord(coords),
        heading = FormatNumber(heading or 0.0),
        type = 'saved',
        createdBy = GetPlayerName(src) or ('ID ' .. src),
        updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    SaveDestinations()
    Notify(src, ('Destination saved: %s'):format(key), 'success')
    SyncDestinationsToAdmins()
end)

RegisterNetEvent('dpn-pg7x:server:savePostalDestination', function(name, code)
    local src = source
    if not IsAdmin(src) then
        Notify(src, 'Access denied. Only admins can save postal destinations.', 'error')
        return
    end

    if not Config.Postal.AllowSavingPostalDestinations then
        Notify(src, 'Saving postal destinations is disabled in config.', 'error')
        return
    end

    local postal = ResolvePostal(code)
    if not postal then
        Notify(src, ('Postal not found: %s'):format(tostring(code or 'nil')), 'error')
        return
    end

    local label = tostring(name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if label == '' then label = ('Postal %s'):format(postal.code) end
    local key = NormalizeKey(label)
    if not key then key = NormalizeKey('postal_' .. postal.code) end

    Destinations[key] = {
        label = label,
        coords = CompactCoord(postal.coords),
        heading = FormatNumber(postal.heading or Config.Postal.DefaultHeading or 0.0),
        type = 'postal',
        postal = postal.code,
        resolveGround = true,
        createdBy = GetPlayerName(src) or ('ID ' .. src),
        updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    SaveDestinations()
    Notify(src, ('Postal destination saved: %s -> %s'):format(key, postal.code), 'success')
    SyncDestinationsToAdmins()
end)

RegisterNetEvent('dpn-pg7x:server:deleteDestination', function(name)
    local src = source
    if not IsAdmin(src) then
        Notify(src, 'Access denied. Only admins can delete portal destinations.', 'error')
        return
    end

    local key = NormalizeKey(name)
    if not key or not Destinations[key] then
        Notify(src, 'Destination not found.', 'error')
        return
    end

    Destinations[key] = nil
    SaveDestinations()
    Notify(src, ('Destination deleted: %s'):format(key), 'success')
    SyncDestinationsToAdmins()
end)

RegisterNetEvent('dpn-pg7x:server:requestDestinations', function()
    local src = source
    if not IsAdmin(src) then
        Notify(src, 'Access denied.', 'error')
        return
    end
    SyncDestinations(src)
    SyncPostalStatus(src)
end)

RegisterNetEvent('dpn-pg7x:server:lookupPostal', function(code)
    local src = source
    if not IsAdmin(src) then
        Notify(src, 'Access denied.', 'error')
        return
    end

    local postal = ResolvePostal(code)
    if not postal then
        Notify(src, ('Postal not found: %s'):format(tostring(code or 'nil')), 'error')
        TriggerClientEvent('dpn-pg7x:client:postalSelected', src, nil)
        return
    end

    TriggerClientEvent('dpn-pg7x:client:postalSelected', src, {
        key = ('postal:%s'):format(postal.code),
        label = postal.label,
        postal = postal.code,
        coords = CompactCoord(postal.coords),
        heading = postal.heading or Config.Postal.DefaultHeading or 0.0,
        resolveGround = true
    })
end)

RegisterNetEvent('dpn-pg7x:server:searchPostals', function(query)
    local src = source
    if not IsAdmin(src) then return end

    local q = NormalizePostal(query)
    local results = {}
    if q then
        for code, postal in pairs(PostalIndex) do
            if code:find(q, 1, true) then
                results[#results + 1] = {
                    code = code,
                    label = postal.label,
                    coords = CompactCoord(postal.coords)
                }
                if #results >= ((Config.UI and Config.UI.MaxPostalSearchResults) or 20) then break end
            end
        end
    end

    table.sort(results, function(a, b) return tostring(a.code) < tostring(b.code) end)
    TriggerClientEvent('dpn-pg7x:client:postalSearchResults', src, results)
end)

RegisterNetEvent('dpn-pg7x:server:createPortal', function(destKey, portalCoords, surfaceNormal, portalHeading, portalTeleportCoords)
    local src = source
    if not IsAdmin(src) then
        Notify(src, 'Access denied. PG-7X is admin-only.', 'error')
        return
    end

    local now = os.time()
    if Cooldowns[src] and Cooldowns[src] > now then
        Notify(src, ('PG-7X charging. Wait %ss.'):format(Cooldowns[src] - now), 'error')
        return
    end

    local dest, resolvedKey = ResolveDestination(destKey)
    if not dest then
        Notify(src, 'No valid destination selected. Pick a saved destination or postal in the PG-7X UI.', 'error')
        return
    end

    if not IsValidCoord(portalCoords) then
        Notify(src, 'Invalid portal coordinates.', 'error')
        return
    end

    if not PlayerNearCoord(src, portalCoords, Config.MaxCreateDistance + 8.0) then
        Notify(src, 'Portal target is too far away.', 'error')
        return
    end

    if Config.OnePortalPerAdmin then
        RemoveOwnerPortals(src)
    end

    Cooldowns[src] = now + Config.CreateCooldown
    local portalId = ('pg7x_%s_%s_%s'):format(src, now, math.random(1000, 9999))
    ActivePortals[portalId] = PortalPayload(src, portalId, resolvedKey, dest, portalCoords, portalTeleportCoords, surfaceNormal, portalHeading, now)

    TriggerClientEvent('dpn-pg7x:client:addPortal', -1, ActivePortals[portalId])
    Notify(src, ('Portal opened to %s.'):format(dest.label or resolvedKey), 'success')
end)

RegisterNetEvent('dpn-pg7x:server:enterPortal', function(portalId, side, clientDisplayCoords)
    local src = source
    local portal = ActivePortals[portalId]
    if not portal then return end

    local now = os.time()
    if portal.expiresAt and portal.expiresAt <= now then
        RemovePortal(portalId, 'expired')
        return
    end

    if Config.RequireAdminToEnterPortal and not IsAdmin(src) then
        Notify(src, 'This portal is restricted to admins.', 'error')
        return
    end

    if TeleportCooldowns[src] and TeleportCooldowns[src] > now then return end

    local endpoints = portal.endpoints or {}
    local fromSide = (side == 'b') and 'b' or 'a'
    local fromEndpoint = endpoints[fromSide]

    -- Backward compatibility for any old one-sided portal payload that may still be in memory.
    if not fromEndpoint and portal.coords then
        fromEndpoint = { side = 'a', coords = portal.coords, teleport = portal.coords, linkedSide = 'b' }
        endpoints.b = { side = 'b', coords = portal.dest and portal.dest.coords, teleport = portal.dest and portal.dest.coords, linkedSide = 'a', resolveGround = portal.dest and portal.dest.resolveGround == true }
    end

    if not fromEndpoint or not PlayerNearPortalEndpoint(src, fromEndpoint, Config.EnterDistance + 3.0, clientDisplayCoords) then
        return
    end

    local toSide = fromEndpoint.linkedSide or (fromSide == 'a' and 'b' or 'a')
    local toEndpoint = endpoints[toSide]
    if not toEndpoint or not IsValidCoord(toEndpoint.teleport or toEndpoint.coords) then return end

    TeleportCooldowns[src] = now + Config.TeleportCooldown

    local target = toEndpoint.teleport or toEndpoint.coords
    TriggerClientEvent('dpn-pg7x:client:teleport', src, {
        x = target.x,
        y = target.y,
        z = target.z,
        heading = toEndpoint.heading or 0.0,
        destLabel = toEndpoint.label or portal.destLabel or portal.destKey,
        resolveGround = toEndpoint.resolveGround == true or (target.z and target.z <= 10.0),
        fromSide = fromSide,
        toSide = toSide,
        portalId = portalId,
        exactZ = toEndpoint.exactZ == true
    })
end)

RegisterNetEvent('dpn-pg7x:server:closeMyPortals', function()
    local src = source
    if not IsAdmin(src) then return end
    RemoveOwnerPortals(src)
    Notify(src, 'Your active PG-7X portal(s) were closed.', 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    if Config.OnePortalPerAdmin then
        RemoveOwnerPortals(src)
    end
    Cooldowns[src] = nil
    TeleportCooldowns[src] = nil
end)

RegisterCommand('pg7xreload', function(src)
    if src ~= 0 and not IsAdmin(src) then return end
    LoadDestinations()
    LoadPostalData()
    if src == 0 then
        Print(('Reloaded %d destination(s), %d postal(s).'):format(CountTable(Destinations), PostalStatus.count or 0))
    else
        Notify(src, 'PG-7X destinations and postals reloaded.', 'success')
        SyncDestinations(src)
        SyncPostalStatus(src)
    end
end, false)

AddEventHandler('onResourceStart', function(resource)
    if resource == ResourceName then return end
    if not Config.Postal or not Config.Postal.Enabled then return end
    for _, name in ipairs(CandidatePostalResources()) do
        if resource == name then
            Wait(1500)
            LoadPostalData()
            return
        end
    end
end)
