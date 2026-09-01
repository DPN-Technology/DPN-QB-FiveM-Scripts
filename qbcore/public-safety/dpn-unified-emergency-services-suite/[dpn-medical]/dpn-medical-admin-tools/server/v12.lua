local VERSION = '12.0.0'
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
    { 'dpn-medical-core', 'RunV12SelfTest' },
    { 'dpn-medical-ems', 'GetV12EMSBoard' },
    { 'dpn-medical-hospital', 'GetV12HospitalBoard' },
    { 'dpn-medical-surgery', 'GetV12SurgeryBoard' },
    { 'dpn-medical-radiology', 'GetV12RadiologyBoard' },
    { 'dpn-medical-pharmacy', 'GetV12PharmacyBoard' },
    { 'dpn-medical-records', 'GetV12RecordsBoard' },
    { 'dpn-medical-coroner', 'GetV12CoronerBoard' },
    { 'dpn-medical-insurance', 'GetV12InsuranceBoard' },
    { 'dpn-medical-training', 'GetV12TrainingBoard' },
    { 'dpn-medical-disease', 'GetV12DiseaseBoard' },
    { 'dpn-medical-ambulance', 'GetV12AmbulanceBoard' },
    { 'dpn-medical-ai', 'GetV12AIBoard' },
    { 'dpn-medical-dispatch', 'GetV12DispatchBoard' },
    { 'dpn-medical-icu', 'GetV12ICUBoard' },
    { 'dpn-medical-rehab', 'GetV12RehabBoard' },
    { 'dpn-medical-lifepak', 'GetV12LifepakBoard' },
    { 'dpn-medical-inventory', 'GetV12InventoryBoard' },
    { 'dpn-medical-billing-plus', 'GetV12BillingBoard' }
}

exports('RunIntegratedNetworkTestV12', function(actor)
    local report = {
        id = ('V12TEST-%s-%04d'):format(os.time(), math.random(0, 9999)), actor = actor,
        modules = {}, passed = 0, failed = 0, startedAt = os.time()
    }
    for _, test in ipairs(tests) do
        local resource, exportName = test[1], test[2]
        local started = GetResourceState(resource) == 'started'
        local ok, result, detail = false, nil, nil
        if started then ok, result, detail = call(resource, exportName) end
        local passed = started and ok and type(result) == 'table' and result.passed ~= false
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

exports('GetIntegratedNetworkOperationsV12', function()
    local ok, data = call('dpn-medical-core', 'GetV12OperationalDashboard')
    return ok and type(data) == 'table' and data or {
        version = VERSION, patients = {}, critical = 0, specialPopulationPatients = 0,
        organSupportCandidates = 0, lowConfidencePatients = 0, activeSessions = 0,
        pendingTransactions = 0, failedTransactions = 0
    }
end)

exports('GetIntegratedNetworkTestReportsV12', function() return reports end)

RegisterCommand('medv12systemtest', function(src)
    if not permitted(src) then return end
    local report = exports['dpn-medical-admin-tools']:RunIntegratedNetworkTestV12(src)
    local message = ('v12 integrated network test: %s passed, %s failed, success=%s'):format(report.passed, report.failed, tostring(report.success))
    if src == 0 then print(message) else TriggerClientEvent('chat:addMessage', src, { args = { 'DPN Medical v12', message } }) end
end, false)
