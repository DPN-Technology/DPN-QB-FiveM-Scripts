const flash = document.getElementById('flash');
const charge = document.getElementById('charge');
const blackout = document.getElementById('blackout');

let flashTimer = null;
let chargeTimer = null;
let blackoutTimer = null;
let blackoutFadeTimer = null;
let audioContext = null;

function playTone(kind) {
    try {
        audioContext = audioContext || new (window.AudioContext || window.webkitAudioContext)();
        const osc = audioContext.createOscillator();
        const gain = audioContext.createGain();
        const now = audioContext.currentTime;

        osc.type = 'sine';
        osc.frequency.setValueAtTime(kind === 'charge' ? 520 : 880, now);
        osc.frequency.exponentialRampToValueAtTime(kind === 'charge' ? 1400 : 2200, now + (kind === 'charge' ? 0.32 : 0.12));

        gain.gain.setValueAtTime(0.0001, now);
        gain.gain.exponentialRampToValueAtTime(kind === 'charge' ? 0.11 : 0.18, now + 0.025);
        gain.gain.exponentialRampToValueAtTime(0.0001, now + (kind === 'charge' ? 0.35 : 0.18));

        osc.connect(gain);
        gain.connect(audioContext.destination);
        osc.start(now);
        osc.stop(now + (kind === 'charge' ? 0.36 : 0.2));
    } catch (error) {
        // NUI audio can be unavailable on some clients. Visual effect still works.
    }
}

function showCharge(duration) {
    clearTimeout(chargeTimer);
    charge.className = 'charge';
    void charge.offsetWidth;
    playTone('charge');
    chargeTimer = setTimeout(() => {
        charge.className = 'charge hidden';
    }, duration || 450);
}

function showFlash(duration, mode) {
    clearTimeout(flashTimer);
    flash.className = `flash ${mode === 'nearby' ? 'nearby' : mode === 'source' ? 'source' : 'full'}`;
    void flash.offsetWidth;
    playTone('flash');
    flashTimer = setTimeout(() => {
        flash.className = 'flash hidden';
    }, duration || 850);
}

function showBlackout(duration, fadeMs) {
    clearTimeout(blackoutTimer);
    clearTimeout(blackoutFadeTimer);

    duration = Number(duration) || 15000;
    fadeMs = Number(fadeMs) || 350;

    blackout.className = 'blackout active';
    blackout.style.transition = `opacity ${fadeMs}ms ease-in-out`;
    blackout.style.opacity = '0';

    requestAnimationFrame(() => {
        blackout.style.opacity = '1';
    });

    blackoutTimer = setTimeout(() => {
        blackout.style.opacity = '0';
        blackoutFadeTimer = setTimeout(() => {
            blackout.className = 'blackout hidden';
        }, fadeMs + 50);
    }, duration);
}

window.addEventListener('message', (event) => {
    if (!event || event.source !== window || event.origin !== window.location.origin) return;
    const data = event.data || {};

    if (data.action === 'charge') {
        showCharge(Number(data.duration) || 450);
    }

    if (data.action === 'flash') {
        showFlash(Number(data.duration) || 850, data.mode || 'full');
    }

    if (data.action === 'blackout') {
        showBlackout(Number(data.duration) || 15000, Number(data.fadeMs) || 350);
    }
});
