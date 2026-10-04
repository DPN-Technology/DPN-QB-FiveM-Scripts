local QBCore = exports['qb-core']:GetCoreObject()
local cooldowns = {}

local function player(src) return QBCore.Functions.GetPlayer(src) end
local function isAdmin(src)
    if not Config.UseAdminPermission then return false end
    for _, ace in pairs(Config.AcePermissions or { 'dpn.mib', 'command.mib' }) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    return QBCore.Functions.HasPermission(src, Config.AdminPermission) or QBCore.Functions.HasPermission(src, 'god')
end
local function isMIB(src)
    local P = player(src)
    if not P then return false end
    if isAdmin(src) then return true end
    local jobData = P.PlayerData.job or {}
    local job = jobData.name
    if Config.RequireDuty and job and Config.AllowedJobs[job] == true and jobData.onduty == false then return false end
    return job and Config.AllowedJobs[job] == true
end
exports('IsMIB', isMIB)

local function requireAccess(src, action, reason)
    if not isMIB(src) then return false end
    if Config.RequireReasonForHighRisk and Config.HighRiskActions[action] and (not reason or reason == '') then
        DPN.Notify(src, 'A reason is required for this high-risk MIB action.', 'error')
        return false
    end
    return true
end

local function canUseDirectorLoadout(src)
    if isAdmin(src) then return true end
    local P = player(src)
    if not P then return false end
    local jobData = P.PlayerData.job or {}
    local grade = jobData.grade or {}
    return jobData.name == Config.MIBJobName and tostring(grade.name or ''):lower() == 'director'
end

local function cooled(src, key, seconds)
    cooldowns[src] = cooldowns[src] or {}
    local now = os.time()
    if cooldowns[src][key] and cooldowns[src][key] > now then return false, cooldowns[src][key] - now end
    cooldowns[src][key] = now + (seconds or 5)
    return true, 0
end

local function validTargetInRange(src, target, maxDistance, rejectSelf)
    target = tonumber(target)
    if not target or not GetPlayerName(target) then return false, 'No valid target in range.' end
    if rejectSelf and target == src then return false, 'You cannot target yourself with this action.' end

    local sourcePed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(target)
    if not sourcePed or sourcePed <= 0 or not DoesEntityExist(sourcePed) then return false, 'Your player entity is unavailable.' end
    if not targetPed or targetPed <= 0 or not DoesEntityExist(targetPed) then return false, 'Target player entity is unavailable.' end

    local sourceCoords = GetEntityCoords(sourcePed)
    local targetCoords = GetEntityCoords(targetPed)
    local range = tonumber(maxDistance) or 10.0
    if #(sourceCoords - targetCoords) > range + 1.0 then
        return false, 'Target is outside the authorized interaction range.'
    end

    return true, nil, target
end

QBCore.Functions.CreateCallback('dpn-mib:server:hasAccess', function(src, cb)
    cb(isMIB(src), isAdmin(src))
end)

CreateThread(function()
    Wait(1500)
    if QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[Config.Neuralizer.Item] then
        QBCore.Functions.CreateUseableItem(Config.Neuralizer.Item, function(src)
            if not isMIB(src) then return DPN.Notify(src, 'Access denied. MIB credentials required.', 'error') end
            TriggerClientEvent('dpn-mib:client:useNeuralizer', src, 'beta')
        end)
    else
        print(('[dpn-mib] Item %s not found in qb-core/shared/items.lua. Menu still works, usable item skipped.'):format(Config.Neuralizer.Item))
    end
end)

RegisterNetEvent('dpn-mib:server:neuralize', function(target, class, reason)
    local src = source; class = class or 'beta'
    if not requireAccess(src, 'neuralizer', reason) then return end
    local cfg = Config.Neuralizer.Classes[class] or Config.Neuralizer.Classes.beta
    local ok, wait = cooled(src, 'neuralizer_'..class, cfg.cooldown)
    if not ok then return DPN.Notify(src, ('Neuralizer recharging: %ss'):format(wait), 'error') end
    local targetOk, targetErr, resolvedTarget = validTargetInRange(src, target, Config.Neuralizer.Range, true)
    if not targetOk then return DPN.Notify(src, targetErr, 'error') end
    target = resolvedTarget
    TriggerClientEvent('dpn-mib:client:blackout', target, cfg.blackout, cfg.label)
    TriggerClientEvent('dpn-mib:client:clearShortMemory', target, cfg.wipeMinutes)
    if Config.Neuralizer.BodycamInterference then TriggerClientEvent('dpn-mib:client:bodycamStatic', -1, GetEntityCoords(GetPlayerPed(src)), 18.0) end
    MIBMemoryLog(src, target, cfg.wipeMinutes, reason or cfg.label)
    local case = MIBLog(src, 'NEURALIZER_'..string.upper(class), target, reason or cfg.label)
    DPN.Notify(src, 'Neuralizer deployed. Case: '..case, 'success')
end)

