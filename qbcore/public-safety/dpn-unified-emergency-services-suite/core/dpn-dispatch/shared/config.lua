Config = Config or {}

Config.Debug = false
Config.OpenKey = 'F7'
Config.ResourceName = 'dpn-dispatch'

-- Players with these jobs can open the dispatch center and see every department.
Config.DispatchCenterJobs = {
    dispatch = true,
    dispatcher = true,
    communications = true
}

-- ACE permissions that can open dispatch regardless of job.
-- add_ace group.admin dpn.dispatch allow
-- add_ace group.admin dpn.dispatch.admin allow
Config.AcePermissions = {
    open = 'dpn.dispatch',
    admin = 'dpn.dispatch.admin'
}

-- If true, any emergency department can see active cross-department calls.
-- If false, users only see calls assigned to their department unless they are dispatch/admin.
Config.CrossDepartmentView = true

-- If true, reports marked sealed/confidential only show to creator, dispatch/admin, and MIB/admin jobs.
Config.RestrictSealedReports = true

-- How often client unit coordinates are sent to dispatch while on duty.
Config.UnitPositionUpdateMs = 5000

-- How long closed/cancelled calls stay visible in the UI before cleanup.
Config.ClosedCallCleanupMinutes = 30

-- Closed reports remain in memory until restart. Set this false if you want archived reports to stay visible in the UI.
Config.HideArchivedReportsByDefault = false

-- Blip behavior.
Config.Blips = {
    enabled = true,
    showOnlyAssigned = false,
    routeOnAssigned = true,
    flashHighPriority = true,
    sprite = 161,
    scale = 1.0,
    shortRange = false
}


-- dpn-mdt bridge. Safe mode uses pcall so mismatched/missing exports do not crash dispatch.
Config.MDT = {
    enabled = true,
    resource = 'dpn-mdt',
    debug = false,

    -- Fire generic events that dpn-mdt can listen for without requiring exports.
    events = {
        enabled = true,
        callCreated = 'dpn-mdt:server:dispatchCallCreated',
        callUpdated = 'dpn-mdt:server:dispatchCallUpdated',
        reportCreated = 'dpn-mdt:server:dispatchReportCreated',
        reportUpdated = 'dpn-mdt:server:dispatchReportUpdated',
        unitUpdated = 'dpn-mdt:server:dispatchUnitUpdated'
    },

    -- Optional export names. Change these if your dpn-mdt uses different exported function names.
    exports = {
        enabled = true,
        syncCall = 'SyncDispatchCall',
        updateCall = 'UpdateDispatchCall',
        syncReport = 'SyncDispatchReport',
        updateReport = 'UpdateDispatchReport',
        createCaseFromCall = 'CreateCaseFromDispatch',
        attachReportToCase = 'AttachDispatchReport'
    },

    -- These MDT references are stored on calls/reports so both systems can cross-link records.
    referencePrefix = 'DPN-MDT',
    createMdtCaseOnCall = true,
    syncReportsToMdt = true,
    syncSealedReports = true
}


-- Department visual themes used by the NUI command center.
-- Requested colors: law = dark blue, EMS = orange, fire = red, justice = grey, MIB/admin = black, corrections = brown.
Config.UITheme = {
    defaultAgency = 'law',
    agencySelector = true,
    departments = {
        law = { label = 'Law Enforcement', accent = '#1d4ed8', accent2 = '#0f172a', text = '#dbeafe' },
        ems = { label = 'EMS', accent = '#f97316', accent2 = '#431407', text = '#ffedd5' },
        fire = { label = 'Fire / Rescue', accent = '#dc2626', accent2 = '#450a0a', text = '#fee2e2' },
        court = { label = 'Justice / Courts', accent = '#6b7280', accent2 = '#111827', text = '#f3f4f6' },
        mib = { label = 'MIB / Admin', accent = '#020617', accent2 = '#000000', text = '#f8fafc' },
        corrections = { label = 'Corrections', accent = '#92400e', accent2 = '#281405', text = '#fef3c7' }
    }
}

-- Realistic CAD/RMS feature presets inspired by modern public safety workflows.
Config.IncidentClasses = {
    law = { '911', 'violent_crime', 'traffic_stop', 'collision', 'pursuit', 'warrant', 'bolo', 'public_assist' },
    ems = { 'medical', 'trauma', 'cardiac', 'overdose', 'mental_health', 'mci', 'hospital_transfer' },
    fire = { 'structure_fire', 'vehicle_fire', 'wildland', 'technical_rescue', 'hazmat', 'alarm', 'utility' },
    court = { 'court_transport', 'warrant_service', 'subpoena', 'bail_bond', 'hearing_security' },
    mib = { 'admin_assist', 'security_event', 'scene_control', 'sensitive_incident', 'staff_investigation' },
    corrections = { 'inmate_transport', 'cell_extraction', 'jail_medical', 'facility_lockdown', 'escape_attempt', 'booking' }
}

