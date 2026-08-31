local QBCore = exports['qb-core']:GetCoreObject()

function MIBLog(src, action, target, notes)
    local Player = QBCore.Functions.GetPlayer(src); if not Player then return 'MIB-NOCASE' end
    local ped=GetPlayerPed(src); local coords=ped and GetEntityCoords(ped) or vector3(0,0,0)
    local citizenid=Player.PlayerData.citizenid
    local targetCid,targetName=nil,nil
    if target then local T=QBCore.Functions.GetPlayer(tonumber(target)); if T then targetCid=T.PlayerData.citizenid; targetName=('%s %s'):format(T.PlayerData.charinfo.firstname or '',T.PlayerData.charinfo.lastname or '') end end
    local caseCode=('MIB-%s-%04d'):format(os.date('%y%m%d%H%M%S'),math.random(1000,9999))
    if Config.LogToDatabase and MySQL then
        MySQL.insert('INSERT INTO dpn_mib_action_logs (case_code, agent_citizenid, target_citizenid, action, notes, coords) VALUES (?, ?, ?, ?, ?, ?)', { caseCode,citizenid,targetCid,action,notes or '',('%.2f, %.2f, %.2f'):format(coords.x,coords.y,coords.z) })
    end
    if Config.DiscordWebhook and Config.DiscordWebhook~='' then
        PerformHttpRequest(Config.DiscordWebhook,function() end,'POST',json.encode({username='DPN MIB Logs',embeds={{title=action,color=11184810,fields={{name='Agent',value=(GetPlayerName(src) or 'Unknown')..' / '..citizenid,inline=false},{name='Target',value=targetName or tostring(target or 'N/A'),inline=false},{name='Case',value=caseCode,inline=true},{name='Notes',value=notes or 'None',inline=false}}}}}),{['Content-Type']='application/json'})
    end
    return caseCode
end

function MIBMemoryLog(src,target,minutes,reason)
    local Player=QBCore.Functions.GetPlayer(src); local T=QBCore.Functions.GetPlayer(tonumber(target)); if not Player or not T then return end
    if Config.LogToDatabase and MySQL then
        MySQL.insert('INSERT INTO dpn_mib_memory_wipes (target_citizenid, target_name, agent_citizenid, duration_minutes, reason) VALUES (?, ?, ?, ?, ?)', { T.PlayerData.citizenid,('%s %s'):format(T.PlayerData.charinfo.firstname or '',T.PlayerData.charinfo.lastname or ''),Player.PlayerData.citizenid,minutes,reason or '' })
    end
end
