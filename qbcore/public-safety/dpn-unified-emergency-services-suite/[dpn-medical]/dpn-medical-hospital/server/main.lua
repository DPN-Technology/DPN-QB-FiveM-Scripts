local QBCore = exports['qb-core']:GetCoreObject()

DPNAdmissions = DPNAdmissions or {}
DPNHospital = DPNHospital or {}

local dischargeCooldowns = {}
local timedStates = {
    [HospitalStates.ADMITTED] = true,
    [HospitalStates.TREATING] = true,
    [HospitalStates.RECOVERY] = true
}

local function GetOnlinePlayerByCitizenId(citizenId)
    local ok, Player = pcall(function()
        return QBCore.Functions.GetPlayerByCitizenId(citizenId)
    end)
    if ok and Player then return Player end

    for _, playerId in pairs(QBCore.Functions.GetPlayers()) do
        local candidate = QBCore.Functions.GetPlayer(playerId)
        if candidate and candidate.PlayerData.citizenid == citizenId then
            return candidate
        end
    end

    return nil
end

local function NormalizeAdmissionRow(row)
    if not row then return nil end
    row.id = tonumber(row.id)
    row.severity = tonumber(row.severity) or 0
    row.recovery_minutes = tonumber(row.recovery_minutes) or 0
    row.remaining_minutes = tonumber(row.remaining_minutes) or 0
    row.bill_amount = tonumber(row.bill_amount) or 0
    return row
end

local function RestoreActiveAdmissions()
    local queryOk, rows = pcall(function()
        return MySQL.query.await(
            'SELECT * FROM dpn_hospital_admissions WHERE status != ? ORDER BY id DESC',
            { HospitalStates.DISCHARGED }
        )
    end)

    if not queryOk then
        print(('[dpn-medical-hospital] DATABASE ERROR: active admissions could not be restored: %s'):format(tostring(rows)))
        print('[dpn-medical-hospital] Verify oxmysql is started and import sql/dpn_medical_hospital.sql.')
        return
    end

    rows = rows or {}
    local restored = 0
    local seenCitizenIds = {}

    for _, rawRow in ipairs(rows) do
        local row = NormalizeAdmissionRow(rawRow)
        if row and row.citizenid then
            if seenCitizenIds[row.citizenid] then
                -- Older duplicate active records can leave ghost beds occupied. Close only the older duplicate.
                MySQL.update.await(
                    'UPDATE dpn_hospital_admissions SET status = ?, discharged_at = NOW() WHERE id = ?',
                    { HospitalStates.DISCHARGED, row.id }
                )
                print(('[dpn-medical-hospital] Closed duplicate active admission %s for %s.'):format(row.id, row.citizenid))
            else
                seenCitizenIds[row.citizenid] = true
                DPNAdmissions[row.citizenid] = row

                local Player = GetOnlinePlayerByCitizenId(row.citizenid)
                local sourceId = Player and Player.PlayerData.source or nil
                local bed = row.bed_id and DPNHospitalBeds[row.bed_id] or nil
                local occupied = false

                if bed then
                    occupied = SetBedOccupied(row.bed_id, sourceId, row.citizenid, {
                        log = false,
                        sync = false
                    })
                end

                if not occupied then
                    local replacement = ClaimAvailableBed(row.hospital, row.ward, sourceId, row.citizenid)
                    if replacement then
                        row.bed_id = replacement.id
                        row.ward = replacement.type
                        MySQL.update.await(
                            'UPDATE dpn_hospital_admissions SET bed_id = ?, ward = ? WHERE id = ?',
                            { row.bed_id, row.ward, row.id }
                        )
                        print(('[dpn-medical-hospital] Reassigned admission %s to bed %s during restore.'):format(row.id, row.bed_id))
                    else
                        print(('[dpn-medical-hospital] Admission %s could not be assigned a bed during restore.'):format(row.id))
                    end
                end

                restored = restored + 1
            end
        end
    end

    SyncHospitalBeds()
    print(('[dpn-medical-hospital] Restored %s active admission(s).'):format(restored))
