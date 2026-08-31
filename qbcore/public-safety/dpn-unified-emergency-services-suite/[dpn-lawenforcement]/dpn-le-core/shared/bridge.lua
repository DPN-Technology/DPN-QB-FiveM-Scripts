DPNBridge = DPNBridge or {}
DPNBridge.Framework = 'qb'
DPNBridge.QBCore = nil

local IS_SERVER = IsDuplicityVersion()

local function debugPrint(...)
    if Config and Config.Debug then
        print('^3[dpn-le-core]^7', ...)
    end
end

local function trim(value)
    return tostring(value or ''):gsub('^%s*(.-)%s*$', '%1')
end

function DPNBridge.Init()
    local ok, core = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if not ok or not core then
        print('^1[dpn-le-core] qb-core is required and was not available.^7')
        return false
    end
    DPNBridge.QBCore = core
    debugPrint('QBCore bridge initialized')
    return true
end

function DPNBridge.GetCore()
    if not DPNBridge.QBCore then DPNBridge.Init() end
    return DPNBridge.QBCore
end

function DPNBridge.GetPlayer(src)
    if not IS_SERVER then return nil end
    local core = DPNBridge.GetCore()
    return core and core.Functions.GetPlayer(tonumber(src)) or nil
end

function DPNBridge.GetPlayerData(src)
    if IS_SERVER then
        local player = DPNBridge.GetPlayer(src)
        return player and player.PlayerData or nil
    end
    local core = DPNBridge.GetCore()
    return core and core.Functions.GetPlayerData() or nil
end

function DPNBridge.GetIdentifier(src)
    local data = DPNBridge.GetPlayerData(src)
    if data and data.citizenid then return data.citizenid end
    if IS_SERVER then
        for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
            if identifier:sub(1, 8) == 'license:' then return identifier end
        end
    end
    return ('src:%s'):format(src or 0)
end

function DPNBridge.GetPlayerName(src)
    local data = DPNBridge.GetPlayerData(src)
    local charinfo = data and data.charinfo or nil
    if charinfo then
        local full = trim(('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''))
        if full ~= '' then return full end
    end
    if IS_SERVER then return GetPlayerName(src) or ('Unit %s'):format(src) end
    return GetPlayerName(PlayerId()) or 'Unknown'
end

function DPNBridge.GetJob(src)
    local data = DPNBridge.GetPlayerData(src)
    local job = data and data.job or {}
    local grade = job.grade
    if type(grade) == 'table' then grade = grade.level or grade.grade or 0 end
    return job.name or 'unemployed', tonumber(grade) or 0, job.label or job.name or 'Unemployed', job.onduty == true, job.isboss == true
end

function DPNBridge.GetJobConfig(jobName)
    return Config.AllowedJobs[jobName]
end

function DPNBridge.IsEmergencyJob(src)
    local job, grade, label, onDuty = DPNBridge.GetJob(src)
    return Config.AllowedJobs[job] ~= nil, job, grade, label, onDuty, Config.AllowedJobs[job]
end

function DPNBridge.IsLawEnforcement(src)
    local allowed, job, grade, label, onDuty, definition = DPNBridge.IsEmergencyJob(src)
    return allowed and definition.type == 'law', job, grade, label, onDuty
end

function DPNBridge.IsOnDuty(src)
    local _, _, _, onDuty = DPNBridge.GetJob(src)
    return onDuty
end

function DPNBridge.HasAce(src, ace)
    return IS_SERVER and ace and ace ~= '' and IsPlayerAceAllowed(src, ace) or false
end

function DPNBridge.IsAllowed(src, requireDuty, lawOnly)
    if IS_SERVER and Config.UseAcePerms and DPNBridge.HasAce(src, Config.AdminAce) then
        return true, select(2, DPNBridge.IsEmergencyJob(src))
    end

    local allowed, job, grade, label, onDuty, definition = DPNBridge.IsEmergencyJob(src)
    if not allowed then
        if IS_SERVER and Config.UseAcePerms and DPNBridge.HasAce(src, Config.CommandAce) then
            return true, job, grade, label, onDuty
        end
        return false, job, grade, label, onDuty
    end
    if lawOnly and definition.type ~= 'law' then return false, job, grade, label, onDuty end
    if requireDuty and Config.RequireOnDuty and not onDuty then
        if not (IS_SERVER and DPNBridge.HasAce(src, Config.BypassDutyAce)) then
            return false, job, grade, label, onDuty
        end
    end
    return true, job, grade, label, onDuty
end

function DPNBridge.IsSupervisor(src)
    if IS_SERVER and Config.UseAcePerms and DPNBridge.HasAce(src, Config.AdminAce) then return true end
    local job, grade, _, _, isBoss = DPNBridge.GetJob(src)
    if isBoss then return true end
    return Config.SupervisorGrades[job] ~= nil and grade >= tonumber(Config.SupervisorGrades[job])
end

function DPNBridge.SetDuty(src, state)
    if not IS_SERVER then return false end
    local player = DPNBridge.GetPlayer(src)
    if not player or not player.Functions or not player.Functions.SetJobDuty then return false end
    player.Functions.SetJobDuty(state == true)
    return true
end

function DPNBridge.Notify(src, message, kind, duration)
    message = tostring(message or '')
    kind = kind or 'primary'
    if IS_SERVER then
        if src == 0 then print(('[dpn-le-core] %s'):format(message)) return end
        TriggerClientEvent('QBCore:Notify', src, message, kind, duration or 5000)
    else
        local core = DPNBridge.GetCore()
        if core and core.Functions and core.Functions.Notify then
            core.Functions.Notify(message, kind, duration or 5000)
        end
    end
end

function DPNBridge.GetInventoryItems(src)
    if not IS_SERVER then return {} end
    local player = DPNBridge.GetPlayer(src)
    if not player then return {} end

    local mode = Config.Inventory
    if mode == 'auto' then
        if GetResourceState('ox_inventory') == 'started' then mode = 'ox_inventory'
        elseif GetResourceState('qb-inventory') == 'started' then mode = 'qb-inventory'
        else mode = 'playerdata' end
    end

    if mode == 'ox_inventory' then
        local ok, items = pcall(function() return exports.ox_inventory:GetInventoryItems(src) end)
        if ok and type(items) == 'table' then return items end
    end

    return player.PlayerData.items or {}
end

function DPNBridge.HasItem(src, itemName, amount)
    if not itemName or itemName == '' then return true end
    amount = tonumber(amount) or 1
    local total = 0
    for _, item in pairs(DPNBridge.GetInventoryItems(src)) do
        local name = item.name or item.item
        if name == itemName then total = total + (tonumber(item.amount or item.count) or 0) end
    end
    return total >= amount
end

function DPNBridge.RemoveMoney(src, account, amount, reason)
    if not IS_SERVER then return false end
    local player = DPNBridge.GetPlayer(src)
    if not player or not player.Functions or not player.Functions.RemoveMoney then return false end
    return player.Functions.RemoveMoney(account or 'bank', tonumber(amount) or 0, reason or 'dpn-law-enforcement')
end

DPNBridge.Init()
