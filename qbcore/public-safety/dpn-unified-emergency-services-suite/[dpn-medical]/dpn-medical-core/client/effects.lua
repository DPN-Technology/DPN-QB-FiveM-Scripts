local injuredClipset = 'move_m@injured'
local clipsetLoaded = false
local movementApplied = false
local cameraApplied = false
local filterApplied = false
local lastStumble = 0

local function loadClipset()
    if clipsetLoaded then return true end
    RequestAnimSet(injuredClipset)
    local timeout = GetGameTimer() + 3000
    while not HasAnimSetLoaded(injuredClipset) and GetGameTimer() < timeout do Wait(10) end
    clipsetLoaded = HasAnimSetLoaded(injuredClipset)
    return clipsetLoaded
end

local function severityFlags(state)
    local body = state and state.body or {}
    local leftLeg = body.left_leg or {}
    local rightLeg = body.right_leg or {}
    local leftArm = body.left_arm or {}
    local rightArm = body.right_arm or {}

    local severeLeg = (leftLeg.damage or 0) >= 45 or (rightLeg.damage or 0) >= 45
        or (leftLeg.fracture or 'none') ~= 'none' or (rightLeg.fracture or 'none') ~= 'none'
    local severeArm = (leftArm.damage or 0) >= 55 or (rightArm.damage or 0) >= 55
        or (leftArm.fracture or 'none') ~= 'none' or (rightArm.fracture or 'none') ~= 'none'
    return severeLeg, severeArm
end

local function resetEffects()
    local ped = PlayerPedId()
    if movementApplied then ResetPedMovementClipset(ped, 0.25); movementApplied = false end
    if cameraApplied then StopGameplayCamShaking(true); cameraApplied = false end
    if filterApplied then
        ClearTimecycleModifier()
        ClearExtraTimecycleModifier()
        filterApplied = false
    end
end

CreateThread(function()
    while true do
        local state = LocalMedicalState
        if not state then
            resetEffects()
            Wait(1000)
        else
            local severeLeg, severeArm = severityFlags(state)
            local pain = tonumber(state.status.pain) or 0
            local shock = tonumber(state.status.shock) or 0
            local ped = PlayerPedId()

            if Config.Effects.enableMovementEffects and severeLeg and not IsPedInAnyVehicle(ped, false) then
                if loadClipset() then SetPedMovementClipset(ped, injuredClipset, 0.65); movementApplied = true end
            elseif movementApplied then
                ResetPedMovementClipset(ped, 0.25)
                movementApplied = false
            end

            local combined = math.max(pain, shock)
            if Config.Effects.enableCameraShake and combined >= Config.Effects.cameraShakeThreshold then
                local amplitude = math.min(Config.Effects.maxCameraShake, combined / 600.0)
                if not cameraApplied then ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', amplitude); cameraApplied = true end
                SetGameplayCamShakeAmplitude(amplitude)
            elseif cameraApplied then
                StopGameplayCamShaking(true)
                cameraApplied = false
            end

            -- Full-screen filters are not supported by DPN Medical. This is intentionally
            -- hard-disabled instead of configuration-controlled because a stuck modifier can
            -- obscure the entire game view after revive, respawn, or a resource restart.
            if filterApplied then
                ClearTimecycleModifier()
                ClearExtraTimecycleModifier()
                filterApplied = false
            end

            if Config.Effects.enableShockStumble and shock >= 70 and not IsPedRagdoll(ped) and not IsPedInAnyVehicle(ped, false) then
                local now = GetGameTimer()
                if now - lastStumble >= Config.Effects.stumbleCooldownMs and math.random(100) <= 18 then
                    lastStumble = now
                    SetPedToRagdoll(ped, 1000, 1300, 0, false, false, false)
                end
            end

            if severeLeg or severeArm or state.status.unconscious then
                while LocalMedicalState do
                    local currentLeg, currentArm = severityFlags(LocalMedicalState)
                    if not currentLeg and not currentArm and not LocalMedicalState.status.unconscious then break end
                    if Config.Effects.disableSprintWithSevereLegTrauma and currentLeg then
                        DisableControlAction(0, 21, true)
                        DisableControlAction(0, 22, true)
                    end
                    if Config.Effects.disableWeaponsWithSevereArmTrauma and currentArm then
                        DisableControlAction(0, 24, true)
                        DisableControlAction(0, 25, true)
                        DisablePlayerFiring(PlayerId(), true)
                    end
                    if LocalMedicalState.status.unconscious then
                        DisableControlAction(0, 24, true)
                        DisableControlAction(0, 25, true)
                        DisableControlAction(0, 21, true)
                    end
                    Wait(0)
                end
            else
                Wait(Config.Timing.effectTickMs)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then resetEffects() end
end)
