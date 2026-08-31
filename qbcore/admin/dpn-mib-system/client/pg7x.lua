local QBCore = exports['qb-core']:GetCoreObject()
local portals = {}
local portalId = 0

local function notify(msg, typ)
    if QBCore and QBCore.Functions then QBCore.Functions.Notify(msg, typ or 'primary') end
end

local function drawPortal(p)
    local c = Config.PG7X.Color
    DrawMarker(1, p.coords.x, p.coords.y, p.coords.z - 1.0, 0,0,0, 0,0,0, 2.2,2.2,2.8, c.r,c.g,c.b,c.a, false, true, 2, false, nil, nil, false)
    DrawMarker(6, p.coords.x, p.coords.y, p.coords.z + 0.25, 0,0,0, 90.0,0,0, 2.0,2.0,2.0, c.r,c.g,c.b,220, false, true, 2, false, nil, nil, false)
end

local function createPortalPair(dest)
    local ped = PlayerPedId()
    local a = GetEntityCoords(ped) + (GetEntityForwardVector(ped) * 2.8)
    local b = vector3(dest.x, dest.y, dest.z)
    portalId = portalId + 1
    portals[portalId] = { a = { coords = a, heading = GetEntityHeading(ped) }, b = { coords = b, heading = dest.w or 0.0 }, expires = GetGameTimer() + ((Config.PG7X.PortalDuration or 300) * 1000) }
    notify('PG7X portal opened. Two-way bridge active.', 'success')
end

CreateThread(function()
    while true do
        local sleep = 750
        local ped = PlayerPedId()
        local pc = GetEntityCoords(ped)
        for id, pair in pairs(portals) do
            if GetGameTimer() > pair.expires then portals[id] = nil goto continue end
            sleep = 0
            drawPortal(pair.a); drawPortal(pair.b)
            if #(pc - pair.a.coords) < 1.65 then
                DoScreenFadeOut(150); Wait(200)
                SetEntityCoordsNoOffset(ped, pair.b.coords.x, pair.b.coords.y, pair.b.coords.z + 0.4, false, false, false)
                SetEntityHeading(ped, pair.b.heading or 0.0)
                Wait(350); DoScreenFadeIn(250)
            elseif Config.PG7X.TwoWay and #(pc - pair.b.coords) < 1.65 then
                DoScreenFadeOut(150); Wait(200)
                SetEntityCoordsNoOffset(ped, pair.a.coords.x, pair.a.coords.y, pair.a.coords.z + 0.4, false, false, false)
                SetEntityHeading(ped, pair.a.heading or 0.0)
                Wait(350); DoScreenFadeIn(250)
            end
            ::continue::
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('dpn-mib:client:pg7xDestination', function(index)
    local dest = Config.PG7X.Destinations[tonumber(index or 1)]
    if dest then createPortalPair(dest.coords) else notify('Invalid PG7X destination.', 'error') end
end)

RegisterNetEvent('dpn-mib:client:pg7xAimPortal', function()
    local hit, coords = RaycastFromCamera(Config.PG7X.MaxDistance or 350.0)
    if hit then createPortalPair(vector4(coords.x, coords.y, coords.z, GetEntityHeading(PlayerPedId()))) else notify('PG7X failed to find a safe portal surface.', 'error') end
end)

RegisterCommand(Config.PG7X.Command or 'pg7x', function(_, args)
    TriggerServerEvent('dpn-mib:server:devAction', 'pg7x_destination', nil, { index = tonumber(args[1] or 1), reason = 'PG7X command' })
end, false)

function RaycastFromCamera(distance)
    local camRot = GetGameplayCamRot(2)
    local camCoord = GetGameplayCamCoord()
    local function rotToDir(rot)
        local z = math.rad(rot.z); local x = math.rad(rot.x); local num = math.abs(math.cos(x))
        return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
    end
    local dir = rotToDir(camRot)
    local dest = camCoord + (dir * distance)
    local ray = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords = GetShapeTestResult(ray)
    return hit == 1, endCoords
end
