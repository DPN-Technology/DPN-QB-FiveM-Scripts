DPNDispatch = DPNDispatch or {}

function DPNDispatch.Debug(msg)
    if Config and Config.Debug then
        print(('^3[dpn-digital-dispatch]^7 %s'):format(msg))
    end
end

function DPNDispatch.HasCore()
    return GetResourceState(Config.CoreResource) == 'started'
end

function DPNDispatch.Notify(src, msg, typ)
    if src and src > 0 then
        TriggerClientEvent('dpn_dispatch:client:notify', src, msg, typ or 'primary')
    end
end

function DPNDispatch.GenerateCallId()
    return ('DPN-%s-%04d'):format(os.date('%H%M%S'), math.random(1000, 9999))
end
