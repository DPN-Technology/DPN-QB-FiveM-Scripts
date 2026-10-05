const app = document.getElementById('app');
const browserPreviewMode = typeof GetParentResourceName !== 'function';
document.body.classList.add('agency-law');
const state = {
  calls: {},
  units: {},
  reports: {},
  departments: {},
  statuses: {},
  unitStatuses: {},
  reportTypes: {},
  reportStatuses: {},
  analytics: {},
  allowedDepartments: [],
  canSeeAll: false,
  selectedTab: 'calls',
  selectedReportId: null,
  agencyMode: 'law',
  uiTheme: {},
  incidentClasses: {},
  responseLevels: [],
  dispatchSOPs: {},
  defaultCallTypes: [],
  previewLog: []
};

const nowUnix = () => Math.floor(Date.now() / 1000);
const demoState = () => ({
  departments: {
    law: { label: 'Law Enforcement', short: 'LEO' },
    ems: { label: 'Emergency Medical Services', short: 'EMS' },
    fire: { label: 'Fire / Rescue', short: 'FIRE' },
    court: { label: 'Court / Justice', short: 'COURT' },
    corrections: { label: 'Corrections / Detention', short: 'DOC' },
    mib: { label: 'MIB / Admin Command', short: 'MIB' }
  },
  statuses: {
    pending: { label: 'Pending' }, assigned: { label: 'Assigned' }, enroute: { label: 'En Route' },
    onscene: { label: 'On Scene' }, holding: { label: 'Holding' }, investigating: { label: 'Investigating' },
    transporting: { label: 'Transporting' }, staged: { label: 'Staged' }, clear: { label: 'Clear / Available' }, closed: { label: 'Closed' }, cancelled: { label: 'Cancelled' }
  },
  unitStatuses: {
    available: { label: 'Available' }, busy: { label: 'Busy' }, enroute: { label: 'En Route' },
    onscene: { label: 'On Scene' }, transporting: { label: 'Transporting' }, court: { label: 'Court Detail' }, corrections: { label: 'Corrections Detail' }, unavailable: { label: 'Unavailable' }
  },
  reportTypes: {
    incident: { label: 'Incident Report' }, arrest: { label: 'Arrest Report' }, medical: { label: 'Medical PCR' },
    fire: { label: 'Fire Investigation' }, court: { label: 'Court / DOJ Report' }, corrections: { label: 'Corrections Report' }, mib: { label: 'MIB/Admin Report' }
  },
  reportStatuses: {
    draft: { label: 'Draft' }, submitted: { label: 'Submitted' }, supervisor_review: { label: 'Supervisor Review' },
    court_review: { label: 'DOJ / Court Review' }, approved: { label: 'Approved' }, returned: { label: 'Returned' },
    rejected: { label: 'Rejected' }, archived: { label: 'Archived' }
  },
  uiTheme: {
    defaultAgency: 'law',
    departments: {
      law: { label: 'Law Enforcement', accent: '#1d4ed8', accent2: '#0f172a', text: '#dbeafe' },
      ems: { label: 'EMS', accent: '#f97316', accent2: '#431407', text: '#ffedd5' },
      fire: { label: 'Fire / Rescue', accent: '#dc2626', accent2: '#450a0a', text: '#fee2e2' },
      court: { label: 'Justice / Courts', accent: '#6b7280', accent2: '#111827', text: '#f3f4f6' },
      corrections: { label: 'Corrections', accent: '#92400e', accent2: '#281405', text: '#fef3c7' },
      mib: { label: 'MIB / Admin', accent: '#020617', accent2: '#000000', text: '#f8fafc' }
    }
  },
  incidentClasses: {
    law: ['911', 'violent_crime', 'traffic_stop', 'collision', 'pursuit', 'warrant', 'bolo'],
    ems: ['medical', 'trauma', 'cardiac', 'overdose', 'mental_health', 'mci'],
    fire: ['structure_fire', 'vehicle_fire', 'wildland', 'technical_rescue', 'hazmat', 'alarm'],
    court: ['court_transport', 'warrant_service', 'subpoena', 'bail_bond', 'hearing_security'],
    corrections: ['inmate_transport', 'cell_extraction', 'jail_medical', 'facility_lockdown', 'escape_attempt', 'booking'],
    mib: ['admin_assist', 'security_event', 'scene_control', 'sensitive_incident']
  },
  responseLevels: [
    { value: 'routine', label: 'Routine' }, { value: 'priority', label: 'Priority Response' },
    { value: 'emergency', label: 'Emergency Response' }, { value: 'critical', label: 'Critical / Life Safety' },
    { value: 'admin', label: 'Administrative / Planned' }
  ],
  dispatchSOPs: {
    law: ['Confirm location/callback', 'Check weapon/threat info', 'Assign primary and backup', 'Start BOLO if suspect flees', 'Mirror to MDT'],
    ems: ['Confirm consciousness/breathing', 'Stage until scene safe if needed', 'Assign hospital destination', 'Capture patient care notes'],
    fire: ['Complete size-up', 'Assign command/tactical channel', 'Request hydrants/utilities/preplan', 'Track entry/search teams'],
    court: ['Verify case/warrant number', 'Confirm custody status', 'Assign secure transport', 'Document hearing result'],
    corrections: ['Verify booking number', 'Assign transport/security team', 'Document restraints/property', 'Track facility status'],
    mib: ['Validate admin authority', 'Seal sensitive records', 'Record scene control actions', 'Keep audit trail']
  },
  calls: {
    1001: {
      id: 1001, caseId: 'DPN-CAD-20260705-1001', code: '10-70', priority: 1, status: 'assigned',
      title: 'Structure Fire With Entrapment', description: 'Caller reports smoke showing from the second floor, possible trapped occupant, gas meter exposed on Bravo side.',
      location: 'Alta St / Power St', coords: { x: 250.5, y: -1380.2, z: 30.1 }, primaryDepartment: 'fire', departments: ['fire', 'ems', 'law'], incidentClass: 'structure_fire', responseLevel: 'critical', riskFlags: ['entrapment', 'gas meter exposed', 'second floor smoke'], staging: 'Hydrant Alpha corner', command: 'ENGINE-12 Command', radioChannel: 'FIRE TAC 2', unitsRequested: ['Engine', 'Medic', 'Law traffic control'], recommendedResponse: ['Primary search', 'Utility shutoff', 'Hydrant map/preplan'], sop: ['Complete size-up', 'Assign command/tactical channel', 'Request hydrants/utilities/preplan'],
      caller: { name: '911 Caller', phone: 'Unknown' }, tags: ['structure-fire', 'rescue', 'utilities'], assignedUnits: [12, 21],
      notes: [{ byName: 'Dispatch', text: 'Hydrant map and utility shutoff requested.', at: nowUnix() - 180 }],
      createdAt: nowUnix() - 540, updatedAt: nowUnix() - 60, meta: { mdtRef: 'MDT-CALL-90021' }
    },
    1002: {
      id: 1002, caseId: 'DPN-CAD-20260705-1002', code: 'MED-1', priority: 2, status: 'enroute',
      title: 'Motor Vehicle Accident With Injuries', description: 'Two vehicle collision. One patient complaining of chest pain. Police requested for traffic control.',
      location: 'Vespucci Blvd / Elgin Ave', coords: { x: 410.2, y: -1031.7, z: 29.3 }, primaryDepartment: 'ems', departments: ['ems', 'law', 'fire'], incidentClass: 'collision', responseLevel: 'emergency', riskFlags: ['traffic hazard', 'chest pain'], staging: 'One block west until lanes blocked', command: 'EMS-31 Medical Group', radioChannel: 'EMS TAC 1', unitsRequested: ['Medic', 'Police traffic control', 'Rescue if pinned'], recommendedResponse: ['Scene safety', 'Triage patient', 'Transport decision'], sop: ['Confirm consciousness/breathing', 'Stage until scene safe if needed', 'Assign hospital destination'],
      caller: { name: 'OnStar / Bystander', phone: '555-0199' }, tags: ['mva', 'injury', 'traffic'], assignedUnits: [31],
      notes: [{ byName: 'EMS 31', text: 'Staging one block out until law secures lane.', at: nowUnix() - 100 }],
      createdAt: nowUnix() - 420, updatedAt: nowUnix() - 75, meta: { mdtRef: 'MDT-CALL-90022' }
    },
    1003: {
      id: 1003, caseId: 'DPN-CAD-20260705-1003', code: 'CRT-2', priority: 4, status: 'pending',
      title: 'Court Transport Request', description: 'DOJ requests secure transport for defendant from holding to courthouse. Attach warrant/case notes in MDT.',
      location: 'Mission Row Holding', coords: { x: 441.2, y: -981.8, z: 30.6 }, primaryDepartment: 'court', departments: ['court', 'law', 'corrections'], incidentClass: 'court_transport', responseLevel: 'routine', riskFlags: ['custody transport'], staging: 'Sally port', command: 'COURT-4', radioChannel: 'COURT OPS', unitsRequested: ['Court security', 'Corrections transport'], recommendedResponse: ['Verify case number', 'Confirm custody status', 'Assign secure transport'], sop: ['Verify case/warrant number', 'Confirm custody status', 'Assign secure transport'],
      caller: { name: 'Court Clerk', phone: 'DOJ Desk' }, tags: ['transport', 'court'], assignedUnits: [], notes: [],
      createdAt: nowUnix() - 210, updatedAt: nowUnix() - 205, meta: { mdtRef: 'MDT-CALL-90023' }
    }
  },
  units: {
    12: { src: 12, source: 12, name: 'Captain Hayes', callsign: 'ENGINE-12', department: 'fire', departments: ['fire'], status: 'onscene', radio: 'FIRE TAC 2', assignedCall: 1001, updatedAt: nowUnix() - 50 },
    21: { src: 21, source: 21, name: 'Medic Carter', callsign: 'MEDIC-21', department: 'ems', departments: ['ems'], status: 'enroute', radio: 'EMS TAC 1', assignedCall: 1001, updatedAt: nowUnix() - 70 },
    31: { src: 31, source: 31, name: 'Officer Diesel', callsign: '3-L-31', department: 'law', departments: ['law'], status: 'enroute', radio: 'LE TAC 1', assignedCall: 1002, updatedAt: nowUnix() - 80 },
    44: { src: 44, source: 44, name: 'Judge Admin', callsign: 'COURT-4', department: 'court', departments: ['court'], status: 'available', radio: 'COURT OPS', assignedCall: false, updatedAt: nowUnix() - 120 },
    55: { src: 55, source: 55, name: 'Sgt. Block', callsign: 'DOC-55', department: 'corrections', departments: ['corrections'], status: 'corrections', radio: 'DOC OPS', assignedCall: 1003, updatedAt: nowUnix() - 110 },
    70: { src: 70, source: 70, name: 'MIB Command', callsign: 'MIB-1', department: 'mib', departments: ['mib'], status: 'available', radio: 'ADMIN NET', assignedCall: false, updatedAt: nowUnix() - 90 }
  },
  reports: {
    501: {
      id: 501, reportNumber: 'DPN-RMS-20260705-0501', caseId: 'DPN-CAD-20260705-1001', callId: 1001,
      type: 'fire', department: 'fire', priority: 1, status: 'supervisor_review', title: 'Initial Fire Investigation - Alta Structure Fire',
      summary: 'Working residential fire with possible entrapment. Fire attack, search, utility isolation, and EMS standby initiated.',
      narrative: 'Engine 12 arrived to smoke showing. Crew established command, initiated primary search, and requested gas/electric shutoff coordination.',
      location: 'Alta St / Power St', tags: ['fire', 'rescue', 'utilities'],
      involved: {
        involvedPersons: ['Unknown occupant | victim | located during search'],
        vehicles: [], witnesses: ['Neighbor | 555-0144 | saw lightning strike utility pole'],
        evidence: ['Bodycam link: pending', 'Photo set: Discord CDN placeholder'], attachments: [], charges: [],
        medical: ['EMS staged for smoke inhalation evaluation'], fire: ['Possible lightning/utility origin; hydrant Alpha corner; gas meter secured'], court: [], adminActions: []
      },
      sealed: false, confidential: false, locked: false,
      audit: [{ byName: 'Captain Hayes', action: 'submitted_for_review', at: nowUnix() - 160 }],
      createdAt: nowUnix() - 300, updatedAt: nowUnix() - 150, meta: { mdtReportId: 'MDT-RPT-4112', mdtRef: 'MDT-RPT-4112' }
    }
  },
  analytics: { activeCalls: 3, criticalCalls: 1, availableUnits: 2, openReports: 1, pendingApprovals: 1, sealedReports: 0 },
  allowedDepartments: ['law', 'ems', 'fire', 'court', 'corrections', 'mib'],
  canSeeAll: true
});

