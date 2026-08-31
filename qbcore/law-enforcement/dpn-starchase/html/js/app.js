const app = document.getElementById('app');
const titleEl = document.getElementById('title');
const unitLabelEl = document.getElementById('unitLabel');
const closeBtn = document.getElementById('closeBtn');
const fireBtn = document.getElementById('fireBtn');
const refreshBtn = document.getElementById('refreshBtn');
const trackerList = document.getElementById('trackerList');
const activeCount = document.getElementById('activeCount');
const staleCount = document.getElementById('staleCount');
const cooldownText = document.getElementById('cooldownText');
const toast = document.getElementById('toast');
const keybindList = document.getElementById('keybindList');

let trackers = {};
let cooldownUntil = 0;
let config = { cooldown: 8, lifetime: 900, controls: {} };

function resourceName() {
    return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'dpn-starchase';
}

async function nui(event, data = {}) {
    const response = await fetch(`https://${resourceName()}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    });
    return response.json().catch(() => ({ ok: false, message: 'Invalid UI response.' }));
}

function showToast(message) {
    toast.textContent = message || 'Ready.';
}

function normalizeTrackers(input) {
    const output = {};
    if (Array.isArray(input)) {
        input.forEach(t => { if (t && t.id) output[t.id] = t; });
    } else if (input && typeof input === 'object') {
        Object.keys(input).forEach(key => {
            const t = input[key];
            if (t && t.id) output[t.id] = t;
        });
    }
    return output;
}


function controlRows() {
    const controls = config.controls || {};
    const rows = [
        ['openRemote', 'Open Remote'],
        ['quickDeploy', 'Quick Deploy'],
        ['toggleLockHud', 'Toggle Lock HUD'],
        ['removeNearest', 'Remove Tracker']
    ];
    return rows.map(([key, label]) => {
        const item = controls[key] || {};
        if (item.enabled === false) return '';
        const boundKey = item.defaultKey || 'UNBOUND';
        const command = item.command ? `/${item.command}` : '';
        return `<div class="keybind-row"><span class="keybind-key">${boundKey}</span><span class="keybind-label">${label} ${command ? `<small>${command}</small>` : ''}</span></div>`;
    }).join('');
}

function renderControls() {
    if (!keybindList) return;
    keybindList.innerHTML = controlRows() || '<div class="keybind-row"><span class="keybind-key">N/A</span><span class="keybind-label">No configured keybinds</span></div>';
}

function fmtTimeLeft(expiresAt) {
    if (!expiresAt) return 'UNKNOWN';
    const left = Math.max(0, Math.floor(expiresAt - Date.now() / 1000));
    const m = Math.floor(left / 60).toString().padStart(2, '0');
    const s = Math.floor(left % 60).toString().padStart(2, '0');
    return `${m}:${s}`;
}

function isStale(t) {
    if (!t.lastUpdate) return false;
    return (Date.now() / 1000 - t.lastUpdate) > 12;
}

function trackerCard(t) {
    const stale = isStale(t);
    const plate = t.plate || 'NO PLATE';
    const street = t.street || 'Unknown Location';
    const speed = typeof t.speed === 'number' ? `${Math.round(t.speed)} MPH` : '0 MPH';
    const officer = t.officerName || 'Unknown Officer';
    const ttl = fmtTimeLeft(t.expiresAt);

    return `
        <article class="tracker-card ${stale ? 'stale' : ''}" data-id="${t.id}">
            <div class="tracker-main">
                <h3>${plate}</h3>
                <div class="tracker-meta">
                    <span class="chip red">${t.id}</span>
                    <span class="chip">${speed}</span>
                    <span class="chip">${street}</span>
                    <span class="chip">Officer: ${officer}</span>
                    <span class="chip ${stale ? 'warn' : ''}">${stale ? 'WEAK GPS' : 'LIVE GPS'}</span>
                    <span class="chip">TTL ${ttl}</span>
                </div>
            </div>
            <div class="tracker-actions">
                <button class="small-btn route" data-id="${t.id}">Route</button>
                <button class="small-btn ping" data-id="${t.id}">Ping</button>
                <button class="small-btn remove" data-id="${t.id}">Detach</button>
            </div>
        </article>`;
}

function render() {
    const list = Object.values(trackers).sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
    const stale = list.filter(isStale).length;
    activeCount.textContent = list.length;
    staleCount.textContent = stale;

    if (!list.length) {
        trackerList.innerHTML = '<div class="empty">No active StarChase trackers. Deploy from a fitted police vehicle to establish GPS lock.</div>';
    } else {
        trackerList.innerHTML = list.map(trackerCard).join('');
    }

    trackerList.querySelectorAll('.route').forEach(btn => btn.addEventListener('click', async () => {
        const resp = await nui('routeTracker', { id: btn.dataset.id });
        showToast(resp.message || 'Route updated.');
    }));

    trackerList.querySelectorAll('.ping').forEach(btn => btn.addEventListener('click', async () => {
        const resp = await nui('pingTracker', { id: btn.dataset.id });
        showToast(resp.message || 'Waypoint set.');
    }));

    trackerList.querySelectorAll('.remove').forEach(btn => btn.addEventListener('click', async () => {
        const resp = await nui('removeTracker', { id: btn.dataset.id, reason: 'remote_detach' });
        showToast(resp.message || 'Detach requested.');
        if (resp.ok) {
            delete trackers[btn.dataset.id];
            render();
        }
    }));
}

function updateCooldown() {
    const remaining = Math.max(0, Math.ceil((cooldownUntil - Date.now()) / 1000));
    cooldownText.textContent = remaining > 0 ? `${remaining}s` : 'Ready';
    fireBtn.disabled = remaining > 0;
}

setInterval(() => {
    if (!app.classList.contains('hidden')) {
        updateCooldown();
        render();
    }
}, 1000);

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') {
        config = Object.assign(config, data.config || {});
        titleEl.textContent = config.title || 'DPN StarChase';
        unitLabelEl.textContent = config.unitLabel || 'LAW GPS TRACKER SYSTEM';
        trackers = normalizeTrackers(data.trackers || {});
        app.classList.remove('hidden');
        app.style.display = 'flex';
        showToast('Remote connected.');
        renderControls();
        render();
    }
    if (data.action === 'sync') {
        trackers = normalizeTrackers(data.trackers || {});
        render();
    }
    if (data.action === 'close') {
        app.classList.add('hidden');
        app.style.display = 'none';
    }
    if (data.action === 'notify') {
        showToast(data.message || 'System update.');
    }
});

closeBtn.addEventListener('click', () => nui('close'));

refreshBtn.addEventListener('click', async () => {
    const resp = await nui('refresh');
    if (resp.ok) {
        trackers = normalizeTrackers(resp.trackers || {});
        render();
        showToast('GPS list refreshed.');
    } else {
        showToast(resp.message || 'Refresh failed.');
    }
});

fireBtn.addEventListener('click', async () => {
    updateCooldown();
    if (fireBtn.disabled) return;
    showToast('Deploying tracker...');
    const resp = await nui('fireTracker');
    showToast(resp.message || (resp.ok ? 'Tracker deployed.' : 'Launch failed.'));
    if (resp.ok) cooldownUntil = Date.now() + ((config.cooldown || 8) * 1000);
    updateCooldown();
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') nui('close');
});
