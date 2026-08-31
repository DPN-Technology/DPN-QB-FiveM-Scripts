Config = Config or {}

Config.Debug = false
Config.Version = '14.0.0'
Config.Framework = 'qb-core'

Config.Persistence = {
    enabled = true,
    saveIntervalMinutes = 3,
    eventLogging = true,
    pruneEventsAfterDays = 60
}

Config.Timing = {
    decayTickMs = 5000,
    effectTickMs = 250,
    damagePollMs = 200,
    damageReportCooldownMs = 120,
    treatmentCooldownMs = 650
}

Config.Security = {
    maxDamagePerHit = 100,
    maxPainPerHit = 100,
    maxTreatmentDistance = 5.0,
    maxInspectDistance = 7.0,
    allowSelfBasicTreatment = true,
    requireTreatmentItems = false,
    requireOnDutyForAdvancedTreatment = true
}


Config.VisualSafety = {
    enabled = true,
    -- Continuous mode prevents any stale/duplicate medical resource from reapplying
    -- a full-screen timecycle, blur, night vision, thermal vision, or post effect.
    continuous = true,
    intervalMs = 250,
    startupResetMs = 20000,
    fadedScreenRecoveryMs = 3000,
    clearTimecycles = true,
    clearPostFx = true,
    clearScreenBlur = true,
    disableNightVision = true,
    disableThermalVision = true
}

Config.Lifecycle = {
    enabled = true,
    lastStandSeconds = 180,
    deadRespawnDelaySeconds = 90,
    reviveHealth = 150,
    respawnHealth = 200,
    preserveInjuriesOnFieldRevive = true,
    clearInjuriesOnHospitalRespawn = true,
    distressKey = 47, -- G fallback control
    distressCommand = '+dpnmeddistress',
    distressKeybind = 'G',
    distressCooldownSeconds = 60,
    distressAllowRepeat = true,
    respawnKey = 38, -- E
    defaultRespawn = vector4(299.21, -584.81, 43.26, 70.0),
    downAnimation = { dict = 'dead', clip = 'dead_a' }
}

Config.Effects = {
    enableMovementEffects = true,
    enableCameraShake = true,
    maxCameraShake = 0.18,
    cameraShakeThreshold = 55,
    enableFullScreenDamageFilter = false,
    disableSprintWithSevereLegTrauma = true,
    disableWeaponsWithSevereArmTrauma = true,
    enableShockStumble = true,
    stumbleCooldownMs = 10000
}

Config.UI = {
    defaultHudEnabled = true,
    openCommand = 'medical',
    hudCommand = 'medhud',
    inspectCommand = 'medinspect'
}

Config.Thresholds = {
    deathBloodMl = 1500,
    unconsciousBloodMl = 2200,
    unconsciousPain = 92,
    unconsciousSpO2 = 80,
    cardiacSpO2 = 62,
    criticalShock = 85
}

Config.Jobs = {
    ems = { ambulance = true, ems = true, paramedic = true, fire = true },
    doctor = { doctor = true, ambulance = true, ems = true, surgeon = true },
    surgeon = { surgeon = true, doctor = true },
    coroner = { coroner = true, doctor = true },
    pharmacist = { pharmacist = true, doctor = true }
}

Config.BodyParts = {
    head = { label = 'Head', fatal = true, mobility = false, painMultiplier = 1.50 },
    neck = { label = 'Neck', fatal = true, mobility = false, painMultiplier = 1.45 },
    chest = { label = 'Chest', fatal = true, mobility = false, painMultiplier = 1.30 },
    abdomen = { label = 'Abdomen', fatal = true, mobility = false, painMultiplier = 1.20 },
    pelvis = { label = 'Pelvis', fatal = false, mobility = true, painMultiplier = 1.10 },
    spine = { label = 'Spine', fatal = true, mobility = true, painMultiplier = 1.60 },
    left_arm = { label = 'Left Arm', fatal = false, mobility = true, painMultiplier = 0.90 },
    right_arm = { label = 'Right Arm', fatal = false, mobility = true, painMultiplier = 0.90 },
    left_leg = { label = 'Left Leg', fatal = false, mobility = true, painMultiplier = 1.00 },
    right_leg = { label = 'Right Leg', fatal = false, mobility = true, painMultiplier = 1.00 }
}

