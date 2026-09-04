#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
V13 = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-dispatch/server/v13.lua'
BRIDGE = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-dispatch/server/compat_bridge.lua'

errors = []

for path in (V13, BRIDGE):
    if not path.exists():
        errors.append(f'missing required file: {path.relative_to(ROOT)}')

if not errors:
    v13 = V13.read_text(encoding='utf-8')
    bridge = BRIDGE.read_text(encoding='utf-8')

    required_v13 = [
        'DPNMedicalDispatchCompatBridge',
        "bridge('medicalContinuumCall',item)",
        "bridge('medicalSurge',item)",
        "exports('CreateContinuumCommandCallV13'",
        "exports('RecommendContinuumAssetsV13'",
        "exports('EscalateRegionalSurgeV13'",
        "exports('GetV13DispatchBoard'",
    ]
    for needle in required_v13:
        if needle not in v13:
            errors.append(f'v13 missing compatibility marker: {needle}')

    forbidden_direct_pairs = [
        "TriggerEvent('dpn-dispatch-system:server:medicalContinuumCall'",
        "TriggerEvent('dpn-dispatch:server:medicalContinuumCall'",
        "TriggerEvent('dpn-dispatch-system:server:medicalSurge'",
        "TriggerEvent('dpn-dispatch:server:medicalSurge'",
    ]
    for needle in forbidden_direct_pairs:
        if needle in v13:
            errors.append(f'v13 still bypasses compatibility router via: {needle}')

    for needle in ['function Bridge.Route', 'GetResourceState(resource)', 'return true, resource']:
        if needle not in bridge:
            errors.append(f'compatibility bridge missing routing marker: {needle}')

if errors:
    print('Medical Dispatch v13 single-route check FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Medical Dispatch v13 single-route check PASS: v13 compatibility events route through the shared active-target bridge while exports and local state surfaces remain present.')
