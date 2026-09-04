local QBCore = exports['qb-core']:GetCoreObject()

DPNAdmissions = DPNAdmissions or {}
DPNHospital = DPNHospital or {}

local cooldowns = {}
local admissionLocks = {}

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.max(minimum, math.min(maximum, value))
end

local function SafeText(value, fallback, maxLength)
    value = type(value) == 'string' and value or fallback
    value = value:gsub('[%c]', ' '):gsub('%s+', ' ')
    return value:sub(1, maxLength or 255)
end

local function GetPlayerDistance(srcA, srcB)
    local pedA = GetPlayerPed(srcA)
    local pedB = GetPlayerPed(srcB)
    if pedA == 0 or pedB == 0 then return nil end

    local a = GetEntityCoords(pedA)
    local b = GetEntityCoords(pedB)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

DPNHospital.GetPlayerDistance = GetPlayerDistance

local function GetDistanceFromCoords(src, targetCoords)
    local ped = GetPlayerPed(src)
    if ped == 0 or not targetCoords then return nil end

    local current = GetEntityCoords(ped)
    local dx = current.x - targetCoords.x
    local dy = current.y - targetCoords.y
    local dz = current.z - targetCoords.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function PassesCooldown(src, key)
    local now = GetGameTimer()
    cooldowns[src] = cooldowns[src] or {}
    local expires = cooldowns[src][key] or 0

    if now < expires then return false end
    cooldowns[src][key] = now + (tonumber(Config.EventCooldownMs) or 1500)
    return true
end

function DPNHospital.IsStaff(src)
    if DPNHospital.IsAdmin(src) then return true end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end

    local job = Player.PlayerData.job or {}
    if Config.JobAccess[job.name] ~= true then return false end
    if Config.RequireOnDutyForStaffActions and job.onduty ~= true then return false end

    return true
end

local function GetPatientName(Player)
    local charInfo = Player.PlayerData.charinfo or {}
    return SafeText(('%s %s'):format(charInfo.firstname or 'Unknown', charInfo.lastname or 'Patient'), 'Unknown Patient', 128)
end

local function CalculateSeverity(coreState)
    if type(coreState) ~= 'table' then return 10 end

    local severity = 0
    local vitals = type(coreState.vitals) == 'table' and coreState.vitals or {}
    local blood = tonumber(vitals.blood) or 5000
    local spo2 = tonumber(vitals.spo2) or 99
    local pain = tonumber(vitals.pain) or 0

    severity = severity + math.max(0, 5000 - blood) / 45
    severity = severity + math.max(0, 95 - spo2) * 4
    severity = severity + Clamp(pain, 0, 100) * 0.55

    if vitals.shock then severity = severity + 30 end
    if vitals.cardiacArrest then severity = severity + 100 end

    if type(coreState.injuries) == 'table' then
        for _, injury in pairs(coreState.injuries) do
            if type(injury) == 'table' then
                severity = severity + Clamp(injury.damage, 0, 100) * 0.25
                if injury.internalBleeding then severity = severity + 25 end
                if injury.organDamage then severity = severity + 30 end
                if injury.fracture then severity = severity + 15 end
                if injury.burn then severity = severity + 10 end
            end
        end
    end

    return math.floor(Clamp(severity, 0, 100))
end

local function GetConditionRecommendation(coreState)
    if type(coreState) ~= 'table' then return nil end

    local matches = {}
    local vitals = type(coreState.vitals) == 'table' and coreState.vitals or {}

    if vitals.cardiacArrest then matches.cardiac_arrest = true end
    if vitals.shock then matches.shock = true end
    if tonumber(vitals.spo2) and tonumber(vitals.spo2) < 88 then matches.low_oxygen = true end

    if type(coreState.conditions) == 'table' then
        for condition, active in pairs(coreState.conditions) do
            if active then matches[condition] = true end
        end
    end

    if type(coreState.injuries) == 'table' then
        for _, injury in pairs(coreState.injuries) do
            if type(injury) == 'table' then
                if injury.organDamage then matches.organ_damage = true end
                if injury.internalBleeding then matches.internal_bleeding = true end
                if injury.fracture then matches.fracture = true end
                if injury.concussion then matches.concussion = true end
                if injury.burn then
                    matches.burn = true
                    if (tonumber(injury.damage) or 0) >= 60 then matches.severe_burn = true end
                end
            end
        end
    end

    local best
    for condition in pairs(matches) do
        local recommendation = Config.RequiredAdmissionByCondition[condition]
        if recommendation and (not best or (recommendation.priority or 0) > (best.priority or 0)) then
            best = recommendation
        end
    end

    return best