RegisterNetEvent('dpn-mib:server:toolAction', function(action, target, payload)
    local src = source; payload = payload or {}
    if not requireAccess(src, action, payload.reason) then return end
    if action == 'freeze' then
        local targetOk, targetErr, resolvedTarget = validTargetInRange(src, target, Config.Tools.freeze.range, false)
        if not targetOk then return DPN.Notify(src, targetErr, 'error') end
        target = resolvedTarget
        local ok, wait = cooled(src, 'freeze', Config.Tools.freeze.cooldown); if not ok then return DPN.Notify(src, ('Containment cooldown: %ss'):format(wait), 'error') end
        TriggerClientEvent('dpn-mib:client:freezeTarget', target, Config.Tools.freeze.duration)
        MIBLog(src, 'CONTAINMENT_FREEZE', target, payload.reason)
    elseif action == 'scan' then
        local targetOk, targetErr, resolvedTarget = validTargetInRange(src, target, Config.Tools.scan.range, false)
        if not targetOk then return DPN.Notify(src, targetErr, 'error') end
        local T = player(resolvedTarget); if not T then return DPN.Notify(src, 'No valid target to scan.', 'error') end
        target = resolvedTarget
        local md = T.PlayerData.metadata or {}
        TriggerClientEvent('dpn-mib:client:scanResult', src, {
            name=(T.PlayerData.charinfo.firstname or 'Unknown')..' '..(T.PlayerData.charinfo.lastname or ''), cid=T.PlayerData.citizenid,
            phone=T.PlayerData.charinfo.phone or 'Unknown', job=T.PlayerData.job.label, gang=T.PlayerData.gang and T.PlayerData.gang.label or 'None',
            stress=md.stress or 0, hunger=md.hunger or 0, thirst=md.thirst or 0, fingerprint=md.fingerprint or 'Unknown', source=target
        })
        MIBLog(src, 'IDENTITY_SCAN', target, 'Deep identity scan')
    elseif action == 'emergency_ping' then
        local ok, wait = cooled(src, 'emergency_ping', Config.Tools.emergency_ping.cooldown); if not ok then return DPN.Notify(src, ('Ping cooldown: %ss'):format(wait), 'error') end
        SendEmergencyPing(src, payload.message)
        MIBLog(src, 'EMERGENCY_SERVICE_PING', nil, payload.message)
    elseif action == 'loadout' then
        local rank = tostring(payload.rank or 'agent'):lower()
        if not Config.MIBLoadouts[rank] then rank = 'agent' end
        if rank == 'director' and not canUseDirectorLoadout(src) then
            MIBLog(src, 'LOADOUT_ESCALATION_DENIED', nil, 'Requested director loadout')
            return DPN.Notify(src, 'Director clearance is required for that MIB loadout.', 'error')
        end
        local loadout = Config.MIBLoadouts[rank]
        local P = player(src)
        if not P then return end
        for _, item in pairs(loadout.items) do
            P.Functions.AddItem(item.name, item.amount)
            if QBCore.Shared.Items[item.name] then TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item.name], 'add') end
        end
        MIBLog(src, 'LOADOUT_ISSUED', nil, rank); DPN.Notify(src, 'MIB loadout issued: '..rank, 'success')
    elseif action == 'wipe_scene' or action == 'mass_wipe' then
        local ok, wait = cooled(src, 'wipe_scene', Config.Tools.wipe_scene.cooldown); if not ok then return DPN.Notify(src, ('Scene wipe cooldown: %ss'):format(wait), 'error') end
        TriggerClientEvent('dpn-mib:client:wipeScene', -1, GetEntityCoords(GetPlayerPed(src)), Config.Tools.wipe_scene.radius, payload.reason)
        MIBLog(src, 'SCENE_MEMORY_PROTOCOL', nil, payload.reason)
    elseif action == 'revive' then
        target = tonumber(target or src)
        local targetOk, targetErr, resolvedTarget = validTargetInRange(src, target, Config.Tools.revive.range, false)
        if not targetOk then return DPN.Notify(src, targetErr, 'error') end
        target = resolvedTarget
        local ok, wait = cooled(src, 'revive', Config.Tools.revive.cooldown)
        if not ok then return DPN.Notify(src, ('Medical override cooldown: %ss'):format(wait), 'error') end
        TriggerClientEvent('hospital:client:Revive', target)
        MIBLog(src, 'MEDICAL_OVERRIDE', target, payload.reason)
    elseif action == 'armor' then
        TriggerClientEvent('dpn-mib:client:setArmor', src, Config.Tools.armor.amount); MIBLog(src, 'SUIT_ARMOR_PROTOCOL', nil, payload.reason)
    elseif action == 'lockdown' then
        local ok, wait = cooled(src, 'lockdown', Config.Tools.lockdown.cooldown); if not ok then return DPN.Notify(src, ('Lockdown cooldown: %ss'):format(wait), 'error') end
        TriggerClientEvent('dpn-mib:client:lockdown', -1, GetEntityCoords(GetPlayerPed(src)), Config.Tools.lockdown.radius, Config.Tools.lockdown.duration, payload.reason)
        MIBLog(src, 'BLACKSITE_LOCKDOWN', nil, payload.reason)
    elseif action == 'set_bucket' then
        target = tonumber(target)
        local bucket = tonumber(payload.bucket or 0) or 0
        if not target or not GetPlayerName(target) then return DPN.Notify(src, 'Invalid target.', 'error') end
        SetPlayerRoutingBucket(target, bucket)
        MIBLog(src, 'ROUTING_BUCKET_SET', target, 'Bucket '..bucket..' | '..(payload.reason or ''))
        DPN.Notify(src, ('Target moved to routing bucket %s.'):format(bucket), 'success')
    elseif action == 'kick' then
        target = tonumber(target)
        if not target or not GetPlayerName(target) then return DPN.Notify(src, 'Invalid target.', 'error') end
        MIBLog(src, 'MIB_KICK', target, payload.reason)
        DropPlayer(target, 'DPN MIB Administrative Removal: '..(payload.reason or 'No reason provided'))
    elseif action == 'create_case' then
        local case = MIBCreateCase(src, { title=payload.title, threat=payload.threat, coords=GetEntityCoords(GetPlayerPed(src)), notes={{time=os.time(), author='System', text=payload.reason or 'Created from MIB menu'}} })
        TriggerClientEvent('dpn-mib:client:caseCreated', src, case)
    elseif action == 'case_note' then
        if MIBAddCaseNote(src, payload.caseId, payload.note) then DPN.Notify(src, 'Case note added.', 'success') end
    elseif action == 'threat' then
        MIBSetThreatLevel(src, payload.level or 'green', payload.reason)
    elseif action == 'goto_player' then
        target = tonumber(target)
        if not target or not GetPlayerName(target) then return DPN.Notify(src, 'Invalid target.', 'error') end
        TriggerClientEvent('dpn-mib:client:teleportToCoords', src, GetEntityCoords(GetPlayerPed(target)))
        MIBLog(src, 'GOTO_PLAYER', target, payload.reason)
    elseif action == 'bring' then
        target = tonumber(target)
        if not target or not GetPlayerName(target) then return DPN.Notify(src, 'Invalid target.', 'error') end
        TriggerClientEvent('dpn-mib:client:teleportToCoords', target, GetEntityCoords(GetPlayerPed(src)))
        MIBLog(src, 'BRING_PLAYER', target, payload.reason)
    elseif action == 'spectate' then
        target = tonumber(target)
        if not target or not GetPlayerName(target) then return DPN.Notify(src, 'Invalid target.', 'error') end
        TriggerClientEvent('dpn-mib:client:spectate', src, target); MIBLog(src, 'SPECTATE_PLAYER', target, payload.reason)
    end
