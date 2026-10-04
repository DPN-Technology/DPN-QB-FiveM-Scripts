local ActiveSessions = {}
local InstructorSessions = {}

local function now() return os.time() end
local function makeId(prefix) return ('%s-%s-%04d'):format(prefix, os.time(), math.random(1000, 9999)) end


local function clean(value, maxLength)
    return tostring(value or ''):gsub('[%z-]', ''):sub(1, maxLength or 255)
end

local function getCoords(src)
    local ok, result = pcall(function()
        local ped = GetPlayerPed(src)
        if not ped or ped <= 0 or not DoesEntityExist(ped) then return nil end
        local coords = GetEntityCoords(ped)
        return { x=coords.x, y=coords.y, z=coords.z }
    end)
    return ok and result or nil
end

local function broadcastSessions()
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        if target and DPN.Bridge.IsLEO(target) then
            TriggerClientEvent('dpn-training-academy:client:syncSessions', target, ActiveSessions)
        end
    end
end

local function isAcademyAdmin(src)
    return Config.AceAdmin and IsPlayerAceAllowed(src, Config.AceAdmin) == true
end

local function canManageScenario(src, session)
    if type(session) ~= 'table' or session.type ~= 'scenario' then return false end
    if session.status == 'closed' or session.status == 'abandoned' then return false end
    if session.instructor == src and InstructorSessions[src] == session.id then return true end
    return session.instructor == 0 and isAcademyAdmin(src)
end

local function enrolledTrainee(session, targetServerId)
    targetServerId = tonumber(targetServerId)
    if not targetServerId or not DPN.Bridge.IsLEO(targetServerId) then return nil, nil end
    local identifier = DPN.Bridge.GetIdentifier(targetServerId)
    if not identifier or identifier == '' then return nil, nil end
    local trainee = session.trainees and session.trainees[identifier] or nil
    return trainee, identifier
end

local function calculateCourseScore(course, session, scoreData)
    scoreData = type(scoreData) == 'table' and scoreData or {}
    local stats = type(scoreData.stats) == 'table' and scoreData.stats or {}
    local elapsed = math.max(0, now() - (session.startedAt or now()))
    local overtime = math.max(0, elapsed - (tonumber(course.maxTimeSeconds) or elapsed))
    local timePenalty = math.min(35, math.floor(overtime / 10))
    local mistakes = math.max(0, math.min(50, math.floor(tonumber(stats.mistakes) or 0)))
    local score
    if course.type == 'firearms' then
        local shots = math.max(0, math.min(200, math.floor(tonumber(stats.shots) or 0)))
        local hits = math.max(0, math.min(shots, math.floor(tonumber(stats.hits) or 0)))
        local accuracy = shots > 0 and (hits / shots) * 100 or 0
        local missing = math.max(0, (tonumber(course.targets) or 0) - shots)
        score = math.floor(accuracy * 0.75 + math.max(0, 100 - timePenalty) * 0.25 - mistakes * 3 - missing * 4)
        stats.shots, stats.hits, stats.accuracy = shots, hits, math.floor(accuracy + 0.5)
    elseif course.type == 'driving' then
        local damage = math.max(0, math.min(1000, tonumber(stats.damage) or 0))
        score = math.floor(100 - timePenalty - mistakes * 5 - damage / 20)
        stats.damage = math.floor(damage)
    else
        score = math.floor(100 - timePenalty - mistakes * 5)
    end
    score = math.max(0, math.min(100, score))
    return score, elapsed, { stats=stats, elapsed=elapsed, serverCalculated=true }
end

local function dbReady()
    return GetResourceState('oxmysql') == 'started'
end

local function insertAudit(src, action, details)
    if not dbReady() then return end
    MySQL.insert('INSERT INTO dpn_academy_audit (identifier, name, action, details, created_at) VALUES (?, ?, ?, ?, NOW())', {
        DPN.Bridge.GetIdentifier(src), DPN.Bridge.GetName(src), action, json.encode(details or {})
    })
end

