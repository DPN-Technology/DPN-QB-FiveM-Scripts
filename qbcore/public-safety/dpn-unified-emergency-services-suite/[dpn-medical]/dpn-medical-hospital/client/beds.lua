local function safeFadeOut(duration)
    duration = tonumber(duration) or 300
    DoScreenFadeOut(duration)
    local timeout = GetGameTimer() + math.max(1500, duration + 1000)
    while not IsScreenFadedOut() and GetGameTimer() < timeout do Wait(0) end
end

RegisterNetEvent('dpn-hospital:client:forceBed', function(coords)
    if not coords or coords.x == nil or coords.y == nil or coords.z == nil then return end

    local ped = PlayerPedId()
    safeFadeOut(300)

    local ok, err = pcall(function()
        ClearPedTasksImmediately(ped)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z - 1.0, false, false, false)
        SetEntityHeading(ped, coords.w or 0.0)
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_SUNBATHE_BACK', 0, true)
        Wait(200)
    end)

    DoScreenFadeIn(500)
    if not ok then print(('[dpn-medical-hospital] forced bed placement failed: %s'):format(err)) end
end)
