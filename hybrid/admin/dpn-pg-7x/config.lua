Config = {}

-- ================================================================
-- DPN PG-7X Portal Gun Configuration
-- ================================================================

-- Only players with this ACE permission can equip/create portals/save destinations.
-- server.cfg example: add_ace group.admin dpn.pg7x.use allow
Config.AcePermission = 'dpn.pg7x.use'

-- Optional hard-coded admin identifiers. Leave empty if you only want ACE.
-- Examples:
-- 'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
-- 'discord:123456789012345678'
Config.AdminIdentifiers = {}

-- Optional QBCore support. If qb-core is running, this creates a usable admin-only item.
Config.EnableQBCoreItem = false
Config.ItemName = 'dpn_pg_7x'

-- Commands
Config.ToggleCommand = 'pg7x'
Config.DestinationCommand = 'pgdest'
Config.CloseCommand = 'pgclose'
Config.UICommand = 'pgui'
Config.UIKey = 'F7' -- can be rebound by each player in FiveM keybind settings
Config.UIResetKey = 'F8' -- emergency keybind to release stuck NUI focus
Config.PostalCommand = 'pgpostal'

-- Portal behavior
Config.PortalDuration = 120              -- seconds before a portal auto-closes
Config.MaxCreateDistance = 80.0          -- max raycast/portal creation distance
Config.EnterDistance = 1.35              -- forward distance required to walk into the portal plane
Config.CreateCooldown = 3                -- seconds between shots
Config.TeleportCooldown = 4              -- seconds between portal entries per player
Config.OnePortalPerAdmin = true          -- removes old portal when the same admin shoots a new one
Config.RequireAdminToEnterPortal = false -- true = only admins can walk through portals
Config.AllowVehicleTeleport = true

-- Visuals
Config.PortalColor = { r = 0, g = 255, b = 80, a = 185 }
Config.PortalOuterAlpha = 90
Config.PortalLightRange = 10.0
Config.PortalLightIntensity = 5.0
Config.PortalScale = 1.65
Config.PortalOuterScale = 2.05
Config.PortalMarkerType = 6              -- vertical circle/core marker; dotted oval ring guarantees vertical look on older clients
Config.ShowDestinationBeam = true

-- Rick-and-Morty-inspired vertical portal visuals, built only with GTA markers so no YDR/YTD is required.
Config.TwoWayPortals = true              -- one shot opens a paired portal at both ends until closed/expired
Config.PortalDrawDistance = 120.0
Config.PortalCenterZOffset = 1.05        -- raises the doorway center above the ground
Config.PortalExitForwardOffset = 1.15    -- pushes the return landing point slightly in front of the portal
Config.PortalWidth = 1.70
Config.PortalHeight = 2.85
Config.PortalThickness = 0.09
Config.PortalRingPoints = 48
Config.PortalSwirlArms = 4
Config.PortalSwirlSteps = 28
Config.PortalEdgeSparks = 18

-- Controls. See FiveM control IDs.
-- E = 38, G = 47, BACKSPACE = 177
Config.Controls = {
    FirePortal = 38,
    ClosePortal = 47,
    ExitMode = 177
}

-- Attached handheld prop while PG-7X mode is enabled.
-- This uses an existing GTA model so no custom YDR is required.
Config.GunProp = 'w_pi_stungun'
Config.GunAttach = {
    bone = 57005, -- right hand
    x = 0.15, y = 0.02, z = -0.02,
    rx = -90.0, ry = 0.0, rz = 0.0
}

-- Nearest Postal integration
Config.Postal = {
    Enabled = true,

    -- Main supported resource. DevBlocky/BlockBa5her usually uses this name.
    PrimaryResource = 'nearest-postal',

    -- Other possible names if your server renamed the postal script.
    AutoDetectResources = {
        'nearest-postal',
        'nearest_postal',
        'nearestpostal',
        'postals',
        'postal',
        'mnr_postals',
        'dex_postal'
    },

    -- The resource is checked for fxmanifest metadata postal_file first.
    -- These are fallbacks for resources that do not expose postal_file metadata.
    PostalFiles = {
        'new-postals.json',
        'ocrp-postals.json',
        'old-postals.json',
        'postals.json',
        'postal.json',
        'data/postals.json',
        'config/postals.json'
    },

    -- Client exports used to read the player's current nearest postal when available.
    -- DevBlocky nearest-postal releases commonly use getPostal(). Older community edits may use npostal().
    CurrentPostalExports = { 'getPostal', 'npostal' },

    DestinationZOffset = 1.0,
    DefaultHeading = 0.0,
    AllowTemporaryPostalDestinations = true,
    AllowSavingPostalDestinations = true,
    Debug = false
}

-- Safety options
Config.BlockPortalInsideVehicleIfPassenger = true -- passengers cannot fire portals from vehicles
Config.MinimumDestinationZOffset = 0.65
Config.SaveFile = 'destinations.json'

-- Teleport safety. This fixes postal destinations that only have X/Y and no real road/ground Z.
Config.Teleport = {
    ResolveGroundWhenBelowZ = 10.0, -- any destination below this Z gets client-side ground detection
    GroundOffset = 0.95,            -- places player slightly above the detected ground
    FallbackZ = 75.0,               -- used only if the client cannot find ground after loading collision
    CollisionTimeoutMs = 8500,
    UseClosestVehicleNode = true,    -- postal teleports land on nearest safe road node when possible
    GroundProbeHeights = { 1200.0, 1000.0, 850.0, 700.0, 550.0, 400.0, 300.0, 200.0, 150.0, 100.0, 75.0, 50.0, 30.0 },

    -- When a postal endpoint is client-resolved to the nearest road/ground, the server also
    -- accepts a client-reported portal display point near the raw postal X/Y. This fixes
    -- return-side portal entries when the road node is offset from the postal coordinate.
    ResolveEndpointServerTolerance = 95.0
}

-- UI options
Config.UI = {
    ShowCommandHelp = true,
    MaxDestinationRows = 100,
    MaxPostalSearchResults = 20
}

-- Chat prefix
Config.Prefix = '^2[DPN PG-7X]^7 '
