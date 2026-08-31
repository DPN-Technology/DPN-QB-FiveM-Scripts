DPNBridge = {}
local QBCore = exports['qb-core']:GetCoreObject()

local function getJobData(src)
    local player = QBCore.Functions.GetPlayer(tonumber(src))
    if not player then return nil, nil end
    return player, player.PlayerData.job or {}
end

function DPNBridge.GetPlayer(src)
    return QBCore.Functions.GetPlayer(tonumber(src))
end

function DPNBridge.GetIdentifier(src)
    local player = DPNBridge.GetPlayer(src)
    return player and player.PlayerData.citizenid or ('src:%s'):format(src)
end

function DPNBridge.GetName(src)
    local player = DPNBridge.GetPlayer(src)
    if not player then return GetPlayerName(src) or ('Officer %s'):format(src) end
    local charinfo = player.PlayerData.charinfo or {}
    return (('%s %s'):format(charinfo.firstname or 'Unknown', charinfo.lastname or 'Officer')):gsub('^%s*(.-)%s*$', '%1')
end

function DPNBridge.GetJob(src)
    local _, job = getJobData(src)
    if not job then return 'unemployed', 0, 'Unemployed', false end
    local grade = job.grade
    if type(grade) == 'table' then grade = grade.level or grade.grade or 0 end
    return job.name or 'unemployed', tonumber(grade) or 0, job.label or job.name or 'Unemployed', job.onduty == true
end

function DPNBridge.IsAllowed(src)
    if src == 0 or IsPlayerAceAllowed(src, 'dpn.officersafety') or IsPlayerAceAllowed(src, 'dpn.leo') then return true end
    local job, _, _, onDuty = DPNBridge.GetJob(src)
    return Config.Jobs[job] == true and onDuty
end

function DPNBridge.HasSupervisor(src)
    if IsPlayerAceAllowed(src, 'dpn.officersafety.supervisor') or IsPlayerAceAllowed(src, 'dpn.supervisor') then return true end
    local job, grade, _, onDuty = DPNBridge.GetJob(src)
    return Config.Jobs[job] == true and onDuty and grade >= 4
end

function DPNBridge.Notify(src, message, kind)
    TriggerClientEvent('dpn-officer-safety:client:notify', src, message, kind or 'primary')
end
