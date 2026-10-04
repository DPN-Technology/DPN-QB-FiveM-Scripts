Config = {}

Config.Debug = false
Config.Framework = 'qbcore'
Config.MenuCommand = 'mib'
Config.MenuKey = 'F7'
Config.UseAdminPermission = true
Config.AdminPermission = 'admin'
Config.MIBJobName = 'mib'
Config.AllowedJobs = { mib = true, admin = true }
Config.RequireDuty = false
Config.AcePermissions = { 'dpn.mib', 'command.mib' }
Config.AdminAcePermissions = { 'dpn.mib.admin' }

-- Server-owned privilege policy. Client payloads never select a clearance tier.
-- mib = normal MIB access, director = server-side MIB director grade, admin = QBCore admin/god or explicit admin ACE.
Config.MIBActionPolicy = {
    wipe_scene='director', mass_wipe='director', revive='director', lockdown='director',
    goto_player='director', bring='director', spectate='director', threat='director',
    kick='admin', set_bucket='admin'
}
Config.NeuralizerPolicy = {
    alpha='mib', beta='mib', gamma='director', omega='director'
}
Config.AdvancedNeuralizerPolicy = {
    alpha='mib', beta='mib', gamma='director', omega='director', area='director'
}
Config.RoutingBucketBounds = { min = 0, max = 9999 }

Config.DepartmentColors = {
    mib = '#050505', admin = '#050505', law = '#0b3d91', ems = '#ff7a00', fire = '#d71920', justice = '#777777', corrections = '#7a4b24'
}

Config.DiscordWebhook = ''
Config.LogToDatabase = true
Config.RequireReasonForHighRisk = true
Config.HighRiskActions = {
    neuralizer=true, mass_wipe=true, wipe_scene=true, spectate=true, bring=true, goto_player=true,
    revive=true, freeze=true, kick=true, set_bucket=true, lockdown=true, cloak=false, scan=false
}

Config.Neuralizer = {
    Item = 'mib_neuralizer', Cooldown = 25, Range = 6.0, Cone = 42.0, BlackoutSeconds = 15,
    MemoryWipeMinutes = 10, NoDamage = true, FlashNearby = true, BodycamInterference = true,
    Classes = {
        alpha = { label='Class Alpha / Witness Calm', wipeMinutes=5, blackout=8, cooldown=20 },
        beta = { label='Class Beta / Standard Wipe', wipeMinutes=15, blackout=15, cooldown=30 },
        gamma = { label='Class Gamma / Incident Wipe', wipeMinutes=45, blackout=25, cooldown=60 },
        omega = { label='Class Omega / Blacksite Protocol', wipeMinutes=120, blackout=35, cooldown=120 }
    }
}

Config.SafeTeleport = { Enabled = true, ZOffset = 1.0, GroundProbeTries = 30, Fade = true }
Config.AgencyBlip = { Enabled = true, Coords = vector3(441.18,-981.92,30.69), Sprite = 487, Color = 0, Scale = 0.75, Label = 'MIB Blacksite' }
Config.BlacksiteLocations = {
    { label='MRPD Secure Intake', coords=vector4(441.18,-981.92,30.69,90.0), type='intake' },
    { label='Pillbox Trauma Liaison', coords=vector4(306.76,-595.05,43.28,70.0), type='medical' },
    { label='Sandy Federal Holding', coords=vector4(1852.43,3687.18,34.27,210.0), type='holding' },
    { label='Paleto Federal Holding', coords=vector4(-447.84,6013.85,31.72,45.0), type='holding' },
    { label='Zancudo Blacksite Gate', coords=vector4(-2344.91,3267.28,32.81,240.0), type='blacksite' },
    { label='Court Federal Liaison', coords=vector4(243.43,-1072.23,29.29,180.0), type='justice' }
}

Config.Tools = {
    cloak = { label='Field Cloak', duration=45, cooldown=90 },
    scan = { label='Identity Scanner', range=10.0, cooldown=8 },
    freeze = { label='Containment Freeze', range=10.0, duration=8, cooldown=20 },
    cuff = { label='Federal Restraints', range=2.5 },
    vehicle_scan = { label='Vehicle Deep Scan', range=10.0, cooldown=12 },
    emergency_ping = { label='Emergency Services Ping', cooldown=30 },
    wipe_scene = { label='Scene Memory Protocol', radius=22.0, cooldown=120 },
    spectate = { label='Remote Observation', cooldown=10 },
    entity_cleanup = { label='Anomaly Cleanup', radius=30.0, cooldown=30 },
    revive = { label='Medical Override', range=10.0, cooldown=30 },
    armor = { label='Suit Armor Protocol', amount=100, cooldown=45 },
    lockdown = { label='Local Blacksite Lockdown', radius=75.0, duration=60, cooldown=180 }
}