end

local function SendAdmissionToPlayer(Player, admission)
    if not Player or not admission then return end

    local sourceId = Player.PlayerData.source
    local bed = admission.bed_id and DPNHospitalBeds[admission.bed_id] or nil
    if bed then
        SetBedOccupied(bed.id, sourceId, admission.citizenid, { log = false })
    end

    TriggerClientEvent('dpn-hospital:client:admitted', sourceId, admission, bed)
end

function DischargePatient(citizenId, dischargedBy, force, dischargeReason)
    local admission = DPNAdmissions[citizenId]
    if not admission then return false, 'No active admission found' end

    local remaining = tonumber(admission.remaining_minutes) or 0
    if not force and remaining > 0 then
        return false, ('Patient requires %s more minute(s) of recovery'):format(remaining)
    end

    local billAmount = tonumber(admission.bill_amount) or 0
    if not force and Config.DischargeRequiresPaidBill and billAmount > 0 then
        return false, ('Outstanding hospital bill: $%s'):format(billAmount)
    end

    local reason = type(dischargeReason) == 'string' and dischargeReason:sub(1, 500) or 'Treatment completed'
    local dbOk, affected = pcall(function()
        return MySQL.update.await(
            'UPDATE dpn_hospital_admissions SET status = ?, discharged_at = NOW() WHERE id = ? AND status != ?',
            { HospitalStates.DISCHARGED, admission.id, HospitalStates.DISCHARGED }
        )
    end)

    if not dbOk or not affected or affected < 1 then
        return false, 'Hospital database error; patient was not discharged'
    end

    admission.status = HospitalStates.DISCHARGED

    if admission.bed_id then
        ReleaseBed(admission.bed_id, ('Discharged by %s: %s'):format(tostring(dischargedBy or 'system'), reason))
    end

    DPNAdmissions[citizenId] = nil

    local Player = GetOnlinePlayerByCitizenId(citizenId)
    if Player then
        local hospital = Config.Hospitals[admission.hospital] or Config.Hospitals.pillbox
        TriggerClientEvent('dpn-hospital:client:discharged', Player.PlayerData.source, hospital and hospital.discharge or nil)
        exports['dpn-medical-core']:SetFlag(Player.PlayerData.source, 'admitted', false)
        exports['dpn-medical-core']:RevivePatient(Player.PlayerData.source, { fullHeal = false, by = 'hospital-discharge', coords = hospital and hospital.discharge or nil })
        if GetResourceState('dpn-medical-records') == 'started' then
            pcall(function() exports['dpn-medical-records']:AddEntry(Player.PlayerData.source, 'hospital_discharge', { admissionId=admission.id, reason=reason }, dischargedBy) end)
        end
    end

    return true, admission
end

MySQL.ready(function()
    RestoreActiveAdmissions()
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if not Player or not Player.PlayerData then return end

    local citizenId = Player.PlayerData.citizenid
    local admission = DPNAdmissions[citizenId]

    if not admission then
        local queryOk, row = pcall(function()
            return MySQL.single.await(
                'SELECT * FROM dpn_hospital_admissions WHERE citizenid = ? AND status != ? ORDER BY id DESC LIMIT 1',
                { citizenId, HospitalStates.DISCHARGED }
            )
        end)
        if queryOk then
            admission = NormalizeAdmissionRow(row)
            if admission then DPNAdmissions[citizenId] = admission end
        else
            print(('[dpn-medical-hospital] Player-load admission query failed for %s.'):format(citizenId))
        end
    end

    if admission then SendAdmissionToPlayer(Player, admission) end
end)

