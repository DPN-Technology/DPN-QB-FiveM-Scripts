DPNDispatch = DPNDispatch or {}

function DPNDispatch.DebugPrint(...)
    if Config and Config.Debug then
        print('[dpn-dispatch]', ...)
    end
end

function DPNDispatch.TableContains(tbl, value)
    if not tbl then return false end
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

function DPNDispatch.JobInDepartment(jobName, departmentName)
    if not jobName or not departmentName then return false end
    local department = Config.Departments[departmentName]
    if not department or not department.jobs then return false end
    return DPNDispatch.TableContains(department.jobs, jobName)
end

function DPNDispatch.GetDepartmentByJob(jobName)
    local found = {}
    if not jobName then return found end
    for departmentName in pairs(Config.Departments) do
        if DPNDispatch.JobInDepartment(jobName, departmentName) then
            found[#found + 1] = departmentName
        end
    end
    return found
end

function DPNDispatch.NormalizeDepartments(value)
    local departments = {}

    if type(value) == 'string' then
        if value == 'all' then
            for name in pairs(Config.Departments) do departments[#departments + 1] = name end
        elseif Config.Departments[value] then
            departments[#departments + 1] = value
        end
    elseif type(value) == 'table' then
        for _, department in pairs(value) do
            if department == 'all' then
                for name in pairs(Config.Departments) do
                    if not DPNDispatch.TableContains(departments, name) then departments[#departments + 1] = name end
                end
            elseif Config.Departments[department] and not DPNDispatch.TableContains(departments, department) then
                departments[#departments + 1] = department
            end
        end
    end

    if #departments == 0 then departments[1] = 'law' end
    return departments
end

function DPNDispatch.NormalizeDepartment(value, fallback)
    if value and Config.Departments[value] then return value end
    return fallback or 'law'
end

function DPNDispatch.SanitizeString(value, fallback, maxLength)
    if type(value) ~= 'string' then return fallback or '' end
    value = value:gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    value = value:gsub('%s%s+', ' ')
    if maxLength and #value > maxLength then value = value:sub(1, maxLength) end
    if value == '' then return fallback or '' end
    return value
end

function DPNDispatch.SanitizeMultiline(value, fallback, maxLength)
    if type(value) ~= 'string' then return fallback or '' end
    value = value:gsub('\r\n', '\n'):gsub('\r', '\n')
    value = value:gsub('[\1-\8\11\12\14-\31]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if maxLength and #value > maxLength then value = value:sub(1, maxLength) end
    if value == '' then return fallback or '' end
    return value
end

function DPNDispatch.ClampPriority(value)
    local priority = tonumber(value) or 3
    if priority < 1 then priority = 1 end
    if priority > 5 then priority = 5 end
    return priority
end

function DPNDispatch.Round(value, decimals)
    local multiplier = 10 ^ (decimals or 0)
    return math.floor((tonumber(value) or 0.0) * multiplier + 0.5) / multiplier
end

function DPNDispatch.Copy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = DPNDispatch.Copy(v) end
    return copy
end

function DPNDispatch.NormalizeLines(value, maxItems, maxLength)
    local result = {}
    if type(value) == 'table' then
        for _, entry in pairs(value) do
            local text = DPNDispatch.SanitizeString(tostring(entry or ''), '', maxLength or 160)
            if text ~= '' then result[#result + 1] = text end
            if maxItems and #result >= maxItems then break end
        end
        return result
    end

    if type(value) == 'string' then
        for line in tostring(value):gmatch('[^\n]+') do
            local text = DPNDispatch.SanitizeString(line, '', maxLength or 160)
            if text ~= '' then result[#result + 1] = text end
            if maxItems and #result >= maxItems then break end
        end
    end
    return result
end