Config.ThreatLevels = {
    green={label='Green / Routine', multiplier=1}, yellow={label='Yellow / Suspicious', multiplier=1.2},
    orange={label='Orange / Active Threat', multiplier=1.5}, red={label='Red / Critical', multiplier=2}, black={label='Black / Reality Breach', multiplier=3}
}

Config.Integrations = { QbPolice=true, QbAmbulance=true, QbManagement=false, QbPhone=false, PsDispatch=false, CdDispatch=false, DpnMdt=true, DpnDispatch=true, DpnEmergencyNetwork=true }
Config.MIBLoadouts = {
    recruit = { items={{name='mib_neuralizer',amount=1},{name='radio',amount=1},{name='bandage',amount=5}} },
    agent = { items={{name='mib_neuralizer',amount=1},{name='weapon_stungun',amount=1},{name='radio',amount=1},{name='heavyarmor',amount=2}} },
    director = { items={{name='mib_neuralizer',amount=1},{name='weapon_pistol_mk2',amount=1},{name='radio',amount=1},{name='heavyarmor',amount=3},{name='advancedlockpick',amount=1}} }
}

Config.CommandCenter = {
    ShowOnlinePlayers = true,
    MaxPlayersInPanel = 96,
    EnableRoutingBuckets = true,
    EnableLockdown = true,
    EnableKick = true
}

-- V4 Expansion: Admin + Developer Operations + PG7X
Config.Version = '4.1.0-admin-dev-pg7x'
Config.DevMode = true
Config.DeveloperAcePermissions = { 'dpn.dev', 'command.dpn-dev', 'god' }
Config.PG7X = {
    Enabled = true,
    Command = 'pg7x',
    MaxDistance = 350.0,
    PortalDuration = 300,
    TwoWay = true,
    Color = { r = 0, g = 255, b = 110, a = 190 },
    Destinations = {
        { label='MIB HQ / MRPD', coords=vector4(441.18,-981.92,30.69,90.0) },
        { label='Pillbox', coords=vector4(306.76,-595.05,43.28,70.0) },
        { label='Sandy Shores', coords=vector4(1852.43,3687.18,34.27,210.0) },
        { label='Paleto', coords=vector4(-447.84,6013.85,31.72,45.0) },
        { label='Zancudo Blacksite', coords=vector4(-2344.91,3267.28,32.81,240.0) }
    }
}
Config.AdminSuite = {
    heal=true, revive=true, armor=true, noclip=true, cloak=true, invisible=true, godmode=true,
    freeze=true, bring=true, goto_player=true, spectate=true, kick=true, set_bucket=true,
    repair_vehicle=true, clean_vehicle=true, flip_vehicle=true, delete_vehicle=true,
    cleanup_peds=true, cleanup_vehicles=true, cleanup_objects=true, clear_area=true,
    announce=true, weather=true, time=true, copy_coords=true
}
Config.DeveloperSuite = {
    entityInspector=true, coordsTool=true, raycastTool=true, debugOverlay=true,
    resourceStatus=true, eventTester=true, nuiReloader=true, perfMonitor=true,
    routingBucketInspector=true, exportTester=true
}
Config.AdvancedNeuralizer = {
    EvidenceSuppression = true,
    FlashRadius = 18.0,
    DizzinessSeconds = 25,
    AudioMuffleSeconds = 12,
    DisableWeaponsSeconds = 20,
    Classes = {
        alpha={label='Alpha Calm Witness', blackout=6, wipeMinutes=5, radius=5, cooldown=15},
        beta={label='Beta Standard Memory Reset', blackout=15, wipeMinutes=15, radius=8, cooldown=30},
        gamma={label='Gamma Incident Suppression', blackout=25, wipeMinutes=45, radius=14, cooldown=60},
        omega={label='Omega Blacksite Protocol', blackout=35, wipeMinutes=120, radius=22, cooldown=120},
        area={label='Area Flash / Crowd Reset', blackout=12, wipeMinutes=20, radius=30, cooldown=180}
    }
}