CreateThread(function()
    while true do
        Wait(math.max(5, tonumber(Config.RecoveryTickSeconds) or 60) * 1000)

        for citizenId, admission in pairs(DPNAdmissions) do
            local remaining = tonumber(admission.remaining_minutes) or 0
            if timedStates[admission.status] and remaining > 0 then
                local nextRemaining = math.max(0, remaining - 1)
                local dbOk, affected = pcall(function()
                    return MySQL.update.await(
                        'UPDATE dpn_hospital_admissions SET remaining_minutes = ? WHERE id = ?',
                        { nextRemaining, admission.id }
                    )
                end)

                if not dbOk or not affected or affected < 1 then
                    print(('[dpn-medical-hospital] Recovery timer database update failed for admission %s.'):format(tostring(admission.id)))
                    goto continueAdmission
                end

                remaining = nextRemaining
                admission.remaining_minutes = remaining

                local Player = GetOnlinePlayerByCitizenId(citizenId)
                if Player then
                    TriggerClientEvent('dpn-hospital:client:updateAdmission', Player.PlayerData.source, admission)
                end

                if remaining <= 0 and admission.status ~= HospitalStates.RECOVERY then
                    local changed = UpdateAdmissionState(citizenId, HospitalStates.RECOVERY, 'recovery-timer')
                    if changed and Player then
                        DPNHospital.Notify(Player.PlayerData.source, 'You are stable and may request discharge.', 'success')
                    end
                end
            end
            ::continueAdmission::
        end
    end
end)

RegisterNetEvent('dpn-hospital:server:dischargeSelf', function()
    local src = source
    local now = GetGameTimer()
    if now < (dischargeCooldowns[src] or 0) then return end
    dischargeCooldowns[src] = now + (Config.EventCooldownMs or 1500)

    if not Config.AllowSelfDischargeWhenReady then
        DPNHospital.Notify(src, 'Self-discharge is disabled. A medical staff member must clear you.', 'error')
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local ok, result = DischargePatient(
        Player.PlayerData.citizenid,
        Player.PlayerData.citizenid,
        false,
        'Patient requested discharge after recovery'
    )

    if not ok then DPNHospital.Notify(src, result, 'error') end
end)

QBCore.Functions.CreateCallback('dpn-hospital:server:getAdmission', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(nil) return end

    local citizenId = Player.PlayerData.citizenid
    local admission = DPNAdmissions[citizenId]

    if not admission then
        local queryOk, row = pcall(function()
            return MySQL.single.await(
                'SELECT * FROM dpn_hospital_admissions WHERE citizenid = ? AND status != ? ORDER BY id DESC LIMIT 1',
                { citizenId, HospitalStates.DISCHARGED }
            )
        end)
        if queryOk then
            admission = NormalizeAdmissionRow(row)
            if admission then DPNAdmissions[citizenId] = admission end
        else
            print(('[dpn-medical-hospital] Admission callback database query failed for %s.'):format(citizenId))
        end
    end

    local bed = admission and admission.bed_id and DPNHospitalBeds[admission.bed_id] or nil
    cb(admission, bed)
end)

