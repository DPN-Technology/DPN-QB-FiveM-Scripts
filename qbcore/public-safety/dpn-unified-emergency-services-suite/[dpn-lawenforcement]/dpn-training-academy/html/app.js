const app = document.getElementById('app');
const content = document.getElementById('content');
let state = { courses:{}, certs:{}, scenarios:{}, profile:{ certs:[], records:[] }, instructor:false, academyAdmin:false, viewerSource:null, sessions:{} };
let tab = 'courses';

function post(name, data = {}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, { method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(data) });
}
function esc(v){ return String(v ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])); }
function setTab(next){ tab = next; document.querySelectorAll('nav button').forEach(b => b.classList.toggle('active', b.dataset.tab === tab)); render(); }

document.getElementById('close').onclick = () => { app.classList.add('hidden'); post('close'); };
document.querySelectorAll('nav button').forEach(b => b.onclick = () => setTab(b.dataset.tab));

window.addEventListener('message', e => {
  if (e.data.action === 'open') { state = e.data.payload; app.classList.remove('hidden'); render(); }
  if (e.data.action === 'sessions') { state.sessions = e.data.sessions || {}; render(); }
});

function renderCourses(){
  const cards = Object.entries(state.courses || {}).map(([id,c]) => `<div class="card"><h3>${esc(c.label)}</h3><p>Type: ${esc(c.type)}<br>Certification: ${esc(c.cert)}<br>Max Time: ${esc(c.maxTimeSeconds || 'N/A')} sec</p><button onclick="post('startCourse',{courseId:'${id}'})">Start Course</button></div>`).join('');
  content.innerHTML = `<div class="grid">${cards}</div><p>Use <b>/finishacademy</b> after completing an active course.</p>`;
}
function renderCerts(){
  const rows = (state.profile.certs || []).map(c => `<tr><td>${esc(c.cert_label || c.cert_id)}</td><td>${esc(c.score)}</td><td>${esc(c.issued_at)}</td><td>${esc(c.expires_at)}</td></tr>`).join('');
  content.innerHTML = `<table><thead><tr><th>Certification</th><th>Score</th><th>Issued</th><th>Expires</th></tr></thead><tbody>${rows || '<tr><td colspan="4">No certifications yet.</td></tr>'}</tbody></table>`;
}
function renderRecords(){
  const rows = (state.profile.records || []).map(r => `<tr><td>${esc(r.course_label)}</td><td>${esc(r.score)}</td><td><span class="badge ${Number(r.passed)?'good':'bad'}">${Number(r.passed)?'Passed':'Failed'}</span></td><td>${esc(r.created_at)}</td></tr>`).join('');
  content.innerHTML = `<table><thead><tr><th>Course</th><th>Score</th><th>Status</th><th>Date</th></tr></thead><tbody>${rows || '<tr><td colspan="4">No records yet.</td></tr>'}</tbody></table>`;
}
function renderScenarios(){
  const rows = Object.values(state.sessions || {}).map(s => {
    const enrolled = Object.keys(s.trainees || {}).length;
    return `<tr><td>${esc(s.id)}</td><td>${esc(s.label)}</td><td>${esc(s.status)}</td><td>${esc(s.instructorName || s.traineeName)}</td><td>${esc(enrolled)}</td></tr>`;
  }).join('');
  content.innerHTML = `<table><thead><tr><th>ID</th><th>Scenario</th><th>Status</th><th>Lead</th><th>Enrolled</th></tr></thead><tbody>${rows || '<tr><td colspan="5">No active sessions.</td></tr>'}</tbody></table>`;
}
function renderInstructor(){
  if (!state.instructor) return content.innerHTML = '<div class="card"><h3>Instructor Access Required</h3><p>You need supervisor/instructor permission.</p></div>';
  const presets = Object.entries(state.scenarios || {}).map(([id,s]) => `<option value="${id}">${esc(s.label)}</option>`).join('');
  const sessions = Object.values(state.sessions || {}).filter(s =>
    s.type === 'scenario' &&
    s.status !== 'closed' &&
    s.status !== 'abandoned' &&
    (Number(s.instructor) === Number(state.viewerSource) || (Number(s.instructor) === 0 && state.academyAdmin === true))
  );
  const sessionOptions = sessions.map(s => `<option value="${esc(s.id)}">${esc(s.label)} · ${esc(s.id)} · ${Object.keys(s.trainees || {}).length} enrolled</option>`).join('');
  const disabled = sessionOptions ? '' : 'disabled';
  content.innerHTML = `<div class="grid">
    <div class="card"><h3>Create Scenario</h3><label>Preset</label><select id="preset">${presets}</select><label>Custom Label</label><input id="label" placeholder="Optional scenario name"><label>Notes</label><textarea id="notes"></textarea><button onclick="post('createScenario',{preset:document.getElementById('preset').value,label:document.getElementById('label').value,notes:document.getElementById('notes').value})">Create At My Location</button></div>
    <div class="card"><h3>Manage Active Scenario</h3><label>Scenario</label><select id="sid" ${disabled}>${sessionOptions || '<option>No active scenarios</option>'}</select><label>Trainee Server ID</label><input id="target" type="number" min="1" placeholder="Online server ID"><div class="button-row"><button ${disabled} onclick="post('setScenarioTrainee',{sessionId:document.getElementById('sid').value,target:document.getElementById('target').value,enrolled:true})">Enroll Trainee</button><button ${disabled} onclick="post('setScenarioTrainee',{sessionId:document.getElementById('sid').value,target:document.getElementById('target').value,enrolled:false})">Remove Trainee</button></div><label>Score</label><input id="score" type="number" min="0" max="100"><label>Grade Notes</label><textarea id="gnotes"></textarea><button ${disabled} onclick="post('gradeScenario',{sessionId:document.getElementById('sid').value,target:document.getElementById('target').value,score:document.getElementById('score').value,notes:document.getElementById('gnotes').value})">Submit Grade</button><button ${disabled} onclick="post('endSession',{sessionId:document.getElementById('sid').value})">End Scenario</button></div>
  </div>`;
}
function render(){
  if(tab==='courses') renderCourses();
  if(tab==='certs') renderCerts();
  if(tab==='records') renderRecords();
  if(tab==='scenarios') renderScenarios();
  if(tab==='instructor') renderInstructor();
}
