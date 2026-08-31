Config = Config or {}

Config.Debug = false
Config.CoreResource = 'dpn-medical-core'
Config.UseTarget = true
Config.TargetResource = 'qb-target'
Config.UseQBManagement = true
Config.BillingResource = 'qb-management'

Config.JobAccess = { ambulance = true, doctor = true, surgeon = true }
Config.SurgeonJobs = { surgeon = true, ambulance = true, doctor = true }
Config.RequireOnDutyForStaffActions = true

Config.CheckInCost = 500
Config.EmergencyAdmissionCost = 1200
Config.ICUDailyCost = 2500
Config.SurgeryDeposit = 3500
Config.SeveritySurchargePerPoint = 8
Config.MaxBillAmount = 25000

Config.RecoveryTickSeconds = 60
Config.MinRecoveryMinutes = 1
Config.MaxRecoveryMinutes = 180
Config.AutoCheckinEnabled = true
Config.RequireEMSOfflineForNPC = false
Config.MinEMSForNoNPC = 1
Config.AllowWardFallback = true
Config.AllowSelfDischargeWhenReady = true
Config.DischargeRequiresPaidBill = false

Config.CheckInInteractionDistance = 6.0
Config.StaffAdmissionDistance = 8.0
Config.EventCooldownMs = 1500

Config.DischargeHealth = 180
Config.DischargeArmor = 0

Config.Commands = {
    status = 'hospitalstatus',
    admit = 'admit',
    discharge = 'dischargepatient',
    transfer = 'transferpatient',
    beds = 'hospitalbeds'
}

Config.Hospitals = {
    pillbox = {
        label = 'Pillbox Medical Center',
        checkIn = vector3(308.09, -595.13, 43.28),
        discharge = vector4(299.21, -584.81, 43.26, 70.0),
        stash = vector3(306.6, -601.7, 43.3),
        beds = {
            { id='PB-ER-01', type='er', label='ER Trauma Bed 1', coords=vector4(314.47,-584.07,44.20,160.0), baseRecovery=8 },
            { id='PB-ER-02', type='er', label='ER Trauma Bed 2', coords=vector4(319.39,-581.55,44.20,340.0), baseRecovery=8 },
            { id='PB-ICU-01', type='icu', label='ICU Bed 1', coords=vector4(322.26,-587.02,44.20,160.0), baseRecovery=18 },
            { id='PB-ICU-02', type='icu', label='ICU Bed 2', coords=vector4(324.22,-582.54,44.20,340.0), baseRecovery=18 },
            { id='PB-OR-01', type='or', label='Operating Room 1', coords=vector4(337.19,-590.64,43.28,65.0), baseRecovery=30 },
            { id='PB-REC-01', type='recovery', label='Recovery Bed 1', coords=vector4(311.21,-597.68,44.20,340.0), baseRecovery=12 }
        }
    }
}

Config.RequiredAdmissionByCondition = {
    cardiac_arrest = { ward='icu', minutes=30, reason='Cardiac arrest recovery and continuous monitoring', priority=100 },
    organ_damage = { ward='or', minutes=40, reason='Organ damage requires surgical intervention', priority=95 },
    internal_bleeding = { ward='or', minutes=35, reason='Internal bleeding requires surgery evaluation', priority=90 },
    shock = { ward='icu', minutes=25, reason='Shock stabilization and critical monitoring', priority=85 },
    low_oxygen = { ward='icu', minutes=22, reason='Critical oxygen saturation instability', priority=80 },
    severe_burn = { ward='er', minutes=20, reason='Severe burn treatment and observation', priority=70 },
    fracture = { ward='er', minutes=15, reason='Fracture stabilization and imaging', priority=55 },
    concussion = { ward='icu', minutes=18, reason='Neurological observation', priority=50 },
    burn = { ward='er', minutes=15, reason='Burn treatment', priority=45 }
}

Config.RecoveryEffects = {
    enabled = true,
    slowWalk = true,
    movementRate = 0.78,
    screenFx = false, -- permanently disabled by the client safety layer
    disableSprintWhenSevere = true,
    disableCombatWhileAdmitted = true,
    disableJumpWhileBedBound = true,
    severeMinutesThreshold = 3
}
