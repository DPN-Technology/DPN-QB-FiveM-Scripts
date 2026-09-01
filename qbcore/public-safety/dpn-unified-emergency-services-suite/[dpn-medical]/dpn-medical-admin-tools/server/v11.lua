local VERSION = '11.0.0'
local reports = {}

local function permitted(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, 'dpn.medical.admin') then return true end
    local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
    return ok and core and core.Functions and core.Functions.HasPermission
        and (core.Functions.HasPermission(src, 'admin') or core.Functions.HasPermission(src, 'god')) or false
end

local function call(resource, name, ...)
    local args = table.pack(...)
    local ok, a, b = pcall(function()
        local proxy = exports[resource]
        local fn = proxy and proxy[name]
        if type(fn) ~= 'function' then error(('missing export %s:%s'):format(resource, name)) end
        return fn(proxy, table.unpack(args, 1, args.n))
    end)
    return ok, a, b
end

local tests = {
    { 'dpn-medical-core', 'RunV11SelfTest', {} },
    { 'dpn-medical-ems', 'GetV11EMSBoard', {} },
    { 'dpn-medical-hospital', 'GetV11HospitalBoard', {} },
    { 'dpn-medical-surgery', 'GetV11SurgeryBoard', {} },
    { 'dpn-medical-radiology', 'GetV11RadiologyBoard', {} },
    { 'dpn-medical-pharmacy', 'GetV11PharmacyBoard', {} },
    { 'dpn-medical-records', 'GetV11RecordsBoard', {} },
    { 'dpn-medical-coroner', 'GetV11CoronerBoard', {} },
    { 'dpn-medical-insurance', 'GetV11InsuranceBoard', {} },
    { 'dpn-medical-training', 'GetV11TrainingBoard', {} },
    { 'dpn-medical-disease', 'GetV11DiseaseBoard', {} },
    { 'dpn-medical-ambulance', 'GetV11AmbulanceBoard', {} },
    { 'dpn-medical-ai', 'GetV11AIBoard', {} },
    { 'dpn-medical-dispatch', 'GetV11DispatchBoard', {} },
    { 'dpn-medical-icu', 'GetV11ICUBoard', {} },
    { 'dpn-medical-rehab', 'GetV11RehabBoard', {} },
    { 'dpn-medical-lifepak', 'GetV11LifepakBoard', {} },
    { 'dpn-medical-inventory', 'GetV11InventoryBoard', {} },
    { 'dpn-medical-billing-plus', 'GetV11BillingBoard', {} }
}

exports('RunAutonomousNetworkTestV11', function(actor)
    local report = {
        id = ('V11TEST-%s-%04d'):format(os.time(), math.random(0, 9999)), actor = actor,
        modules = {}, passed = 0, failed = 0, startedAt = os.time()
    }
    for _, test in ipairs(tests) do
        local resource, exportName, args = test[1], test[2], test[3]
        local started = GetResourceState(resource) == 'started'
        local ok, result, detail = false, nil, nil
        if started then ok, result, detail = call(resource, exportName, table.unpack(args)) end
        local passed = started and ok and type(result) == 'table' and (result.passed ~= false)
        report.modules[#report.modules + 1] = {
            resource = resource, exportName = exportName, started = started, passed = passed,
            version = GetResourceMetadata(resource, 'version', 0), detail = passed and nil or tostring(detail or result)
        }
        if passed then report.passed = report.passed + 1 else report.failed = report.failed + 1 end
    end
    report.completedAt = os.time()
    report.success = report.failed == 0
    reports[report.id] = report
    return report
end)

exports('GetAutonomousNetworkOperationsV11', function()
    local ok, data = call('dpn-medical-core', 'GetV11NetworkDashboard')
    return ok and type(data) == 'table' and data or {
        version = VERSION, patients = {}, immediate = 0, critical = 0,
        highIntensity = 0, activeReassessments = 0, openPlans = 0
    }
end)

exports('GetAutonomousNetworkTestReportsV11', function()
    return reports
end)

RegisterCommand('medv11systemtest', function(src)
    if not permitted(src) then return end
    local report = exports['dpn-medical-admin-tools']:RunAutonomousNetworkTestV11(src)
    local message = ('v11 autonomous network test: %s passed, %s failed, success=%s'):format(report.passed, report.failed, tostring(report.success))
    if src == 0 then print(message) else TriggerClientEvent('chat:addMessage', src, { args = { 'DPN Medical v11', message } }) end
end, false)
