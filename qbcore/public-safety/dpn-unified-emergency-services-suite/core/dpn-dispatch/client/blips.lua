DPNDispatchBlips = DPNDispatchBlips or {}

local ActiveBlips = {}

local function RemoveBlipSafe(blip)
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
end

local function ClearBlips()
    for _, blip in pairs(ActiveBlips) do
        RemoveBlipSafe(blip)
    end
    ActiveBlips = {}
end

local function ShouldShowCall(call, assignedCall)
    if not Config.Blips.enabled then return false end
    if not call or not call.coords then return false end
    if call.status == 'closed' or call.status == 'cancelled' then return false end
    if Config.Blips.showOnlyAssigned then
        if not call.assignedUnits then return false end
        local myServerId = GetPlayerServerId(PlayerId())
        for _, unit in pairs(call.assignedUnits) do
            if tonumber(unit) == myServerId then return true end
        end
        return assignedCall and tonumber(assignedCall) == tonumber(call.id)
    end
    return true
end

function DPNDispatchBlips.Refresh(state, assignedCall)
    ClearBlips()
    if not state or not state.calls then return end

    for _, call in pairs(state.calls) do
        if ShouldShowCall(call, assignedCall) then
            local department = call.primaryDepartment or (call.departments and call.departments[1]) or 'law'
            local departmentConfig = Config.Departments[department] or Config.Departments.law
            local blip = AddBlipForCoord(call.coords.x + 0.0, call.coords.y + 0.0, call.coords.z + 0.0)
            SetBlipSprite(blip, Config.Blips.sprite)
            SetBlipScale(blip, Config.Blips.scale)
            SetBlipColour(blip, departmentConfig.blipColor or 3)
            SetBlipAsShortRange(blip, Config.Blips.shortRange)
            if Config.Blips.flashHighPriority and call.priority == 1 then
                SetBlipFlashes(blip, true)
                SetBlipFlashInterval(blip, 500)
            end
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(('[%s] #%s %s'):format(departmentConfig.short or 'DPN', call.id, call.code or 'CALL'))
            EndTextCommandSetBlipName(blip)
            ActiveBlips[call.id] = blip
        end
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        ClearBlips()
    end
end)