local function JoinArguments(args, startIndex)
    local parts = {}
    for index = startIndex, #args do
        parts[#parts + 1] = tostring(args[index])
    end
    return #parts > 0 and table.concat(parts, ' ') or nil
end

QBCore.Commands.Add(Config.Commands.admit or 'admit', 'Admit a nearby patient to the hospital', {
    { name='id', help='Player server ID' },
    { name='ward', help='er / icu / or / recovery' },
    { name='minutes', help='Recovery minutes (optional)' },
    { name='reason', help='Admission reason (optional)' }
}, false, function(source, args)
    if not DPNHospital.IsStaff(source) then
        DPNHospital.Notify(source, 'You are not authorized to admit patients.', 'error')
        return
    end

    local targetId = tonumber(args[1])
    local ward = NormalizeWard(args[2])
    local minutes = tonumber(args[3])
    local reason = JoinArguments(args, 4)

    if not targetId or (args[2] and not ward) then
        DPNHospital.Notify(source, 'Usage: /admit [id] [er|icu|or|recovery] [minutes] [reason]', 'error')
        return
    end

    local target = QBCore.Functions.GetPlayer(targetId)
    if not target then
        DPNHospital.Notify(source, 'Patient is not online.', 'error')
        return
    end

    if not DPNHospital.IsAdmin(source) and DPNHospital.GetPlayerDistance then
        local distance = DPNHospital.GetPlayerDistance(source, targetId)
        if distance and distance > (Config.StaffAdmissionDistance or 8.0) then
            DPNHospital.Notify(source, 'You are too far away from the patient.', 'error')
            return
        end
    end

    local staff = QBCore.Functions.GetPlayer(source)
    local admittedBy = staff and staff.PlayerData.citizenid or ('console:%s'):format(source)
    local ok, result = AdmitPatient(targetId, 'pillbox', admittedBy, ward, minutes, reason)
    DPNHospital.Notify(source, ok and 'Patient admitted successfully.' or result, ok and 'success' or 'error')
end, 'user')

QBCore.Commands.Add(Config.Commands.discharge or 'dischargepatient', 'Discharge a hospital patient', {
    { name='id', help='Player server ID' },
    { name='reason', help='Discharge reason (optional)' }
}, false, function(source, args)
    if not DPNHospital.IsStaff(source) then
        DPNHospital.Notify(source, 'You are not authorized to discharge patients.', 'error')
        return
    end

    local target = QBCore.Functions.GetPlayer(tonumber(args[1]))
    if not target then
        DPNHospital.Notify(source, 'Patient is not online.', 'error')
        return
    end

    local force = DPNHospital.IsAdmin(source)
    local staff = QBCore.Functions.GetPlayer(source)
    local dischargedBy = staff and staff.PlayerData.citizenid or ('console:%s'):format(source)
    local ok, result = DischargePatient(
        target.PlayerData.citizenid,
        dischargedBy,
        force,
        JoinArguments(args, 2) or 'Cleared by medical staff'
    )
    DPNHospital.Notify(source, ok and 'Patient discharged.' or result, ok and 'success' or 'error')
end, 'user')

QBCore.Commands.Add(Config.Commands.transfer or 'transferpatient', 'Transfer a patient to another hospital ward', {
    { name='id', help='Player server ID' },
    { name='ward', help='er / icu / or / recovery' },
    { name='hospital', help='Hospital ID (optional)' }
}, false, function(source, args)
    if not DPNHospital.IsStaff(source) then
        DPNHospital.Notify(source, 'You are not authorized to transfer patients.', 'error')
        return
    end

    local target = QBCore.Functions.GetPlayer(tonumber(args[1]))
    local ward = NormalizeWard(args[2])
    if not target or not ward then
        DPNHospital.Notify(source, 'Usage: /transferpatient [id] [er|icu|or|recovery] [hospital]', 'error')
        return
    end

    local staff = QBCore.Functions.GetPlayer(source)
    local ok, result = TransferPatient(
        target.PlayerData.citizenid,
        args[3] or nil,
        ward,
        staff and staff.PlayerData.citizenid or source
    )
    DPNHospital.Notify(source, ok and 'Patient transferred.' or result, ok and 'success' or 'error')
end, 'user')

QBCore.Commands.Add(Config.Commands.beds or 'hospitalbeds', 'Show hospital bed availability', {}, false, function(source)
    if not DPNHospital.IsStaff(source) then
        DPNHospital.Notify(source, 'You are not authorized to view the bed census.', 'error')
        return
    end

    local occupied, total = 0, 0
    for _, bed in pairs(DPNHospitalBeds) do
        total = total + 1
        if bed.occupied then occupied = occupied + 1 end
    end

    DPNHospital.Notify(source, ('Hospital beds: %s occupied, %s available, %s total.'):format(occupied, total - occupied, total), 'primary')
end, 'user')

AddEventHandler('playerDropped', function()
    dischargeCooldowns[source] = nil
end)