Config.ResponseLevels = {
    { value = 'routine', label = 'Routine', priority = 4 },
    { value = 'priority', label = 'Priority Response', priority = 3 },
    { value = 'emergency', label = 'Emergency Response', priority = 2 },
    { value = 'critical', label = 'Critical / Life Safety', priority = 1 },
    { value = 'admin', label = 'Administrative / Planned', priority = 5 }
}

Config.DispatchSOPs = {
    law = { 'Confirm caller/location/callback', 'Check weapon/threat info', 'Assign primary and backup', 'Start BOLO if suspect flees', 'Mirror call to MDT/case notes' },
    ems = { 'Confirm consciousness/breathing', 'Stage until scene safe when needed', 'Assign transport hospital', 'Capture patient care notes', 'Update destination and ETA' },
    fire = { 'Complete size-up', 'Assign command/tactical channel', 'Request utilities/hydrants/preplan', 'Track entry/search teams', 'Record fire cause and recovery needs' },
    court = { 'Verify case/warrant number', 'Confirm custody status', 'Assign secure transport', 'Document hearing result', 'Attach DOJ notes' },
    mib = { 'Validate admin authority', 'Seal sensitive records', 'Record scene control actions', 'Keep audit trail', 'Sync limited MDT reference only' },
    corrections = { 'Verify inmate/booking number', 'Assign transport/security team', 'Document restraints and property', 'Track facility status', 'Complete chain-of-custody notes' }
}

-- Optional Discord webhook logging.
Config.Discord = {
    enabled = false,
    webhook = '',
    username = 'DPN Dispatch',
    avatar = ''
}

-- Optional SQL logging through oxmysql.
Config.Database = {
    enabled = false,
    resource = 'oxmysql'
}

Config.Statuses = {
    pending = { label = 'Pending', color = '#f59e0b' },
    assigned = { label = 'Assigned', color = '#38bdf8' },
    enroute = { label = 'En Route', color = '#60a5fa' },
    onscene = { label = 'On Scene', color = '#22c55e' },
    holding = { label = 'Holding', color = '#a855f7' },
    investigating = { label = 'Investigating', color = '#f97316' },
    transporting = { label = 'Transporting', color = '#c084fc' },
    staged = { label = 'Staged', color = '#f97316' },
    clear = { label = 'Clear / Available', color = '#22c55e' },
    closed = { label = 'Closed', color = '#64748b' },
    cancelled = { label = 'Cancelled', color = '#ef4444' }
}

Config.UnitStatuses = {
    available = { label = 'Available', color = '#22c55e' },
    busy = { label = 'Busy', color = '#f59e0b' },
    enroute = { label = 'En Route', color = '#60a5fa' },
    onscene = { label = 'On Scene', color = '#22c55e' },
    transporting = { label = 'Transporting', color = '#a855f7' },
    court = { label = 'Court Detail', color = '#c084fc' },
    corrections = { label = 'Corrections Detail', color = '#92400e' },
    unavailable = { label = 'Unavailable', color = '#64748b' },
    panic = { label = 'PANIC', color = '#ef4444' }
}

Config.ReportStatuses = {
    draft = { label = 'Draft', color = '#94a3b8' },
    submitted = { label = 'Submitted', color = '#38bdf8' },
    supervisor_review = { label = 'Supervisor Review', color = '#f59e0b' },
    doj_review = { label = 'DOJ / Court Review', color = '#c084fc' },
    approved = { label = 'Approved', color = '#22c55e' },
    returned = { label = 'Returned for Correction', color = '#ef4444' },
    rejected = { label = 'Rejected / Voided', color = '#991b1b' },
    archived = { label = 'Archived', color = '#64748b' }
}

Config.ReportTypes = {
    incident = {
        label = 'General Incident Report',
        departments = { 'law', 'ems', 'fire', 'court', 'mib', 'corrections' },
        required = { 'title', 'summary', 'narrative', 'location' }
    },
    law_incident = {
        label = 'Law Enforcement Incident',
        departments = { 'law' },
        required = { 'title', 'narrative', 'involvedPersons' }
    },
    arrest = {
        label = 'Arrest / Booking Report',
        departments = { 'law', 'court', 'corrections' },
        required = { 'title', 'charges', 'involvedPersons', 'narrative' }
    },
    traffic = {
        label = 'Traffic Stop / Collision Report',
        departments = { 'law', 'ems', 'fire' },
        required = { 'vehicles', 'location', 'narrative' }
    },
    medical = {
        label = 'EMS Patient Care Report',
        departments = { 'ems' },
        required = { 'medical', 'narrative', 'location' }
    },
    fire = {
        label = 'Fire / Rescue Incident Report',
        departments = { 'fire', 'ems', 'law' },
        required = { 'fire', 'narrative', 'location' }
    },
    hazmat = {
        label = 'HazMat / Utility Report',
        departments = { 'fire', 'law', 'ems' },
        required = { 'fire', 'evidence', 'narrative' }
    },
    court = {
        label = 'Court / DOJ Action Report',
        departments = { 'court', 'law', 'corrections' },
        required = { 'court', 'narrative' }
    },
    corrections = {
        label = 'Corrections / Detention Report',
        departments = { 'corrections', 'law', 'court', 'ems' },
        required = { 'corrections', 'involvedPersons', 'narrative' }
    },
    mib = {
        label = 'MIB / Admin Sensitive Report',
        departments = { 'mib' },
        required = { 'adminActions', 'narrative' },
        defaultSealed = true
    }
}

