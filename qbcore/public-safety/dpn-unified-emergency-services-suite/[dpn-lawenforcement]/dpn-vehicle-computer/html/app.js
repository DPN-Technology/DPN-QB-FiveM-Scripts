const app = document.getElementById('app');
let data = {};
function post(name, payload = {}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload)
  }).then(response => response.json()).catch(() => ({}));
}
function node(tag, value, className) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (value !== undefined) element.textContent = String(value ?? '');
  return element;
}
function prependResult(containerId, lines, alert) {
  const container = document.getElementById(containerId);
  const result = node('div', undefined, alert ? 'result alert' : 'result');
  lines.forEach((line, index) => {
    if (index === 0) result.appendChild(node('b', line)); else result.append(document.createElement('br'), document.createTextNode(String(line ?? '')));
  });
  container.prepend(result);
}
function renderOpen(payload) {
  data = payload || {};
  app.classList.remove('hidden');
  document.getElementById('officer').textContent = `${data.officer?.name || 'Unknown'} | ${data.officer?.job || 'unassigned'}`;
  const vehicle = document.getElementById('vehicle');
  vehicle.replaceChildren();
  if (data.vehicle) {
    vehicle.appendChild(node('b', data.vehicle.model || 'Emergency Vehicle'));
    vehicle.append(document.createElement('br'), document.createTextNode(`Plate: ${data.vehicle.plate || 'UNKNOWN'}`));
    vehicle.append(document.createElement('br'), document.createTextNode(`Seat: ${data.vehicle.seat ?? 'Unknown'}`));
  } else vehicle.textContent = 'No vehicle data';
  const statuses = document.getElementById('statuses');
  statuses.replaceChildren();
  Object.entries(data.statuses || {}).forEach(([code, label]) => {
    const button = node('button');
    button.append(document.createTextNode(code), document.createElement('br'), document.createTextNode(String(label)));
    button.addEventListener('click', () => setStatus(code));
    statuses.appendChild(button);
  });
}
window.addEventListener('message', event => {
  if (!event || event.source !== window || event.origin !== window.location.origin) return;
  const message = event.data || {};
  if (message.action === 'open') renderOpen(message.payload);
  if (message.action === 'plateResult') plateResult(message.payload || {});
  if (message.action === 'radar') document.getElementById('speed').textContent = Number(message.payload?.speed || 0);
  if (message.action === 'alprScan') prependResult('scans', [`Scanned ${message.payload?.plate || 'UNKNOWN'} at ${message.payload?.distance || 0}m`], false);
});
function closeUI() { app.classList.add('hidden'); post('close'); }
document.addEventListener('keydown', event => { if (event.key === 'Escape') closeUI(); });
function tab(id) { document.querySelectorAll('.tab').forEach(section => section.classList.remove('active')); document.getElementById(id)?.classList.add('active'); }
function setStatus(status) { post('status', { status }); }
function panic() { post('panic'); }
function toggleRadar() { post('toggleRadar'); }
function toggleALPR() { post('toggleALPR'); }
function plateCheck() { post('plateCheck', { plate: document.getElementById('plate').value }); }
function hotlist() { post('hotlist', { plate: document.getElementById('hotPlate').value, reason: document.getElementById('hotReason').value }); }
function createCall() { post('createCall', { title: document.getElementById('callTitle').value, code: document.getElementById('callCode').value, description: document.getElementById('callDesc').value, priority: 2 }); }
function saveNote() { post('saveNote', { text: document.getElementById('noteText').value }); }
function moduleOpen(module) { post('module', { module }); }
function plateResult(result) { prependResult('plateResults', [result.plate || 'UNKNOWN', result.flagged ? 'FLAGGED' : 'Clear', result.reason || ''], result.flagged === true); }
Object.assign(window, { closeUI, tab, setStatus, panic, toggleRadar, toggleALPR, plateCheck, hotlist, createCall, saveNote, moduleOpen });
