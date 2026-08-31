DPN = DPN or {}
DPN.Bridge = {}
DPN.Bridge.Framework = 'qbcore'

function DPN.Bridge.Notify(src, message, kind)
    kind = kind or 'primary'
    if IsDuplicityVersion() then
        TriggerClientEvent('dpn-training-academy:client:notify', src, message, kind)
    else
        TriggerEvent('QBCore:Notify', message, kind)
    end
end

if IsDuplicityVersion() then
    local QBCore = exports['qb-core']:GetCoreObject()

    local function player(src)
        return QBCore.Functions.GetPlayer(tonumber(src))
    end

    function DPN.Bridge.GetIdentifier(src)
        local current = player(src)
        return current and current.PlayerData.citizenid or ('src:' .. src)
    end

    function DPN.Bridge.GetName(src)
        local current = player(src)
        if not current then return GetPlayerName(src) or ('Trainee ' .. src) end
        local charinfo = current.PlayerData.charinfo or {}
        return (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1')
    end

    function DPN.Bridge.GetJob(src)
        local current = player(src)
        local job = current and current.PlayerData.job or {}
        local grade = job.grade
        if type(grade) == 'table' then grade = grade.level or grade.grade or 0 end
        return job.name or 'unemployed', tonumber(grade) or 0, job.onduty == true, job.isboss == true
    end

    function DPN.Bridge.IsLEO(src)
        if IsPlayerAceAllowed(src, Config.AceInstructor) or IsPlayerAceAllowed(src, Config.AceAdmin) then return true end
        local job, _, onDuty = DPN.Bridge.GetJob(src)
        return Config.AllowedJobs[job] == true and (not Config.RequireDuty or onDuty)
    end

    function DPN.Bridge.IsInstructor(src)
        if IsPlayerAceAllowed(src, Config.AceInstructor) or IsPlayerAceAllowed(src, Config.AceAdmin) then return true end
        local job, grade, onDuty, isBoss = DPN.Bridge.GetJob(src)
        return Config.AllowedJobs[job] == true and (not Config.RequireDuty or onDuty) and (isBoss or Config.InstructorGrades[grade] == true)
    end

    function DPN.Bridge.Log(title, message)
        print(('[DPN Academy] %s: %s'):format(title, message))
        if Config.Webhook and Config.Webhook ~= '' then
            PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
                username = 'DPN Training Academy',
                embeds = {{ title = title, description = message, color = 16753920 }}
            }), { ['Content-Type'] = 'application/json' })
        end
    end
end
