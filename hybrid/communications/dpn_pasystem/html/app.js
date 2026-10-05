(function () {
    var resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'dpn_pasystem';
    var statusData = {};
    var settings = {};
    var selectedRange = 160;

    function $(id) { return document.getElementById(id); }

    function post(name, data) {
        return fetch('https://' + resource + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        }).then(function (res) {
            return res.json().catch(function () { return {}; });
        });
    }

    function setCard(card, ok, warn) {
        card.classList.remove('ok', 'bad', 'warn', 'live');
        if (ok) card.classList.add('ok');
        else if (warn) card.classList.add('warn');
        else card.classList.add('bad');
    }

    function rangeLabel(value) {
        return Math.round(Number(value || 0)) + 'm';
    }

    function renderPresets() {
        var list = $('presetList');
        list.innerHTML = '';
        var presets = statusData.presets || [];

        for (var i = 0; i < presets.length; i++) {
            (function (preset) {
                var btn = document.createElement('button');
                btn.className = 'preset';
                if (Math.round(Number(preset.range)) === Math.round(Number(selectedRange))) btn.classList.add('active');
                var strong = document.createElement('strong');
                strong.textContent = String(preset.label || '') + ' · ' + rangeLabel(preset.range);
                var small = document.createElement('small');
                small.textContent = String(preset.description || '');
                btn.appendChild(strong);
                btn.appendChild(small);
                btn.addEventListener('click', function () {
                    selectedRange = Number(preset.range);
                    updateRangeInputs();
                    post('setRange', { range: selectedRange, preset: preset.id });
                    renderPresets();
                });
                list.appendChild(btn);
            })(presets[i]);
        }
    }

    function updateRangeInputs() {
        var min = Number(statusData.minRange || 40);
        var max = Number(statusData.maxRange || 260);
        selectedRange = Math.max(min, Math.min(max, Number(selectedRange || 160)));
        $('rangeSlider').min = min;
        $('rangeSlider').max = max;
        $('rangeNumber').min = min;
        $('rangeNumber').max = max;
        $('rangeSlider').value = selectedRange;
        $('rangeNumber').value = selectedRange;
        $('rangeValue').innerText = rangeLabel(selectedRange);
    }

    function renderKeybinds() {
        var list = $('keybindList');
        list.innerHTML = '';
        var keybinds = statusData.keybinds || {};

        for (var key in keybinds) {
            if (Object.prototype.hasOwnProperty.call(keybinds, key)) {
                var binding = keybinds[key];
                var row = document.createElement('div');
                row.className = 'keybind';
                var label = document.createElement('span');
                label.textContent = String(binding.label || '');
                var key = document.createElement('kbd');
                key.textContent = String(binding.default || '');
                row.appendChild(label);
                row.appendChild(key);
                list.appendChild(row);
            }
        }
    }

    function applyUiPosition(position) {
        var app = $('app');
        var safePosition = String(position || 'right').toLowerCase();
        var allowed = {
            right: true,
            left: true,
            center: true,
            'top-right': true,
            'top-left': true,
            'bottom-right': true,
            'bottom-left': true
        };

        if (!allowed[safePosition]) safePosition = 'right';

        app.classList.remove(
            'position-right',
            'position-left',
            'position-center',
            'position-top-right',
            'position-top-left',
            'position-bottom-right',
            'position-bottom-left'
        );
        app.classList.add('position-' + safePosition);
        settings.uiPosition = safePosition;
        return safePosition;
    }

    function applySettingsToControls() {
        settings = Object.assign({}, statusData.settings || settings || {});
        $('hudToggle').checked = settings.hudEnabled !== false;
        $('soundToggle').checked = settings.clickSounds !== false;
        $('latchToggle').checked = settings.latchMode === true;
        $('positionSelect').value = applyUiPosition(settings.uiPosition || 'right');
    }

    function renderStatus(data) {
        statusData = Object.assign(statusData, data || {});
        settings = Object.assign(settings, statusData.settings || {});
        selectedRange = Number(statusData.selectedRange || settings.selectedRange || selectedRange || 160);

        var auth = statusData.auth || {};
        var pma = statusData.pmaVoice || {};
        var vehicle = statusData.vehicle;

        $('authText').innerText = auth.authorized ? ((auth.job && auth.job.label) || 'Authorized') : 'Not authorized';
        setCard($('authCard'), !!auth.authorized, auth.reason === 'loading');

        $('voiceText').innerText = pma.ready ? 'Ready' : String(pma.state || 'missing');
        setCard($('voiceCard'), !!pma.ready, false);

        if (vehicle) {
            $('vehicleText').innerText = vehicle.valid ? (vehicle.plate + ' · ' + vehicle.model) : (vehicle.message || 'Invalid vehicle');
            setCard($('vehicleCard'), !!vehicle.valid, false);
        } else {
            $('vehicleText').innerText = 'Not in vehicle';
            setCard($('vehicleCard'), false, false);
        }

        $('liveText').innerText = statusData.active ? 'LIVE' : (statusData.pending ? 'Starting...' : 'Idle');
        setCard($('liveCard'), !statusData.active && !statusData.pending, statusData.pending);
        if (statusData.active) $('liveCard').classList.add('live');

        $('startBtn').disabled = !!statusData.active || !!statusData.pending;
        $('latchBtn').disabled = !!statusData.pending;
        $('stopBtn').disabled = !statusData.active && !statusData.pending;

        updateRangeInputs();
        renderPresets();
        renderKeybinds();
        applySettingsToControls();
    }

    function saveSettings() {
        settings.hudEnabled = $('hudToggle').checked;
        settings.clickSounds = $('soundToggle').checked;
        settings.latchMode = $('latchToggle').checked;
        settings.uiPosition = $('positionSelect').value;
        settings.selectedRange = Number(selectedRange);
        post('saveSettings', { settings: settings });
    }

    $('closeBtn').addEventListener('click', function () { post('close'); });
    $('startBtn').addEventListener('mousedown', function () { post('startPA', { range: selectedRange, latched: false }); });
    $('startBtn').addEventListener('mouseup', function () { post('stopPA'); });
    $('startBtn').addEventListener('mouseleave', function () { post('stopPA'); });
    $('latchBtn').addEventListener('click', function () {
        if (statusData.active) post('stopPA');
        else post('startPA', { range: selectedRange, latched: true });
    });
    $('stopBtn').addEventListener('click', function () { post('stopPA'); });
    $('saveSettingsBtn').addEventListener('click', saveSettings);
    $('positionSelect').addEventListener('change', function (event) {
        applyUiPosition(event.target.value);
        saveSettings();
    });

    $('rangeSlider').addEventListener('input', function (event) {
        selectedRange = Number(event.target.value);
        updateRangeInputs();
    });
    $('rangeSlider').addEventListener('change', function () { post('setRange', { range: selectedRange }); });
    $('rangeNumber').addEventListener('input', function (event) {
        selectedRange = Number(event.target.value);
        updateRangeInputs();
    });
    $('rangeNumber').addEventListener('change', function () { post('setRange', { range: selectedRange }); });

    var tabs = document.querySelectorAll('.tab');
    for (var t = 0; t < tabs.length; t++) {
        tabs[t].addEventListener('click', function () {
            var allTabs = document.querySelectorAll('.tab');
            var pages = document.querySelectorAll('.tab-page');
            for (var i = 0; i < allTabs.length; i++) allTabs[i].classList.remove('active');
            for (var j = 0; j < pages.length; j++) pages[j].classList.remove('active');
            this.classList.add('active');
            $(this.getAttribute('data-tab')).classList.add('active');
        });
    }

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape') post('close');
    });

    window.addEventListener('message', function (event) {
        var payload = event.data || {};
        var action = payload.action;
        var data = payload.data;

        if (action === 'open') {
            $('app').classList.remove('hidden');
            renderStatus(data || {});
        }

        if (action === 'close') {
            $('app').classList.add('hidden');
        }

        if (action === 'status') {
            renderStatus(data || {});
        }

        if (action === 'paState') {
            statusData.active = !!(data && data.active);
            statusData.pending = false;
            renderStatus(statusData);
        }

        if (action === 'incoming') {
            // Listener-side PA broadcast HUD removed by request.
            // Keep this message handler as a safe no-op for compatibility.
            const hud = $('incomingHud');
            if (hud) hud.classList.add('hidden');
            return;
        }
    });
})();
