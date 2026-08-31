exports('CreateCall', function(data)
    if not DPNDispatchServer or not DPNDispatchServer.CreateCall then return nil end
    local id, call = DPNDispatchServer.CreateCall(data or {}, 0)
    return id, call
end)

exports('UpdateCall', function(callId, changes)
    if not DPNDispatchServer or not DPNDispatchServer.UpdateCall then return false end
    return DPNDispatchServer.UpdateCall(callId, changes or {}, 0)
end)

exports('GetCalls', function()
    if not DPNDispatchServer or not DPNDispatchServer.GetCalls then return {} end
    return DPNDispatchServer.GetCalls()
end)

exports('GetUnits', function()
    if not DPNDispatchServer or not DPNDispatchServer.GetUnits then return {} end
    return DPNDispatchServer.GetUnits()
end)

exports('CreateReport', function(data)
    if not DPNDispatchServer or not DPNDispatchServer.CreateReport then return false end
    return DPNDispatchServer.CreateReport(data or {}, 0)
end)

exports('UpdateReport', function(reportId, changes)
    if not DPNDispatchServer or not DPNDispatchServer.UpdateReport then return false end
    return DPNDispatchServer.UpdateReport(reportId, changes or {}, 0)
end)

exports('GetReports', function()
    if not DPNDispatchServer or not DPNDispatchServer.GetReports then return {} end
    return DPNDispatchServer.GetReports()
end)

exports('BroadcastState', function()
    if DPNDispatchServer and DPNDispatchServer.BroadcastState then DPNDispatchServer.BroadcastState() end
end)


exports('SyncMdt', function(src)
    if not DPNDispatchServer or not DPNDispatchServer.SyncMdtFor then return false end
    return DPNDispatchServer.SyncMdtFor(src or 0)
end)
