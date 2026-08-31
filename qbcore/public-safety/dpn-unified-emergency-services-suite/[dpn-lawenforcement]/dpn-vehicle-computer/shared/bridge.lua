DPNVC = DPNVC or {}

function DPNVC.Debug(msg)
    if Config.Debug then
        print(('^3[dpn-vehicle-computer]^7 %s'):format(msg))
    end
end

function DPNVC.TableCount(tbl)
    local c = 0
    for _ in pairs(tbl or {}) do c = c + 1 end
    return c
end

function DPNVC.Trim(str)
    return (str or ''):gsub('^%s*(.-)%s*$', '%1')
end