Config.OrganMap = {
    head = { 'brain', 'eyes' }, neck = { 'airway', 'carotid' },
    chest = { 'heart', 'left_lung', 'right_lung' },
    abdomen = { 'liver', 'spleen', 'kidneys', 'stomach', 'intestines' },
    pelvis = { 'bladder', 'femoral_artery' }, spine = { 'spinal_cord' }
}

Config.BoneMap = {
    head = { 'skull' }, neck = { 'c_spine' }, chest = { 'ribs', 'sternum' }, abdomen = {},
    pelvis = { 'pelvis' }, spine = { 'vertebrae' },
    left_arm = { 'left_humerus', 'left_radius', 'left_ulna' },
    right_arm = { 'right_humerus', 'right_radius', 'right_ulna' },
    left_leg = { 'left_femur', 'left_tibia', 'left_fibula' },
    right_leg = { 'right_femur', 'right_tibia', 'right_fibula' }
}

Config.BleedingPriority = { none = 0, capillary = 1, venous = 2, arterial = 3 }
Config.BleedRatesMlPerTick = { none = 0, capillary = 2, venous = 8, arterial = 22, internal = 12 }
Config.FallDamage = { minVelocity = 8.0, multiplier = 3.8, cooldownMs = 2500 }
Config.VehicleCrashDamage = { minDeltaMph = 28.0, multiplier = 0.55, cooldownMs = 2000 }

Config.WeaponDamageProfiles = {
    WEAPON_UNARMED = { type = 'blunt', damage = 5, pain = 6 },
    WEAPON_BAT = { type = 'blunt', damage = 16, pain = 18, fractureChance = 24 },
    WEAPON_CROWBAR = { type = 'blunt', damage = 18, pain = 20, fractureChance = 28 },
    WEAPON_KNIFE = { type = 'stab', damage = 21, bleeding = 'venous', pain = 22, internalChance = 18 },
    WEAPON_PISTOL = { type = 'gunshot', damage = 35, bleeding = 'arterial', pain = 29, internalChance = 30 },
    WEAPON_COMBATPISTOL = { type = 'gunshot', damage = 36, bleeding = 'arterial', pain = 30, internalChance = 31 },
    WEAPON_PISTOL50 = { type = 'gunshot', damage = 48, bleeding = 'arterial', pain = 38, internalChance = 42, fractureChance = 24 },
    WEAPON_REVOLVER = { type = 'gunshot', damage = 52, bleeding = 'arterial', pain = 40, internalChance = 45, fractureChance = 28 },
    WEAPON_SMG = { type = 'gunshot', damage = 38, bleeding = 'arterial', pain = 31, internalChance = 32 },
    WEAPON_ASSAULTRIFLE = { type = 'gunshot', damage = 50, bleeding = 'arterial', pain = 38, internalChance = 46, fractureChance = 22 },
    WEAPON_CARBINERIFLE = { type = 'gunshot', damage = 48, bleeding = 'arterial', pain = 36, internalChance = 43, fractureChance = 20 },
    WEAPON_PUMPSHOTGUN = { type = 'gunshot', damage = 62, bleeding = 'arterial', pain = 48, internalChance = 55, fractureChance = 40 },
    WEAPON_SNIPERRIFLE = { type = 'gunshot', damage = 78, bleeding = 'arterial', pain = 58, internalChance = 68, fractureChance = 48 },
    WEAPON_STUNGUN = { type = 'electrical', damage = 4, pain = 10 },
    WEAPON_MOLOTOV = { type = 'burn', damage = 28, burn = 3, pain = 32 }
}

Config.DefaultDamageProfiles = {
    bullet = { type = 'gunshot', damage = 28, pain = 25, bleeding = 'venous', internalChance = 22 },
    melee = { type = 'blunt', damage = 12, pain = 14, fractureChance = 12 },
    explosion = { type = 'blast', damage = 55, pain = 45, bleeding = 'venous', internalChance = 50, fractureChance = 35 },
    fire = { type = 'burn', damage = 24, pain = 28, burn = 2 },
    collision = { type = 'trauma', damage = 18, pain = 19, fractureChance = 18 },
    unknown = { type = 'trauma', damage = 10, pain = 10 }
}

