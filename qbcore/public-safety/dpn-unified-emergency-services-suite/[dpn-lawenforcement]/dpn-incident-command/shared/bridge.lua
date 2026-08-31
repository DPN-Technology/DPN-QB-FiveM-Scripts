DPN_IC_Bridge = {}

function DPN_IC_Bridge.Debug(msg)
    if DPN_IC_Config and DPN_IC_Config.Debug then
        print(('^3[dpn-incident-command]^7 %s'):format(msg))
    end
end

function DPN_IC_Bridge.Notify(source, msg, nType)
    if IsDuplicityVersion() then
        TriggerClientEvent('dpn-incident-command:client:notify', source, msg, nType or 'primary')
    else
        if GetResourceState('qb-core') == 'started' then
            TriggerEvent('QBCore:Notify', msg, nType or 'primary')
            return
        end
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

function DPN_IC_Bridge.GetFramework()
    return GetResourceState('qb-core') == 'started' and 'qbcore' or 'standalone'
end