end)

AddEventHandler('playerDropped', function() cooldowns[source] = nil end)

local function isDeveloper(src)
    if isAdmin(src) then return true end
    for _, ace in pairs(Config.DeveloperAcePermissions or {}) do
        if ace == 'god' and QBCore.Functions.HasPermission(src, 'god') then return true end
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    return false
end
exports('IsMIBDeveloper', isDeveloper)

RegisterNetEvent('dpn-mib:server:devAction', function(action, target, payload)
    local src = source; payload = payload or {}
    if not isDeveloper(src) then return DPN.Notify(src, 'Developer clearance required.', 'error') end
    if Config.RequireReasonForHighRisk and (action == 'event_tester' or action == 'resource_restart') and (not payload.reason or payload.reason == '') then
        return DPN.Notify(src, 'Developer action requires a reason.', 'error')
    end
    if action == 'pg7x_destination' then
        TriggerClientEvent('dpn-mib:client:pg7xDestination', src, payload.index or 1)
        MIBLog(src, 'PG7X_PORTAL_DESTINATION', nil, 'Destination index '..tostring(payload.index or 1))
    elseif action == 'pg7x_aim' then
        TriggerClientEvent('dpn-mib:client:pg7xAimPortal', src)
        MIBLog(src, 'PG7X_PORTAL_AIM', nil, payload.reason or 'Aim portal')
    elseif action == 'admin_client' or action == 'developer_client' then
        TriggerClientEvent('dpn-mib:client:adminAction', src, payload.clientAction, payload)
        MIBLog(src, 'CLIENT_'..string.upper(payload.clientAction or 'UNKNOWN'), nil, payload.reason or '')
    elseif action == 'announce' then
        local msg = tostring(payload.message or 'DPN MIB announcement')
        TriggerClientEvent('chat:addMessage', -1, { color = {0,255,120}, multiline = true, args = {'DPN MIB', msg} })
        MIBLog(src, 'GLOBAL_ANNOUNCEMENT', nil, msg)
    elseif action == 'weather' then
        TriggerClientEvent('qb-weathersync:client:SyncWeather', -1, payload.weather or 'CLEAR')
        MIBLog(src, 'WEATHER_OVERRIDE', nil, tostring(payload.weather))
    elseif action == 'time' then
        TriggerClientEvent('qb-weathersync:client:SyncTime', -1, tonumber(payload.hour or 12), tonumber(payload.minute or 0))
        MIBLog(src, 'TIME_OVERRIDE', nil, tostring(payload.hour)..':'..tostring(payload.minute))
    elseif action == 'cleanup_world' then
        TriggerClientEvent('dpn-mib:client:cleanupArea', src)
        MIBLog(src, 'DEVELOPER_WORLD_CLEANUP', nil, payload.reason or '')
    elseif action == 'resource_status' then
        local names = {'qb-core','qb-inventory','qb-policejob','qb-ambulancejob','dpn-mdt','dpn-dispatch','dpn-pg-7x','dpn-neuralizer'}
        local rows = {}
        for _, name in ipairs(names) do rows[#rows+1] = name..' = '..GetResourceState(name) end
        TriggerClientEvent('dpn-mib:client:adminAction', src, 'dev_result', { title='Resource Status', text=table.concat(rows, '\n') })
        TriggerClientEvent('dpn-mib:client:devResultDirect', src, 'Resource Status', table.concat(rows, '\n'))
        MIBLog(src, 'RESOURCE_STATUS_CHECK', nil, 'Checked common resources')
    end
end)

RegisterNetEvent('dpn-mib:server:advancedNeuralizer', function(mode, target, reason)
    local src = source; mode = mode or 'beta'
    if not requireAccess(src, 'neuralizer', reason) then return end
    local cfg = (Config.AdvancedNeuralizer.Classes and Config.AdvancedNeuralizer.Classes[mode]) or Config.AdvancedNeuralizer.Classes.beta
    local ok, wait = cooled(src, 'advanced_neuralizer_'..mode, cfg.cooldown or 30)
    if not ok then return DPN.Notify(src, ('Advanced neuralizer charging: %ss'):format(wait), 'error') end
    local srcCoords = GetEntityCoords(GetPlayerPed(src))
    if mode == 'area' then
        TriggerClientEvent('dpn-mib:client:advancedNeuralizeArea', -1, srcCoords, cfg)
        MIBLog(src, 'ADVANCED_NEURALIZER_AREA', nil, reason or cfg.label)
    else
        local targetOk, targetErr, resolvedTarget = validTargetInRange(src, target, cfg.radius, true)
        if not targetOk then return DPN.Notify(src, targetErr, 'error') end
        target = resolvedTarget
        TriggerClientEvent('dpn-mib:client:advancedNeuralizeTarget', target, cfg)
        MIBMemoryLog(src, target, cfg.wipeMinutes or 15, reason or cfg.label)
        MIBLog(src, 'ADVANCED_NEURALIZER_'..string.upper(mode), target, reason or cfg.label)
    end
end)
