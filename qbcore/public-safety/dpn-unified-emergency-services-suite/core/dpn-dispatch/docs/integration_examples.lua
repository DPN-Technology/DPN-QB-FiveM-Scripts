-- DPN Dispatch integration examples

-- Server-side: create a call from another DPN resource.
exports['dpn-dispatch']:CreateCall({
    code = '10-70',
    title = 'Structure Fire',
    description = 'Smoke showing from a commercial building. Fire and EMS requested.',
    departments = { 'fire', 'ems', 'law' },
    priority = 1,
    incidentClass = 'structure_fire',
    responseLevel = 'critical',
    riskFlags = { 'possible entrapment', 'gas meter exposed' },
    staging = 'Hydrant Alpha corner',
    command = 'Engine 1 Command',
    radioChannel = 'FIRE TAC 2',
    unitsRequested = { 'Engine', 'Medic', 'Law traffic control' },
    recommendedResponse = { 'Primary search', 'Utility shutoff', 'Hydrant/preplan check' },
    location = 'Downtown Los Santos',
    coords = { x = 215.22, y = -810.44, z = 30.73 },
    meta = {
        sourceResource = 'dpn-fire-system',
        fireType = 'structure',
        hydrantNeeded = true
    }
})

-- Client-side: create a call from the current player's GPS location.
exports['dpn-dispatch']:CreateClientCall({
    code = 'MED-2',
    title = 'Trauma Response',
    description = 'Civilian down with severe bleeding.',
    departments = { 'ems', 'law' },
    priority = 1,
    incidentClass = 'trauma',
    responseLevel = 'emergency',
    riskFlags = { 'severe bleeding', 'unknown scene safety' },
    staging = 'Nearest safe access point',
    radioChannel = 'EMS TAC 1'
})

-- Server-side: update a call status from an external script.
exports['dpn-dispatch']:UpdateCall(1001, {
    status = 'onscene',
    note = 'First engine arrived on scene.',
    command = 'Engine 1 Command',
    radioChannel = 'FIRE TAC 2'
})

-- Server-side: create a report linked to a call.
exports['dpn-dispatch']:CreateReport({
    type = 'fire',
    callId = 1001,
    title = 'Structure Fire After-Action Report',
    summary = 'Commercial fire response with EMS standby and utility shutoff.',
    narrative = 'Engine 1 established command. Primary search completed. Fire knocked down and scene transferred to investigation.',
    department = 'fire',
    priority = 2,
    status = 'supervisor_review',
    tags = { 'structure-fire', 'utilities', 'investigation' },
    involved = {
        fire = {
            'Initial size-up: smoke showing from side C',
            'Hydrant established on Alta Street',
            'Gas and electrical utilities requested for shutoff'
        },
        evidence = {
            'Photo log uploaded to Discord incident folder',
            'Command notes attached to MDT case'
        },
        riskFlags = { 'Utility hazard', 'Smoke exposure' },
        dispatchTimeline = { 'Call received', 'Engine dispatched', 'Command established', 'Utilities secured' },
        qaChecklist = { 'Narrative complete', 'Evidence attached', 'Supervisor review ready' }
    }
})

-- Server-side: create a corrections/detention call.
exports['dpn-dispatch']:CreateCall({
    code = 'DOC-1',
    title = 'Secure Inmate Transport',
    description = 'Corrections requests transport from jail intake to courthouse holding.',
    departments = { 'corrections', 'court', 'law' },
    priority = 3,
    incidentClass = 'inmate_transport',
    responseLevel = 'routine',
    riskFlags = { 'custody transport', 'restraints required' },
    staging = 'Sally port',
    radioChannel = 'DOC OPS',
    unitsRequested = { 'Corrections transport', 'Court security' },
    recommendedResponse = { 'Verify booking number', 'Document restraints/property', 'Confirm receiving officer' }
})

-- Server-side: update a report after supervisor review.
exports['dpn-dispatch']:UpdateReport(5001, {
    status = 'approved',
    auditAction = 'approved_by_supervisor'
})

-- dpn-mdt can create a CAD call without relying on exports.
TriggerEvent('dpn-dispatch:server:mdtCreateCall', {
    code = '10-80',
    title = 'MDT Pursuit Alert',
    description = 'MDT flagged active pursuit from law enforcement record.',
    departments = { 'law' },
    priority = 1,
    meta = { sourceResource = 'dpn-mdt', mdtCaseId = 'CASE-1234' }
})

-- dpn-mdt can create or mirror a report into dispatch.
TriggerEvent('dpn-dispatch:server:mdtCreateReport', {
    type = 'law_incident',
    title = 'MDT Imported Incident Report',
    summary = 'Report generated from dpn-mdt case file.',
    narrative = 'Narrative imported from MDT.',
    department = 'law',
    status = 'submitted',
    meta = { sourceResource = 'dpn-mdt', mdtReportId = 'RPT-1234' }
})

-- Optional manual MDT resync from another resource.
exports['dpn-dispatch']:SyncMdt()

-- Suggested examples for DPN systems:
-- dpn-fire-system: fire started, explosion, hazmat, vehicle fire, rescue/extrication, hydrant/utility report.
-- dpn-medical-system: cardiac arrest, trauma, overdose, hospital transport request, patient care report.
-- dpn-le-core: shots fired, pursuit, officer panic, warrant service, arrest transport, arrest/booking report.
-- dpn-justice-system: court transport, subpoena service, warrant review, bail bond request, court action report.
-- dpn-corrections-system: jail incidents, inmate transport, booking, cell extraction, escape attempt, property chain-of-custody.
-- dpn-mib-system: admin assist, scene lockdown, neuralizer review, sensitive incident response, sealed report.
-- dpn-mdt: case board, report sync, unit status sync, CAD call mirror, linked evidence references.
