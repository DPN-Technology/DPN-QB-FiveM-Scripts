const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'dpn-mdt';

const state = {
  open: false,
  page: 'dashboard',
  context: null,
  data: {
    dashboard: {}, dispatch: [], bolos: [], warrants: [], bulletins: [], roster: [], recentCharges: [], config: { modules: {} }
  },
  chargeResults: [],
  selectedCharges: []
};

const pageMeta = {
  dashboard: ['Dashboard', 'Live command overview'],
  dispatch: ['Dispatch', 'Unified emergency calls and unit response'],
  citizens: ['Citizens', 'Citizen profiles, licenses, priors, and warrants'],
  vehicles: ['Vehicles', 'Vehicle registry, plates, owners, and impounds'],
  reports: ['Reports', 'Incident reports and investigative narratives'],
  cases: ['Cases', 'Case files and long-form investigations'],
  warrants: ['Warrants', 'Active, served, and expired warrants'],
  bolos: ['BOLOs', 'Be-on-lookout alerts for people and vehicles'],
  evidence: ['Evidence', 'Evidence intake and chain of custody'],
  weapons: ['Weapons', 'Firearm registry and serial tracking'],
  roster: ['Roster', 'Live department roster and callsigns'],
  charges: ['Penal Code', 'Charge, fine, jail-time, and points definitions'],
  courts: ['Courts', 'Dockets, hearings, sentencing, and case status'],
  ems: ['EMS Medical', 'Patient care reports, triage, treatment, and transport'],
  fire: ['Fire / Rescue', 'Fire incidents, preplans, hydrants, hazards, utilities'],
  mib: ['MIB / Admin', 'Secure admin operations and emergency overrides'],
  corrections: ['Corrections', 'Intake, housing, inmate movement, transport, and custody records'],
  audit: ['Audit Trail', 'Every MDT action recorded and reviewable']
};

function $(sel) { return document.querySelector(sel); }
function el(tag, cls, html) {
  const node = document.createElement(tag);
  if (cls) node.className = cls;
  if (html !== undefined) node.innerHTML = html;
  return node;
}
function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>'"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#039;', '"': '&quot;' }[c]));
}
function jsString(value) {
  return String(value ?? '').replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\r?\n/g, ' ');
}
function money(value) {
  const n = Number(value || 0);
  return '$' + n.toLocaleString();
}
function pretty(value) {
  if (value === true) return 'Yes';
  if (value === false) return 'No';
  if (value === null || value === undefined || value === '') return 'N/A';
  return String(value);
}
function kv(label, value) {
  return `<div class="kv"><span>${escapeHtml(label)}</span><b>${escapeHtml(pretty(value))}</b></div>`;
}
function chipsFromObject(obj) {
  const entries = Object.entries(obj || {});
  if (!entries.length) return '<span class="muted">No license data found.</span>';
  return `<div class="chips">${entries.map(([k,v]) => `<span class="chip">${escapeHtml(k)}: ${escapeHtml(pretty(v))}</span>`).join('')}</div>`;
}
function badge(value) {
  const cls = String(value || 'normal').toLowerCase().replace(/[^a-z0-9_-]+/g, '-');
  return `<span class="badge ${escapeHtml(cls)}">${escapeHtml(value || 'normal')}</span>`;
}

function normalizeTheme(value) {
  const raw = String(value || '').toLowerCase();
  const aliases = {
    law: 'leo', police: 'leo', lspd: 'leo', bcso: 'leo', sahp: 'leo', fib: 'leo', sasp: 'leo', sheriff: 'leo',
    ambulance: 'ems', medical: 'ems', doctor: 'ems',
    fd: 'fire', firefighter: 'fire', firedept: 'fire', rescue: 'fire',
    court: 'courts', doj: 'courts', justice: 'courts', judge: 'courts', lawyer: 'courts',
    admin: 'mib', staff: 'mib', black: 'mib',
    doc: 'corrections', prison: 'corrections', jail: 'corrections', jailer: 'corrections', correctional: 'corrections'
  };
  return aliases[raw] || raw || 'leo';
}
function getActiveTheme() {
  return normalizeTheme(state.context?.theme || state.context?.department || state.data.config?.theme || 'leo');
}
function applyTheme(theme) {
  const active = normalizeTheme(theme || getActiveTheme());
  const themes = ['leo', 'ems', 'fire', 'courts', 'mib', 'corrections'];
  document.body.classList.remove(...themes.map(t => `theme-${t}`));
  const app = $('#app');
  if (app) app.classList.remove(...themes.map(t => `theme-${t}`));
  document.body.classList.add(`theme-${active}`);
  if (app) {
    app.classList.add(`theme-${active}`);
    app.dataset.theme = active;
  }
}

