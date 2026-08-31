Config = {}

-- PD Reception Location (vector3: x, y, z)
Config.PDReception = vector3(442.73, -982.18, 31.78) -- Mission Row PD desk; adjust for your server

-- Interaction Settings
Config.InteractDistance = 2.0 -- Meters for proximity check
Config.UseTarget = false -- Set to false if no qb-target; uses F3 key instead
Config.BellModel = `prop_wall_light_10a` -- Doorbell prop model (optional visual)

-- Job Settings
Config.PoliceJob = 'police' -- Job name
Config.RequiredGrade = 0 -- Minimum police grade to receive notifications

-- Cooldown (ms)
Config.Cooldown = 30000 -- 30 seconds per player

-- Notifications
Config.RingText = 'Ring Doorbell'
Config.PoliceNotifyTitle = 'PD Reception'
Config.PoliceNotifyMessage = 'Someone is at the reception desk!'
Config.RingerNotify = 'You rang the doorbell. Police notified.'

-- Sound (GTA native)
Config.BellSound = 'DLC_EXEC_SECU_DOOR_UNLOCK' -- Doorbell-like sound; change if needed