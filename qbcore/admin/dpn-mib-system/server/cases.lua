local QBCore = exports['qb-core']:GetCoreObject()
MIBOpenCases = MIBOpenCases or {}
MIBThreatLevel = 'green'

local function agentName(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return ('Source %s'):format(src) end
    local c = P.PlayerData.charinfo or {}
    return ((c.firstname or 'Unknown')..' '..(c.lastname or 'Agent'))
end

function MIBCreateCase(src, data)
    data = data or {}
    local id = ('MIB-%s-%04d'):format(os.date('%Y%m%d'), math.random(1,9999))
    local case = {
        id=id, title=data.title or 'Classified Incident', threat=data.threat or MIBThreatLevel,
        status='open', owner=agentName(src), created=os.time(), notes=data.notes or {}, tags=data.tags or {},
        coords=data.coords, linkedPlayers=data.linkedPlayers or {}
    }
    MIBOpenCases[id] = case
    if Config.LogToDatabase and MySQL then
        MySQL.insert('INSERT INTO dpn_mib_cases (case_id, title, threat, status, owner, data) VALUES (?, ?, ?, ?, ?, ?)', { id, case.title, case.threat, case.status, case.owner, json.encode(case) })
    end
    MIBLog(src, 'CASE_CREATED', nil, id..' | '..case.title)
    return case
end

function MIBAddCaseNote(src, caseId, note)
    local case = MIBOpenCases[caseId]
    if not case then return false end
    case.notes[#case.notes+1] = { time=os.time(), author=agentName(src), text=note }
    if Config.LogToDatabase and MySQL then
        MySQL.update('UPDATE dpn_mib_cases SET data = ? WHERE case_id = ?', { json.encode(case), caseId })
    end
    MIBLog(src, 'CASE_NOTE_ADDED', nil, caseId..' | '..note)
    return true
end

function MIBSetThreatLevel(src, level, reason)
    if not Config.ThreatLevels[level] then return false end
    MIBThreatLevel = level
    TriggerClientEvent('dpn-mib:client:threatLevel', -1, level, Config.ThreatLevels[level].label, reason or 'No reason provided')
    MIBLog(src, 'THREAT_LEVEL_CHANGED', nil, level..' | '..(reason or ''))
    return true
end

QBCore.Functions.CreateCallback('dpn-mib:server:getDashboard', function(src, cb)
    local cases = {}
    for _, case in pairs(MIBOpenCases) do cases[#cases+1] = case end
    local players, counts = {}, { total=0, police=0, ambulance=0, fire=0, mib=0, admin=0 }
    for _, id in pairs(QBCore.Functions.GetPlayers()) do
        local P = QBCore.Functions.GetPlayer(id)
        if P then
            local c, j = P.PlayerData.charinfo or {}, P.PlayerData.job or {}
            counts.total = counts.total + 1
            if counts[j.name] ~= nil then counts[j.name] = counts[j.name] + 1 end
            players[#players+1] = {
                id=id, name=GetPlayerName(id), citizenid=P.PlayerData.citizenid,
                char=((c.firstname or 'Unknown')..' '..(c.lastname or '')), job=j.label or j.name or 'Unknown', grade=j.grade and (j.grade.name or j.grade.level) or 'N/A',
                ping=GetPlayerPing(id), bucket=GetPlayerRoutingBucket(id)
            }
        end
    end
    cb({ threat=MIBThreatLevel, threatLabel=Config.ThreatLevels[MIBThreatLevel].label, cases=cases, locations=Config.BlacksiteLocations, players=players, counts=counts, serverTime=os.date('%H:%M:%S') })
end)