end

local function RecommendWard(coreState)
    local recommendation = GetConditionRecommendation(coreState)
    if recommendation then
        return recommendation.ward, recommendation.minutes, recommendation.reason
    end

    return WardTypes.ER, 12, 'Emergency treatment and observation'
end

local function GetMedicalState(targetSrc)
    if GetResourceState(Config.CoreResource) ~= 'started' then return nil end

    local ok, state = pcall(function()
        return exports[Config.CoreResource]:GetMedicalState(targetSrc)
    end)

    if not ok then
        print(('[dpn-medical-hospital] GetMedicalState failed for source %s: %s'):format(targetSrc, tostring(state)))
        return nil
    end

    return state
end

local function CalculateBill(ward, severity)
    local amount = tonumber(Config.EmergencyAdmissionCost) or 0

    if ward == WardTypes.ICU then
        amount = amount + (tonumber(Config.ICUDailyCost) or 0)
    elseif ward == WardTypes.OPERATING_ROOM then
        amount = amount + (tonumber(Config.SurgeryDeposit) or 0)
    end

    amount = amount + (severity * (tonumber(Config.SeveritySurchargePerPoint) or 0))
    return math.floor(Clamp(amount, 0, tonumber(Config.MaxBillAmount) or 25000))
end

local function HasActiveAdmission(citizenId)
    local cached = DPNAdmissions[citizenId]
    if cached and cached.status ~= HospitalStates.DISCHARGED then
        return true, cached
    end

    local row = MySQL.single.await(
        'SELECT * FROM dpn_hospital_admissions WHERE citizenid = ? AND status != ? ORDER BY id DESC LIMIT 1',
        { citizenId, HospitalStates.DISCHARGED }
    )

    if row then
        DPNAdmissions[citizenId] = row
        return true, row
    end

    return false
end

function AdmitPatient(targetSrc, hospitalId, admittedBy, forcedWard, forcedMinutes, reason)
    targetSrc = tonumber(targetSrc)
    local Patient = targetSrc and QBCore.Functions.GetPlayer(targetSrc) or nil
    if not Patient then return false, 'Patient is not online' end

    hospitalId = type(hospitalId) == 'string' and hospitalId or 'pillbox'
    local hospital = Config.Hospitals[hospitalId]
    if not hospital then return false, 'Unknown hospital location' end

    local citizenId = Patient.PlayerData.citizenid
    if admissionLocks[citizenId] then return false, 'An admission is already being processed for this patient' end
    admissionLocks[citizenId] = true

    local function Finish(ok, result)
        admissionLocks[citizenId] = nil
        return ok, result
    end

    local activeCheckOk, alreadyAdmitted = pcall(HasActiveAdmission, citizenId)
    if not activeCheckOk then
        print(('[dpn-medical-hospital] Active-admission lookup failed for %s: %s'):format(citizenId, tostring(alreadyAdmitted)))
        return Finish(false, 'Hospital database error; admission could not be verified')
    end
    if alreadyAdmitted then return Finish(false, 'Patient already has an active hospital admission') end

    local coreState = GetMedicalState(targetSrc)
    local recommendedWard, recommendedMinutes, recommendedReason = RecommendWard(coreState)
    local ward = NormalizeWard(forcedWard) or NormalizeWard(recommendedWard) or WardTypes.ER
    local minutes = Clamp(forcedMinutes or recommendedMinutes, Config.MinRecoveryMinutes or 1, Config.MaxRecoveryMinutes or 180)
    reason = SafeText(reason, recommendedReason or 'Medical admission', 500)

    local bed, bedError = ClaimAvailableBed(hospitalId, ward, targetSrc, citizenId)
    if not bed then return Finish(false, bedError or 'No available hospital beds') end

    -- If the requested ward was full and fallback selected another ward, store the actual ward.
    ward = bed.type
    minutes = math.max(minutes, tonumber(bed.baseRecovery) or 1)

    local severity = CalculateSeverity(coreState)
    local bill = CalculateBill(ward, severity)
    local patientName = GetPatientName(Patient)

    local ok, insertId = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO dpn_hospital_admissions
                (citizenid, patient_name, hospital, bed_id, ward, status, reason, admitted_by, severity, recovery_minutes, remaining_minutes, bill_amount)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            citizenId,
            patientName,
            hospitalId,
            bed.id,
            ward,
            HospitalStates.ADMITTED,
            reason,
            SafeText(admittedBy, 'system', 64),
            severity,
            minutes,
            minutes,
            bill
        })
    end)

    if not ok or not insertId then
        ReleaseBed(bed.id, 'Admission database insert failed')
        print(('[dpn-medical-hospital] Failed to create admission for %s: %s'):format(citizenId, tostring(insertId)))
        return Finish(false, 'Hospital database error; admission was cancelled')
    end

    local admission = {
        id = insertId,
        citizenid = citizenId,
        patient_name = patientName,
        hospital = hospitalId,
        bed_id = bed.id,
        ward = ward,
        status = HospitalStates.ADMITTED,
        severity = severity,
        recovery_minutes = minutes,
        remaining_minutes = minutes,
        reason = reason,
        admitted_by = admittedBy or 'system',
        bill_amount = bill
    }

    DPNAdmissions[citizenId] = admission

    if GetResourceState('dpn-medical-records') == 'started' then
        pcall(function() exports['dpn-medical-records']:AddEntry(targetSrc, 'hospital_admission', { admissionId=admission.id, ward=ward, bed=bed.id, reason=reason, severity=severity }, admittedBy) end)
    end
    if GetResourceState('dpn-medical-billing-plus') == 'started' and bill > 0 then
        local billed = pcall(function() exports['dpn-medical-billing-plus']:CreateInvoice(targetSrc, bill, ('Hospital admission - %s'):format(GetWardLabel(ward)), 'hospital', admittedBy) end)
        if billed then
            admission.bill_amount = 0
            MySQL.update('UPDATE dpn_hospital_admissions SET bill_amount = 0 WHERE id = ?', { admission.id })
        end
    end

    exports['dpn-medical-core']:SetFlag(targetSrc, 'admitted', true)
    TriggerClientEvent('dpn-hospital:client:admitted', targetSrc, admission, bed)
    DPNHospital.Notify(targetSrc, ('Admitted to %s: %s'):format(GetWardLabel(ward), reason), 'primary')

    return Finish(true, admission)