Config.Departments = {
    law = {
        label = 'Law Enforcement',
        short = 'LEO',
        theme = 'dark-blue',
        color = '#1d4ed8',
        jobs = { 'police', 'sheriff', 'statepolice', 'trooper', 'marshal' },
        blipColor = 3,
        defaultCodes = {
            { code = '10-31', label = 'Crime In Progress' },
            { code = '10-32', label = 'Person With Weapon' },
            { code = '10-50', label = 'Traffic Collision' },
            { code = '10-80', label = 'Vehicle Pursuit' },
            { code = '10-99', label = 'Officer Panic' }
        }
    },
    ems = {
        label = 'Emergency Medical Services',
        short = 'EMS',
        theme = 'orange',
        color = '#f97316',
        jobs = { 'ambulance', 'ems', 'doctor', 'hospital' },
        blipColor = 1,
        defaultCodes = {
            { code = 'MED-1', label = 'Medical Emergency' },
            { code = 'MED-2', label = 'Trauma Response' },
            { code = 'MED-3', label = 'Cardiac / Critical' },
            { code = 'MED-4', label = 'Mass Casualty' }
        }
    },
    fire = {
        label = 'Fire / Rescue',
        short = 'FIRE',
        theme = 'red',
        color = '#dc2626',
        jobs = { 'fire', 'firefighter', 'firedept', 'rescue' },
        blipColor = 17,
        defaultCodes = {
            { code = '10-70', label = 'Structure Fire' },
            { code = '10-71', label = 'Vehicle Fire' },
            { code = '10-72', label = 'Rescue / Extrication' },
            { code = 'HAZMAT', label = 'Hazardous Materials' }
        }
    },
    court = {
        label = 'Justice / Courts',
        short = 'COURT',
        theme = 'grey',
        color = '#6b7280',
        jobs = { 'judge', 'lawyer', 'attorney', 'doj', 'court', 'justice', 'bailbonds', 'bailbond' },
        blipColor = 27,
        defaultCodes = {
            { code = 'CRT-1', label = 'Court Summons' },
            { code = 'CRT-2', label = 'Transport Order' },
            { code = 'CRT-3', label = 'Warrant Service' },
            { code = 'CRT-4', label = 'Bail Bond Request' }
        }
    },
    corrections = {
        label = 'Corrections / Detention',
        short = 'DOC',
        theme = 'brown',
        color = '#92400e',
        jobs = { 'corrections', 'doc', 'prison', 'jail', 'detention' },
        blipColor = 56,
        defaultCodes = {
            { code = 'DOC-1', label = 'Inmate Transport' },
            { code = 'DOC-2', label = 'Facility Incident' },
            { code = 'DOC-3', label = 'Booking / Intake' },
            { code = 'DOC-4', label = 'Escape Attempt' },
            { code = 'DOC-5', label = 'Cell Extraction' }
        }
    },
    mib = {
        label = 'MIB / Admin Response',
        short = 'MIB',
        theme = 'black',
        color = '#020617',
        jobs = { 'mib', 'admin', 'staff' },
        blipColor = 40,
        defaultCodes = {
            { code = 'MIB-1', label = 'Admin Assistance' },
            { code = 'MIB-2', label = 'Server Security' },
            { code = 'MIB-3', label = 'Scene Control' },
            { code = 'MIB-4', label = 'Sensitive Incident' }
        }
    }
}

Config.DefaultCallTypes = {
    { code = '911', label = 'Emergency Call', departments = { 'law', 'ems', 'fire' }, priority = 2 },
    { code = '10-13', label = 'Officer Needs Help', departments = { 'law', 'ems' }, priority = 1 },
    { code = '10-50', label = 'Traffic Collision', departments = { 'law', 'ems', 'fire' }, priority = 2 },
    { code = '10-70', label = 'Fire Response', departments = { 'fire', 'ems', 'law' }, priority = 1 },
    { code = 'CRT-1', label = 'Court / DOJ Request', departments = { 'court', 'law', 'corrections' }, priority = 3 },
    { code = 'DOC-1', label = 'Corrections Transport', departments = { 'corrections', 'law', 'court' }, priority = 3 },
    { code = 'DOC-2', label = 'Facility Incident', departments = { 'corrections', 'ems', 'law' }, priority = 2 },
    { code = 'MIB-1', label = 'MIB/Admin Request', departments = { 'mib' }, priority = 1 }
}

Config.Commands = {
    dispatch = 'dispatch',
    report = 'report',
    emergency911 = '911',
    panic = 'panic',
    status = 'unitstatus'
}
