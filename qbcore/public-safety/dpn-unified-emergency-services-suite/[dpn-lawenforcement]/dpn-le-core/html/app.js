const state = { officers: {}, calls: {}, self: null, extra: {}, config: { statuses: {} } };
const $ = (id) => document.getElementById(id);
const app = $('app');

function nui(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).then((response) => response.json().catch(() => ({ ok: true })));
}

function esc(value) {
    const node = document.createElement('div');
    node.textContent = String(value ?? '');
    return node.innerHTML;
}

function values(object) { return Object.values(object || {}); }
function callId(call) { return call.callId ?? call.id; }
function showToast(message) {
    const toast = $('toast');
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(showToast.timer);
    showToast.timer = setTimeout(() => toast.classList.remove('show'), 2600);
}

function renderIdentity() {
    const officer = state.self;
    $('title').textContent = state.config.title || 'DPN Law Enforcement Network';
    $('identity').textContent = officer ? `${officer.unit || 'UNASSIGNED'} • ${officer.name} • ${officer.jobLabel || officer.job}` : 'Secure emergency operations console';
    $('dutyBadge').textContent = officer?.onDuty ? 'ON DUTY' : 'OFF DUTY';
    $('dutyBadge').className = `badge ${officer?.onDuty ? 'on' : 'off'}`;
    if (officer?.unit) $('unitInput').value = officer.unit;
}

function renderStatuses() {
    const current = state.self?.status;
    $('statusSelect').innerHTML = Object.entries(state.config.statuses || {}).map(([code, item]) =>
        `<option value="${esc(code)}" ${code === current ? 'selected' : ''}>${esc(code)} — ${esc(item.label)}</option>`
    ).join('');
}

function assignedText(assigned) {
    const entries = values(assigned);
    if (!entries.length) return 'None';
    return entries.map((entry) => typeof entry === 'object' ? (entry.unit || entry.name || entry.src) : entry).join(', ');
}

function callCard(call) {
    const id = callId(call);
    const priority = Number(call.priority || 3);
    return `<div class="card ${priority === 1 ? 'priority' : ''}">
        <h3>${esc(id)} • ${esc(call.title || 'Dispatch Call')}</h3>
        <div class="chips"><span class="chip">Priority ${priority}</span><span class="chip">${esc(call.status || 'active')}</span><span class="chip">${esc(call.type || 'general')}</span></div>
        <p>${esc(call.description || 'No details provided.')}</p>
        <div class="meta">Assigned: ${esc(assignedText(call.assigned))}</div>
        <div class="actions"><button data-assign="${esc(id)}">Assign Self</button><button data-waypoint="${esc(id)}">Waypoint</button><button data-closecall="${esc(id)}" class="danger">Close</button></div>
    </div>`;
}

function renderCalls() {
    const calls = values(state.calls).sort((a, b) => Number(a.priority || 9) - Number(b.priority || 9) || Number(b.createdAt || 0) - Number(a.createdAt || 0));
    $('calls').innerHTML = calls.length ? calls.map(callCard).join('') : '<p class="hint">No active dispatch calls.</p>';
    const priority = calls.filter((call) => Number(call.priority) === 1).slice(0, 5);
    $('priorityCalls').innerHTML = priority.length ? priority.map(callCard).join('') : '<p class="hint">No priority-one incidents.</p>';
    $('callCount').textContent = calls.length;
    $('priorityCount').textContent = priority.length;
}

function renderUnits() {
    const units = values(state.officers).sort((a, b) => String(a.unit || '').localeCompare(String(b.unit || '')));
    $('officers').innerHTML = units.length ? units.map((unit) => `<div class="unit-card">
        <h3>${esc(unit.unit || unit.source)} • ${esc(unit.name)}</h3>
        <div class="chips"><span class="chip">${esc(unit.jobLabel || unit.job)}</span><span class="chip">${esc(unit.status || '10-7')}</span><span class="chip">${unit.onDuty ? 'On Duty' : 'Off Duty'}</span>${unit.supervisor ? '<span class="chip">Supervisor</span>' : ''}</div>
    </div>`).join('') : '<p class="hint">No emergency-network units are registered.</p>';
    $('unitCount').textContent = units.filter((unit) => unit.onDuty).length;
}