Config.Treatments = {
    pressure_bandage = { label = 'Pressure Bandage', level = 'basic', item = 'pressure_bandage', self = true },
    hemostatic_gauze = { label = 'Hemostatic Gauze', level = 'ems', item = 'hemostatic_gauze' },
    tourniquet = { label = 'Tourniquet', level = 'ems', item = 'medical_tourniquet', limbOnly = true },
    chest_seal = { label = 'Chest Seal', level = 'ems', item = 'chest_seal', parts = { chest = true } },
    splint = { label = 'Splint', level = 'ems', item = 'medical_splint', limbOnly = true },
    oxygen = { label = 'Oxygen', level = 'ems', item = 'oxygen_mask', global = true },
    iv_fluids = { label = 'IV Fluids', level = 'ems', item = 'iv_kit', global = true },
    blood = { label = 'Blood Transfusion', level = 'doctor', item = 'blood_bag', global = true },
    morphine = { label = 'Morphine', level = 'ems', item = 'morphine', global = true },
    epinephrine = { label = 'Epinephrine', level = 'ems', item = 'epinephrine', global = true },
    narcan = { label = 'Naloxone', level = 'ems', item = 'narcan', global = true },
    aed = { label = 'AED', level = 'ems', item = 'aed', global = true },
    surgical_repair = { label = 'Surgical Repair', level = 'surgeon' },
    antibiotics = { label = 'Antibiotics', level = 'doctor', global = true },
    rehab_session = { label = 'Rehabilitation Session', level = 'doctor', global = true },
    full_heal = { label = 'Definitive Care', level = 'doctor', global = true }
}

-- DPN Medical 5.0 advanced physiology and clinical coordination.
Config.Advanced = {
    enabled = true,
    physiologyTickSeconds = 5,
    criticalAlertCooldownSeconds = 45,
    autoCreateEpisodes = true,
    autoCloseHealthyEpisodesMinutes = 15,
    enableMedicationSafety = true,
    enableTourniquetIschemia = true,
    enableSepsisProgression = true,
    enableProtocolEngine = true,
    enableCarePlans = true,
    defaultBloodType = 'unknown',
    maxTimelineEntries = 150,
    maxCarePlanTasks = 40
}

Config.AdvancedThresholds = {
    mapCritical = 55,
    mapLow = 65,
    shockIndexHigh = 1.0,
    shockIndexCritical = 1.4,
    lactateHigh = 2.5,
    lactateCritical = 4.0,
    gcsCritical = 8,
    sepsisTemperatureHigh = 101.3,
    sepsisTemperatureLow = 95.0,
    tourniquetWarningMinutes = 90,
    tourniquetCriticalMinutes = 120
}

Config.Protocols = {
    massive_hemorrhage = { priority = 1, triggers = { bleeding = true, bloodBelow = 3500 }, actions = { 'Control hemorrhage', 'Establish IV/IO access', 'Consider blood products', 'Rapid transport to trauma center' } },
    airway_compromise = { priority = 1, triggers = { spo2Below = 90 }, actions = { 'Open and suction airway', 'Apply oxygen', 'Assist ventilations if inadequate', 'Prepare advanced airway' } },
    shock = { priority = 1, triggers = { mapBelow = 65, shockIndexAbove = 1.0 }, actions = { 'Identify shock cause', 'Control bleeding', 'Maintain temperature', 'Initiate fluid or blood resuscitation' } },
    traumatic_brain_injury = { priority = 2, triggers = { gcsBelow = 14 }, actions = { 'Protect airway', 'Avoid hypoxia and hypotension', 'Elevate head when appropriate', 'Urgent CT and neurosurgical evaluation' } },
    sepsis = { priority = 1, triggers = { qsofaAtLeast = 2 }, actions = { 'Obtain cultures', 'Begin antibiotics', 'Administer fluids', 'Trend lactate and urine output' } },
    cardiac_arrest = { priority = 0, triggers = { cardiacArrest = true }, actions = { 'Begin high-quality CPR', 'Attach LIFEPAK', 'Analyze rhythm', 'Follow ACLS algorithm' } }
}