async function nui(name, payload = {}) {
  try {
    const res = await fetch(`https://${RESOURCE}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(payload)
    });
    return await res.json();
  } catch (e) {
    console.warn('NUI fallback', name, e);
    return mockResponse(name, payload);
  }
}
function serverAction(name, payload = {}) { return nui('serverAction', { name, payload }); }
function showAlert(message, type = '') {
  const alerts = $('#alerts');
  alerts.innerHTML = `<div class="alert ${type}">${escapeHtml(message)}</div>`;
  setTimeout(() => { alerts.innerHTML = ''; }, 5000);
}
function setPage(page) {
  state.page = page;
  renderNav();
  const [title, subtitle] = pageMeta[page] || [page, ''];
  $('#pageTitle').textContent = title;
  $('#pageSubtitle').textContent = subtitle;
  renderContent();
}
function modulesAllowed() {
  if (!state.context) return ['dashboard'];
  const modules = state.context.modules || [];
  return modules.length ? modules : ['dashboard'];
}
function renderNav() {
  const nav = $('#nav');
  nav.innerHTML = '';
  modulesAllowed().forEach(module => {
    const label = (state.data.config?.modules && state.data.config.modules[module]) || pageMeta[module]?.[0] || module;
    const btn = el('button', `nav-btn ${state.page === module ? 'active' : ''}`, `<span class="nav-dot"></span><span>${escapeHtml(label)}</span>`);
    btn.onclick = () => setPage(module);
    nav.appendChild(btn);
  });
}
function renderShell() {
  applyTheme();
  $('#operatorName').textContent = state.context?.name || 'DPN Operator';
  $('#operatorDept').textContent = state.context?.departmentLabel || 'Unified Emergency Service Network';
  renderNav();
}
async function refresh() {
  const result = await nui('getInitialData', {});
  if (!result.ok) { showAlert(result.error || 'Failed to refresh MDT data', 'error'); return; }
  state.context = result.context || state.context;
  state.data = { ...state.data, ...result };
  renderShell();
  renderContent();
}
function table(headers, rows) {
  return `<div class="table-wrap"><table class="table"><thead><tr>${headers.map(h => `<th>${escapeHtml(h)}</th>`).join('')}</tr></thead><tbody>${rows.join('') || `<tr><td colspan="${headers.length}" class="muted">No records found.</td></tr>`}</tbody></table></div>`;
}
function renderDashboard() {
  const d = state.data.dashboard || {};
  const cards = [
    ['Active Calls', d.activeDispatch || 0],
    ['Active Warrants', d.activeWarrants || 0],
    ['Open Cases', d.openCases || 0],
    ['Reports Today', d.reportsToday || 0],
    ['Charges Today', d.chargesToday || 0]
  ].map(([label, val]) => `<div class="card"><span class="muted">${label}</span><div class="stat">${val}</div></div>`).join('');

  const calls = (state.data.dispatch || []).slice(0, 8).map(c => `<tr><td>${escapeHtml(c.call_id || c.id)}</td><td>${badge(c.priority)}</td><td>${escapeHtml(c.title)}</td><td>${escapeHtml(c.location)}</td><td>${badge(c.status)}</td></tr>`);
  const roster = (state.data.roster || []).slice(0, 8).map(r => `<tr><td>${escapeHtml(r.callsign)}</td><td>${escapeHtml(r.name)}</td><td>${escapeHtml(r.departmentLabel)}</td><td>${badge(r.onduty ? 'On Duty' : 'Off Duty')}</td></tr>`);
  return `
    <div class="grid cols-4">${cards}</div>
    <div class="grid cols-2" style="margin-top:16px">
      <div class="card"><h3>Recent Dispatch</h3>${table(['Call', 'Priority', 'Title', 'Location', 'Status'], calls)}</div>
      <div class="card"><h3>Online Roster</h3>${table(['Callsign', 'Name', 'Department', 'Duty'], roster)}</div>
    </div>
  `;
}
function renderDispatch() {
  const calls = (state.data.dispatch || []).map(c => `<tr>
    <td><b>${escapeHtml(c.call_id || c.id)}</b><br><span class="muted">${escapeHtml(c.code || '911')}</span></td>
    <td>${badge(c.priority)}</td><td>${escapeHtml(c.title)}<br><span class="muted">${escapeHtml(c.description || '')}</span></td>
    <td>${escapeHtml(c.location)}</td><td>${badge(c.status)}</td>
    <td><div class="action-buttons"><button onclick="updateDispatch('${escapeHtml(c.call_id || c.id)}','enroute')">Enroute</button><button onclick="updateDispatch('${escapeHtml(c.call_id || c.id)}','onscene')">On Scene</button><button onclick="updateDispatch('${escapeHtml(c.call_id || c.id)}','cleared')">Clear</button></div></td>
  </tr>`);
  return `
    <div class="module-header"><h3>Dispatch Board</h3><button class="success" onclick="quickCreateCall()">Create Test Call</button></div>
    <div class="card">${table(['Call', 'Priority', 'Details', 'Location', 'Status', 'Actions'], calls)}</div>
  `;
}
function renderSearchModule(kind) {
  const title = pageMeta[kind][0];
  const action = kind === 'citizens' ? 'SearchCitizens' : 'SearchVehicles';
  return `
    <div class="module-header"><h3>${escapeHtml(title)}</h3></div>
    <div class="toolbar"><input class="search" id="searchBox" placeholder="Search ${escapeHtml(title.toLowerCase())}..." /><button onclick="runSearch('${action}')">Search</button></div>
    <div id="searchResults" class="card"><p class="muted">Enter a name, citizen ID, plate, or keyword.</p></div>
  `;
}
function renderReports() {
  return `
    <div class="split">
      <div class="card">
        <h3>Create Report</h3>
        <div class="form">
          <div class="field"><label>Type</label><select id="reportType"><option>incident</option><option>arrest</option><option>citation</option><option>medical</option><option>fire</option><option>court</option></select></div>
          <div class="field"><label>Title</label><input id="reportTitle" placeholder="Report title" /></div>
          <div class="field"><label>Priority</label><select id="reportPriority"><option>normal</option><option>low</option><option>high</option><option>critical</option></select></div>
          <div class="field"><label>Narrative</label><textarea id="reportNarrative" placeholder="Full incident narrative..."></textarea></div>
          <button class="success" onclick="createReport()">Save Report</button>
        </div>
      </div>
      <div class="card">
        <h3>Search Reports</h3>
        <div class="toolbar"><input id="reportSearch" class="search" placeholder="Search reports..." /><button onclick="searchReports()">Search</button></div>
        <div id="reportResults" class="muted">Search to display reports.</div>
      </div>
    </div>`;
}
function renderBolos() {
  const rows = (state.data.bolos || []).map(b => `<tr><td>${escapeHtml(b.title)}</td><td>${escapeHtml(b.bolo_type)}</td><td>${escapeHtml(b.plate || b.citizenid || '')}</td><td>${badge(b.priority)}</td><td>${badge(b.status)}</td></tr>`);
  return `
    <div class="split">
      <div class="card"><h3>Create BOLO</h3><div class="form">
        <div class="field"><label>Type</label><select id="boloType"><option>person</option><option>vehicle</option><option>weapon</option></select></div>
        <div class="field"><label>Title</label><input id="boloTitle" /></div>
        <div class="field"><label>Plate / Citizen ID</label><input id="boloTarget" /></div>
        <div class="field"><label>Description</label><textarea id="boloDescription"></textarea></div>
        <button class="success" onclick="createBolo()">Publish BOLO</button>
      </div></div>
      <div class="card"><h3>Active BOLOs</h3>${table(['Title','Type','Target','Priority','Status'], rows)}</div>
    </div>`;
}
function renderWarrants() {
  const rows = (state.data.warrants || []).map(w => `<tr><td>${escapeHtml(w.suspect_name || w.citizenid)}</td><td>${escapeHtml(w.title)}</td><td>${badge(w.status)}</td><td>${escapeHtml(w.expires_at || '')}</td></tr>`);
  return `
    <div class="split">
      <div class="card"><h3>Create Warrant</h3><div class="form">
        <div class="field"><label>Citizen ID</label><input id="warCitizen" /></div>
        <div class="field"><label>Suspect Name</label><input id="warName" /></div>
        <div class="field"><label>Title</label><input id="warTitle" value="Arrest Warrant" /></div>
        <div class="field"><label>Reason</label><textarea id="warReason"></textarea></div>
        <button class="success" onclick="createWarrant()">Issue Warrant</button>
      </div></div>
      <div class="card"><h3>Active Warrants</h3>${table(['Suspect','Title','Status','Expires'], rows)}</div>
    </div>`;
}
function renderCaseBuilder(type) {
  const config = {
    cases: ['CreateCase', 'Case File', ['Title', 'Summary'], ['caseTitle', 'caseSummary']],
    evidence: ['CreateEvidence', 'Evidence Intake', ['Title', 'Description'], ['evTitle', 'evDescription']],
    courts: ['CreateCourtCase', 'Court Docket', ['Title', 'Notes'], ['courtTitle', 'courtNotes']],
    ems: ['CreateMedicalRecord', 'Patient Care Report', ['Patient Name', 'Assessment / Treatment'], ['medName', 'medText']],
    fire: ['CreateFireRecord', 'Fire Incident Report', ['Address / Building', 'Actions Taken'], ['fireAddress', 'fireText']],
    mib: ['MIBAction', 'MIB Secure Action', ['Target', 'Details'], ['mibTarget', 'mibDetails']],
    corrections: ['CreateCorrectionsRecord', 'Corrections / Custody Record', ['Inmate / Citizen ID', 'Custody Notes'], ['corrTarget', 'corrText']]
  }[type];
  const [action, heading, labels, ids] = config;
  return `
    <div class="card"><h3>${heading}</h3><div class="form">
      <div class="field"><label>${labels[0]}</label><input id="${ids[0]}" /></div>
      <div class="field"><label>${labels[1]}</label><textarea id="${ids[1]}"></textarea></div>
      <button class="success" onclick="createGeneric('${type}','${action}')">Submit</button>
    </div></div>
    <div class="card" style="margin-top:16px"><h3>${pageMeta[type][0]} Notes</h3><p class="muted">This module is wired to the server database, audit trail, and unified network events. Expand its form fields in app.js/server/main.lua as your RP SOPs grow.</p></div>`;
}

function renderCharges() {
  const recentRows = (state.data.recentCharges || []).slice(0, 12).map(c => `<tr>
    <td><b>${escapeHtml(c.charge_no)}</b><br><span class="muted">${escapeHtml(c.created_at || '')}</span></td>
    <td>${escapeHtml(c.citizen_name || c.citizenid)}<br><span class="muted">${escapeHtml(c.citizenid || '')}</span></td>
    <td>${badge(c.charge_type)}<br>${badge(c.status)}</td>
    <td>${money(c.total_fine)}<br><span class="muted">${escapeHtml(c.total_jail || 0)} months / ${escapeHtml(c.total_points || 0)} pts</span></td>
    <td>${escapeHtml(c.arresting_officer_name || '')}</td>
  </tr>`);
  const categories = [
    ['','All Categories'], ['traffic','Traffic'], ['public_order','Public Order'], ['violent','Violent Crimes'], ['property','Property'],
    ['narcotics','Narcotics'], ['weapons','Weapons'], ['financial','Financial'], ['courts','Courts / DOJ'], ['corrections','Corrections'],
    ['emergency_services','Emergency Services'], ['fire_rescue','Fire / Rescue'], ['medical','EMS / Medical'], ['admin','MIB / Admin']
  ];
  const classes = [['','All Classes'], ['infraction','Infraction'], ['misdemeanor','Misdemeanor'], ['felony','Felony'], ['capital','Capital'], ['civil','Civil'], ['departmental','Departmental']];
  return `
    <div class="penal-summary">
      <div class="summary-tile"><span>Penal Library</span><b>Advanced RP Codes</b></div>
      <div class="summary-tile"><span>Selected Charges</span><b id="selectedChargeCount">${state.selectedCharges.length}</b></div>
      <div class="summary-tile"><span>Charge Output</span><b>Arrest / Citation / Court</b></div>
      <div class="summary-tile"><span>Integrations</span><b>Reports · Warrants · Courts</b></div>
    </div>
    <div class="charge-layout">
      <div class="card charge-search-card">
        <div class="module-header"><h3>Penal Code Search</h3><button onclick="searchPenalCode()">Search Codes</button></div>
        <div class="charge-filter-grid">
          <div class="field"><label>Search</label><input class="search" id="penalSearch" placeholder="Code, title, category, class, description..." onkeydown="if(event.key==='Enter') searchPenalCode()" /></div>
          <div class="field"><label>Category</label><select id="penalCategory">${categories.map(([v,l]) => `<option value="${v}">${l}</option>`).join('')}</select></div>
          <div class="field"><label>Class</label><select id="penalClass">${classes.map(([v,l]) => `<option value="${v}">${l}</option>`).join('')}</select></div>
          <button class="success" onclick="searchPenalCode()">Search</button>
        </div>
        <div id="penalResults" class="table-zone"><p class="muted">Search penal codes and add charges to the citizen charging sheet. Use category and class filters to narrow long code books fast.</p></div>
      </div>
      <div class="card charge-sheet-card">
        <h3>Citizen Charging Sheet</h3>
        <div class="form two-col-form">
          <div class="field"><label>Citizen ID</label><input id="chargeCitizenId" placeholder="Citizen ID / CID" /></div>
          <div class="field"><label>Citizen Name</label><input id="chargeCitizenName" placeholder="Auto-fills if CID exists, optional" /></div>
          <div class="field"><label>Charge Type</label><select id="chargeType"><option value="arrest">Arrest</option><option value="citation">Citation</option><option value="warrant_request">Warrant Request</option><option value="court_referral">Court Referral</option></select></div>
          <div class="field"><label>Status</label><select id="chargeStatus"><option value="filed">Filed</option><option value="pending_court">Pending Court</option><option value="convicted">Convicted</option><option value="dismissed">Dismissed</option></select></div>
          <div class="field"><label>Linked Report ID</label><input id="chargeReportId" type="number" placeholder="Optional report #" /></div>
          <div class="field"><label>Linked Case No.</label><input id="chargeCaseNo" placeholder="Optional case no." /></div>
        </div>
        <div id="selectedCharges" class="selected-charges"></div>
        <div class="field"><label>Charging Notes / Probable Cause Summary</label><textarea id="chargeNotes" placeholder="Explain the probable cause, evidence, victim/witness statements, officer observations, and charging decision..."></textarea></div>
        <div class="charge-actions"><button class="danger" onclick="clearSelectedCharges()">Clear Charges</button><button class="success" onclick="fileCitizenCharges()">File Charges</button></div>
      </div>
    </div>
    <div class="grid cols-2 stack-card">
      <div class="card"><h3>Supervisor Penal Code Builder</h3>
        <div class="form two-col-form">
          <div class="field"><label>Code</label><input id="newChargeCode" placeholder="Example: TR-226" /></div>
          <div class="field"><label>Title</label><input id="newChargeTitle" placeholder="Charge title" /></div>
          <div class="field"><label>Category</label><input id="newChargeCategory" placeholder="traffic / violent / courts" /></div>
          <div class="field"><label>Class</label><input id="newChargeClass" placeholder="infraction / misdemeanor / felony" /></div>
          <div class="field"><label>Fine</label><input id="newChargeFine" type="number" min="0" placeholder="0" /></div>
          <div class="field"><label>Jail Months</label><input id="newChargeJail" type="number" min="0" placeholder="0" /></div>
          <div class="field"><label>License Points</label><input id="newChargePoints" type="number" min="0" placeholder="0" /></div>
          <div class="field"><label>Description</label><input id="newChargeDescription" placeholder="Short charge definition" /></div>
        </div>
        <div class="charge-actions"><button onclick="createPenalCode()">Create Penal Code</button></div>
        <p class="muted">Requires the manageCharges permission grade in config.lua. SQL-seeded codes can also be edited in your database panel.</p>
      </div>
      <div class="card"><h3>Recent Filed Charges</h3>${table(['Charge No.','Citizen','Type / Status','Totals','Officer'], recentRows)}</div>
    </div>
  `;
}
function renderSelectedCharges() {
  const box = $('#selectedCharges');
  const countBox = $('#selectedChargeCount');
  if (countBox) countBox.textContent = String(state.selectedCharges.length);
  if (!box) return;
  if (!state.selectedCharges.length) {
    box.innerHTML = '<p class="muted">No charges selected yet.</p>';
    return;
  }
  let fine = 0, jail = 0, points = 0;
  const rows = state.selectedCharges.map((c, i) => {
    const count = Number(c.count || 1);
    fine += Number(c.fine || 0) * count;
    jail += Number(c.jail || 0) * count;
    points += Number(c.points || 0) * count;
    return `<tr>
      <td><b>${escapeHtml(c.code)}</b><br><span class="muted">${escapeHtml(c.category)} / ${escapeHtml(c.class)}</span></td>
      <td>${escapeHtml(c.title)}<br><span class="muted">${escapeHtml(c.description || '')}</span></td>
      <td><input class="qty-input" type="number" min="1" max="25" value="${escapeHtml(count)}" onchange="setChargeCount(${i}, this.value)" /></td>
      <td>${money(Number(c.fine || 0) * count)}<br><span class="muted">${Number(c.jail || 0) * count} months / ${Number(c.points || 0) * count} pts</span></td>
      <td><button class="danger" onclick="removeSelectedCharge(${i})">Remove</button></td>
    </tr>`;
  });
  box.innerHTML = `${table(['Code','Charge','Qty','Totals',''], rows)}<div class="charge-total-bar"><span>Total Fine: <b>${money(fine)}</b></span><span>Total Jail: <b>${jail} months</b></span><span>Total Points: <b>${points}</b></span></div>`;
}

async function searchPenalCode() {
  const res = await serverAction('SearchPenalCode', {
    query: $('#penalSearch')?.value || '',
    category: $('#penalCategory')?.value || '',
    class: $('#penalClass')?.value || '',
    limit: 250
  });
  const target = $('#penalResults');
  if (!res.ok) { target.innerHTML = `<p class="muted">${escapeHtml(res.error)}</p>`; return; }
  state.chargeResults = res.results || [];
  if (!state.chargeResults.length) {
    target.innerHTML = '<p class="muted">No penal codes matched that search/filter.</p>';
    return;
  }
  const rows = state.chargeResults.map((c, i) => `<tr>
    <td><b>${escapeHtml(c.code)}</b><div class="code-meta">${badge(c.class)}${badge(c.category)}</div></td>
    <td>${escapeHtml(c.title)}<br><span class="muted">${escapeHtml(c.description || '')}</span></td>
    <td>${money(c.fine)}<br><span class="muted">${escapeHtml(c.jail || 0)} months / ${escapeHtml(c.points || 0)} pts</span></td>
    <td><button onclick="selectPenalCharge(${i})">Add Charge</button></td>
  </tr>`);
  target.innerHTML = table(['Code','Charge Definition','Penalty','Action'], rows);
}
function selectPenalCharge(index) {
  const c = state.chargeResults[index];
  if (!c) return;
  const existing = state.selectedCharges.find(x => x.code === c.code);
  if (existing) existing.count = Number(existing.count || 1) + 1;
  else state.selectedCharges.push({ ...c, count: 1 });
  renderSelectedCharges();
}
function setChargeCount(index, value) {
  const c = state.selectedCharges[index];
  if (!c) return;
  let count = Number(value || 1);
  if (count < 1) count = 1;
  if (count > 25) count = 25;
  c.count = count;
  renderSelectedCharges();
}
function removeSelectedCharge(index) {
  state.selectedCharges.splice(index, 1);
  renderSelectedCharges();
}
function clearSelectedCharges() {
  state.selectedCharges = [];
  renderSelectedCharges();
}
async function createPenalCode() {
  const payload = {
    code: $('#newChargeCode')?.value || '',
    title: $('#newChargeTitle')?.value || '',
    category: $('#newChargeCategory')?.value || 'general',
    class: $('#newChargeClass')?.value || 'misdemeanor',
    fine: $('#newChargeFine')?.value || 0,
    jail: $('#newChargeJail')?.value || 0,
    points: $('#newChargePoints')?.value || 0,
    description: $('#newChargeDescription')?.value || ''
  };
  const res = await serverAction('CreatePenalCode', payload);
  if (!res.ok) { showAlert(res.error || 'Failed to create penal code', 'error'); return; }
  showAlert(`Penal code ${payload.code.toUpperCase()} created.`);
  ['newChargeCode','newChargeTitle','newChargeCategory','newChargeClass','newChargeFine','newChargeJail','newChargePoints','newChargeDescription'].forEach(id => { const n = $('#' + id); if (n) n.value = ''; });
  await searchPenalCode();
}

async function fileCitizenCharges() {
  const charges = state.selectedCharges.map(c => ({ id: c.id, code: c.code, count: c.count || 1 }));
  const res = await serverAction('ChargeCitizen', {
    citizenid: $('#chargeCitizenId')?.value || '',
    citizen_name: $('#chargeCitizenName')?.value || '',
    charge_type: $('#chargeType')?.value || 'arrest',
    status: $('#chargeStatus')?.value || 'filed',
    linked_report_id: $('#chargeReportId')?.value || null,
    linked_case_no: $('#chargeCaseNo')?.value || '',
    notes: $('#chargeNotes')?.value || '',
    charges
  });
  if (!res.ok) { showAlert(res.error || 'Failed to file charges', 'error'); return; }
  showAlert(`Charges filed as ${res.charge_no}. Fine ${money(res.totals?.fine || 0)}, jail ${res.totals?.jail || 0} months.`);
  state.selectedCharges = [];
  await refresh();
}

function renderRoster() {
  const rows = (state.data.roster || []).map(r => `<tr><td>${escapeHtml(r.callsign)}</td><td>${escapeHtml(r.name)}</td><td>${escapeHtml(r.departmentLabel)}</td><td>${escapeHtml(r.gradeName || r.grade)}</td><td>${badge(r.onduty ? 'On Duty' : 'Off Duty')}</td></tr>`);
  return `<div class="card"><h3>Live Roster</h3>${table(['Callsign','Name','Department','Rank','Duty'], rows)}</div>`;
}
function renderSimpleNotice() {
  return `<div class="card"><h3>${pageMeta[state.page][0]}</h3><p class="muted">This module is registered and permission-aware. Add your exact SOP forms, penal-code imports, and external script hooks inside server/main.lua and html/app.js.</p></div>`;
}
function renderContent() {
  const content = $('#content');
  const page = state.page;
  if (page === 'dashboard') content.innerHTML = renderDashboard();
  else if (page === 'dispatch') content.innerHTML = renderDispatch();
  else if (page === 'citizens' || page === 'vehicles') content.innerHTML = renderSearchModule(page);
  else if (page === 'reports') content.innerHTML = renderReports();
  else if (page === 'bolos') content.innerHTML = renderBolos();
  else if (page === 'warrants') content.innerHTML = renderWarrants();
  else if (page === 'charges') { content.innerHTML = renderCharges(); setTimeout(() => { renderSelectedCharges(); searchPenalCode(); }, 0); }
  else if (page === 'cases' || page === 'evidence' || page === 'courts' || page === 'ems' || page === 'fire' || page === 'mib' || page === 'corrections') content.innerHTML = renderCaseBuilder(page);
  else if (page === 'roster') content.innerHTML = renderRoster();
  else content.innerHTML = renderSimpleNotice();
}
async function runSearch(action) {
  const query = $('#searchBox').value;
  const res = await serverAction(action, { query, limit: 50 });
  const target = $('#searchResults');
  if (!res.ok) { target.innerHTML = `<p class="muted">${escapeHtml(res.error)}</p>`; return; }
  if (action === 'SearchCitizens') {
    const rows = (res.results || []).map(r => {
      const job = r.job || {};
      return `<tr>
        <td><b>${escapeHtml(r.citizenid)}</b><br>${r.online ? badge('Online') : badge('Offline')}</td>
        <td>${escapeHtml(r.name || '')}<br><span class="muted">${escapeHtml(r.phone || 'No phone')}</span></td>
        <td>${escapeHtml(r.birthdate || '')}<br><span class="muted">${escapeHtml(r.gender || '')}</span></td>
        <td>${escapeHtml(job.label || job.name || '')}<br><span class="muted">${escapeHtml(job.grade?.name || job.grade?.level || '')}</span></td>
        <td>${escapeHtml(r.vehicleCount || 0)} vehicles<br>${escapeHtml(r.activeWarrantCount || 0)} active warrants</td>
        <td><button onclick="getProfile('${jsString(r.citizenid)}')">Open Profile</button></td>
      </tr>`;
    });
    target.innerHTML = table(['CID','Citizen','DOB / Gender','Job','Linked Data','Action'], rows);
  } else {
    const rows = (res.results || []).map(r => `<tr>
      <td><b>${escapeHtml(r.plate)}</b>${r.fakeplate ? `<br><span class="muted">Fake: ${escapeHtml(r.fakeplate)}</span>` : ''}</td>
      <td>${escapeHtml(r.model || r.vehicle || '')}<br><span class="muted">${escapeHtml(r.hash || '')}</span></td>
      <td>${escapeHtml(r.ownerName || '')}<br><span class="muted">${escapeHtml(r.citizenid || '')}</span></td>
      <td>${escapeHtml(r.garage || '')}<br>${badge(r.stateLabel || r.state)}</td>
      <td>${escapeHtml(r.activeBoloCount || 0)} BOLOs<br>${escapeHtml(r.flagCount || 0)} flags</td>
      <td><button onclick="getVehicleProfile('${jsString(r.plate)}')">Open Vehicle</button></td>
    </tr>`);
    target.innerHTML = table(['Plate','Vehicle','Owner','Garage / State','Alerts','Action'], rows);
  }
}
async function getProfile(citizenid) {
  const res = await serverAction('GetCitizenProfile', { citizenid });
  if (!res.ok) { showAlert(res.error, 'error'); return; }
  const p = res.profile || {}; const job = p.job || {}; const gang = p.gang || {}; const linked = res.linked || {};
  const vehicleRows = (res.vehicles || []).map(v => `<tr><td>${escapeHtml(v.plate)}</td><td>${escapeHtml(v.model || v.vehicle || '')}</td><td>${escapeHtml(v.garage || '')}</td><td>${badge(v.stateLabel || v.state)}</td><td><button onclick="getVehicleProfile('${jsString(v.plate)}')">Open</button></td></tr>`);
  const warrantRows = (res.warrants || []).map(w => `<tr><td>${escapeHtml(w.title)}</td><td>${badge(w.status)}</td><td>${escapeHtml(w.signed_by || '')}</td><td>${escapeHtml(w.created_at || '')}</td></tr>`);
  const reportRows = (res.reports || []).map(r => `<tr><td>#${escapeHtml(r.id)}</td><td>${escapeHtml(r.title)}</td><td>${badge(r.priority)}</td><td>${badge(r.status)}</td></tr>`);
  const medRows = (res.medical || []).map(m => `<tr><td>${escapeHtml(m.incident_id)}</td><td>${escapeHtml(m.patient_name || p.name)}</td><td>${badge(m.triage)}</td><td>${badge(m.status)}</td></tr>`);
  const corrRows = (res.corrections || []).map(c => `<tr><td>${escapeHtml(c.record_no)}</td><td>${badge(c.custody_status)}</td><td>${escapeHtml(c.housing || '')}</td><td>${escapeHtml(c.created_at || '')}</td></tr>`);
  const weaponRows = (res.weapons || []).map(w => `<tr><td>${escapeHtml(w.weapon_name)}</td><td>${escapeHtml(w.serial)}</td><td>${badge(w.status)}</td><td>${escapeHtml(w.created_at || '')}</td></tr>`);
  const noteRows = (res.notes || []).map(n => `<tr><td>${escapeHtml(n.note_type)}</td><td>${escapeHtml(n.body)}</td><td>${escapeHtml(n.created_by)}</td><td>${escapeHtml(n.created_at || '')}</td></tr>`);
  const chargeRows = (res.charges || []).map(c => `<tr><td><b>${escapeHtml(c.charge_no)}</b><br><span class="muted">${escapeHtml(c.created_at || '')}</span></td><td>${badge(c.charge_type)}<br>${badge(c.status)}</td><td>${money(c.total_fine)}<br><span class="muted">${escapeHtml(c.total_jail || 0)} months / ${escapeHtml(c.total_points || 0)} pts</span></td><td>${escapeHtml(c.arresting_officer_name || '')}</td></tr>`);
  $('#searchResults').innerHTML = `
    <div class="profile-grid">
      <div class="card profile-hero">
        <div class="profile-title"><h3>${escapeHtml(p.name || 'Unknown Citizen')}</h3>${p.online ? badge('Online') : badge('Offline')}</div>
        ${kv('Citizen ID', p.citizenid)}${kv('Server ID', p.source || '')}${kv('Phone', p.phone)}${kv('Date of Birth', p.birthdate)}${kv('Gender', p.gender)}${kv('Nationality', p.nationality)}${kv('Fingerprint', p.fingerprint)}${kv('Blood Type', p.bloodtype)}
      </div>
      <div class="card">
        <h3>Employment / Money</h3>
        ${kv('Job', job.label || job.name)}${kv('Grade', job.grade?.name || job.grade?.level || job.grade || '')}${kv('On Duty', job.onduty)}${kv('Gang', gang.label || gang.name || 'None')}${kv('Cash', money(p.cash))}${kv('Bank', money(p.bank))}${kv('Crypto', money(p.crypto))}
      </div>
      <div class="card">
        <h3>Linked Records</h3>
        <div class="mini-stats">
          <span><b>${escapeHtml(linked.vehicles || 0)}</b> Vehicles</span><span><b>${escapeHtml(linked.activeWarrants || 0)}</b> Active Warrants</span><span><b>${escapeHtml(linked.charges || 0)}</b> Charges</span><span><b>${escapeHtml(linked.reports || 0)}</b> Reports</span><span><b>${escapeHtml(linked.cases || 0)}</b> Cases</span><span><b>${escapeHtml(linked.medical || 0)}</b> Medical</span><span><b>${escapeHtml(linked.corrections || 0)}</b> Corrections</span>
        </div>
      </div>
      <div class="card"><h3>Licenses</h3>${chipsFromObject(p.licenses)}</div>
    </div>
    <div class="card stack-card"><h3>Registered Vehicles</h3>${table(['Plate','Model','Garage','State','Action'], vehicleRows)}</div>
    <div class="grid cols-2 stack-card"><div class="card"><h3>Warrants</h3>${table(['Title','Status','Signed By','Created'], warrantRows)}</div><div class="card"><h3>Charge History</h3>${table(['Charge No.','Type / Status','Totals','Officer'], chargeRows)}</div></div>
    <div class="card stack-card"><h3>Reports</h3>${table(['ID','Title','Priority','Status'], reportRows)}</div>
    <div class="grid cols-2 stack-card"><div class="card"><h3>Medical Records</h3>${table(['Incident','Patient','Triage','Status'], medRows)}</div><div class="card"><h3>Corrections Records</h3>${table(['Record','Custody','Housing','Created'], corrRows)}</div></div>
    <div class="grid cols-2 stack-card"><div class="card"><h3>Weapons</h3>${table(['Weapon','Serial','Status','Created'], weaponRows)}</div><div class="card"><h3>Citizen Notes</h3>${table(['Type','Note','By','Created'], noteRows)}</div></div>`;
}
async function getVehicleProfile(plate) {
  const res = await serverAction('GetVehicleProfile', { plate });
  if (!res.ok) { showAlert(res.error, 'error'); return; }
  const v = res.vehicle || {}; const owner = res.owner || {}; const finance = v.finance || {};
  const reportRows = (res.reports || []).map(r => `<tr><td>#${escapeHtml(r.id)}</td><td>${escapeHtml(r.title)}</td><td>${badge(r.priority)}</td><td>${badge(r.status)}</td></tr>`);
  const boloRows = (res.bolos || []).map(b => `<tr><td>${escapeHtml(b.title)}</td><td>${badge(b.priority)}</td><td>${badge(b.status)}</td><td>${escapeHtml(b.created_at || '')}</td></tr>`);
  const flagRows = (res.flags || []).map(f => `<tr><td>${escapeHtml(f.flag_type)}</td><td>${escapeHtml(f.title)}</td><td>${badge(f.status)}</td><td>${escapeHtml(f.created_by || '')}</td></tr>`);
  $('#searchResults').innerHTML = `
    <div class="profile-grid">
      <div class="card profile-hero"><div class="profile-title"><h3>${escapeHtml(v.plate || plate)}</h3>${badge(v.stateLabel || v.state)}</div>${kv('Model', v.model || v.vehicle)}${kv('Hash', v.hash)}${kv('Fake Plate', v.fakeplate)}${kv('Garage', v.garage)}${kv('Fuel', v.fuel)}${kv('Engine', v.engine)}${kv('Body', v.body)}${kv('Mileage', v.mileage)}</div>
      <div class="card"><h3>Registered Owner</h3>${kv('Name', owner.name || v.ownerName)}${kv('Citizen ID', v.citizenid)}${kv('Phone', owner.phone)}${kv('Online', owner.online)}${v.citizenid ? `<button onclick="getProfile('${jsString(v.citizenid)}')">Open Owner Profile</button>` : ''}</div>
      <div class="card"><h3>Finance / Depot</h3>${kv('Balance', money(finance.balance))}${kv('Payment', money(finance.paymentamount))}${kv('Payments Left', finance.paymentsleft)}${kv('Finance Time', finance.financetime)}${kv('Depot Price', money(v.depotprice))}</div>
      <div class="card"><h3>Vehicle Alerts</h3><div class="mini-stats"><span><b>${escapeHtml((res.bolos || []).length)}</b> BOLOs</span><span><b>${escapeHtml((res.flags || []).length)}</b> Flags</span><span><b>${escapeHtml((res.reports || []).length)}</b> Reports</span></div></div>
    </div>
    <div class="grid cols-3 stack-card"><div class="card"><h3>BOLOs</h3>${table(['Title','Priority','Status','Created'], boloRows)}</div><div class="card"><h3>Vehicle Flags</h3>${table(['Type','Title','Status','By'], flagRows)}</div><div class="card"><h3>Linked Reports</h3>${table(['ID','Title','Priority','Status'], reportRows)}</div></div>`;
}
async function updateDispatch(call_id, status) {
  const res = await serverAction('UpdateDispatchCall', { call_id, status });
  if (res.ok) { showAlert(`Call ${call_id} marked ${status}`); await refresh(); } else showAlert(res.error, 'error');
}
async function quickCreateCall() {
  showAlert('Create real calls from dpn-dispatch exports/events. Test calls are disabled in production UI; use integration_examples/dpn-dispatch.lua.');
}
async function createReport() {
  const res = await serverAction('CreateReport', { type: $('#reportType').value, title: $('#reportTitle').value, priority: $('#reportPriority').value, narrative: $('#reportNarrative').value });
  if (res.ok) { showAlert(`Report saved #${res.id}`); } else showAlert(res.error, 'error');
}
async function searchReports() {
  const res = await serverAction('SearchReports', { query: $('#reportSearch').value });
  if (!res.ok) { showAlert(res.error, 'error'); return; }
  const rows = (res.results || []).map(r => `<tr><td>${r.id}</td><td>${escapeHtml(r.title)}</td><td>${badge(r.priority)}</td><td>${badge(r.status)}</td><td>${escapeHtml(r.author_name)}</td></tr>`);
  $('#reportResults').innerHTML = table(['ID','Title','Priority','Status','Author'], rows);
}
async function createBolo() {
  const type = $('#boloType').value; const target = $('#boloTarget').value;
  const res = await serverAction('CreateBOLO', { bolo_type: type, title: $('#boloTitle').value, description: $('#boloDescription').value, plate: type === 'vehicle' ? target : '', citizenid: type !== 'vehicle' ? target : '', priority: 'normal' });
  if (res.ok) { showAlert(`BOLO published #${res.id}`); await refresh(); } else showAlert(res.error, 'error');
}
async function createWarrant() {
  const res = await serverAction('CreateWarrant', { citizenid: $('#warCitizen').value, suspect_name: $('#warName').value, title: $('#warTitle').value, reason: $('#warReason').value, charges: [] });
  if (res.ok) { showAlert(`Warrant issued #${res.id}`); await refresh(); } else showAlert(res.error, 'error');
}
async function createGeneric(type, action) {
  let payload = {};
  if (type === 'cases') payload = { title: $('#caseTitle').value, summary: $('#caseSummary').value };
  if (type === 'evidence') payload = { title: $('#evTitle').value, description: $('#evDescription').value };
  if (type === 'courts') payload = { title: $('#courtTitle').value, notes: $('#courtNotes').value };
  if (type === 'ems') payload = { patient_name: $('#medName').value, assessment: $('#medText').value, treatment: $('#medText').value };
  if (type === 'fire') payload = { address: $('#fireAddress').value, actions_taken: $('#fireText').value };
  if (type === 'mib') payload = { action: 'emergency_override', target: $('#mibTarget').value, details: $('#mibDetails').value };
  if (type === 'corrections') payload = { citizenid: $('#corrTarget').value, notes: $('#corrText').value, status: 'active' };
  const res = await serverAction(action, payload);
  if (res.ok) showAlert(`${pageMeta[type][0]} record created`); else showAlert(res.error, 'error');
}
function mockResponse(name, payload) {
  if (name === 'getInitialData') return { ok: true, context: { name: 'Preview Operator', department: 'leo', theme: 'leo', departmentLabel: 'Law Enforcement', modules: Object.keys(pageMeta), job: { grade: 5 } }, dashboard: { activeDispatch: 3, activeWarrants: 2, openCases: 6, reportsToday: 8 }, dispatch: [{ call_id: 'CALL-0705-1001', code: '10-80', title: 'Vehicle Pursuit', description: 'Units requested', priority: 'high', location: 'Alta St', status: 'new' }], roster: [], bolos: [], warrants: [], config: { modules: Object.fromEntries(Object.entries(pageMeta).map(([k,v]) => [k,v[0]])) } };
  if (name === 'serverAction' && payload?.name === 'SearchCitizens') return { ok: true, results: [{ citizenid: 'DPN12345', name: 'John Citizen', phone: '555-0101', birthdate: '1992-04-12', gender: 'Male', online: true, source: 12, job: { label: 'Mechanic', grade: { name: 'Tech' } }, vehicleCount: 2, activeWarrantCount: 1 }] };
  if (name === 'serverAction' && payload?.name === 'SearchVehicles') return { ok: true, results: [{ plate: 'DPN001', model: 'police3', citizenid: 'DPN12345', ownerName: 'John Citizen', garage: 'pillboxgarage', stateLabel: 'Garaged', activeBoloCount: 0, flagCount: 1 }] };
  if (name === 'serverAction' && payload?.name === 'SearchPenalCode') return { ok: true, results: [{ id: 1, code: 'TR-204', title: 'Reckless Driving', category: 'traffic', class: 'misdemeanor', fine: 2500, jail: 10, points: 3, description: 'Operating a motor vehicle with willful disregard for safety.' }, { id: 2, code: 'AS-303', title: 'Assault on Emergency Personnel', category: 'violent', class: 'felony', fine: 10000, jail: 40, points: 0, description: 'Assault against emergency staff.' }] };
  if (name === 'serverAction' && payload?.name === 'ChargeCitizen') return { ok: true, id: 77, charge_no: 'CHG-0709-1776', totals: { fine: 12500, jail: 50, points: 3 }, charges: [] };
  return { ok: true, results: [] };
}
window.addEventListener('message', async (event) => {
  const data = event.data || {};
  if (data.action === 'open') { $('#app').classList.remove('hidden'); state.open = true; await refresh(); }
  if (data.action === 'close') { $('#app').classList.add('hidden'); state.open = false; }
  if (data.action === 'context') { state.context = data.context; renderShell(); }
  if (data.action === 'dispatchUpdated') { await refresh(); showAlert('Dispatch board updated.'); }
  if (data.action === 'boloUpdated') { await refresh(); showAlert('New BOLO received.'); }
});
$('#closeBtn').onclick = () => nui('close');
$('#refreshBtn').onclick = refresh;
$('#unitStatus').onchange = (e) => nui('setUnitStatus', { status: e.target.value });
applyTheme('leo');
document.addEventListener('keydown', e => { if (e.key === 'Escape') nui('close'); });

// Browser preview helper: open the interface outside FiveM for layout testing.
if (typeof GetParentResourceName !== 'function') {
  $('#app').classList.remove('hidden');
  refresh();
}
