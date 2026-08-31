DPN = DPN or {}

function DPN.Debug(msg)
    if Config.Debug then print(('[dpn-smart-city] %s'):format(msg)) end
end

function DPN.Distance(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

function DPN.Round(num, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

function DPN.PlateTrim(plate)
    if not plate then return '' end
    return string.upper((plate:gsub('%s+', '')))
end

function DPN.Clock()
    return os.date('%Y-%m-%d %H:%M:%S')
end
