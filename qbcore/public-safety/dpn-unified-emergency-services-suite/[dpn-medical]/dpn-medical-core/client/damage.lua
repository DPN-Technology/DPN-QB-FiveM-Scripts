local QBCore = exports['qb-core']:GetCoreObject()

local lastHealth = nil
local lastArmor = nil
local lastPed = 0
local lastCrashSpeed = 0.0
local lastCrashAt = 0
local wasFalling = false
local peakFallVelocity = 0.0
local lastFallAt = 0
local weaponProfiles = {}

local boneToPart = {
    [31086] = 'head', [12844] = 'head', [65068] = 'head',
    [39317] = 'neck', [57597] = 'spine', [23553] = 'spine', [24816] = 'spine',
    [24818] = 'chest', [24817] = 'chest', [64729] = 'chest', [10706] = 'chest',
    [11816] = 'pelvis', [56604] = 'pelvis', [51826] = 'pelvis',
    [18905] = 'left_arm', [61163] = 'left_arm', [45509] = 'left_arm', [60309] = 'left_arm',
    [57005] = 'right_arm', [28252] = 'right_arm', [40269] = 'right_arm', [28422] = 'right_arm',
    [58271] = 'left_leg', [63931] = 'right_leg', [46078] = 'left_leg', [16335] = 'right_leg',
    [14201] = 'left_leg', [52301] = 'right_leg', [2108] = 'left_leg', [20781] = 'right_leg'
}

local parts = { 'head', 'neck', 'chest', 'abdomen', 'pelvis', 'spine', 'left_arm', 'right_arm', 'left_leg', 'right_leg' }

local function copyProfile(profile)
    local result = {}
    for key, value in pairs(profile or {}) do result[key] = value end
    return result
end

local function randomPart()
    return parts[math.random(1, #parts)]
end

local function damagedPart(ped)
    local hit, bone = GetPedLastDamageBone(ped)
    if hit and boneToPart[bone] then return boneToPart[bone] end
    return randomPart()
end

local function isUnavailable()
    return LocalMedicalState and (LocalMedicalState.status.lifeState or 'alive') ~= 'alive'
end

local function classifyWeapon(hash)
    local damageType = GetWeaponDamageType(hash)
    if damageType == 2 then return 'melee' end
    if damageType == 3 then return 'bullet' end
    if damageType == 4 then return 'explosion' end
    if damageType == 5 then return 'fire' end
    if damageType == 6 then return 'collision' end
    return 'unknown'
end

local function profileFromWeapon(hash, actualDamage)
    local entry = weaponProfiles[hash]
    local profile = copyProfile(entry and entry.profile or Config.DefaultDamageProfiles[classifyWeapon(hash)] or Config.DefaultDamageProfiles.unknown)
    local name = entry and entry.name or ('HASH_%s'):format(hash)
    local damage = math.max(1, tonumber(actualDamage) or 1)

    profile.damage = math.min(Config.Security.maxDamagePerHit, math.max(profile.damage or 0, damage))
    profile.pain = math.min(Config.Security.maxPainPerHit, math.max(profile.pain or 0, damage * 0.75))
    profile.weapon = name
    profile.source = 'native_damage'

    if (profile.internalChance or 0) > 0 and math.random(100) <= profile.internalChance then profile.internalBleeding = true end
    if (profile.fractureChance or 0) > 0 and math.random(100) <= profile.fractureChance then
        profile.fracture = profile.damage >= 55 and 'compound' or 'closed'
    end
    profile.internalChance = nil
    profile.fractureChance = nil
    return profile
end

local function report(part, injury)
    if isUnavailable() then return end
    TriggerServerEvent(DPN_MED.Events.ReportDamage, part, injury)
end

CreateThread(function()
    for weaponName, profile in pairs(Config.WeaponDamageProfiles) do
        weaponProfiles[joaat(weaponName)] = { name = weaponName, profile = profile }
    end
end)

RegisterNetEvent('dpn-medical-core:client:resetDamageTracker', function()
    local ped = PlayerPedId()
    lastPed = ped
    lastHealth = GetEntityHealth(ped)
    lastArmor = GetPedArmour(ped)
    lastCrashSpeed = 0.0
    wasFalling = false
    peakFallVelocity = 0.0
end)

CreateThread(function()
    while true do
        Wait(Config.Timing.damagePollMs)
        local ped = PlayerPedId()
        if ped ~= lastPed then
            lastPed = ped
            lastHealth = GetEntityHealth(ped)
            lastArmor = GetPedArmour(ped)
        end

        local health = GetEntityHealth(ped)
        local armor = GetPedArmour(ped)
        lastHealth = lastHealth or health
        lastArmor = lastArmor or armor

        if not isUnavailable() and not IsEntityDead(ped) then
            local healthLoss = math.max(0, lastHealth - health)
            local armorLoss = math.max(0, lastArmor - armor)
            local effectiveDamage = healthLoss + math.floor(armorLoss * 0.30)
            if effectiveDamage > 0 then
                local weapon = GetPedCauseOfDeath(ped)
                report(damagedPart(ped), profileFromWeapon(weapon, effectiveDamage))
            end
        end

        lastHealth = health
        lastArmor = armor
    end
end)

CreateThread(function()
    while true do
        Wait(100)
        local ped = PlayerPedId()
        if isUnavailable() or IsEntityDead(ped) then
            lastCrashSpeed = 0.0
            wasFalling = false
            peakFallVelocity = 0.0
        elseif IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            local speed = GetEntitySpeed(vehicle) * 2.236936
            local delta = lastCrashSpeed - speed
            local now = GetGameTimer()
            if delta >= Config.VehicleCrashDamage.minDeltaMph and now - lastCrashAt >= Config.VehicleCrashDamage.cooldownMs then
                lastCrashAt = now
                local damage = math.min(100, math.floor(delta * Config.VehicleCrashDamage.multiplier))
                report('chest', {
                    type = 'vehicle_crash', damage = damage, pain = damage,
                    bleeding = damage > 40 and 'venous' or 'capillary',
                    internalBleeding = damage > 32,
                    fracture = damage > 52 and 'closed' or nil,
                    source = 'vehicle_crash'
                })
                if damage > 45 then
                    report(math.random(100) > 50 and 'left_leg' or 'right_leg', {
                        type = 'vehicle_crash', damage = math.floor(damage * 0.60), pain = math.floor(damage * 0.65),
                        fracture = 'closed', source = 'vehicle_crash'
                    })
                end
            end
            lastCrashSpeed = speed
            wasFalling = false
            peakFallVelocity = 0.0
        else
            lastCrashSpeed = 0.0
            if IsPedFalling(ped) then
                wasFalling = true
                peakFallVelocity = math.max(peakFallVelocity, math.abs(GetEntityVelocity(ped).z))
            elseif wasFalling then
                local now = GetGameTimer()
                if peakFallVelocity >= Config.FallDamage.minVelocity and now - lastFallAt >= Config.FallDamage.cooldownMs then
                    lastFallAt = now
                    local damage = math.min(100, math.floor(peakFallVelocity * Config.FallDamage.multiplier))
                    local part = math.random(100) <= 75 and (math.random(100) > 50 and 'left_leg' or 'right_leg') or 'spine'
                    report(part, {
                        type = 'fall', damage = damage, pain = damage,
                        bleeding = damage > 45 and 'capillary' or 'none',
                        fracture = damage > 28 and 'closed' or nil,
                        internalBleeding = part == 'spine' and damage > 45,
                        source = 'fall'
                    })
                end
                wasFalling = false
                peakFallVelocity = 0.0
            end
        end
    end
end)
