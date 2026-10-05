const app = document.getElementById('app');
const unitsEl = document.getElementById('units');
const alertsEl = document.getElementById('alerts');
let alerts = [], units = {};
function post(name, data = {}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data)
  }).catch(() => {});
}
function element(tag, value, className) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (value !== undefined) node.textContent = String(value ?? '');
  return node;
}
document.getElementById('close').onclick = () => post('close');
document.getElementById('panic').onclick = () => post('panic');
document.querySelectorAll('[data-status]').forEach(button => button.onclick = () => post('status', { status: button.dataset.status }));
function renderUnits() {
  unitsEl.replaceChildren();
  Object.values(units || {}).forEach(unit => {
    const item = element('div', undefined, 'item');
    item.appendChild(element('b', `${unit.unit || 'UNIT'} - ${unit.officer || 'Officer'}`));
    item.appendChild(element('div', `${unit.status || 'Unknown'} • HR ${unit.heartRate || '?'} • Stress ${unit.stress || 0}%`, 'meta'));
    unitsEl.appendChild(item);
  });
}
function renderAlerts() {
  alertsEl.replaceChildren();
  [...(alerts || [])].reverse().slice(0, 35).forEach(alert => {
    const item = element('div', undefined, `item priority${Math.max(1, Math.min(4, Number(alert.priority) || 3))}`);
    item.appendChild(element('b', alert.title || alert.type || 'Safety Alert'));
    item.appendChild(element('div', alert.message || ''));
    item.appendChild(element('div', `${alert.unit || ''} ${alert.officer || ''} • ${alert.createdAt || ''}${alert.ackBy ? ` • Ack: ${alert.ackBy}` : ''}`, 'meta'));
    const button = element('button', 'Acknowledge');
    button.addEventListener('click', () => post('ack', { id: alert.id }));
    item.appendChild(button);
    alertsEl.appendChild(item);
  });
}
window.addEventListener('message', event => {
  if (!event || event.source !== window || event.origin !== window.location.origin) return;
  const message = event.data || {};
  if (message.action === 'open') {
    app.classList.remove('hidden'); units = message.units || {}; alerts = message.alerts || [];
    renderUnits(); renderAlerts();
  }
  if (message.action === 'close') app.classList.add('hidden');
  if (message.action === 'units') { units = message.units || {}; renderUnits(); }
  if (message.action === 'alerts') { alerts = message.alerts || []; renderAlerts(); }
  if (message.action === 'newAlert') { alerts.push(message.alert || {}); renderAlerts(); }
  if (message.action === 'self' && message.self) {
    document.getElementById('hr').textContent = message.self.heartRate || 78;
    document.getElementById('stress').textContent = `${message.self.stress || 0}%`;
    document.getElementById('health').textContent = message.self.health || 100;
  }
});
document.addEventListener('keyup', event => { if (event.key === 'Escape') post('close'); });