local function getProfile(src, cb)
    local identifier = DPN.Bridge.GetIdentifier(src)
    if not dbReady() then cb({ identifier = identifier, name = DPN.Bridge.GetName(src), certs = {}, records = {} }) return end
    MySQL.query('SELECT * FROM dpn_academy_records WHERE identifier = ? ORDER BY created_at DESC LIMIT 100', { identifier }, function(records)
        MySQL.query('SELECT * FROM dpn_academy_certs WHERE identifier = ?', { identifier }, function(certs)
            cb({ identifier = identifier, name = DPN.Bridge.GetName(src), certs = certs or {}, records = records or {} })
        end)
    end)
end

RegisterNetEvent('dpn-training-academy:server:requestOpen', function()
    local src = source
    if not DPN.Bridge.IsLEO(src) then return DPN.Bridge.Notify(src, 'Access denied.', 'error') end
    getProfile(src, function(profile)
        TriggerClientEvent('dpn-training-academy:client:openUI', src, {
            profile = profile,
            courses = Config.Courses,
            certs = Config.Certifications,
            scenarios = Config.ScenarioPresets,
            instructor = DPN.Bridge.IsInstructor(src),
            sessions = ActiveSessions
        })
    end)
end)

RegisterNetEvent('dpn-training-academy:server:startCourse', function(courseId)
    local src = source
    local course = Config.Courses[courseId]
    if not course or not DPN.Bridge.IsLEO(src) then return end
    local sid = makeId('COURSE')
    ActiveSessions[sid] = {
        id = sid, type = 'course', courseId = courseId, label = course.label,
        trainee = src, traineeName = DPN.Bridge.GetName(src), identifier = DPN.Bridge.GetIdentifier(src),
        startedAt = now(), status = 'active', score = 0
    }
    insertAudit(src, 'start_course', { session = sid, course = courseId })
    TriggerClientEvent('dpn-training-academy:client:courseStarted', src, sid, courseId, course)
end)

RegisterNetEvent('dpn-training-academy:server:finishCourse', function(sessionId, scoreData)
    local src = source
    sessionId = clean(sessionId, 64)
    local session = ActiveSessions[sessionId]
    if not session or session.trainee ~= src or not DPN.Bridge.IsLEO(src) then return end
    local course = Config.Courses[session.courseId]
    local cert = course and Config.Certifications[course.cert]
    if not course or not cert then return end
    local duration = now() - (session.startedAt or now())
    if duration < (Config.MinimumCourseSeconds or 15) then
        return DPN.Bridge.Notify(src, 'Course completion was rejected because the minimum training time was not met.', 'error')
    end
    local score, elapsed, verifiedData = calculateCourseScore(course, session, scoreData)
    local passed = score >= cert.minScore
    session.status = passed and 'passed' or 'failed'
    session.score = score
    session.endedAt = now()
    session.elapsed = elapsed

    if dbReady() then
        MySQL.insert('INSERT INTO dpn_academy_records (session_id, identifier, name, course_id, course_label, score, passed, notes, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())', {
            sessionId, session.identifier, session.traineeName, session.courseId, course.label, score, passed and 1 or 0, json.encode(verifiedData)
        })
        if passed then
            local expiryDays = math.max(1, math.min(3650, math.floor(tonumber(cert.expiresDays or Config.DefaultCertExpiryDays) or 90)))
            local expiresAt = os.date('%Y-%m-%d %H:%M:%S', now() + (expiryDays * 86400))
            local certQuery = [[INSERT INTO dpn_academy_certs (identifier, name, cert_id, cert_label, score, issued_at, expires_at)
                VALUES (?, ?, ?, ?, ?, NOW(), ?)
                ON DUPLICATE KEY UPDATE score = VALUES(score), issued_at = NOW(), expires_at = VALUES(expires_at), cert_label = VALUES(cert_label)]]
            MySQL.update(certQuery, {
                session.identifier, session.traineeName, course.cert, cert.label, score, expiresAt
            })
        end
    end

    if GetResourceState('dpn-evidence-ai') == 'started' then
        exports['dpn-evidence-ai']:AddSystemRecord('other', ('Training %s: %s scored %s'):format(session.status, session.traineeName, score), {
            sessionId = sessionId, courseId = session.courseId, score = score, passed = passed, elapsed = elapsed
        }, 'DPN Training Academy')
    end

    insertAudit(src, 'finish_course', { session = sessionId, score = score, passed = passed, elapsed = elapsed })
    DPN.Bridge.Log('Training Course Finished', ('%s finished %s with %s%% (%s)'):format(session.traineeName, course.label, score, session.status))
    TriggerClientEvent('dpn-training-academy:client:courseFinished', src, session.status, score)
    broadcastSessions()
end)