end

function UpdateAdmissionState(citizenId, newState, changedBy)
    local admission = DPNAdmissions[citizenId]
    if not admission then return false, 'No active admission found' end
    if not IsValidHospitalState(newState) then return false, 'Invalid hospital state' end
    if admission.status == newState then return true, admission end
    if not CanTransitionHospitalState(admission.status, newState) then
        return false, ('Invalid state transition from %s to %s'):format(admission.status, newState)
    end

    local dbOk, affected = pcall(function()
        return MySQL.update.await(
            'UPDATE dpn_hospital_admissions SET status = ? WHERE id = ? AND status = ?',
            { newState, admission.id, admission.status }
        )
    end)

    if not dbOk or not affected or affected < 1 then
        return false, 'Hospital database error; status was not changed'
    end

    admission.status = newState

    local Player = nil
    if QBCore.Functions.GetPlayerByCitizenId then
        local ok, result = pcall(QBCore.Functions.GetPlayerByCitizenId, citizenId)
        if ok then Player = result end
    end
    if Player then
        TriggerClientEvent('dpn-hospital:client:updateAdmission', Player.PlayerData.source, admission)
        DPNHospital.Notify(Player.PlayerData.source, ('Hospital status updated: %s'):format(GetHospitalStateLabel(newState)), 'primary')
    end

    if Config.Debug then
        print(('[dpn-medical-hospital] Admission %s state changed to %s by %s'):format(admission.id, newState, tostring(changedBy)))
    end

    return true, admission
end

function TransferPatient(citizenId, hospitalId, ward, changedBy)
    local admission = DPNAdmissions[citizenId]
    if not admission then return false, 'No active admission found' end

    hospitalId = hospitalId or admission.hospital
    if not Config.Hospitals[hospitalId] then return false, 'Unknown hospital location' end

    ward = NormalizeWard(ward)
    if not ward then return false, 'Invalid hospital ward' end
    if admission.hospital == hospitalId and admission.ward == ward then
        return false, 'Patient is already assigned to that hospital ward'
    end

    local Player = nil
    if QBCore.Functions.GetPlayerByCitizenId then
        local ok, result = pcall(QBCore.Functions.GetPlayerByCitizenId, citizenId)
        if ok then Player = result end
    end
    local sourceId = Player and Player.PlayerData.source or nil
    local newBed, err = ClaimAvailableBed(hospitalId, ward, sourceId, citizenId)
    if not newBed then return false, err end

    local oldBedId = admission.bed_id
    local oldHospitalId = admission.hospital
    local oldWard = admission.ward
    admission.hospital = hospitalId
    admission.bed_id = newBed.id
    admission.ward = newBed.type

    local dbOk, updated = pcall(function()
        return MySQL.update.await(
            'UPDATE dpn_hospital_admissions SET hospital = ?, bed_id = ?, ward = ? WHERE id = ?',
            { admission.hospital, admission.bed_id, admission.ward, admission.id }
        )
    end)

    if not dbOk or not updated or updated < 1 then
        admission.hospital = oldHospitalId
        admission.bed_id = oldBedId
        admission.ward = oldWard
        ReleaseBed(newBed.id, 'Transfer database update failed')
        return false, 'Hospital database error; transfer cancelled'
    end

    if oldBedId and oldBedId ~= newBed.id then
        ReleaseBed(oldBedId, ('Transferred by %s'):format(tostring(changedBy)))
    end

    if sourceId then
        TriggerClientEvent('dpn-hospital:client:admitted', sourceId, admission, newBed)
        DPNHospital.Notify(sourceId, ('Transferred to %s, bed %s.'):format(GetWardLabel(admission.ward), newBed.id), 'primary')
    end

    return true, admission
