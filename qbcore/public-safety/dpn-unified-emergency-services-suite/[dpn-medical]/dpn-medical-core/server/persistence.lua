MedicalStates = MedicalStates or {}
DPNMedicalStorage = DPNMedicalStorage or {}

local function dbEnabled()
    return Config.Persistence.enabled and MySQL ~= nil
end

function DPNMedicalStorage.Load(citizenid)
    if not citizenid then return DPN_MED.NewBodyState() end
    if not dbEnabled() then return DPN_MED.NewBodyState() end

    local ok, row = pcall(function()
        return MySQL.single.await('SELECT state FROM dpn_medical_states WHERE citizenid = ?', { citizenid })
    end)

    if not ok then
        print(('[dpn-medical-core] Database load failed for %s: %s'):format(citizenid, tostring(row)))
        return DPN_MED.NewBodyState()
    end

    if row and row.state then
        local decodedOk, decoded = pcall(json.decode, row.state)
        if decodedOk and type(decoded) == 'table' then return DPN_MED.NormalizeState(decoded) end
    end

    return DPN_MED.NewBodyState()
end

function DPNMedicalStorage.Save(citizenid, state)
    if not citizenid or not state or not dbEnabled() then return false end
    local payload = json.encode(DPN_MED.NormalizeState(state))
    local ok, err = pcall(function()
        MySQL.insert.await([[
            INSERT INTO dpn_medical_states (citizenid, state, updated_at)
            VALUES (?, ?, NOW())
            ON DUPLICATE KEY UPDATE state = VALUES(state), updated_at = NOW()
        ]], { citizenid, payload })
    end)
    if not ok then print(('[dpn-medical-core] Database save failed for %s: %s'):format(citizenid, tostring(err))) end
    return ok
end

function DPNMedicalStorage.Log(citizenid, eventType, data)
    if not Config.Persistence.eventLogging or not citizenid or not dbEnabled() then return end
    local ok, err = pcall(function()
        MySQL.insert('INSERT INTO dpn_medical_events (citizenid, event_type, event_data) VALUES (?, ?, ?)', {
            citizenid,
            tostring(eventType or 'unknown'):sub(1, 64),
            json.encode(data or {})
        })
    end)
    if not ok and Config.Debug then print(('[dpn-medical-core] Event log failed: %s'):format(tostring(err))) end
end

CreateThread(function()
    Wait(15000)
    if not dbEnabled() then return end
    local days = tonumber(Config.Persistence.pruneEventsAfterDays) or 0
    if days <= 0 then return end
    pcall(function()
        MySQL.query.await(('DELETE FROM dpn_medical_events WHERE created_at < DATE_SUB(NOW(), INTERVAL %d DAY)'):format(days))
    end)
end)
