Config = {}

-- Interaction Settings
Config.InteractDistance = 2.0 -- Meters to detect/sit
Config.UseTarget = true -- Set to false if no qb-target; uses E key proximity
Config.SitKey = 38 -- E key (0 for disabled)
Config.Cooldown = 5000 -- ms between sits

-- Animations (customizable)
Config.SitAnimDict = 'amb@world_human_picnic@male@idle_a' -- Sitting idle
Config.SitAnimName = 'idle_a'
Config.StandAnimDict = 'amb@world_human_picnic@male@exit' -- Standing up
Config.StandAnimName = 'exit'
Config.GroundSitAnimDict = 'amb@world_human_sit_ground@male@idle_a' -- For /sitground
Config.GroundSitAnimName = 'idle_a'

-- Seat Detection (common GTA V chair/bench props; add more hashes as needed)
Config.SeatModels = {
    `prop_chair_01a`, `prop_chair_02a`, `prop_chair_03a`, `prop_chair_04a`, `prop_chair_05a`,
    `prop_chair_06a`, `prop_chair_07a`, `prop_chair_08a`, `prop_chair_09a`, `prop_chair_10a`,
    `prop_bench_01a`, `prop_bench_02a`, `prop_bench_03a`, `prop_bench_04a`, `prop_bench_05a`,
    `prop_stool_01a`, `prop_stool_02a`, `prop_stool_03a`, `prop_bar_stool_01a`, `prop_bar_stool_02a`,
    `prop_couch_01a`, `prop_couch_02a`, `prop_couch_03a`, `prop_sofa_01a`, `prop_sofa_02a`,
    `v_ilev_chair02`, `v_ilev_chair03`, `v_ilev_chair04`, `v_res_j_armchair`, `v_res_m_armchair`,
    `p_amb_lounger_01_s`, `p_amb_lounger_02_s`, `prop_ld_gazebo_02`, `prop_barrel_pile_03a`,
    `hei_prop_yah_seat_03a`, `hei_prop_yah_seat_04a`, `bkr_prop_club_chair_01a`, `bkr_prop_club_chair_02a`,
    `gr_prop_gr_chair_02a`, `gr_prop_gr_chair_03a`, `xm_prop_base_chair_01a`, `xm_prop_base_chair_02a`
    -- Add more: Use GetHashKey('model_name') in a test script to get hashes
}

-- Offset for player position on seat (adjust per seat type if needed; x,y,z, rotation)
Config.SeatOffset = vector4(0.0, 0.0, 0.0, 0.0) -- Default; customize in code for specific models

-- Notifications
Config.SitNotify = 'You sat down.'
Config.StandNotify = 'You stood up.'
Config.NoSeatNotify = 'No seat nearby.'
Config.CooldownNotify = 'Wait before sitting again.'