end

RegisterNetEvent('dpn-hospital:server:admitNearest', function(targetId, ward, minutes, reason)
    local src = source
    if not PassesCooldown(src, 'admit') then return end

    if not DPNHospital.IsStaff(src) then
        DPNHospital.Notify(src, 'You are not authorized to admit patients.', 'error')
        return
    end

    targetId = tonumber(targetId)
    local targetPlayer = targetId and QBCore.Functions.GetPlayer(targetId) or nil
    if not targetPlayer then
        DPNHospital.Notify(src, 'Patient is not online.', 'error')
        return
    end

    if not DPNHospital.IsAdmin(src) then
        local distance = GetPlayerDistance(src, targetId)
        if type(distance) ~= 'number' then
            DPNHospital.Notify(src, 'Unable to verify patient proximity.', 'error')
            return
        end

        local maxDistance = tonumber(Config.StaffAdmissionDistance) or 8.0
        if distance > maxDistance then
            DPNHospital.Notify(src, 'You are too far away from the patient.', 'error')
            return
        end
    end

    local staff = QBCore.Functions.GetPlayer(src)
    local staffCitizenId = staff and staff.PlayerData.citizenid or ('source:%s'):format(src)
    local ok, result = AdmitPatient(targetId, 'pillbox', staffCitizenId, ward, minutes, reason)
    DPNHospital.Notify(src, ok and 'Patient admitted successfully.' or result, ok and 'success' or 'error')
end)

RegisterNetEvent('dpn-hospital:server:selfCheckIn', function(hospitalId)
    local src = source
    if not PassesCooldown(src, 'selfCheckIn') then return end

    if not Config.AutoCheckinEnabled then
        DPNHospital.Notify(src, 'Self check-in is currently unavailable.', 'error')
        return
    end

    hospitalId = type(hospitalId) == 'string' and hospitalId or 'pillbox'
    local hospital = Config.Hospitals[hospitalId]
    if not hospital then
        DPNHospital.Notify(src, 'Unknown hospital location.', 'error')
        return
    end

    local distance = GetDistanceFromCoords(src, hospital.checkIn)
    if type(distance) ~= 'number' then
        DPNHospital.Notify(src, 'Unable to verify hospital check-in proximity.', 'error')
        return
    end

    local maxDistance = tonumber(Config.CheckInInteractionDistance) or 6.0
    if distance > maxDistance then
        DPNHospital.Notify(src, 'You must be at the hospital check-in desk.', 'error')
        return
    end

    local emsOnDuty = 0
    for _, id in pairs(QBCore.Functions.GetPlayers()) do
        local player = QBCore.Functions.GetPlayer(id)
        local job = player and player.PlayerData.job or nil
        if job and Config.JobAccess[job.name] and job.onduty then
            emsOnDuty = emsOnDuty + 1
        end
    end

    if Config.RequireEMSOfflineForNPC and emsOnDuty >= (Config.MinEMSForNoNPC or 1) then
        DPNHospital.Notify(src, 'Medical staff are available. Please request treatment from them.', 'error')
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local charge = tonumber(Config.CheckInCost) or 0
    if charge > 0 and not Player.Functions.RemoveMoney('bank', charge, 'hospital-checkin') then
        DPNHospital.Notify(src, 'Not enough money in your bank account for check-in.', 'error')
        return
    end

    local ok, result = AdmitPatient(src, hospitalId, 'npc-checkin', nil, nil, 'Hospital self check-in')
    if not ok and charge > 0 then
        Player.Functions.AddMoney('bank', charge, 'hospital-checkin-refund')
    end

    DPNHospital.Notify(src, ok and 'Hospital check-in complete.' or result, ok and 'success' or 'error')
end)

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)