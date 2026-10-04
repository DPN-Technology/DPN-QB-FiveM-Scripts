local uiOpen = false
local currentCourse = nil
local currentSession = nil
local courseStats = {}

local function notify(msg)
    TriggerEvent('chat:addMessage', { args = { '^3DPN Academy', msg } })
end

RegisterNetEvent('dpn-training-academy:client:notify', function(msg, typ)
    notify(msg)
end)

RegisterCommand(Config.OpenCommand, function()
    TriggerServerEvent('dpn-training-academy:server:requestOpen')
end, false)

RegisterKeyMapping(Config.OpenCommand, 'Open DPN Training Academy', 'keyboard', Config.OpenKey)

RegisterNetEvent('dpn-training-academy:client:openUI', function(payload)
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', payload = payload })
end)

RegisterNUICallback('close', function(_, cb)
    uiOpen = false
    SetNuiFocus(false, false)
    cb(true)
end)

RegisterNUICallback('startCourse', function(data, cb)
    TriggerServerEvent('dpn-training-academy:server:startCourse', data.courseId)
    cb(true)
end)

RegisterNUICallback('createScenario', function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    data.location = { x = coords.x, y = coords.y, z = coords.z }
    TriggerServerEvent('dpn-training-academy:server:createScenario', data)
    cb(true)
end)

RegisterNUICallback('setScenarioTrainee', function(data, cb)
    TriggerServerEvent('dpn-training-academy:server:setScenarioTrainee', data.sessionId, tonumber(data.target), data.enrolled == true)
    cb(true)
end)

RegisterNUICallback('gradeScenario', function(data, cb)
    TriggerServerEvent('dpn-training-academy:server:gradeScenario', data.sessionId, tonumber(data.target), tonumber(data.score), data.notes)
    cb(true)
end)

RegisterNUICallback('endSession', function(data, cb)
    TriggerServerEvent('dpn-training-academy:server:endSession', data.sessionId)
    cb(true)
end)

RegisterNetEvent('dpn-training-academy:client:syncSessions', function(sessions)
    SendNUIMessage({ action = 'sessions', sessions = sessions })
end)

RegisterNetEvent('dpn-training-academy:client:courseStarted', function(sessionId, courseId, course)
    currentSession = sessionId
    currentCourse = course
    courseStats = { started = GetGameTimer(), hits = 0, shots = 0, damage = 0, checkpoints = 0, mistakes = 0 }
    notify(('Started %s. Complete the objective, then use /finishacademy.'):format(course.label))
    if course.location then
        SetNewWaypoint(course.location.x, course.location.y)
    end
end)

RegisterCommand('finishacademy', function()
    if not currentSession or not currentCourse then return notify('No active academy course.') end
    local elapsed = math.floor((GetGameTimer() - courseStats.started) / 1000)
    local timePenalty = 0
    if currentCourse.maxTimeSeconds and elapsed > currentCourse.maxTimeSeconds then
        timePenalty = math.min(30, math.floor((elapsed - currentCourse.maxTimeSeconds) / 10))
    end
    local score = 100 - timePenalty - (courseStats.mistakes * 5) - math.floor((courseStats.damage or 0) / 50)
    if currentCourse.type == 'firearms' and courseStats.shots > 0 then
        local acc = (courseStats.hits / courseStats.shots) * 100
        score = math.floor((score * 0.4) + (acc * 0.6))
    end
    score = math.max(0, math.min(100, score))
    TriggerServerEvent('dpn-training-academy:server:finishCourse', currentSession, {
        score = score,
        elapsed = elapsed,
        stats = courseStats
    })
end, false)

RegisterNetEvent('dpn-training-academy:client:courseFinished', function(status, score)
    notify(('Course %s with %s%%.'):format(status, score))
    currentCourse = nil
    currentSession = nil
    courseStats = {}
end)

AddEventHandler('CEventGunShot', function(_, shooter)
    if currentCourse and currentCourse.type == 'firearms' and shooter == PlayerPedId() then
        courseStats.shots = (courseStats.shots or 0) + 1
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if currentCourse then
            local ped = PlayerPedId()
            if IsPedInjured(ped) then courseStats.mistakes = (courseStats.mistakes or 0) + 1 end
            if IsPedInAnyVehicle(ped, false) and currentCourse.type == 'driving' then
                local veh = GetVehiclePedIsIn(ped, false)
                courseStats.damage = 1000.0 - GetVehicleBodyHealth(veh)
            end
        end
    end
end)

exports('IsInAcademyCourse', function() return currentSession ~= nil end)
exports('AddTrainingHit', function(points)
    if currentCourse then
        courseStats.hits = (courseStats.hits or 0) + 1
        courseStats.scoreBonus = (courseStats.scoreBonus or 0) + (points or 1)
    end
end)
exports('AddTrainingMistake', function(reason)
    if currentCourse then courseStats.mistakes = (courseStats.mistakes or 0) + 1 end
end)
