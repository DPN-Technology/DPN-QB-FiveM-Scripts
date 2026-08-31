DPNDrone = DPNDrone or {}

function DPNDrone.Debug(msg)
    if Config and Config.Debug then
        print(('[dpn-drone-command] %s'):format(msg))
    end
end

function DPNDrone.Notify(msg, typ)
    typ = typ or 'primary'
    if GetResourceState('qb-core') == 'started' then
        TriggerEvent('QBCore:Notify', msg, typ)
        return
    end
    print(('[DPN Drone] %s'):format(msg))
end

function DPNDrone.HasResource(name)
    return GetResourceState(name) == 'started'
end
