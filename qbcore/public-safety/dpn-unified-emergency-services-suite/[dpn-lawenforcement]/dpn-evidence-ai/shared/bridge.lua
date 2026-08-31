DPN_EvidenceBridge = {}
local QBCore = exports['qb-core']:GetCoreObject()

local function gradeLevel(job)
    local grade = job and job.grade or 0
    if type(grade) == 'table' then return tonumber(grade.level or grade.grade) or 0 end
    return tonumber(grade) or 0
end

function DPN_EvidenceBridge.GetPlayer(src)
    return QBCore.Functions.GetPlayer(tonumber(src))
end

function DPN_EvidenceBridge.GetOfficer(src)
    local player = DPN_EvidenceBridge.GetPlayer(src)
    if not player then return nil end
    local data = player.PlayerData or {}
    local charinfo = data.charinfo or {}
    local job = data.job or {}
    return {
        identifier = data.citizenid or tostring(src),
        name = (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1'),
        job = job.name or 'unemployed',
        grade = gradeLevel(job),
        onDuty = job.onduty == true,
        isBoss = job.isboss == true
    }
end

function DPN_EvidenceBridge.IsLEO(src)
    if IsPlayerAceAllowed(src, Config.AdminAce) then return true end
    local officer = DPN_EvidenceBridge.GetOfficer(src)
    return officer and Config.Jobs[officer.job] == true and officer.onDuty
end

function DPN_EvidenceBridge.IsSupervisor(src)
    if IsPlayerAceAllowed(src, Config.AdminAce) then return true end
    local officer = DPN_EvidenceBridge.GetOfficer(src)
    if not officer or not Config.Jobs[officer.job] or not officer.onDuty then return false end
    if officer.isBoss then return true end
    for _, grade in ipairs(Config.SupervisorGrades) do
        if officer.grade == tonumber(grade) then return true end
    end
    return false
end

function DPN_EvidenceBridge.Notify(src, message, kind)
    TriggerClientEvent('dpn-evidence-ai:client:notify', src, message, kind or 'primary')
end