RegisterNetEvent('dpn-training-academy:server:createScenario', function(data)
    local src = source
    if not DPN.Bridge.IsInstructor(src) then return DPN.Bridge.Notify(src, 'Instructor access required.', 'error') end
    local existingId = InstructorSessions[src]
    local existing = existingId and ActiveSessions[existingId] or nil
    if existing and existing.status ~= 'closed' and existing.status ~= 'abandoned' then
        return DPN.Bridge.Notify(src, ('End active scenario %s before creating another.'):format(existingId), 'error')
    end
    InstructorSessions[src] = nil
    data = type(data) == 'table' and data or {}
    local presetId = clean(data.preset or 'traffic_stop', 64)
    local preset = Config.ScenarioPresets[presetId] or Config.ScenarioPresets.traffic_stop
    local sid = makeId('SCENE')
    ActiveSessions[sid] = {
        id = sid, type = 'scenario', preset = presetId, label = clean(data.label ~= '' and data.label or preset.label, 120),
        instructor = src, instructorName = DPN.Bridge.GetName(src), startedAt = now(), status = 'staged',
        location = getCoords(src), trainees = {}, notes = clean(data.notes or '', 2000)
    }
    InstructorSessions[src] = sid
    insertAudit(src, 'create_scenario', ActiveSessions[sid])
    broadcastSessions()
    if GetResourceState('dpn-digital-dispatch') == 'started' then
        exports['dpn-digital-dispatch']:CreateDispatchCall({
            type = 'training', title = ActiveSessions[sid].label,
            description = ('Training scenario %s is active.'):format(sid),
            priority = 4, coords = ActiveSessions[sid].location,
            departments = { 'law', 'fire', 'medical', 'dispatch' },
            metadata = { sessionId = sid, training = true }
        }, 0)
    end
end)

RegisterNetEvent('dpn-training-academy:server:setScenarioTrainee', function(sessionId, targetServerId, enrolled)
    local src = source
    if not DPN.Bridge.IsInstructor(src) then return DPN.Bridge.Notify(src, 'Instructor access required.', 'error') end
    sessionId = clean(sessionId, 64)
    local session = ActiveSessions[sessionId]
    if not canManageScenario(src, session) then
        return DPN.Bridge.Notify(src, 'You do not own that active training scenario.', 'error')
    end
    targetServerId = tonumber(targetServerId)
    if not targetServerId or not DPN.Bridge.IsLEO(targetServerId) then
        return DPN.Bridge.Notify(src, 'Trainee must be an online emergency-services member.', 'error')
    end
    local identifier = DPN.Bridge.GetIdentifier(targetServerId)
    if not identifier or identifier == '' then return DPN.Bridge.Notify(src, 'Unable to resolve trainee identity.', 'error') end
    session.trainees = session.trainees or {}
    if enrolled == false then
        if not session.trainees[identifier] then return DPN.Bridge.Notify(src, 'That member is not enrolled in this scenario.', 'error') end
        session.trainees[identifier] = nil
        insertAudit(src, 'remove_scenario_trainee', { session = sessionId, target = identifier })
        DPN.Bridge.Notify(src, 'Trainee removed from scenario.', 'success')
        TriggerClientEvent('dpn-training-academy:client:notify', targetServerId, ('Removed from training scenario %s.'):format(session.label), 'primary')
    else
        session.trainees[identifier] = {
            identifier = identifier,
            source = targetServerId,
            name = DPN.Bridge.GetName(targetServerId),
            enrolledAt = now()
        }
        insertAudit(src, 'enroll_scenario_trainee', { session = sessionId, target = identifier })
        DPN.Bridge.Notify(src, 'Trainee enrolled in scenario.', 'success')
        TriggerClientEvent('dpn-training-academy:client:notify', targetServerId, ('Enrolled in training scenario %s.'):format(session.label), 'primary')
    end
    broadcastSessions()
end)

