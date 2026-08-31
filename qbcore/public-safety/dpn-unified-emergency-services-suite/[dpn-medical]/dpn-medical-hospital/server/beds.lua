local QBCore = exports['qb-core']:GetCoreObject()

DPNHospital = DPNHospital or {}
DPNHospitalBeds = DPNHospitalBeds or {}

function DPNHospital.Notify(src, message, messageType)
    if src and src > 0 then
        TriggerClientEvent('QBCore:Notify', src, message, messageType or 'primary')
    elseif src == 0 then
        print(('[dpn-medical-hospital] %s'):format(tostring(message)))
    end
end

function DPNHospital.IsAdmin(src)
    if src == 0 then return true end
    if not src or src < 1 then return false end

    local ok, allowed = pcall(function()
        return QBCore.Functions.HasPermission(src, 'god')
            or QBCore.Functions.HasPermission(src, 'admin')
    end)

    return ok and allowed == true
end

local function BuildBeds()
    DPNHospitalBeds = {}

    for hospitalId, hospital in pairs(Config.Hospitals or {}) do
        for _, configuredBed in ipairs(hospital.beds or {}) do
            local ward = NormalizeWard(configuredBed.type)
            if configuredBed.id and ward and configuredBed.coords then
                DPNHospitalBeds[configuredBed.id] = {
                    id = configuredBed.id,
                    hospital = hospitalId,
                    type = ward,
                    label = configuredBed.label or configuredBed.id,
                    coords = configuredBed.coords,
                    baseRecovery = tonumber(configuredBed.baseRecovery) or 10,
                    occupied = false,
                    citizenid = nil,
                    source = nil
                }
            else
                print(('[dpn-medical-hospital] Skipping invalid bed configuration in hospital %s.'):format(tostring(hospitalId)))
            end
        end
    end
end

function GetPublicBeds()
    local publicBeds = {}

    for bedId, bed in pairs(DPNHospitalBeds) do
        publicBeds[bedId] = {
            id = bed.id,
            hospital = bed.hospital,
            type = bed.type,
            label = bed.label,
            baseRecovery = bed.baseRecovery,
            occupied = bed.occupied == true
        }
    end

    return publicBeds
end

function SyncHospitalBeds(target)
    TriggerClientEvent('dpn-hospital:client:syncBeds', target or -1, GetPublicBeds())
end

function GetAvailableBed(hospitalId, ward, allowFallback)
    hospitalId = type(hospitalId) == 'string' and hospitalId or 'pillbox'
    ward = NormalizeWard(ward) or WardTypes.ER

    for _, bed in pairs(DPNHospitalBeds) do
        if bed.hospital == hospitalId and bed.type == ward and not bed.occupied then
            return bed
        end
    end

    if allowFallback == false or Config.AllowWardFallback == false then
        return nil
    end

    for _, bed in pairs(DPNHospitalBeds) do
        if bed.hospital == hospitalId and not bed.occupied then
            return bed
        end
    end

    return nil
end

function SetBedOccupied(bedId, src, citizenid, options)
    local bed = DPNHospitalBeds[bedId]
    if not bed then return false, 'Unknown hospital bed' end

    if bed.occupied and bed.citizenid and bed.citizenid ~= citizenid then
        return false, 'Hospital bed is already occupied'
    end

    bed.occupied = true
    bed.source = tonumber(src)
    bed.citizenid = citizenid

    options = options or {}
    if options.log ~= false then
        MySQL.insert('INSERT INTO dpn_hospital_bed_log (bed_id, hospital, citizenid, action, notes) VALUES (?, ?, ?, ?, ?)', {
            bedId,
            bed.hospital,
            citizenid,
            options.action or 'occupied',
            options.notes or ''
        })
    end

    if options.sync ~= false then SyncHospitalBeds() end
    return true, bed
end

function ClaimAvailableBed(hospitalId, ward, src, citizenid)
    local bed = GetAvailableBed(hospitalId, ward, Config.AllowWardFallback)
    if not bed then return nil, 'No available hospital beds' end

    local ok, result = SetBedOccupied(bed.id, src, citizenid, {
        action = 'reserved',
        notes = ('Requested ward: %s'):format(tostring(ward))
    })

    if not ok then return nil, result end
    return bed
end

function ReleaseBed(bedId, reason, options)
    local bed = DPNHospitalBeds[bedId]
    if not bed then return false, 'Unknown hospital bed' end

    options = options or {}
    local previousCitizenId = bed.citizenid

    if options.log ~= false then
        MySQL.insert('INSERT INTO dpn_hospital_bed_log (bed_id, hospital, citizenid, action, notes) VALUES (?, ?, ?, ?, ?)', {
            bedId,
            bed.hospital,
            previousCitizenId,
            'released',
            tostring(reason or ''):sub(1, 500)
        })
    end

    bed.occupied = false
    bed.source = nil
    bed.citizenid = nil

    if options.sync ~= false then SyncHospitalBeds() end
    return true
end

QBCore.Functions.CreateCallback('dpn-hospital:server:getBeds', function(_, cb)
    cb(GetPublicBeds())
end)

RegisterNetEvent('dpn-hospital:server:releaseBed', function(bedId)
    local src = source
    local authorized = DPNHospital.IsAdmin(src)

    if not authorized and DPNHospital.IsStaff then
        authorized = DPNHospital.IsStaff(src)
    end

    if not authorized then
        DPNHospital.Notify(src, 'You are not authorized to release hospital beds.', 'error')
        return
    end

    local bed = DPNHospitalBeds[tostring(bedId or '')]
    if not bed then
        DPNHospital.Notify(src, 'That hospital bed does not exist.', 'error')
        return
    end

    if bed.citizenid and DPNAdmissions and DPNAdmissions[bed.citizenid] then
        DPNHospital.Notify(src, 'Discharge or transfer the patient before releasing this bed.', 'error')
        return
    end

    local ok, err = ReleaseBed(bed.id, ('Manual release by source %s'):format(src))
    DPNHospital.Notify(src, ok and ('Released bed %s.'):format(bed.id) or err, ok and 'success' or 'error')
end)

AddEventHandler('playerDropped', function()
    local src = source
    for _, bed in pairs(DPNHospitalBeds) do
        if bed.source == src then
            -- Admissions are persistent. Keep the bed occupied but clear the stale server ID.
            bed.source = nil
        end
    end
end)

BuildBeds()
