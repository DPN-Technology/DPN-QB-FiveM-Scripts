DPN = DPN or {}

function DPN.Debug(msg)
    if Config.Debug then print(('[dpn-mib-system] %s'):format(msg)) end
end

function DPN.Notify(src, msg, typ, time)
    typ = typ or 'primary'
    time = time or 4500
    if IsDuplicityVersion() then
        TriggerClientEvent('QBCore:Notify', src, msg, typ, time)
    else
        TriggerEvent('QBCore:Notify', msg, typ, time)
    end
end

function DPN.Trim(s)
    return (s:gsub('^%s*(.-)%s*$', '%1'))
end