RegisterNetEvent('dpn-training-academy:server:gradeScenario', function(sessionId, targetServerId, score, notes)
    local src = source
    if not DPN.Bridge.IsInstructor(src) then return DPN.Bridge.Notify(src, 'Instructor access required.', 'error') end
    sessionId = clean(sessionId, 64)
    local session = ActiveSessions[sessionId]
    if not canManageScenario(src, session) then
        return DPN.Bridge.Notify(src, 'You do not own that active training scenario.', 'error')
    end
    local trainee, identifier = enrolledTrainee(session, targetServerId)
    if not trainee then
        return DPN.Bridge.Notify(src, 'Target must be enrolled in this scenario before grading.', 'error')
    end
    targetServerId = tonumber(targetServerId)
    score = math.max(0, math.min(100, math.floor(tonumber(score) or 0)))
    notes = clean(notes or '', 2000)
    local name = trainee.name or DPN.Bridge.GetName(targetServerId)
    if dbReady() then
        MySQL.insert('INSERT INTO dpn_academy_records (session_id, identifier, name, course_id, course_label, score, passed, notes, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())', {
            sessionId, identifier, name, session.preset or 'scenario', session.label, score, score >= 80 and 1 or 0, notes or ''
        })
    end
    trainee.lastScore = score
    trainee.lastGradedAt = now()
    trainee.lastGradedBy = DPN.Bridge.GetIdentifier(src)
    TriggerClientEvent('dpn-training-academy:client:notify', targetServerId, ('Scenario graded: %s%%'):format(score), 'primary')
    insertAudit(src, 'grade_scenario', { session = sessionId, target = identifier, score = score })
    broadcastSessions()
end)

RegisterNetEvent('dpn-training-academy:server:endSession', function(sessionId)
    local src = source
    sessionId = clean(sessionId, 64)
    if not DPN.Bridge.IsInstructor(src) then return DPN.Bridge.Notify(src, 'Instructor access required.', 'error') end
    local session = ActiveSessions[sessionId]
    if not canManageScenario(src, session) then
        return DPN.Bridge.Notify(src, 'You do not own that active training scenario.', 'error')
    end
    session.status = 'closed'
    session.endedAt = now()
    if session.instructor == src and InstructorSessions[src] == sessionId then InstructorSessions[src] = nil end
    insertAudit(src, 'end_session', { session = sessionId })
    broadcastSessions()
end)

AddEventHandler('playerDropped', function()
    local src = source
    local sessionId = InstructorSessions[src]
    local session = sessionId and ActiveSessions[sessionId] or nil
    if session and session.instructor == src and session.status ~= 'closed' then
        session.status = 'abandoned'
        session.endedAt = now()
    end
    InstructorSessions[src] = nil
    if session then broadcastSessions() end
end)

libCallback = libCallback or {}

exports('GetAcademyProfile', function(source, cb) getProfile(source, cb) end)
exports('HasCertification', function(source, certId, cb)
    local identifier = DPN.Bridge.GetIdentifier(source)
    if not dbReady() then cb(false) return end
    MySQL.scalar('SELECT COUNT(*) FROM dpn_academy_certs WHERE identifier = ? AND cert_id = ? AND expires_at > NOW()', { identifier, certId }, function(count)
        cb((count or 0) > 0)
    end)
end)
exports('CreateScenario', function(data)
    data = type(data) == 'table' and data or {}
    local sid = makeId('SCENE')
    ActiveSessions[sid] = {
        id = sid,
        type = 'scenario',
        preset = clean(data.preset or 'external', 64),
        label = clean(data.label or 'External Training Scenario', 120),
        instructor = 0,
        instructorName = clean(data.instructorName or 'DPN System', 120),
        ownerResource = clean(GetInvokingResource() or 'dpn-training-academy', 120),
        startedAt = now(),
        status = 'staged',
        location = type(data.location) == 'table' and {
            x = tonumber(data.location.x) or 0.0,
            y = tonumber(data.location.y) or 0.0,
            z = tonumber(data.location.z) or 0.0
        } or nil,
        trainees = {},
        notes = clean(data.notes or '', 2000)
    }
    insertAudit(0, 'create_external_scenario', { session = sid, preset = ActiveSessions[sid].preset })
    broadcastSessions()
    return sid
end)
