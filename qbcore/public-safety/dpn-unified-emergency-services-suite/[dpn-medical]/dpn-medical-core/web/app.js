(function () {
    'use strict';

    var app = document.getElementById('app');
    var hud = document.getElementById('hud');
    var state = null;
    var target = null;
    var bodyMeta = {};
    var treatments = [];
    var selectedPart = null;

    function byId(id) { return document.getElementById(id); }
    function setAppVisible(visible) { var show = visible === true; app.hidden = !show; app.classList.toggle('hidden', !show); app.classList.toggle('dpn-open', show); app.setAttribute('aria-hidden', String(!show)); }
    function setHudVisible(visible) { var show = visible === true; hud.hidden = !show; hud.classList.toggle('hidden', !show); hud.classList.toggle('dpn-open', show); hud.setAttribute('aria-hidden', String(!show)); }
    function number(value, fallback) { var n = Number(value); return isFinite(n) ? n : (fallback || 0); }
    function text(id, value) { var el = byId(id); if (el) { el.textContent = String(value); } }
    function post(name, data) {
        return fetch('https://' + GetParentResourceName() + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        }).then(function (response) { return response.json(); });
    }

    function triageClass(value) {
        value = String(value || 'green').toLowerCase();
        return ['green', 'yellow', 'red', 'black'].indexOf(value) >= 0 ? value : 'green';
    }

    function applyTriage(el, value) {
        if (!el) { return; }
        var triage = triageClass(value);
        el.className = 'triage ' + triage;
        el.textContent = triage.toUpperCase();
    }

    function updateHud() {
        if (!state) { setHudVisible(false); return; }
        var vitals = state.vitals || {};
        var status = state.status || {};
        text('hud-blood', Math.round(number(vitals.blood, 5000)) + ' ml');
        text('hud-spo2', Math.round(number(vitals.spo2, 99)) + '%');
        text('hud-pain', Math.round(number(status.pain, 0)));
        text('hud-shock', Math.round(number(status.shock, 0)));
        applyTriage(byId('hud-triage'), status.triage);
    }

    function updateOverview() {
        if (!state) { return; }
        var v = state.vitals || {};
        var s = state.status || {};
        text('blood', Math.round(number(v.blood, 5000)));
        text('bp', Math.round(number(v.systolic, 120)) + '/' + Math.round(number(v.diastolic, 80)));
        text('hr', Math.round(number(v.hr, 74)));
        text('rr', Math.round(number(v.rr, 16)));
        text('spo2', Math.round(number(v.spo2, 99)) + '%');
        text('temp', number(v.temp, 98.6).toFixed(1));
        text('pain', Math.round(number(s.pain, 0)));
        text('shock', Math.round(number(s.shock, 0)));
        byId('pain-bar').style.width = Math.min(100, number(s.pain, 0)) + '%';
        byId('shock-bar').style.width = Math.min(100, number(s.shock, 0)) + '%';
        applyTriage(byId('triage'), s.triage);
        text('consciousness', s.cardiacArrest ? 'Cardiac Arrest' : (s.unconscious ? 'Unconscious' : 'Conscious'));
        var a = state.advanced || {}; var n = state.neuro || {}; var c = state.circulation || {};
        text('map', Math.round(number(a.map, 0))); text('gcs', Math.round(number(n.gcs, 15))); text('news', Math.round(number(a.news, 0)));
        text('qsofa', Math.round(number(a.qsofa, 0))); text('lactate', number(a.lactate, 1).toFixed(1)); text('risk', String(a.risk || 'low').toUpperCase());
        text('rhythm', String(c.rhythm || 'sinus').replace(/_/g, ' ')); text('perfusion', String(c.perfusion || 'normal').replace(/_/g, ' '));
        var v10 = state.v10 || {}; var circulation10 = state.circulationModel || {}; var gas10 = state.bloodGas || {}; var tox10 = state.toxicity || {};
        text('command-risk', Math.round(number(v10.commandRisk, 0)) + '%');
        text('arrest-min', number(v10.predictedArrestMinutes, -1) > 0 ? Math.round(number(v10.predictedArrestMinutes, -1)) + ' min' : 'Not imminent');
        text('clot-stability', Math.round(number(circulation10.clotStability, 100)) + '%');
        text('abg-status', String(gas10.acidBase || 'normal').replace(/_/g, ' '));
        text('icu-need', Math.round(number(v10.predictedICUNeed, 0)) + '%');
        text('care-gaps', Math.round(number(v10.careGapCount, 0)));
        text('toxidrome', String(tox10.dominantToxidrome || 'none').replace(/_/g, ' '));
        text('data-confidence', Math.round(number(v10.dataConfidence, 0)) + '%');
        var v12 = state.v12 || {}; var population12 = state.populationModelV12 || {}; var cardio12 = state.cardiovascularModelV12 || {}; var vent12 = state.ventilationModelV12 || {}; var support12 = state.organSupportModelV12 || {};
        text('v12-risk', Math.round(number(v12.integratedRisk, 0)) + '%');
        text('v12-population', String(population12.group || 'adult').replace(/_/g, ' '));
        text('v12-cardiac-reserve', Math.round(number(cardio12.cardiacReserve, 100)) + '%');
        text('v12-pf-ratio', Math.round(number(vent12.pfRatio, 0)));
        text('v12-ecmo', Math.round(number(support12.ecmoNeed, 0)) + '%');
        text('v12-crrt', Math.round(number(support12.crrtNeed, 0)) + '%');
        text('v12-destination', String(v12.recommendedDestination || 'self_care').replace(/_/g, ' '));
        text('v12-decomp', number(v12.decompensationMinutes, 0) > 0 ? Math.round(number(v12.decompensationMinutes, 0)) + ' min' : 'Stable');
        byId('critical-banner').classList.toggle('hidden', !(s.cardiacArrest || s.triage === 'black' || s.triage === 'red' || number(v10.commandRisk, 0) >= 70 || number(v12.integratedRisk, 0) >= 70));
    }

    function injuryDescription(part) {
        var pieces = [];
        if ((part.bleeding || 'none') !== 'none') { pieces.push(part.bleeding + ' bleeding'); }
        if (part.internalBleeding) { pieces.push('internal bleeding'); }
        if ((part.fracture || 'none') !== 'none') { pieces.push(part.fracture + ' fracture'); }
        if (number(part.burn, 0) > 0) { pieces.push('degree ' + part.burn + ' burn'); }
        if (number(part.nerve, 0) > 0) { pieces.push('nerve trauma'); }
        if (!pieces.length) { pieces.push(number(part.damage, 0) > 0 ? 'soft-tissue trauma' : 'no active injury'); }
        return pieces.join(' · ');
    }

    function renderBody() {
        var grid = byId('body-grid');
        grid.textContent = '';
        if (!state || !state.body) { return; }
        var active = 0;
        Object.keys(bodyMeta).forEach(function (key) {
            var part = state.body[key] || {};
            var damage = Math.round(number(part.damage, 0));
            var isActive = damage > 0 || part.internalBleeding || (part.bleeding || 'none') !== 'none' || (part.fracture || 'none') !== 'none';
            if (isActive) { active += 1; }
            var card = document.createElement('button');
            card.type = 'button';
            card.className = 'body-card' + (damage >= 55 || part.internalBleeding || part.bleeding === 'arterial' ? ' critical' : '') + (selectedPart === key ? ' selected' : '');
            card.addEventListener('click', function () { selectedPart = key; renderBody(); renderTreatments(); switchTab('treatments'); });

            var info = document.createElement('div');
            var title = document.createElement('h3');
            title.textContent = (bodyMeta[key] && bodyMeta[key].label) || key;
            var description = document.createElement('p');
            description.textContent = injuryDescription(part) + ' · mobility ' + Math.round(number(part.mobility, 100)) + '%';
            info.appendChild(title); info.appendChild(description);
            var severity = document.createElement('div');
            severity.className = 'severity';
            severity.textContent = damage;
            card.appendChild(info); card.appendChild(severity);
            grid.appendChild(card);
        });
        text('injury-count', active + ' active');
    }

    function renderTreatments() {
        var grid = byId('treatment-grid');
        grid.textContent = '';
        var selectedLabel = selectedPart && bodyMeta[selectedPart] ? bodyMeta[selectedPart].label : null;
        text('selected-part-label', selectedLabel ? ('Selected region: ' + selectedLabel) : 'Select an injured body region first. Global treatments remain available.');

        treatments.forEach(function (treatment) {
            if (!treatment.global && !selectedPart) { return; }
            if (treatment.limbOnly && selectedPart && selectedPart.indexOf('_arm') < 0 && selectedPart.indexOf('_leg') < 0) { return; }
            var button = document.createElement('button');
            button.type = 'button';
            button.className = 'treatment';
            var strong = document.createElement('strong');
            strong.textContent = treatment.label;
            var small = document.createElement('small');
            small.textContent = treatment.level + (treatment.global ? ' · systemic' : ' · regional');
            button.appendChild(strong); button.appendChild(small);
            button.addEventListener('click', function () {
                button.disabled = true;
                post('treat', { treatment: treatment.id, part: treatment.global ? null : selectedPart })
                    .then(function (result) { if (!result || result.ok !== true) { button.disabled = false; } })
                    .catch(function () { button.disabled = false; });
            });
            grid.appendChild(button);
        });

        if (!grid.children.length) {
            var empty = document.createElement('div');
            empty.className = 'empty';
            empty.textContent = 'Select a compatible body region to view available treatments.';
            grid.appendChild(empty);
        }
    }

    function formatTime(timestamp) {
        var value = number(timestamp, 0);
        if (!value) { return 'Unknown time'; }
        try { return new Date(value * 1000).toLocaleTimeString(); } catch (_) { return 'Unknown time'; }
    }


    function renderClinical() {
        if (!state) { return; }
        var profile = state.profile || {}; var a = state.advanced || {}; var airway = state.airway || {}; var resp = state.respiration || {};
        var profileBox = byId('profile-summary'); profileBox.textContent = '';
        var allergies = Object.keys(profile.allergies || {}).filter(function (key) { return profile.allergies[key]; });
        [
            'Blood type: ' + (profile.bloodType || 'unknown'),
            'Code status: ' + String(profile.codeStatus || 'full_code').replace(/_/g, ' '),
            'Allergies: ' + (allergies.length ? allergies.join(', ') : 'none documented'),
            'Airway: ' + (airway.patent === false ? 'compromised' : 'patent'),
            'Oxygen: ' + number(resp.oxygenLpm, 0) + ' L/min',
            'Recommended care: ' + String(a.recommendedCare || 'routine').replace(/_/g, ' '),
            'V10 command: ' + String(((state.v10 || {}).recommendedCommand) || 'routine_monitoring').replace(/_/g, ' '),
            'Hemorrhage rate: ' + Math.round(number((state.circulationModel || {}).hemorrhageRateMlMin, 0) + number((state.circulationModel || {}).internalHemorrhageRateMlMin, 0)) + ' mL/min',
            'ABG: pH ' + number((state.bloodGas || {}).ph, 7.4).toFixed(2) + ' · PaCO2 ' + Math.round(number((state.bloodGas || {}).paCO2, 40)) + ' · Lactate ' + number((state.bloodGas || {}).lactate, 1).toFixed(1),
            'V12 population: ' + String(((state.populationModelV12 || {}).group) || 'adult').replace(/_/g, ' '),
            'V12 command: ' + String(((state.v12 || {}).commandLevel) || 'routine').replace(/_/g, ' '),
            'V12 destination: ' + String(((state.v12 || {}).recommendedDestination) || 'self_care').replace(/_/g, ' '),
            'V12 support: ' + (((state.organSupportModelV12 || {}).recommendedSupports || []).join(', ') || 'none')
        ].forEach(function (line) { var row=document.createElement('div'); row.textContent=line; profileBox.appendChild(row); });

        var protocolBox = byId('protocol-list'); protocolBox.textContent='';
        var protocols = a.protocols || [];
        if (!protocols.length) { var none=document.createElement('div'); none.textContent='No active critical protocols.'; protocolBox.appendChild(none); }
        protocols.forEach(function (protocol) {
            var row=document.createElement('div'); var title=document.createElement('strong'); title.textContent=String(protocol.id || 'protocol').replace(/_/g,' '); row.appendChild(title);
            var actions=document.createElement('small'); actions.textContent=(protocol.actions || []).join(' · '); row.appendChild(actions); protocolBox.appendChild(row);
        });

        var careBox=byId('care-plan-list'); careBox.textContent=''; var tasks=((state.carePlan || {}).tasks || []);
        if (!tasks.length) { var empty=document.createElement('div'); empty.textContent='No active care-plan tasks.'; careBox.appendChild(empty); }
        tasks.slice().sort(function(x,y){ return number(x.priority,3)-number(y.priority,3); }).forEach(function(task){
            var row=document.createElement('div'); row.className='care-task '+String(task.status || 'pending');
            var title=document.createElement('strong'); title.textContent=task.label || task.id; var status=document.createElement('span'); status.textContent=String(task.status || 'pending').toUpperCase();
            row.appendChild(title); row.appendChild(status); careBox.appendChild(row);
        });
    }

    function renderHistory() {
        var list = byId('history-list');
        list.textContent = '';
        if (!state) { return; }
        var entries = [];
        (state.timeline || []).forEach(function (item) { entries.push({ time:item.time, title:item.type || 'clinical event', detail:(item.actor || 'system'), kind:'EVENT' }); });
        (state.procedures || []).forEach(function (item) { entries.push({ time:item.time, title:item.type || 'procedure', detail:item.bodyPart || item.outcome || 'clinical', kind:'PROCEDURE' }); });
        (state.treatments || []).forEach(function (item) {
            entries.push({ time: item.time, title: item.type || 'treatment', detail: item.part || 'systemic', kind: 'TREATMENT' });
        });
        Object.keys(state.body || {}).forEach(function (partKey) {
            ((state.body[partKey] || {}).wounds || []).forEach(function (wound) {
                entries.push({ time: wound.time, title: wound.type || 'trauma', detail: (bodyMeta[partKey] && bodyMeta[partKey].label) || partKey, kind: 'INJURY' });
            });
        });
        entries.sort(function (a, b) { return number(b.time, 0) - number(a.time, 0); });
        entries.slice(0, 40).forEach(function (entry) {
            var row = document.createElement('article'); row.className = 'history-item';
            var time = document.createElement('time'); time.textContent = formatTime(entry.time);
            var title = document.createElement('strong'); title.textContent = entry.title + ' · ' + entry.detail;
            var kind = document.createElement('span'); kind.textContent = entry.kind;
            row.appendChild(time); row.appendChild(title); row.appendChild(kind); list.appendChild(row);
        });
        if (!entries.length) {
            var empty = document.createElement('div'); empty.className = 'empty'; empty.textContent = 'No clinical history is recorded for this patient.'; list.appendChild(empty);
        }
    }

    function renderAll() {
        updateHud(); updateOverview(); renderBody(); renderTreatments(); renderClinical(); renderHistory();
        text('patient-label', target ? ('Server ID ' + target) : 'Patient');
    }

    function switchTab(name) {
        document.querySelectorAll('.tab').forEach(function (button) { button.classList.toggle('active', button.getAttribute('data-tab') === name); });
        document.querySelectorAll('.view').forEach(function (view) { view.classList.toggle('active', view.id === name); });
    }

    document.querySelectorAll('.tab').forEach(function (button) {
        button.addEventListener('click', function () { switchTab(button.getAttribute('data-tab')); });
    });
    byId('close').addEventListener('click', function () { post('close'); });
    byId('refresh').addEventListener('click', function () { post('refresh'); });
    document.addEventListener('keydown', function (event) { if (event.key === 'Escape') { post('close'); } });

    window.addEventListener('message', function (event) {
        var data = event.data || {};
        if (data.state) { state = data.state; }
        if (data.target !== undefined) { target = data.target; }
        if (data.bodyMeta) { bodyMeta = data.bodyMeta; }
        if (data.treatments) { treatments = data.treatments; }

        if (data.action === 'open') {
            selectedPart = null;
            setAppVisible(true);
            switchTab('overview');
            renderAll();
        } else if (data.action === 'sync') {
            renderAll();
        } else if (data.action === 'close' || data.action === 'forceClose') {
            setAppVisible(false);
            selectedPart = null;
        } else if (data.action === 'hud') {
            setHudVisible(data.enabled === true && !!state);
            updateHud();
        }
    });
    // Fail closed on CEF load/reload. Lua explicitly opens each interface.
    setAppVisible(false);
    setHudVisible(false);
})();