function recomputeAnalytics() {
  const calls = Object.values(state.calls || {});
  const reports = Object.values(state.reports || {});
  state.analytics = {
    activeCalls: calls.filter(c => !['closed', 'cancelled'].includes(c.status)).length,
    criticalCalls: calls.filter(c => Number(c.priority) === 1 && !['closed', 'cancelled'].includes(c.status)).length,
    availableUnits: Object.values(state.units || {}).filter(u => u.status === 'available').length,
    openReports: reports.filter(r => !['approved', 'rejected', 'archived'].includes(r.status)).length,
    pendingApprovals: reports.filter(r => ['submitted', 'supervisor_review', 'court_review'].includes(r.status)).length,
    sealedReports: reports.filter(r => r.sealed || r.confidential).length
  };
}

function nextNumericId(collection, fallback) {
  const keys = Object.keys(collection || {}).map(Number).filter(Number.isFinite);
  return keys.length ? Math.max(...keys) + 1 : fallback;
}

function demoMdtRef(prefix, id) {
  return `${prefix}-${String(id).padStart(5, '0')}`;
}

function demoResponse(ok = true, extra = {}) {
  recomputeAnalytics();
  render();
  return { ok, preview: true, ...extra };
}

const nui = async (name, data = {}) => {
  if (browserPreviewMode) {
    if (name === 'requestState') return demoState();
    if (name === 'close' || name === 'escape') return demoResponse(true);
    if (name === 'panic') {
      const id = nextNumericId(state.calls, 1001);
      state.calls[String(id)] = {
        id, caseId: `DPN-CAD-20260705-${id}`, code: 'PANIC', priority: 1, status: 'pending', title: 'Unit Panic Activation',
        description: data.message || 'Panic button activated from DPN Dispatch UI.', location: 'Current GPS Location',
        coords: { x: 437.2, y: -978.9, z: 30.7 }, primaryDepartment: 'law', departments: ['law', 'ems', 'fire', 'mib'], incidentClass: 'officer_distress', responseLevel: 'critical', riskFlags: ['panic', 'officer distress'], staging: 'Nearest safe approach', command: 'Dispatch Supervisor', radioChannel: 'LE TAC 1', unitsRequested: ['All available law units', 'EMS stage', 'MIB admin monitor'], recommendedResponse: ['Emergency traffic only', 'Assign nearest backup', 'MDT panic record'], sop: ['Confirm unit location', 'Assign primary and backup', 'Mirror to MDT'],
        caller: { name: 'Preview User' }, tags: ['panic', 'officer-distress'], assignedUnits: [],
        notes: [{ byName: 'CAD Preview', text: 'PANIC event mirrored to dpn-mdt preview bridge.', at: nowUnix() }],
        createdAt: nowUnix(), updatedAt: nowUnix(), meta: { mdtRef: demoMdtRef('MDT-CALL', id) }
      };
      return demoResponse(true, { callId: id });
    }
    if (name === 'createCall') {
      const id = nextNumericId(state.calls, 1001);
      state.calls[String(id)] = {
        id, caseId: `DPN-CAD-20260705-${id}`, code: data.code || '911', priority: Number(data.priority || 3), status: 'pending',
        title: data.title || 'Dispatch Call', description: data.description || 'No details provided.', location: data.location || 'Current GPS Location',
        coords: { x: 412.7, y: -1020.4, z: 29.2 }, primaryDepartment: (data.departments || ['law'])[0], departments: data.departments || ['law'], incidentClass: data.incidentClass || '', responseLevel: data.responseLevel || 'priority', riskFlags: data.riskFlags || [], staging: data.staging || '', command: data.command || '', radioChannel: data.radioChannel || '', unitsRequested: data.unitsRequested || [], recommendedResponse: data.recommendedResponse || [], sop: data.sop || [],
        caller: { name: 'Preview Dispatcher' }, tags: ['manual-entry'], assignedUnits: [], notes: [], createdAt: nowUnix(), updatedAt: nowUnix(),
        meta: { mdtRef: demoMdtRef('MDT-CALL', id) }
      };
      return demoResponse(true, { callId: id });
    }
    if (name === 'assignSelf') {
      const call = state.calls[String(data.callId)];
      if (call && !call.assignedUnits.includes(31)) call.assignedUnits.push(31);
      if (call) { call.status = 'assigned'; call.updatedAt = nowUnix(); call.notes.push({ byName: '3-L-31', text: 'Self-assigned in live preview.', at: nowUnix() }); }
      state.units['31'].assignedCall = Number(data.callId); state.units['31'].status = 'enroute'; state.units['31'].updatedAt = nowUnix();
      return demoResponse(true);
    }
    if (name === 'assignUnit') {
      const call = state.calls[String(data.callId)];
      if (call && !call.assignedUnits.includes(Number(data.unitSrc))) call.assignedUnits.push(Number(data.unitSrc));
      if (call) { call.status = 'assigned'; call.updatedAt = nowUnix(); }
      if (state.units[String(data.unitSrc)]) { state.units[String(data.unitSrc)].assignedCall = Number(data.callId); state.units[String(data.unitSrc)].status = 'enroute'; }
      return demoResponse(true);
    }
    if (name === 'unassignUnit') {
      const call = state.calls[String(data.callId)];
      if (call) call.assignedUnits = (call.assignedUnits || []).filter(src => Number(src) !== Number(data.unitSrc));
      if (state.units[String(data.unitSrc)]) { state.units[String(data.unitSrc)].assignedCall = false; state.units[String(data.unitSrc)].status = 'available'; }
      return demoResponse(true);
    }
    if (name === 'setCallStatus') {
      const call = state.calls[String(data.callId)];
      if (call) { call.status = data.status; call.updatedAt = nowUnix(); call.notes.push({ byName: 'CAD Preview', text: `Status changed to ${data.status}.`, at: nowUnix() }); }
      return demoResponse(true);
    }
    if (name === 'addNote') {
      const call = state.calls[String(data.callId)];
      if (call) { call.notes.push({ byName: 'CAD Preview', text: data.note, at: nowUnix() }); call.updatedAt = nowUnix(); }
      return demoResponse(true);
    }
    if (name === 'setUnitStatus') {
      state.units['31'].status = data.status || 'available';
      state.units['31'].radio = data.radio || state.units['31'].radio;
      state.units['31'].updatedAt = nowUnix();
      return demoResponse(true);
    }
    if (name === 'createReport') {
      const id = nextNumericId(state.reports, 501);
      const call = data.callId ? state.calls[String(data.callId)] : null;
      state.reports[String(id)] = {
        id, reportNumber: `DPN-RMS-20260705-${String(id).padStart(4, '0')}`, caseId: call?.caseId || `DPN-CASE-20260705-${id}`,
        callId: data.callId || false, type: data.type || 'incident', department: data.department || call?.primaryDepartment || 'law',
        priority: Number(data.priority || 3), status: data.status || 'draft', title: data.title || 'Dispatch Report',
        summary: data.summary || '', narrative: data.narrative || '', location: data.location || call?.location || 'Current GPS Location',
        tags: data.tags || [], involved: data.involved || {}, sealed: !!data.sealed, confidential: !!data.confidential, locked: !!data.locked,
        audit: [{ byName: 'CAD Preview', action: data.auditAction || 'created', at: nowUnix() }], createdAt: nowUnix(), updatedAt: nowUnix(),
        meta: { mdtReportId: demoMdtRef('MDT-RPT', id), mdtRef: demoMdtRef('MDT-RPT', id) }
      };
      return demoResponse(true, { reportId: id });
    }
    if (name === 'updateReport') {
      const report = state.reports[String(data.reportId)];
      if (report) {
        const changes = data.changes || {};
        Object.assign(report, changes, { updatedAt: nowUnix() });
        report.audit = report.audit || [];
        report.audit.push({ byName: 'CAD Preview', action: changes.auditAction || 'updated', at: nowUnix() });
        report.meta = report.meta || { mdtRef: demoMdtRef('MDT-RPT', report.id) };
      }
      return demoResponse(true);
    }
    if (name === 'forceMdtSync') {
      state.previewLog.push({ at: nowUnix(), text: 'Forced MDT sync for visible calls, reports, and unit states.' });
      Object.values(state.calls).forEach(call => { call.meta = call.meta || {}; call.meta.mdtRef = call.meta.mdtRef || demoMdtRef('MDT-CALL', call.id); });
      Object.values(state.reports).forEach(report => { report.meta = report.meta || {}; report.meta.mdtRef = report.meta.mdtRef || demoMdtRef('MDT-RPT', report.id); });
      return demoResponse(true);
    }
    if (name === 'setGps' || name === 'copyLocation') return demoResponse(true);
    return demoResponse(false, { error: `Preview action not implemented: ${name}` });
  }
  try {
    const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data)
    });
    return await response.json();
  } catch (err) {
    return { ok: false, error: String(err) };
  }
};

