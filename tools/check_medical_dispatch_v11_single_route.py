#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
V11 = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-dispatch/server/v11.lua'
BRIDGE = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-dispatch/server/compat_bridge.lua'

errors = []

for path in (V11, BRIDGE):
    if not path.exists():
        errors.append(f'missing required file: {path.relative_to(ROOT)}')

if not errors:
    v11 = V11.read_text(encoding='utf-8')
    bridge = BRIDGE.read_text(encoding='utf-8')

    required_v11 = [
        'DPNMedicalDispatchCompatBridge',
        "bridge('medicalPredictiveCall',item)",
        "bridge('medicalNetworkEscalation',item)",
        "exports('CreatePredictiveMedicalCallV11'",
        "exports('RecommendMedicalUnitsV11'",
        "exports('EscalateNetworkIncidentV11'",
        "exports('GetV11DispatchBoard'",
        "TriggerEvent('dpn-dispatch-system:server:'..event,payload)",
    ]
    for needle in required_v11:
        if needle not in v11:
            errors.append(f'v11 missing compatibility marker: {needle}')

    forbidden = [
        "TriggerEvent('dpn-dispatch:server:'..event,payload)",
        "TriggerEvent('dpn-dispatch-system:server:medicalPredictiveCall'",
        "TriggerEvent('dpn-dispatch:server:medicalPredictiveCall'",
        "TriggerEvent('dpn-dispatch-system:server:medicalNetworkEscalation'",
        "TriggerEvent('dpn-dispatch:server:medicalNetworkEscalation'",
    ]
    for needle in forbidden:
        if needle in v11:
            errors.append(f'v11 still fans out or bypasses compatibility routing via: {needle}')

    if v11.count("TriggerEvent('dpn-dispatch-system:server:'..event,payload)") != 1:
        errors.append('v11 must retain exactly one bounded historical dispatch fallback')

    for needle in ['function Bridge.Route', 'GetResourceState(resource)', 'return true, resource']:
        if needle not in bridge:
            errors.append(f'compatibility bridge missing routing marker: {needle}')

if errors:
    print('Medical Dispatch v11 single-route check FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Medical Dispatch v11 single-route check PASS: v11 compatibility events prefer the shared active-target bridge and retain one bounded historical fallback.')
