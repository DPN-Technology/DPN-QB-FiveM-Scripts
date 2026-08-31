local QBCore = exports['qb-core']:GetCoreObject()

local paymentLocks = {}

RegisterNetEvent('dpn-hospital:server:payBill', function(admissionId)
    local src = source
    admissionId = tonumber(admissionId)
    if not admissionId or paymentLocks[admissionId] then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    paymentLocks[admissionId] = true

    local chargedAmount = 0
    local ok, err = pcall(function()
        local row = MySQL.single.await(
            'SELECT id, citizenid, bill_amount FROM dpn_hospital_admissions WHERE id = ? AND citizenid = ? LIMIT 1',
            { admissionId, Player.PlayerData.citizenid }
        )

        if not row then
            DPNHospital.Notify(src, 'Hospital bill was not found.', 'error')
            return
        end

        local amount = math.max(0, tonumber(row.bill_amount) or 0)
        if amount <= 0 then
            DPNHospital.Notify(src, 'This hospital bill is already paid.', 'primary')
            return
        end

        if not Player.Functions.RemoveMoney('bank', amount, 'hospital-bill') then
            DPNHospital.Notify(src, 'Not enough money in your bank account.', 'error')
            return
        end
        chargedAmount = amount

        local affected = MySQL.update.await(
            'UPDATE dpn_hospital_admissions SET bill_amount = 0 WHERE id = ? AND citizenid = ? AND bill_amount = ?',
            { admissionId, Player.PlayerData.citizenid, amount }
        )

        if not affected or affected < 1 then
            Player.Functions.AddMoney('bank', amount, 'hospital-bill-refund')
            chargedAmount = 0
            DPNHospital.Notify(src, 'The bill changed before payment completed. Your money was refunded.', 'error')
            return
        end
        chargedAmount = 0

        local admission = DPNAdmissions[Player.PlayerData.citizenid]
        if admission and tonumber(admission.id) == admissionId then
            admission.bill_amount = 0
            TriggerClientEvent('dpn-hospital:client:updateAdmission', src, admission)
        end

        DPNHospital.Notify(src, ('Hospital bill paid: $%s'):format(amount), 'success')
    end)

    paymentLocks[admissionId] = nil

    if not ok then
        if chargedAmount > 0 then
            Player.Functions.AddMoney('bank', chargedAmount, 'hospital-bill-error-refund')
        end
        print(('[dpn-medical-hospital] Bill payment error for admission %s: %s'):format(admissionId, tostring(err)))
        DPNHospital.Notify(src, 'Hospital billing encountered an error. Any charge was refunded.', 'error')
    end
end)
