/* DPN PG-7X NUI - TRUE LEGACY CEF BUILD
   ES5 only. No fetch. No arrow functions. No template strings. No CSS variables. */
(function () {
    var resourceName = 'dpn-pg-7x';
    var app = null;
    var openedSent = false;

    try {
        if (typeof GetParentResourceName === 'function') {
            resourceName = GetParentResourceName();
        }
    } catch (e0) {}

    var state = {
        isAdmin: false,
        portalMode: false,
        selectedKey: null,
        selectedLabel: 'NONE',
        destinations: [],
        currentPostal: null,
        postalStatus: { ready: false, count: 0, resource: null, file: null },
        postalSearchResults: [],
        activePortalCount: 0
    };

    function id(name) {
        return document.getElementById(name);
    }

    function post(name, data) {
        var xhr;
        try {
            xhr = new XMLHttpRequest();
            xhr.open('POST', 'https://' + resourceName + '/' + name, true);
            xhr.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
            xhr.send(JSON.stringify(data || {}));
        } catch (e) {}
    }

    function setText(name, value) {
        var el = id(name);
        if (!el) return;
        if (value === undefined || value === null || value === '') value = 'N/A';
        try { el.textContent = String(value); }
        catch (e) { el.innerText = String(value); }
    }

    function hasClass(el, cls) {
        if (!el) return false;
        return (' ' + el.className + ' ').indexOf(' ' + cls + ' ') !== -1;
    }

    function addClass(el, cls) {
        if (!el || hasClass(el, cls)) return;
        el.className = el.className ? (el.className + ' ' + cls) : cls;
    }

    function removeClass(el, cls) {
        if (!el) return;
        var s = ' ' + el.className + ' ';
        while (s.indexOf(' ' + cls + ' ') !== -1) {
            s = s.replace(' ' + cls + ' ', ' ');
        }
        el.className = s.replace(/^\s+|\s+$/g, '');
    }

    function html(v) {
        v = String(v === undefined || v === null ? '' : v);
        return v.replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#039;');
    }

    function clean(v) {
        return String(v === undefined || v === null ? '' : v).replace(/^\s+|\s+$/g, '');
    }

    function coordsText(coords) {
        if (!coords) return 'coords unavailable';
        var x = Number(coords.x || 0).toFixed(1);
        var y = Number(coords.y || 0).toFixed(1);
        var z = Number(coords.z || 0).toFixed(1);
        return 'x ' + x + ' / y ' + y + ' / z ' + z;
    }

    function safeArray(a) {
        return a && typeof a.length === 'number' ? a : [];
    }

    function merge(data) {
        var k;
        data = data || {};
        for (k in data) {
            if (Object.prototype.hasOwnProperty.call(data, k) && Object.prototype.hasOwnProperty.call(state, k)) state[k] = data[k];
        }
    }

    function render() {
        var ps;
        try {
            setText('adminStatus', state.isAdmin ? 'AUTHORIZED' : 'LOCKED');
            setText('deviceStatus', state.portalMode ? 'ARMED' : 'DISARMED');
            setText('selectedLabel', state.selectedLabel || 'NONE');
            setText('currentPostal', state.currentPostal || 'N/A');

            ps = state.postalStatus || {};
            setText('postalDbStatus', ps.ready ? String(ps.count || 0) + ' POSTALS LOADED' : 'NOT READY');
            setText('postalDbSource', ps.resource ? String(ps.resource) + '/' + String(ps.file || '') : 'N/A');

            renderDestinations();
            renderPostalResults();
        } catch (e) {
            setText('selectedLabel', 'UI RENDER ERROR - USE /pguifix');
        }
    }

    function renderDestinations() {
        var list = id('destList');
        var searchBox = id('destSearch');
        var q = searchBox ? clean(searchBox.value).toLowerCase() : '';
        var arr = safeArray(state.destinations);
        var out = '';
        var i, d, hay, type, postal, cls, disabled, count;

        if (!list) return;
        count = 0;

        for (i = 0; i < arr.length; i++) {
            d = arr[i] || {};
            hay = String(d.label || d.key || '') + ' ' + String(d.key || '') + ' ' + String(d.postal || '');
            if (q && hay.toLowerCase().indexOf(q) === -1) continue;
            count++;
            type = d.type || 'saved';
            postal = d.postal ? '<span class="badge">postal ' + html(d.postal) + '</span>' : '';
            cls = d.selected ? 'row selected' : 'row';
            disabled = type === 'temporary_postal' ? ' disabled="disabled"' : '';
            out += '<div class="' + cls + '">' +
                '<div class="rowTitle">' + html(d.label || d.key || 'Destination') + '</div>' +
                '<div class="rowMeta"><span class="badge">' + html(type) + '</span>' + postal + html(coordsText(d.coords)) + '</div>' +
                '<button type="button" class="selectBtn" data-key="' + html(d.key || '') + '">SELECT</button>' +
                '<button type="button" class="deleteBtn danger" data-key="' + html(d.key || '') + '"' + disabled + '>DELETE</button>' +
                '</div>';
        }

        if (!count) {
            out = '<div class="row"><div class="rowTitle">No destinations found</div><div class="rowMeta">Save your location or select a postal destination.</div></div>';
        }

        list.innerHTML = out;
        bindListButtons(list);
    }

    function renderPostalResults() {
        var list = id('postalResults');
        var arr = safeArray(state.postalSearchResults);
        var out = '';
        var i, item;

        if (!list) return;

        if (!arr.length) {
            list.innerHTML = '<div class="row"><div class="rowTitle">No postal search results yet</div><div class="rowMeta">Type a postal and press Search Postal.</div></div>';
            return;
        }

        for (i = 0; i < arr.length; i++) {
            item = arr[i] || {};
            out += '<div class="row">' +
                '<div class="rowTitle">' + html(item.label || ('Postal ' + item.code)) + '</div>' +
                '<div class="rowMeta">' + html(coordsText(item.coords)) + '</div>' +
                '<button type="button" class="selectPostalBtn" data-postal="' + html(item.code || '') + '">SELECT</button>' +
                '<button type="button" class="savePostalResultBtn primary" data-postal="' + html(item.code || '') + '">SAVE</button>' +
                '</div>';
        }

        list.innerHTML = out;
        bindListButtons(list);
    }

    function bindListButtons(parent) {
        var buttons = parent.getElementsByTagName('button');
        var i, btn, cls;
        for (i = 0; i < buttons.length; i++) {
            btn = buttons[i];
            cls = ' ' + btn.className + ' ';
            if (cls.indexOf(' selectBtn ') !== -1) {
                btn.onclick = function () { post('selectDestination', { key: this.getAttribute('data-key') }); };
            } else if (cls.indexOf(' deleteBtn ') !== -1) {
                btn.onclick = function () { if (!this.disabled) post('deleteDestination', { key: this.getAttribute('data-key') }); };
            } else if (cls.indexOf(' selectPostalBtn ') !== -1) {
                btn.onclick = function () { post('selectPostal', { postal: this.getAttribute('data-postal') }); };
            } else if (cls.indexOf(' savePostalResultBtn ') !== -1) {
                btn.onclick = function () {
                    var nameBox = id('postalSaveName');
                    post('savePostal', { postal: this.getAttribute('data-postal'), name: nameBox ? nameBox.value : '' });
                };
            }
        }
    }

    function showTab(name) {
        var tabs = document.getElementsByTagName('button');
        var pages = document.getElementsByTagName('div');
        var i, tabName, page;

        for (i = 0; i < tabs.length; i++) {
            tabName = tabs[i].getAttribute('data-tab');
            if (tabName) {
                if (tabName === name) addClass(tabs[i], 'active');
                else removeClass(tabs[i], 'active');
            }
        }

        page = id('savedTab'); if (page) removeClass(page, 'active');
        page = id('postalTab'); if (page) removeClass(page, 'active');
        page = id('systemTab'); if (page) removeClass(page, 'active');
        page = id(name + 'Tab'); if (page) addClass(page, 'active');
    }

    function openPanel() {
        if (!app) app = id('app');
        if (!app) return;
        removeClass(app, 'hidden');
        /* Acknowledge immediately so the Lua client does not think old CEF failed. */
        post('opened', { legacy: true });
        openedSent = true;
        render();
    }

    function closePanel() {
        if (!app) app = id('app');
        if (!app) return;
        addClass(app, 'hidden');
        openedSent = false;
    }

    function handleMessage(event) {
        var data;
        try {
            data = event && event.data ? event.data : {};
            if (typeof data === 'string') {
                try { data = JSON.parse(data); } catch (eParse) { data = {}; }
            }

            if (data.action === 'close' || data.uiOpen === false) {
                closePanel();
                return;
            }

            merge(data);

            if (data.action === 'open' || data.uiOpen === true) {
                openPanel();
                return;
            }

            if (data.action === 'state') {
                render();
            }
        } catch (e) {
            /* Do not force-close on render errors; keep fallback visible so admin can close/reset. */
            try { setText('selectedLabel', 'UI ERROR - PRESS ESC OR /pguifix'); } catch (e2) {}
        }
    }

    function bindStatic() {
        var tabs, i;
        app = id('app');

        tabs = document.getElementsByTagName('button');
        for (i = 0; i < tabs.length; i++) {
            if (tabs[i].getAttribute('data-tab')) {
                tabs[i].onclick = function () { showTab(this.getAttribute('data-tab')); };
            }
        }

        if (id('closeBtn')) id('closeBtn').onclick = function () { post('close'); closePanel(); };
        if (id('toggleModeBtn')) id('toggleModeBtn').onclick = function () { post('toggleMode'); };
        if (id('firePortalBtn')) id('firePortalBtn').onclick = function () { post('firePortal'); };
        if (id('closePortalBtn')) id('closePortalBtn').onclick = function () { post('closePortal'); };
        if (id('refreshBtn')) id('refreshBtn').onclick = function () { post('refresh'); };
        if (id('saveHereBtn')) id('saveHereBtn').onclick = function () {
            post('saveHere', { name: id('saveName') ? id('saveName').value : '' });
        };
        if (id('selectPostalBtn')) id('selectPostalBtn').onclick = function () {
            post('selectPostal', { postal: id('postalInput') ? id('postalInput').value : '' });
        };
        if (id('useCurrentPostalBtn')) id('useCurrentPostalBtn').onclick = function () { post('useCurrentPostal'); };
        if (id('savePostalBtn')) id('savePostalBtn').onclick = function () {
            post('savePostal', {
                postal: id('postalInput') && id('postalInput').value ? id('postalInput').value : state.currentPostal,
                name: id('postalSaveName') ? id('postalSaveName').value : ''
            });
        };
        if (id('searchPostalBtn')) id('searchPostalBtn').onclick = function () {
            post('searchPostals', { query: id('postalInput') ? id('postalInput').value : '' });
        };
        if (id('destSearch')) {
            id('destSearch').onkeyup = renderDestinations;
            id('destSearch').onchange = renderDestinations;
        }
        if (id('postalInput')) {
            id('postalInput').onkeyup = function () {
                var value = clean(this.value);
                if (value.length >= 2) post('searchPostals', { query: value });
            };
        }

        document.onkeydown = function (event) {
            event = event || window.event;
            var code = event.keyCode || event.which;
            if (code === 27 || code === 8) {
                try { if (event.preventDefault) event.preventDefault(); } catch (e) {}
                post('close');
                closePanel();
                return false;
            }
            return true;
        };

        render();
        post('ready', { legacy: true });
    }

    if (window.addEventListener) {
        window.addEventListener('message', handleMessage, false);
        window.addEventListener('load', function () { bindStatic(); post('ready', { legacy: true, load: true }); }, false);
    } else if (window.attachEvent) {
        window.attachEvent('onmessage', handleMessage);
        window.attachEvent('onload', function () { bindStatic(); post('ready', { legacy: true, load: true }); });
    }

    /* FiveM NUI usually has DOM ready by the time this script runs because it is placed at end of body. */
    bindStatic();
})();
