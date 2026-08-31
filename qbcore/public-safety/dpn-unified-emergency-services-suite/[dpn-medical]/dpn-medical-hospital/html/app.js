let currentAdmission = null;
let currentBeds = {};
let wardLabels = {};
let stateLabels = {};

const app = document.getElementById('app');
const content = document.getElementById('content');
const payButton = document.getElementById('pay-button');
const dischargeButton = document.getElementById('discharge-button');
const footerStatus = document.getElementById('footer-status');

function escapeHtml(value) {
    return String(value == null ? '' : value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function money(value) {
    const amount = Number(value) || 0;
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        maximumFractionDigits: 0
    }).format(amount);
}

function labelFor(map, key, fallback) {
    return map && map[key] ? map[key] : fallback;
}

function bedSummary() {
    const beds = Object.values(currentBeds || {});
    const occupied = beds.filter((bed) => bed.occupied).length;
    return { total: beds.length, occupied, available: Math.max(0, beds.length - occupied) };
}

function renderBeds() {
    const beds = Object.values(currentBeds || {}).sort((a, b) => String(a.id).localeCompare(String(b.id)));
    if (!beds.length) return '<p class="notice">No hospital bed data is currently available.</p>';

    return `<div class="bed-list">${beds.map((bed) => `
        <div class="bed ${bed.occupied ? 'occupied' : ''}">
            <span>${escapeHtml(bed.label || bed.id)}</span>
            <span class="status-dot" title="${bed.occupied ? 'Occupied' : 'Available'}"></span>
        </div>
    `).join('')}</div>`;
}

function renderEmpty() {
    const beds = bedSummary();
    content.innerHTML = `
        <div class="empty-state">
            <div class="symbol">+</div>
            <h2>No Active Admission</h2>
            <p class="notice">You are not currently registered as an admitted hospital patient.</p>
            <p class="notice">Network bed census: ${beds.available} available of ${beds.total} total.</p>
        </div>
    `;
    payButton.disabled = true;
    dischargeButton.disabled = true;
    footerStatus.textContent = 'No active patient record';
}

function renderAdmission() {
    if (!currentAdmission) {
        renderEmpty();
        return;
    }

    const remaining = Math.max(0, Number(currentAdmission.remaining_minutes) || 0);
    const total = Math.max(remaining, Number(currentAdmission.recovery_minutes) || 0, 1);
    const completed = Math.max(0, Math.min(100, ((total - remaining) / total) * 100));
    const bill = Math.max(0, Number(currentAdmission.bill_amount) || 0);
    const beds = bedSummary();
    const statusLabel = labelFor(stateLabels, currentAdmission.status, currentAdmission.status || 'Admitted');
    const wardLabel = labelFor(wardLabels, currentAdmission.ward, currentAdmission.ward || 'ER');

    content.innerHTML = `
        <div class="grid">
            <article class="card highlight">
                <span class="label">Current Status</span>
                <div class="value accent">${escapeHtml(statusLabel)}</div>
                <div class="progress-track" aria-label="Recovery progress">
                    <div class="progress-bar" style="width:${completed.toFixed(1)}%"></div>
                </div>
                <p class="notice">${remaining > 0 ? `${remaining} recovery minute(s) remaining.` : 'Recovery timer complete. You may request discharge.'}</p>
            </article>

            <article class="card">
                <div class="metric-grid">
                    <div class="metric">
                        <span class="label">Ward</span>
                        <div class="value">${escapeHtml(wardLabel)}</div>
                    </div>
                    <div class="metric">
                        <span class="label">Bed</span>
                        <div class="value">${escapeHtml(currentAdmission.bed_id || 'Unassigned')}</div>
                    </div>
                    <div class="metric">
                        <span class="label">Severity</span>
                        <div class="value ${Number(currentAdmission.severity) >= 70 ? 'warning' : ''}">${escapeHtml(currentAdmission.severity == null ? 0 : currentAdmission.severity)}/100</div>
                    </div>
                </div>
            </article>

            <article class="card full">
                <span class="label">Admission Reason</span>
                <div class="value">${escapeHtml(currentAdmission.reason || 'Medical treatment and observation')}</div>
            </article>

            <article class="card">
                <span class="label">Outstanding Balance</span>
                <div class="value ${bill <= 0 ? 'success' : 'warning'}">${money(bill)}</div>
                <p class="notice">Bills are securely verified and processed by the server.</p>
            </article>

            <article class="card">
                <span class="label">Hospital Bed Census</span>
                <div class="value">${beds.available} Available / ${beds.total} Total</div>
                ${renderBeds()}
            </article>
        </div>
    `;

    payButton.disabled = bill <= 0;
    dischargeButton.disabled = remaining > 0;
    footerStatus.textContent = `Admission #${currentAdmission.id || 'pending'} synchronized`;
}

function setVisible(visible) {
    const shouldShow = visible === true;
    app.hidden = !shouldShow;
    app.classList.toggle('hidden', !shouldShow);
    app.classList.toggle('dpn-open', shouldShow);
    app.setAttribute('aria-hidden', String(!shouldShow));
    document.body.style.pointerEvents = shouldShow ? 'auto' : 'none';
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.wardLabels) wardLabels = data.wardLabels;
    if (data.stateLabels) stateLabels = data.stateLabels;
    if (data.beds) currentBeds = data.beds;

    if (data.action === 'open') {
        currentAdmission = data.admission || null;
        renderAdmission();
        setVisible(true);
    } else if (data.action === 'admitted' || data.action === 'sync') {
        currentAdmission = data.admission || null;
        renderAdmission();
    } else if (data.action === 'syncBeds') {
        currentBeds = data.beds || {};
        if (!app.classList.contains('hidden')) renderAdmission();
    } else if (data.action === 'discharged' || data.action === 'close' || data.action === 'forceClose') {
        currentAdmission = null;
        setVisible(false);
    }
});

async function post(endpoint, payload = {}) {
    try {
        await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload)
        });
    } catch (error) {
        console.error(`[dpn-medical-hospital] NUI ${endpoint} failed`, error);
    }
}

function closeUI() {
    setVisible(false);
    post('close');
}

function discharge() {
    if (dischargeButton.disabled) return;
    post('discharge');
}

function payBill() {
    if (payButton.disabled || !currentAdmission || !currentAdmission.id) return;
    post('payBill', { id: currentAdmission.id });
}

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !app.classList.contains('hidden')) closeUI();
});

// Fail closed: a CEF reload must never leave a full-screen layer over gameplay.
setVisible(false);
