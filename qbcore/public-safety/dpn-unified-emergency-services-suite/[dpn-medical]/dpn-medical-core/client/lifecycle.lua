local downSince, deadSince, sentDownRequest, sentDeathRequest = 0, 0, false, false
local distress = { sent=false, pending=false, lastSentAt=0, callId=nil, message=nil }

local function drawText(text, y, scale)
    SetTextFont(4); SetTextScale(scale or 0.45, scale or 0.45); SetTextColour(255,255,255,230)
    SetTextCentre(true); SetTextOutline(); BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, y)
end

local function notify(message, kind)
    TriggerEvent('QBCore:Notify', tostring(message), kind or 'primary', 6000)
end

local function loadAnim(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function resurrectAtCurrent(health)
    local ped = PlayerPedId(); local coords = GetEntityCoords(ped); local heading = GetEntityHeading(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
    ped = PlayerPedId(); SetEntityHealth(ped, health or 105); ClearPedTasksImmediately(ped)
end

local function applyDownAnimation()
    local ped = PlayerPedId(); local anim = Config.Lifecycle.downAnimation
    if not IsEntityPlayingAnim(ped, anim.dict, anim.clip, 3) and loadAnim(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

local function resetDistress()
    distress.sent=false;distress.pending=false;distress.lastSentAt=0;distress.callId=nil;distress.message=nil
end

local function currentLifeState()
    return LocalMedicalState and LocalMedicalState.status and LocalMedicalState.status.lifeState or 'alive'
end

local function requestDistress(origin)
    local life=currentLifeState()
    if life~='incapacitated' and life~='dead' then
        if origin=='command' then notify('EMS distress can only be sent while incapacitated or deceased.','error') end
        return false
    end
    local now=GetGameTimer()
    local cooldown=(tonumber(Config.Lifecycle.distressCooldownSeconds) or 60)*1000
    if distress.pending then
        notify('Your EMS distress alert is still being processed.','error');return false
    end
    if distress.sent and Config.Lifecycle.distressAllowRepeat~=true then
        notify('An EMS distress alert has already been sent.','error');return false
    end
    if distress.lastSentAt>0 and now-distress.lastSentAt<cooldown then
        local remaining=math.ceil((cooldown-(now-distress.lastSentAt))/1000)
        notify(('Wait %s seconds before sending another distress alert.'):format(remaining),'error');return false
    end
    local ped=PlayerPedId();local coords=GetEntityCoords(ped)
    distress.pending=true;distress.lastSentAt=now;distress.message='Sending EMS distress alert...'
    TriggerServerEvent('dpn-medical-dispatch:server:distress',{x=coords.x,y=coords.y,z=coords.z,lifeState=life,origin=origin or 'unknown'})
    return true
end

RegisterCommand(Config.Lifecycle.distressCommand or '+dpnmeddistress',function() requestDistress('command') end,false)
RegisterCommand((Config.Lifecycle.distressCommand or '+dpnmeddistress'):gsub('^%+','-'),function() end,false)
pcall(function()
    RegisterKeyMapping(Config.Lifecycle.distressCommand or '+dpnmeddistress','Send DPN EMS distress alert','keyboard',Config.Lifecycle.distressKeybind or 'G')
end)

RegisterNetEvent('dpn-medical-dispatch:client:distressResult',function(result)
    result=type(result)=='table' and result or{}
    distress.pending=false
    if result.ok==true then
        distress.sent=true;distress.callId=result.callId;distress.message=result.message or ('EMS distress call '..tostring(result.callId or '')..' sent.')
        notify(distress.message,result.units and result.units>0 and 'success' or 'primary')
    else
        distress.sent=false;distress.lastSentAt=0;distress.message=result.message or 'EMS distress alert failed.'
        notify(distress.message,'error')
    end
end)

RegisterNetEvent(DPN_MED.Events.ReviveClient, function(options)
    options = type(options) == 'table' and options or {}
    local ped = PlayerPedId(); local coords = GetEntityCoords(ped); local heading = GetEntityHeading(ped)
    if options.coords then coords = vector3(options.coords.x, options.coords.y, options.coords.z); heading = options.coords.w or heading end
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
    ped = PlayerPedId(); SetEntityHealth(ped, tonumber(options.health) or Config.Lifecycle.reviveHealth)
    ClearPedTasksImmediately(ped); ClearPedBloodDamage(ped); ClearTimecycleModifier(); ClearExtraTimecycleModifier(); AnimpostfxStopAll(); StopGameplayCamShaking(true); SetNuiFocus(false, false); SetNuiFocusKeepInput(false); SendNUIMessage({ action = 'forceClose' })
    downSince, deadSince, sentDownRequest, sentDeathRequest = 0, 0, false, false
    resetDistress()
    TriggerEvent('dpn-medical-core:client:resetDamageTracker')
    TriggerEvent('dpn-medical-core:client:resetScreen')
end)

RegisterNetEvent(DPN_MED.Events.RespawnClient, function(coords)
    coords = coords or Config.Lifecycle.defaultRespawn
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.w or 0.0, true, false)
    local ped = PlayerPedId(); SetEntityHealth(ped, Config.Lifecycle.respawnHealth); SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, coords.w or 0.0); ClearPedTasksImmediately(ped); ClearPedBloodDamage(ped)
    downSince, deadSince, sentDownRequest, sentDeathRequest = 0, 0, false, false
    resetDistress()
    TriggerEvent('dpn-medical-core:client:resetDamageTracker')
    TriggerEvent('dpn-medical-core:client:resetScreen')
end)

CreateThread(function()
    while true do
        local state = LocalMedicalState
        local life = state and state.status and state.status.lifeState or 'alive'
        local ped = PlayerPedId()
        if Config.Lifecycle.enabled and life == 'alive' and (IsEntityDead(ped) or GetEntityHealth(ped) <= 101) then
            if not sentDownRequest then
                sentDownRequest = true
                TriggerServerEvent(DPN_MED.Events.EnterIncapacitated, { cause = 'Traumatic injury' })
            end
            if IsEntityDead(ped) then resurrectAtCurrent(105) end
        elseif life == 'incapacitated' or life == 'dead' then
            if IsEntityDead(ped) then resurrectAtCurrent(105) end
            SetEntityHealth(PlayerPedId(), 105)
            applyDownAnimation()
            if life == 'incapacitated' then
                if downSince == 0 then downSince = GetGameTimer() end
                local elapsed = math.floor((GetGameTimer() - downSince) / 1000)
                local remaining = math.max(0, Config.Lifecycle.lastStandSeconds - elapsed)
                drawText(('INCAPACITATED - %ss until death'):format(remaining), 0.83, 0.48)
                if distress.pending then
                    drawText('Sending EMS distress alert...',0.87,0.38)
                elseif distress.sent then
                    drawText(('EMS ALERT SENT%s - Press ~b~G~s~ to resend after cooldown'):format(distress.callId and (' (#'..tostring(distress.callId)..')') or ''),0.87,0.34)
                else
                    drawText('Press ~b~G~s~ to send an EMS distress alert', 0.87, 0.38)
                end
                -- The player is under DisableAllControlActions, so the disabled-control variant is required.
                if IsDisabledControlJustPressed(0, Config.Lifecycle.distressKey) or IsControlJustPressed(0, Config.Lifecycle.distressKey) then
                    requestDistress('control_fallback')
                end
                if remaining <= 0 and not sentDeathRequest then
                    sentDeathRequest = true
                    TriggerServerEvent(DPN_MED.Events.RequestDeath, { cause = state.status.causeOfDeath or 'Injuries sustained' })
                end
            else
                if deadSince == 0 then deadSince = GetGameTimer() end
                local elapsed = math.floor((GetGameTimer() - deadSince) / 1000)
                local remaining = math.max(0, Config.Lifecycle.deadRespawnDelaySeconds - elapsed)
                if not distress.sent and not distress.pending then drawText('Press ~b~G~s~ to send an EMS distress alert',0.79,0.34) end
                if IsDisabledControlJustPressed(0, Config.Lifecycle.distressKey) or IsControlJustPressed(0, Config.Lifecycle.distressKey) then requestDistress('control_fallback') end
                if remaining > 0 then drawText(('DECEASED - respawn available in %ss'):format(remaining), 0.84, 0.48)
                else
                    drawText('DECEASED - Press ~b~E~s~ for hospital respawn', 0.84, 0.48)
                    if IsDisabledControlJustPressed(0, Config.Lifecycle.respawnKey) or IsControlJustPressed(0, Config.Lifecycle.respawnKey) then TriggerServerEvent(DPN_MED.Events.RequestRespawn) end
                end
            end
            Wait(0)
        else
            downSince, deadSince, sentDownRequest, sentDeathRequest = 0, 0, false, false
            resetDistress()
            Wait(250)
        end
    end
end)

CreateThread(function()
    while true do
        local life = currentLifeState()
        if life ~= 'alive' then
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true); EnableControlAction(0, 2, true)
            EnableControlAction(0, Config.Lifecycle.distressKey, true); EnableControlAction(0, Config.Lifecycle.respawnKey, true)
            EnableControlAction(0, 245, true)
            Wait(0)
        else Wait(300) end
    end
end)
