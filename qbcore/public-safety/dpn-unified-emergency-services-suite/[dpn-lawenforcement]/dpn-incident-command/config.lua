DPN_IC_Config = {}

DPN_IC_Config.Framework = 'qbcore' -- QBCore-only release
DPN_IC_Config.Command = 'ics'
DPN_IC_Config.OpenKey = 'F11'
DPN_IC_Config.RequireDuty = true
DPN_IC_Config.UseAcePermissions = true
DPN_IC_Config.CommandAce = 'dpn.incident.command'
DPN_IC_Config.SupervisorAce = 'dpn.incident.supervisor'

DPN_IC_Config.AllowedJobs = {
    police = true,
    sheriff = true,
    state = true,
    trooper = true,
    ranger = true,
    corrections = true,
    ambulance = true,
    ems = true,
    fire = true,
    dispatch = true
}

DPN_IC_Config.CommandRanks = {
    police = { 4, 5, 6, 7, 8, 9, 10 },
    sheriff = { 4, 5, 6, 7, 8, 9, 10 },
    state = { 4, 5, 6, 7, 8, 9, 10 },
    trooper = { 4, 5, 6, 7, 8, 9, 10 },
    ranger = { 4, 5, 6, 7, 8, 9, 10 },
    corrections = { 4, 5, 6, 7, 8, 9, 10 },
    ambulance = { 3, 4, 5, 6, 7, 8, 9, 10 },
    ems = { 3, 4, 5, 6, 7, 8, 9, 10 },
    fire = { 3, 4, 5, 6, 7, 8, 9, 10 },
    dispatch = { 2, 3, 4, 5, 6, 7, 8, 9, 10 }
}

DPN_IC_Config.DefaultBlip = {
    sprite = 161,
    color = 1,
    scale = 1.0,
    shortRange = false
}

DPN_IC_Config.StagingBlip = { sprite = 280, color = 5, scale = 0.85 }
DPN_IC_Config.RoadblockBlip = { sprite = 58, color = 47, scale = 0.8 }
DPN_IC_Config.SearchGridBlip = { sprite = 9, color = 3, scale = 0.7 }

DPN_IC_Config.Webhooks = {
    enabled = false,
    url = ''
}

DPN_IC_Config.MaxActiveIncidents = 25
DPN_IC_Config.AutoArchiveHours = 6
DPN_IC_Config.Debug = false
