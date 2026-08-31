local effectsActive = false

local bedBoundStates = {
    [HospitalStates.ADMITTED] = true,
    [HospitalStates.TREATING] = true,
    [HospitalStates.SURGERY_REQUIRED] = true,
    [HospitalStates.IN_SURGERY] = true
}

local function ClearRecoveryEffects()
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    AnimpostfxStopAll()
    TriggerScreenblurFadeOut(0.0)
    SetNightvision(false)
    SetSeethrough(false)
    effectsActive = false
end

CreateThread(function()
    while true do
        if PlayerAdmission and Config.RecoveryEffects.enabled then
            Wait(0)

            local ped = PlayerPedId()
            local remaining = tonumber(PlayerAdmission.remaining_minutes) or 0
            local status = PlayerAdmission.status
            local bedBound = bedBoundStates[status] == true

            -- Full-screen timecycle effects are deliberately disabled. They can persist
            -- across admission/revive/restart and obscure the entire game view.
            ClearRecoveryEffects()

            if Config.RecoveryEffects.slowWalk and remaining > 0 and not bedBound then
                SetPedMoveRateOverride(ped, tonumber(Config.RecoveryEffects.movementRate) or 0.78)
            end

            if Config.RecoveryEffects.disableSprintWhenSevere and remaining > (Config.RecoveryEffects.severeMinutesThreshold or 3) then
                DisableControlAction(0, 21, true) -- sprint
            end

            if bedBound then
                DisableControlAction(0, 21, true) -- sprint
                DisableControlAction(0, 22, true) -- jump
                DisableControlAction(0, 23, true) -- enter vehicle
                DisableControlAction(0, 75, true) -- exit vehicle
            end

            if Config.RecoveryEffects.disableJumpWhileBedBound and bedBound then
                DisableControlAction(0, 22, true)
            end

            if Config.RecoveryEffects.disableCombatWhileAdmitted and bedBound then
                DisablePlayerFiring(PlayerId(), true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 37, true)
                DisableControlAction(0, 44, true)
                DisableControlAction(0, 140, true)
                DisableControlAction(0, 141, true)
                DisableControlAction(0, 142, true)
                DisableControlAction(0, 143, true)
            end
        else
            ClearRecoveryEffects()
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then ClearRecoveryEffects() end
end)
