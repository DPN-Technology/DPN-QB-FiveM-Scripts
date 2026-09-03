-- DPN Technology — Phase 3F bounded medical-dispatch deduplication
DPNMedicalDispatchDedup = DPNMedicalDispatchDedup or {}

local Dedup = DPNMedicalDispatchDedup
local entries = {}
local DEFAULT_WINDOW = 90
local MAX_ENTRIES = 512

local function now() return os.time() end

local function clean(current)
    local count = 0
    for key, entry in pairs(entries) do
        if entry.expiresAt <= current then
            entries[key] = nil
        else
            count = count + 1
        end
    end
    if count <= MAX_ENTRIES then return end
    local ordered = {}
    for key, entry in pairs(entries) do
        ordered[#ordered + 1] = { key = key, createdAt = entry.createdAt }
    end
    table.sort(ordered, function(a, b) return a.createdAt < b.createdAt end)
    for i = 1, math.max(0, #ordered - MAX_ENTRIES) do
        entries[ordered[i].key] = nil
    end
end

local function stableKey(data)
    if type(data) ~= 'table' then return nil end
    local key = data.correlationId or data.eventId or data.dispatchCallId or data.incidentId or data.medicalCallId
    if key == nil or tostring(key) == '' then return nil end
    return tostring(key):sub(1, 160)
end

function Dedup.Create(data, createFn)
    data = type(data) == 'table' and data or {}
    if type(createFn) ~= 'function' then return false, 'missing-create-function' end
    local current = now()
    clean(current)
    local key = stableKey(data)
    if not key then
        return createFn(data)
    end
    local existing = entries[key]
    if existing and existing.expiresAt > current then
        return true, existing.call, 'reused'
    end
    local ok, call, extra = createFn(data)
    if ok and type(call) == 'table' then
        call.correlationId = call.correlationId or key
        entries[key] = {
            call = call,
            createdAt = current,
            expiresAt = current + math.max(15, tonumber(data.dedupWindowSeconds) or DEFAULT_WINDOW)
        }
    end
    return ok, call, extra or 'created'
end

function Dedup.GetStats()
    clean(now())
    local count = 0
    for _ in pairs(entries) do count = count + 1 end
    return { entries = count, maxEntries = MAX_ENTRIES, defaultWindowSeconds = DEFAULT_WINDOW }
end

exports('GetMedicalDispatchDedupStats', function()
    return Dedup.GetStats()
end)