function render() {
    renderIdentity();
    renderStatuses();
    renderCalls();
    renderUnits();
}

function renderSearch(result) {
    $('searchSubject').textContent = `${result.name || 'Unknown'} • ${result.citizenid || 'No ID'}`;
    const money = result.money || {};
    const items = result.items || [];
    $('searchResults').innerHTML = `<div class="money-grid"><div>Cash<br><strong>$${Number(money.cash || 0).toLocaleString()}</strong></div><div>Bank<br><strong>$${Number(money.bank || 0).toLocaleString()}</strong></div></div>${
        items.length ? items.map((item) => `<div class="search-row"><span>${esc(item.label || item.name)}</span><strong>× ${Number(item.amount || 0)}</strong></div>`).join('') : '<p class="hint">No inventory items found.</p>'
    }`;
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'toggle') app.classList.toggle('hidden', !data.show);
    if (data.action === 'state') {
        state.officers = data.officers || {};
        state.calls = data.calls || {};
        state.self = data.self || null;
        state.extra = data.extra || {};
        state.config = data.config || state.config;
        render();
    }
    if (data.action === 'newCall' && data.call) {
        state.calls[callId(data.call)] = data.call;
        renderCalls();
    }
    if (data.action === 'searchResult') {
        renderSearch(data.result || {});
        document.querySelector('[data-tab="interactions"]').click();
    }
});

document.querySelectorAll('.nav').forEach((button) => button.addEventListener('click', () => {
    document.querySelectorAll('.nav').forEach((item) => item.classList.toggle('active', item === button));
    document.querySelectorAll('.tab').forEach((tab) => tab.classList.toggle('active', tab.id === button.dataset.tab));
}));

$('close').onclick = () => nui('close');
$('toggleDuty').onclick = () => nui('toggleDuty');
$('setStatus').onclick = () => nui('setStatus', { status: $('statusSelect').value });
$('setUnit').onclick = () => nui('setUnit', { unit: $('unitInput').value });
$('testCall').onclick = () => nui('createTestCall').then(() => showToast('Dispatch test call submitted.'));

$('interactions').addEventListener('click', (event) => {
    const action = event.target.dataset.action;
    if (!action) return;
    nui('targetAction', { action, target: $('actionTarget').value || null }).then((result) => {
        if (result.ok) showToast(`Action sent for server ID ${result.target}.`);
    });
});

$('issueCitation').onclick = () => nui('issueCitation', {
    target: $('citationTarget').value || null,
    amount: $('citationAmount').value,
    reason: $('citationReason').value
}).then((result) => { if (result.ok) showToast('Citation submitted.'); });

$('bookSuspect').onclick = () => nui('bookSuspect', {
    target: $('bookingTarget').value || null,
    charges: $('bookingCharges').value,
    sentence: $('bookingSentence').value,
    fine: $('bookingFine').value,
    notes: $('bookingNotes').value
}).then((result) => { if (result.ok) showToast('Booking submitted.'); });

function dispatchClick(event) {
    const id = event.target.dataset.assign || event.target.dataset.waypoint || event.target.dataset.closecall;
    if (!id) return;
    if (event.target.dataset.assign) nui('assignSelf', { callId: id });
    if (event.target.dataset.waypoint) nui('waypoint', { callId: id });
    if (event.target.dataset.closecall) {
        const disposition = window.prompt(`Disposition for ${id}`, 'completed');
        if (!disposition) return;
        const notes = window.prompt('Closing notes', '') || '';
        nui('closeCall', { callId: id, disposition, notes });
    }
}
$('calls').addEventListener('click', dispatchClick);
$('priorityCalls').addEventListener('click', dispatchClick);

document.addEventListener('keyup', (event) => { if (event.key === 'Escape') nui('close'); });