const esc = (value) => String(value ?? '').replace(/[&<>'"]/g, (c) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
}[c]));

const timeAgo = (unix) => {
  if (!unix) return 'unknown';
  const seconds = Math.max(1, Math.floor(Date.now() / 1000 - unix));
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
};

const getDepartmentLabel = (department) => state.departments?.[department]?.short || department?.toUpperCase() || 'DPN';
const getDepartmentFull = (department) => state.departments?.[department]?.label || department || 'Unknown';
const getStatusLabel = (status) => state.statuses?.[status]?.label || status || 'Unknown';
const getUnitStatusLabel = (status) => state.unitStatuses?.[status]?.label || status || 'Unknown';
const getReportStatusLabel = (status) => state.reportStatuses?.[status]?.label || status || 'Unknown';
const getReportTypeLabel = (type) => state.reportTypes?.[type]?.label || type || 'Report';
const objectValues = (obj) => Object.values(obj || {});
const lines = (value) => String(value || '').split(/[\n,]+/).map(v => v.trim()).filter(Boolean);
const linesFromTextarea = (id) => lines(document.getElementById(id)?.value || '');
const bool = (id) => !!document.getElementById(id)?.checked;

const currentAgency = () => state.agencyMode || (state.allowedDepartments && state.allowedDepartments[0]) || state.uiTheme?.defaultAgency || 'law';
const deptClass = (department) => `dept-${String(department || 'law').replace(/[^a-z0-9_-]/gi, '').toLowerCase()}`;
const prettyKey = (value) => String(value || '').replace(/[_-]+/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
const primaryDept = (item) => item?.primaryDepartment || item?.department || (item?.departments || [currentAgency()])[0] || currentAgency();
const displayLines = (items, empty = 'None listed') => (items || []).length ? (items || []).map(v => `<span class="badge">${esc(v)}</span>`).join('') : `<span class="badge">${esc(empty)}</span>`;

function applyAgencyMode(department) {
  state.agencyMode = department || state.uiTheme?.defaultAgency || 'law';
  document.body.classList.remove('agency-law', 'agency-ems', 'agency-fire', 'agency-court', 'agency-mib', 'agency-corrections');
  document.body.classList.add(`agency-${state.agencyMode}`);
  renderAgencyMode();
  buildIncidentControls();
  const sopBox = document.getElementById('responsePlanInput');
  if (sopBox && !sopBox.value.trim()) sopBox.value = (state.dispatchSOPs?.[state.agencyMode] || []).join('\n');
  render();
}

function renderAgencyMode() {
  const bar = document.getElementById('agencyModeBar');
  if (!bar) return;
  const entries = Object.entries(state.departments || {});
  bar.innerHTML = entries.map(([key, dept]) => {
    const active = key === currentAgency() ? 'active' : '';
    const short = dept.short || key.toUpperCase();
    const color = state.uiTheme?.departments?.[key]?.accent || dept.color || '';
    return `<button class="agency-btn ${active}" style="border-color:${esc(color)}" onclick="applyAgencyMode('${esc(key)}')"><strong>${esc(dept.label || key)}</strong><span>${esc(short)} theme • ${esc(prettyKey(key))}</span></button>`;
  }).join('');
}

function buildIncidentControls() {
  const agency = currentAgency();
  const classEntries = (state.incidentClasses?.[agency] || state.incidentClasses?.law || []).map(v => [v, prettyKey(v)]);
  buildSelect(document.getElementById('incidentClassInput'), classEntries, 'Select Incident Class', '');
  const levelEntries = (state.responseLevels || []).map(level => [level.value || level, level.label || prettyKey(level)]);
  buildSelect(document.getElementById('responseLevelInput'), levelEntries, 'Select Response Level', '');
}

function syncState(payload) {
  if (!payload || payload.denied) return;
  state.calls = payload.calls || {};
  state.units = payload.units || {};
  state.reports = payload.reports || {};
  state.departments = payload.departments || {};
  state.statuses = payload.statuses || {};
  state.unitStatuses = payload.unitStatuses || {};
  state.reportTypes = payload.reportTypes || {};
  state.reportStatuses = payload.reportStatuses || {};
  state.uiTheme = payload.uiTheme || {};
  state.incidentClasses = payload.incidentClasses || {};
  state.responseLevels = payload.responseLevels || [];
  state.dispatchSOPs = payload.dispatchSOPs || {};
  state.defaultCallTypes = payload.defaultCallTypes || [];
  state.analytics = payload.analytics || {};
  state.allowedDepartments = payload.allowedDepartments || [];
  state.canSeeAll = !!payload.canSeeAll;
  buildControls();
  if (!state.agencyMode || !state.departments[state.agencyMode]) state.agencyMode = state.uiTheme?.defaultAgency || state.allowedDepartments?.[0] || 'law';
  applyAgencyMode(state.agencyMode);
}

function selectTab(name) {
  if (!name || !document.getElementById(name)) return;
  document.querySelectorAll('.tab').forEach(t => t.classList.toggle('active', t.dataset.tab === name));
  document.querySelectorAll('.panel').forEach(p => p.classList.toggle('active', p.id === name));
  state.selectedTab = name;
}

function buildSelect(select, entries, firstLabel, firstValue = 'all') {
  if (!select) return;
  const old = select.value;
  select.innerHTML = `<option value="${esc(firstValue)}">${esc(firstLabel)}</option>`;
  entries.forEach(([value, label]) => {
    const opt = document.createElement('option');
    opt.value = value;
    opt.textContent = label;
    select.appendChild(opt);
  });
  if ([...select.options].some(o => o.value === old)) select.value = old;
}

function buildControls() {
  const deptEntries = Object.entries(state.departments).map(([key, dept]) => [key, dept.label || key]);
  buildSelect(document.getElementById('departmentFilter'), deptEntries, 'All Departments');
  buildSelect(document.getElementById('reportDepartmentInput'), deptEntries, 'Auto Department', '');

  const checks = document.getElementById('departmentChecks');
  if (checks && checks.dataset.built !== JSON.stringify(Object.keys(state.departments))) {
    checks.innerHTML = '';
    Object.entries(state.departments).forEach(([key, dept]) => {
      const label = document.createElement('label');
      label.innerHTML = `<input type="checkbox" value="${esc(key)}" ${key === 'law' ? 'checked' : ''}/> ${esc(dept.label || key)}`;
      checks.appendChild(label);
    });
    checks.dataset.built = JSON.stringify(Object.keys(state.departments));
  }

  const typeEntries = Object.entries(state.reportTypes).map(([key, cfg]) => [key, cfg.label || key]);
  buildSelect(document.getElementById('reportTypeFilter'), typeEntries, 'All Report Types');
  buildSelect(document.getElementById('reportTypeInput'), typeEntries, 'General Incident Report', 'incident');

  const statusEntries = Object.entries(state.reportStatuses).map(([key, cfg]) => [key, cfg.label || key]);
  buildSelect(document.getElementById('reportStatusFilter'), statusEntries, 'All Report Statuses');
  buildSelect(document.getElementById('reportStatusInput'), statusEntries, 'Draft', 'draft');

  const callSelect = document.getElementById('reportCallInput');
  if (callSelect) {
    const previous = callSelect.value;
    callSelect.innerHTML = '<option value="">No Linked Call</option>';
    objectValues(state.calls).sort((a, b) => b.createdAt - a.createdAt).forEach(call => {
      const opt = document.createElement('option');
      opt.value = call.id;
      opt.textContent = `#${call.id} ${call.code || ''} — ${call.title || 'Call'} (${call.caseId || 'No Case'})`;
      callSelect.appendChild(opt);
    });
    if ([...callSelect.options].some(o => o.value === previous)) callSelect.value = previous;
  }
  renderAgencyMode();
  buildIncidentControls();
}

function filteredCalls() {
  const search = document.getElementById('searchInput').value.toLowerCase();
  const department = document.getElementById('departmentFilter').value;
  const status = document.getElementById('statusFilter').value;
  return objectValues(state.calls)
    .filter(call => {
      const haystack = `${call.id} ${call.caseId} ${call.code} ${call.title} ${call.description} ${call.location} ${call.caller?.name} ${(call.tags || []).join(' ')} ${call.incidentClass || ''} ${call.responseLevel || ''} ${(call.riskFlags || []).join(' ')} ${call.staging || ''} ${call.command || ''} ${call.radioChannel || ''} ${(call.unitsRequested || []).join(' ')}`.toLowerCase();
      if (search && !haystack.includes(search)) return false;
      if (department !== 'all' && !(call.departments || []).includes(department)) return false;
      if (status === 'active' && ['closed', 'cancelled'].includes(call.status)) return false;
      if (status !== 'all' && status !== 'active' && call.status !== status) return false;
      return true;
    })
    .sort((a, b) => (a.priority - b.priority) || (b.createdAt - a.createdAt));
}

function filteredReports() {
  const search = document.getElementById('searchInput').value.toLowerCase();
  const department = document.getElementById('departmentFilter').value;
  const type = document.getElementById('reportTypeFilter')?.value || 'all';
  const status = document.getElementById('reportStatusFilter')?.value || 'all';
  return objectValues(state.reports)
    .filter(report => {
      const involved = Object.values(report.involved || {}).flat().join(' ');
      const haystack = `${report.id} ${report.reportNumber} ${report.caseId} ${report.type} ${report.title} ${report.summary} ${report.narrative} ${report.location} ${report.department} ${(report.tags || []).join(' ')} ${involved}`.toLowerCase();
      if (search && !haystack.includes(search)) return false;
      if (department !== 'all' && report.department !== department && !(report.departments || []).includes(department)) return false;
      if (type !== 'all' && report.type !== type) return false;
      if (status !== 'all' && report.status !== status) return false;
      return true;
    })
    .sort((a, b) => (b.updatedAt - a.updatedAt) || (b.createdAt - a.createdAt));
}

function renderAnalytics() {
  const el = document.getElementById('analyticsBar');
  const a = state.analytics || {};
  el.innerHTML = `
    <div class="stat"><strong>${esc(a.activeCalls || 0)}</strong><span>Active Calls</span></div>
    <div class="stat danger-text"><strong>${esc(a.criticalCalls || 0)}</strong><span>Critical</span></div>
    <div class="stat"><strong>${esc(a.availableUnits || 0)}</strong><span>Available Units</span></div>
    <div class="stat"><strong>${esc(a.openReports || 0)}</strong><span>Open Reports</span></div>
    <div class="stat warn-text"><strong>${esc(a.pendingApprovals || 0)}</strong><span>Pending Review</span></div>
    <div class="stat"><strong>${esc(a.sealedReports || 0)}</strong><span>Sealed</span></div>`;
}

function renderCalls() {
  const list = document.getElementById('callList');
  const calls = filteredCalls();
  if (!calls.length) {
    list.innerHTML = '<div class="empty">No dispatch calls match the current filters.</div>';
    return;
  }
  list.innerHTML = calls.map(call => {
    const departments = (call.departments || []).map(d => `<span class="badge dept-badge ${deptClass(d)}">${esc(getDepartmentLabel(d))}</span>`).join('');
    const assigned = (call.assignedUnits || []).map(src => {
      const unit = state.units[String(src)];
      return unit ? `${esc(unit.callsign)} ${esc(unit.name)}` : `Unit ${esc(src)}`;
    }).join(', ');
    const coords = call.coords ? esc(`${Number(call.coords.x).toFixed(1)}, ${Number(call.coords.y).toFixed(1)}`) : 'No GPS';
    const notes = (call.notes || []).slice(-2).map(note => `<div class="badge">${esc(note.byName)}: ${esc(note.text)}</div>`).join('');
    const reportButtons = `<button class="small primary" onclick="draftReportFromCall(${Number(call.id)})">Report</button>`;
    return `
      <article class="card ${deptClass(primaryDept(call))} priority-${esc(call.priority)}">
        <div class="card-head">
          <div>
            <h3>#${esc(call.id)} ${esc(call.code)} — ${esc(call.title)}</h3>
            <div class="meta">
              ${departments}
              <span class="badge">Priority ${esc(call.priority)}</span>
              <span class="badge">${esc(getStatusLabel(call.status))}</span>
              <span class="badge">${esc(call.location || 'Unknown')}</span>
              <span class="badge">GPS ${coords}</span>
              <span class="badge">${esc(timeAgo(call.createdAt))}</span>
            </div>
          </div>
          <div class="meta"><span class="badge">Case ${esc(call.caseId || 'N/A')}</span>${(call.linkedReports || []).length ? `<span class="badge">Reports ${(call.linkedReports || []).length}</span>` : ''}</div>
        </div>
        <p class="desc">${esc(call.description)}</p>
        <div class="call-intel">
          ${call.incidentClass ? `<span class="badge">Class ${esc(prettyKey(call.incidentClass))}</span>` : ''}
          ${call.responseLevel ? `<span class="badge">Response ${esc(prettyKey(call.responseLevel))}</span>` : ''}
          ${call.staging ? `<span class="badge">Staging ${esc(call.staging)}</span>` : ''}
          ${call.radioChannel ? `<span class="badge">Channel ${esc(call.radioChannel)}</span>` : ''}
          ${call.command ? `<span class="badge">Command ${esc(call.command)}</span>` : ''}
        </div>
        ${(call.riskFlags || []).length ? `<div class="meta">${displayLines(call.riskFlags, 'No risk flags')}</div>` : ''}
        <div class="meta"><span>Caller: ${esc(call.caller?.name || 'Unknown')}</span>${assigned ? `<span class="assigned">Assigned: ${assigned}</span>` : '<span>No units assigned</span>'}</div>
        <div class="actions">
          <button class="small success" onclick="assignSelf(${Number(call.id)})">Assign Self</button>
          <button class="small" onclick="setCallStatus(${Number(call.id)}, 'enroute')">En Route</button>
          <button class="small" onclick="setCallStatus(${Number(call.id)}, 'onscene')">On Scene</button>
          <button class="small" onclick="setCallStatus(${Number(call.id)}, 'investigating')">Investigating</button>
          <button class="small" onclick="setCallStatus(${Number(call.id)}, 'holding')">Hold</button>
          <button class="small" onclick="setGps(${Number(call.id)})">GPS</button>
          <button class="small" onclick="copyLocation(${Number(call.id)})">Coords</button>
          ${reportButtons}
          <button class="small" onclick="setCallStatus(${Number(call.id)}, 'closed')">Close</button>
          <button class="small danger" onclick="setCallStatus(${Number(call.id)}, 'cancelled')">Cancel</button>
        </div>
        <div class="note-input">
          <input id="note-${Number(call.id)}" placeholder="Add dispatch note..." />
          <button class="small" onclick="addNote(${Number(call.id)})">Add Note</button>
        </div>
        <div class="meta" style="margin-top:10px">${notes}</div>
      </article>`;
  }).join('');
}

function renderUnits() {
  const list = document.getElementById('unitList');
  const units = objectValues(state.units).sort((a, b) => String(a.callsign).localeCompare(String(b.callsign)));
  if (!units.length) {
    list.innerHTML = '<div class="empty">No active units are registered with dispatch.</div>';
    return;
  }
  list.innerHTML = units.map(unit => {
    const departments = (unit.departments || []).map(d => `<span class="badge dept-badge ${deptClass(d)}">${esc(getDepartmentLabel(d))}</span>`).join('');
    const call = unit.assignedCall ? state.calls[String(unit.assignedCall)] : null;
    return `
      <article class="card ${deptClass(primaryDept(unit))} ${unit.status === 'panic' ? 'priority-1' : ''}">
        <div class="card-head">
          <div>
            <h3>${esc(unit.callsign)} — ${esc(unit.name)}</h3>
            <div class="meta">
              ${departments}
              <span class="badge">${esc(unit.jobLabel || unit.job)}</span>
              <span class="badge">${esc(getUnitStatusLabel(unit.status))}</span>
              ${unit.radio ? `<span class="badge">Radio ${esc(unit.radio)}</span>` : ''}
              ${call ? `<span class="badge">Assigned #${esc(call.id)} ${esc(call.code)}</span>` : ''}
            </div>
          </div>
          <span class="unit-pill">${esc(timeAgo(unit.lastSeen))}</span>
        </div>
        <div class="actions">
          ${objectValues(state.calls).filter(c => !['closed', 'cancelled'].includes(c.status)).slice(0, 8).map(c => `<button class="small" onclick="assignUnit(${Number(c.id)}, ${Number(unit.source || unit.src)})">Assign #${esc(c.id)}</button>`).join('')}
          ${unit.assignedCall ? `<button class="small danger" onclick="unassignUnit(${Number(unit.assignedCall)}, ${Number(unit.source || unit.src)})">Unassign</button>` : ''}
        </div>
      </article>`;
  }).join('');
}

function renderReports() {
  const list = document.getElementById('reportList');
  const reports = filteredReports();
  if (!reports.length) {
    list.innerHTML = '<div class="empty">No reports match the current filters. Create one from the Report Builder or convert a call into a report.</div>';
    return;
  }
  list.innerHTML = reports.map(report => {
    const flags = [report.sealed ? 'SEALED' : '', report.confidential ? 'CONFIDENTIAL' : '', report.locked ? 'LOCKED' : ''].filter(Boolean).map(v => `<span class="badge danger-badge">${v}</span>`).join('');
    const call = report.callId ? state.calls[String(report.callId)] : null;
    const mdtRef = report.meta?.mdtRef || report.meta?.mdtReportId || '';
    const tags = (report.tags || []).slice(0, 8).map(t => `<span class="badge">${esc(t)}</span>`).join('');
    return `
      <article class="card report-card ${deptClass(primaryDept(report))} ${String(state.selectedReportId) === String(report.id) ? 'selected-card' : ''}">
        <div class="card-head">
          <div>
            <h3>${esc(report.reportNumber)} — ${esc(report.title)}</h3>
            <div class="meta">
              <span class="badge">${esc(getReportTypeLabel(report.type))}</span>
              <span class="badge dept-badge ${deptClass(report.department)}">${esc(getDepartmentFull(report.department))}</span>
              <span class="badge">${esc(getReportStatusLabel(report.status))}</span>
              <span class="badge">Priority ${esc(report.priority)}</span>
              <span class="badge">Case ${esc(report.caseId || 'N/A')}</span>
              ${call ? `<span class="badge">Linked #${esc(call.id)} ${esc(call.code)}</span>` : ''}
              ${mdtRef ? `<span class="badge">MDT ${esc(mdtRef)}</span>` : ''}
              ${flags}
            </div>
          </div>
          <span class="unit-pill">Updated ${esc(timeAgo(report.updatedAt))}</span>
        </div>
        <p class="desc">${esc(report.summary || report.narrative || 'No report summary.')}</p>
        <div class="meta">${tags}</div>
        <div class="actions">
          <button class="small primary" onclick="openReport(${Number(report.id)})">Open / Edit</button>
          <button class="small" onclick="setReportStatus(${Number(report.id)}, 'supervisor_review')">Supervisor Review</button>
          <button class="small" onclick="setReportStatus(${Number(report.id)}, 'doj_review')">DOJ Review</button>
          <button class="small success" onclick="setReportStatus(${Number(report.id)}, 'approved')">Approve</button>
          <button class="small danger" onclick="setReportStatus(${Number(report.id)}, 'returned')">Return</button>
          <button class="small" onclick="setReportStatus(${Number(report.id)}, 'archived')">Archive</button>
        </div>
      </article>`;
  }).join('');
}

function renderMdt() {
  const list = document.getElementById('mdtList');
  const rows = [];
  objectValues(state.calls).forEach(call => rows.push({ kind: 'Call', id: `#${call.id}`, title: call.title, ref: call.meta?.mdtRef || call.meta?.mdtCaseId || call.caseId, updatedAt: call.updatedAt }));
  objectValues(state.reports).forEach(report => rows.push({ kind: 'Report', id: report.reportNumber, title: report.title, ref: report.meta?.mdtRef || report.meta?.mdtReportId || report.caseId, updatedAt: report.updatedAt }));
  rows.sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0));
  list.innerHTML = rows.length ? rows.slice(0, 30).map(row => `
    <div class="mdt-row">
      <span class="badge">${esc(row.kind)}</span>
      <strong>${esc(row.id)}</strong>
      <span>${esc(row.title || '')}</span>
      <span class="badge">${esc(row.ref || 'Awaiting sync')}</span>
    </div>`).join('') : '<div class="empty">No MDT-linked calls or reports yet.</div>';
}

function renderAudit() {
  const list = document.getElementById('auditList');
  const callRows = objectValues(state.calls).map(call => ({ type: 'call', updatedAt: call.updatedAt, item: call }));
  const reportRows = objectValues(state.reports).map(report => ({ type: 'report', updatedAt: report.updatedAt, item: report }));
  const rows = [...callRows, ...reportRows].sort((a, b) => b.updatedAt - a.updatedAt).slice(0, 80);
  if (!rows.length) {
    list.innerHTML = '<div class="empty">No dispatch audit history is loaded.</div>';
    return;
  }
  list.innerHTML = rows.map(row => {
    if (row.type === 'call') {
      const call = row.item;
      const notes = (call.notes || []).map(note => `<div class="badge">${esc(timeAgo(note.at))} — ${esc(note.byName)}: ${esc(note.text)}</div>`).join('') || '<span class="badge">No notes</span>';
      return `<article class="card"><h3>Call #${esc(call.id)} ${esc(call.title)}</h3><div class="meta">${notes}</div></article>`;
    }
    const report = row.item;
    const audit = (report.audit || []).map(a => `<div class="badge">${esc(timeAgo(a.at))} — ${esc(a.byName)}: ${esc(a.action)}</div>`).join('') || '<span class="badge">No audit entries</span>';
    return `<article class="card"><h3>Report ${esc(report.reportNumber)} ${esc(report.title)}</h3><div class="meta">${audit}</div></article>`;
  }).join('');
}

function renderCommand() {
  const el = document.getElementById('commandView');
  if (!el) return;
  const agency = currentAgency();
  const activeCalls = objectValues(state.calls).filter(c => !['closed', 'cancelled'].includes(c.status));
  const agencyCalls = activeCalls.filter(c => (c.departments || []).includes(agency));
  const agencyUnits = objectValues(state.units).filter(u => (u.departments || [u.department]).includes(agency));
  const critical = agencyCalls.filter(c => Number(c.priority) === 1);
  const available = agencyUnits.filter(u => u.status === 'available');
  const newest = agencyCalls.slice().sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0))[0];
  const sop = state.dispatchSOPs?.[agency] || [];
  const pendingReports = objectValues(state.reports).filter(r => (r.department === agency || (r.departments || []).includes(agency)) && ['submitted', 'supervisor_review', 'doj_review'].includes(r.status));
  const boloLike = activeCalls.filter(c => (c.tags || []).join(' ').toLowerCase().includes('bolo') || (c.incidentClass || '').includes('bolo') || (c.riskFlags || []).join(' ').toLowerCase().includes('flee'));
  el.innerHTML = `
    <div class="command-stack">
      <article class="card command-card ${deptClass(agency)}">
        <h3>${esc(getDepartmentFull(agency))} Live Command <span class="badge">${esc(prettyKey(agency))} Mode</span></h3>
        <p class="desc">Agency-specific command board with active incidents, AVL/unit status, SOP checklist, MDT/RMS links, supervisor queue, and risk flags.</p>
        <div class="kpi-row">
          <div class="kpi-box"><strong>${esc(agencyCalls.length)}</strong><span>Agency Calls</span></div>
          <div class="kpi-box"><strong>${esc(critical.length)}</strong><span>Critical</span></div>
          <div class="kpi-box"><strong>${esc(available.length)}</strong><span>Available Units</span></div>
        </div>
      </article>
      <article class="card command-card ${deptClass(primaryDept(newest || { department: agency }))}">
        <h3>Current Focus ${newest ? `<span class="badge">#${esc(newest.id)}</span>` : ''}</h3>
        ${newest ? `<p class="desc">${esc(newest.code)} — ${esc(newest.title)}\n${esc(newest.description || '')}</p>
        <div class="meta">${displayLines([newest.location, newest.responseLevel && prettyKey(newest.responseLevel), newest.radioChannel, newest.command].filter(Boolean), 'No focus incident')}</div>
        <div class="meta">${displayLines(newest.riskFlags || [], 'No current risk flags')}</div>` : '<p class="desc">No active agency call is currently selected by filters.</p>'}
      </article>
    </div>
    <div class="command-stack">
      <article class="card command-card ${deptClass(agency)}">
        <h3>Recommended SOP</h3>
        <div class="sop-list">${displayLines(sop, 'No SOP configured for this agency')}</div>
      </article>
      <article class="card command-card ${deptClass(agency)}">
        <h3>Supervisor / RMS Queue <span class="badge">${esc(pendingReports.length)}</span></h3>
        <div class="timeline">${pendingReports.slice(0, 6).map(r => `<div class="timeline-row"><strong>${esc(r.reportNumber)}</strong> — ${esc(r.title)} • ${esc(getReportStatusLabel(r.status))}</div>`).join('') || '<div class="timeline-row">No pending reports for this agency.</div>'}</div>
      </article>
    </div>
    <div class="command-stack">
      <article class="card command-card ${deptClass(agency)}">
        <h3>Unit Availability / AVL</h3>
        <div class="timeline">${agencyUnits.slice(0, 10).map(u => `<div class="timeline-row"><strong>${esc(u.callsign || 'UNIT')}</strong> ${esc(u.name || '')} — ${esc(getUnitStatusLabel(u.status))}${u.radio ? ' • ' + esc(u.radio) : ''}</div>`).join('') || '<div class="timeline-row">No active units for this agency.</div>'}</div>
      </article>
      <article class="card command-card ${deptClass(agency)}">
        <h3>BOLO / Safety Alerts <span class="badge">${esc(boloLike.length)}</span></h3>
        <div class="timeline">${boloLike.slice(0, 6).map(c => `<div class="timeline-row"><strong>#${esc(c.id)} ${esc(c.code)}</strong> — ${esc(c.title)} • ${esc((c.riskFlags || []).join(', ') || 'risk pending')}</div>`).join('') || '<div class="timeline-row">No BOLO/safety alerts currently flagged.</div>'}</div>
      </article>
    </div>`;
}

function render() {
  renderAnalytics();
  renderCommand();
  renderCalls();
  renderUnits();
  renderReports();
  renderMdt();
  renderAudit();
}

function reportPayload() {
  return {
    type: document.getElementById('reportTypeInput').value || 'incident',
    callId: document.getElementById('reportCallInput').value || false,
    department: document.getElementById('reportDepartmentInput').value || undefined,
    priority: Number(document.getElementById('reportPriorityInput').value || 3),
    status: document.getElementById('reportStatusInput').value || 'draft',
    title: document.getElementById('reportTitleInput').value || 'Dispatch Report',
    summary: document.getElementById('reportSummaryInput').value || 'No summary provided.',
    narrative: document.getElementById('reportNarrativeInput').value || '',
    location: document.getElementById('reportLocationInput').value || '',
    tags: lines(document.getElementById('reportTagsInput').value),
    involved: {
      involvedPersons: linesFromTextarea('involvedPersonsInput'),
      vehicles: linesFromTextarea('vehiclesInput'),
      witnesses: linesFromTextarea('witnessesInput'),
      evidence: linesFromTextarea('evidenceInput'),
      attachments: linesFromTextarea('evidenceInput'),
      charges: linesFromTextarea('chargesInput'),
      medical: linesFromTextarea('medicalInput'),
      fire: linesFromTextarea('fireInput'),
      court: linesFromTextarea('courtInput'),
      corrections: linesFromTextarea('correctionsInput'),
      adminActions: linesFromTextarea('adminActionsInput'),
      riskFlags: linesFromTextarea('reportRiskInput'),
      dispatchTimeline: linesFromTextarea('dispatchTimelineInput'),
      supervisorNotes: linesFromTextarea('supervisorNotesInput'),
      disposition: linesFromTextarea('dispositionInput'),
      mdtLinks: linesFromTextarea('mdtLinksInput'),
      qaChecklist: linesFromTextarea('qaChecklistInput'),
      ncicChecks: linesFromTextarea('ncicChecksInput'),
      property: linesFromTextarea('propertyInput'),
      chainOfCustody: linesFromTextarea('propertyInput')
    },
    sealed: bool('sealedInput'),
    confidential: bool('confidentialInput'),
    locked: bool('lockedInput'),
    useCurrentLocation: bool('reportUseCurrentLocation')
  };
}

function resetReportForm() {
  state.selectedReportId = null;
  document.getElementById('reportForm').reset();
  document.getElementById('reportUseCurrentLocation').checked = true;
  document.getElementById('reportStatusInput').value = 'draft';
  document.getElementById('reportTypeInput').value = 'incident';
  document.getElementById('reportPriorityInput').value = '3';
  document.getElementById('reportBuilderTitle').textContent = 'Advanced Dispatch Report Builder';
  selectTab('builder');
  renderReports();
}

function setOwnRecord(collection, key, value) {
  const safeKey = String(key ?? '').trim();
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(safeKey)) return false;
  Object.defineProperty(collection, safeKey, { value, writable: true, enumerable: true, configurable: true });
  return true;
}

function fillText(id, value) { const el = document.getElementById(id); if (el) el.value = Array.isArray(value) ? value.join('\n') : (value || ''); }
function setChecked(id, value) { const el = document.getElementById(id); if (el) el.checked = !!value; }

window.openReport = (reportId) => {
  const report = state.reports[String(reportId)];
  if (!report) return;
  state.selectedReportId = reportId;
  document.getElementById('reportBuilderTitle').textContent = `Editing ${report.reportNumber || ('Report #' + report.id)}`;
  fillText('reportTypeInput', report.type || 'incident');
  fillText('reportCallInput', report.callId || '');
  fillText('reportDepartmentInput', report.department || '');
  fillText('reportPriorityInput', report.priority || 3);
  fillText('reportStatusInput', report.status || 'draft');
  fillText('reportLocationInput', report.location || '');
  fillText('reportTagsInput', (report.tags || []).join('\n'));
  fillText('reportTitleInput', report.title || '');
  fillText('reportSummaryInput', report.summary || '');
  fillText('reportNarrativeInput', report.narrative || '');
  const inv = report.involved || {};
  fillText('involvedPersonsInput', inv.involvedPersons || []);
  fillText('vehiclesInput', inv.vehicles || []);
  fillText('witnessesInput', inv.witnesses || []);
  fillText('evidenceInput', [...(inv.evidence || []), ...(inv.attachments || [])]);
  fillText('chargesInput', inv.charges || []);
  fillText('medicalInput', inv.medical || []);
  fillText('fireInput', inv.fire || []);
  fillText('courtInput', inv.court || []);
  fillText('adminActionsInput', inv.adminActions || []);
  fillText('correctionsInput', inv.corrections || []);
  fillText('reportRiskInput', inv.riskFlags || []);
  fillText('dispatchTimelineInput', inv.dispatchTimeline || []);
  fillText('supervisorNotesInput', inv.supervisorNotes || []);
  fillText('dispositionInput', inv.disposition || []);
  fillText('mdtLinksInput', inv.mdtLinks || []);
  fillText('qaChecklistInput', inv.qaChecklist || []);
  fillText('ncicChecksInput', inv.ncicChecks || []);
  fillText('propertyInput', [...(inv.property || []), ...(inv.chainOfCustody || [])]);
  setChecked('sealedInput', report.sealed);
  setChecked('confidentialInput', report.confidential);
  setChecked('lockedInput', report.locked);
  setChecked('reportUseCurrentLocation', false);
  selectTab('builder');
  renderReports();
};

window.draftReportFromCall = (callId) => {
  const call = state.calls[String(callId)];
  resetReportForm();
  if (!call) return;
  fillText('reportCallInput', call.id);
  fillText('reportDepartmentInput', call.primaryDepartment || (call.departments || [])[0] || 'law');
  fillText('reportPriorityInput', call.priority || 3);
  fillText('reportTitleInput', call.title || 'Dispatch Report');
  fillText('reportSummaryInput', call.description || '');
  fillText('reportLocationInput', call.location || '');
  fillText('reportTagsInput', (call.tags || []).join('\n'));
  fillText('reportRiskInput', (call.riskFlags || []).join('\n'));
  fillText('dispatchTimelineInput', [`CAD created ${timeAgo(call.createdAt)}`, `Current status: ${getStatusLabel(call.status)}`, call.radioChannel ? `Radio: ${call.radioChannel}` : '', call.command ? `Command: ${call.command}` : ''].filter(Boolean));
  fillText('qaChecklistInput', ['Call linked to CAD', 'Narrative required', 'Evidence/bodycam reviewed if available', 'Supervisor review before approval']);
  fillText('mdtLinksInput', call.meta?.mdtRef || call.meta?.mdtCaseId || call.caseId || '');
  setChecked('reportUseCurrentLocation', false);
  selectTab('builder');
};

window.setReportStatus = (reportId, status) => nui('updateReport', { reportId, changes: { status, auditAction: `status:${status}` } });
window.assignSelf = (callId) => nui('assignSelf', { callId });
window.assignUnit = (callId, unitSrc) => nui('assignUnit', { callId, unitSrc });
window.unassignUnit = (callId, unitSrc) => nui('unassignUnit', { callId, unitSrc });
window.setCallStatus = (callId, status) => nui('setCallStatus', { callId, status });
window.setGps = (callId) => {
  const call = state.calls[String(callId)];
  if (call?.coords) nui('setGps', { coords: call.coords });
};
window.copyLocation = (callId) => {
  const call = state.calls[String(callId)];
  if (call?.coords) nui('copyLocation', { coords: call.coords });
};
window.addNote = (callId) => {
  const input = document.getElementById(`note-${callId}`);
  if (!input || !input.value.trim()) return;
  nui('addNote', { callId, note: input.value.trim() });
  input.value = '';
};

window.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.action === 'open') app.classList.remove('hidden');
  if (data.action === 'close') app.classList.add('hidden');
  if (data.action === 'syncState') syncState(data.state);
  if (data.action === 'newCall') {
    setOwnRecord(state.calls, String(data.call.id), data.call);
    render();
  }
  if (data.action === 'setTab') selectTab(data.tab);
  if (data.tab) selectTab(data.tab);
});

document.querySelectorAll('.tab').forEach(tab => {
  tab.addEventListener('click', () => selectTab(tab.dataset.tab));
});

document.getElementById('closeBtn').addEventListener('click', () => nui('close'));
document.getElementById('refreshBtn').addEventListener('click', async () => syncState(await nui('requestState')));
document.getElementById('panicBtn').addEventListener('click', () => nui('panic', { message: 'Panic button activated from DPN Dispatch UI.' }));
document.getElementById('searchInput').addEventListener('input', render);
document.getElementById('departmentFilter').addEventListener('change', render);
document.getElementById('statusFilter').addEventListener('change', renderCalls);
document.getElementById('reportTypeFilter').addEventListener('change', renderReports);
document.getElementById('reportStatusFilter').addEventListener('change', renderReports);
document.getElementById('newReportBtn').addEventListener('click', resetReportForm);
document.getElementById('clearReportSelectionBtn').addEventListener('click', resetReportForm);
document.getElementById('forceMdtSyncBtn').addEventListener('click', () => nui('forceMdtSync'));


document.getElementById('departmentChecks')?.addEventListener('change', () => {
  const checked = [...document.querySelectorAll('#departmentChecks input:checked')].map(el => el.value);
  if (checked[0]) applyAgencyMode(checked[0]);
});

document.getElementById('setStatusBtn').addEventListener('click', () => {
  nui('setUnitStatus', {
    status: document.getElementById('myStatus').value,
    radio: document.getElementById('radioInput').value
  });
});

document.getElementById('createForm').addEventListener('submit', (event) => {
  event.preventDefault();
  const departments = [...document.querySelectorAll('#departmentChecks input:checked')].map(el => el.value);
  nui('createCall', {
    departments: departments.length ? departments : ['law'],
    code: document.getElementById('callCode').value || '911',
    priority: Number(document.getElementById('priorityInput').value || 3),
    title: document.getElementById('titleInput').value || 'Dispatch Call',
    description: document.getElementById('descriptionInput').value || 'No details provided.',
    incidentClass: document.getElementById('incidentClassInput').value,
    responseLevel: document.getElementById('responseLevelInput').value,
    riskFlags: linesFromTextarea('riskFlagsInput'),
    staging: document.getElementById('stagingInput').value,
    command: document.getElementById('commandInput').value,
    radioChannel: document.getElementById('radioChannelInput').value,
    unitsRequested: linesFromTextarea('unitsRequestedInput'),
    recommendedResponse: linesFromTextarea('responsePlanInput'),
    sop: linesFromTextarea('responsePlanInput'),
    location: document.getElementById('locationInput').value,
    useCurrentLocation: document.getElementById('useCurrentLocation').checked
  });
  event.target.reset();
  document.getElementById('useCurrentLocation').checked = true;
  const sopBox = document.getElementById('responsePlanInput');
  if (sopBox) sopBox.value = (state.dispatchSOPs?.[currentAgency()] || []).join('\n');
});

document.getElementById('createReportBtn').addEventListener('click', () => nui('createReport', reportPayload()));
document.getElementById('saveReportBtn').addEventListener('click', () => {
  if (!state.selectedReportId) return nui('createReport', reportPayload());
  nui('updateReport', { reportId: state.selectedReportId, changes: reportPayload() });
});
document.getElementById('submitReportBtn').addEventListener('click', () => {
  const payload = reportPayload();
  payload.status = 'supervisor_review';
  payload.auditAction = 'submitted_for_review';
  if (!state.selectedReportId) return nui('createReport', payload);
  nui('updateReport', { reportId: state.selectedReportId, changes: payload });
});

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') nui('escape');
});


if (browserPreviewMode) {
  syncState(demoState());
  app.classList.remove('hidden');
  const demoNotice = document.createElement('div');
  demoNotice.className = 'demo-notice';
  demoNotice.innerHTML = '<strong>Live Browser Preview</strong> — This is mock CAD/RMS/MDT data so you can click through the dispatch workflow outside FiveM. Inside FiveM, these buttons use real NUI callbacks, server events, SQL, and dpn-mdt bridge sync.';
  document.querySelector('.shell')?.prepend(demoNotice);
}
