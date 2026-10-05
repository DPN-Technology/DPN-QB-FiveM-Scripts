const app = document.getElementById('app');
const bolosEl = document.getElementById('bolos');
const eventsEl = document.getElementById('events');
const nodesEl = document.getElementById('nodes');
let cfg = { nodes: [] };
function post(name, data = {}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data)
  }).catch(() => {});
}
function el(tag, text, className) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = String(text ?? '');
  return node;
}
function action(label, callback, mode) {
  const button = el('button', label);
  if (mode) button.dataset.mode = mode;
  button.addEventListener('click', callback);
  return button;
}
document.getElementById('close').onclick = () => post('close');
document.getElementById('refresh').onclick = () => post('refreshEvents');
document.getElementById('addBolo').onclick = () => {
  const plate = document.getElementById('plate').value.trim();
  const reason = document.getElementById('reason').value.trim();
  const priority = document.getElementById('priority').value;
  if (!plate) return;
  post('addBolo', { plate, reason, priority });
  document.getElementById('plate').value = '';
  document.getElementById('reason').value = '';
};
function renderBolos(bolos) {
  bolosEl.replaceChildren();
  if (!bolos.length) return bolosEl.appendChild(el('div', 'No active BOLOs.', 'small'));
  bolos.forEach(bolo => {
    const item = el('div', undefined, 'item');
    const row = el('div', undefined, 'row');
    row.appendChild(el('strong', bolo.plate || 'UNKNOWN'));
    row.appendChild(el('span', bolo.priority || 'medium', 'badge'));
    item.appendChild(row);
    item.appendChild(el('div', bolo.reason || 'BOLO Vehicle', 'small'));
    item.appendChild(action('Clear', () => post('clearBolo', { id: bolo.id })));
    bolosEl.appendChild(item);
  });
}
function renderNodes() {
  nodesEl.replaceChildren();
  (cfg.nodes || []).forEach(node => {
    const item = el('div', undefined, 'item');
    item.appendChild(el('strong', node.name || node.id || 'Traffic Node'));
    item.appendChild(el('div', node.id || '', 'small'));
    const row = el('div', undefined, 'row');
    ['emergency', 'scene', 'normal'].forEach(mode => row.appendChild(action(mode[0].toUpperCase() + mode.slice(1), () => post('trafficOverride', { nodeId: node.id, mode }), mode)));
    item.appendChild(row);
    nodesEl.appendChild(item);
  });
}
function renderEvents(events) {
  eventsEl.replaceChildren();
  if (!events.length) return eventsEl.appendChild(el('div', 'No recent events.', 'small'));
  events.forEach(event => {
    const item = el('div', undefined, 'item');
    const row = el('div', undefined, 'row');
    row.appendChild(el('strong', event.title || 'Smart City Event'));
    row.appendChild(el('span', event.event_type || 'event', 'badge'));
    item.appendChild(row);
    item.appendChild(el('div', `${event.created_at || ''}${event.plate ? ` • ${event.plate}` : ''}`, 'small'));
    eventsEl.appendChild(item);
  });
}
window.addEventListener('message', event => {
  if (!event || event.source !== window || event.origin !== window.location.origin) return;
  const data = event.data || {};
  if (data.action === 'setVisible') app.classList.toggle('hidden', !data.visible);
  if (data.action === 'bolos') renderBolos(data.bolos || []);
  if (data.action === 'events') renderEvents(data.events || []);
  if (data.action === 'config') { cfg = data.config || cfg; renderNodes(); }
});
document.addEventListener('keydown', event => { if (event.key === 'Escape') post('close'); });
