#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/core/dpn-dispatch/fxmanifest.lua'
BRIDGE = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/core/dpn-dispatch/server/correlation_bridge.lua'

errors = []

if not BRIDGE.exists():
    errors.append('missing dispatch correlation bridge')
else:
    text = BRIDGE.read_text(encoding='utf-8')
    required = {
        'CreateEmergencyCorrelation': 'Phase 3B normalization',
        'LinkEmergencyCorrelation': 'immutable dispatchCallId linkage',
        'GetEmergencyCorrelation': 'canonical correlation refresh',
        'FindExistingCall': 'idempotent eventId reuse',
        'eventId': 'root emergency correlation',
        'dispatchCallId': 'dispatch child correlation',
        'BaseCreateCall': 'legacy creator preservation',
        'DPNDispatchDatabase.UpdateCall': 'persistence refresh',
        'DPNDispatchMDT.SyncCall': 'MDT compatibility refresh',
        "return existingId, existingCall, true": 'duplicate-create reuse result',
    }
    for token, description in required.items():
        if token not in text:
            errors.append(f'missing {description}: {token}')

    forbidden = [
        "RegisterNetEvent('dpn-dispatch:server:correlation",
        'RegisterNetEvent("dpn-dispatch:server:correlation',
    ]
    for token in forbidden:
        if token in text:
            errors.append('correlation mutation must not be client-network exposed')

if not MANIFEST.exists():
    errors.append('missing dpn-dispatch fxmanifest.lua')
else:
    manifest = MANIFEST.read_text(encoding='utf-8')
    bridge_pos = manifest.find("'server/correlation_bridge.lua'")
    main_pos = manifest.find("'server/main.lua'")
    exports_pos = manifest.find("'server/exports.lua'")
    if bridge_pos < 0:
        errors.append('dispatch manifest does not load correlation bridge')
    elif main_pos < 0 or exports_pos < 0 or not (main_pos < bridge_pos < exports_pos):
        errors.append('correlation bridge must load after server/main.lua and before server/exports.lua')

if errors:
    print('FAIL: Phase 3C dispatch correlation/dedup contract')
    for error in errors:
        print(f' - {error}')
    raise SystemExit(1)

print('PASS: Phase 3C dispatch correlation/dedup contract')
