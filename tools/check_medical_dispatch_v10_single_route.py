#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
V10 = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-dispatch/server/v10.lua'
BRIDGE = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-dispatch/server/compat_bridge.lua'

errors = []
for path in (V10, BRIDGE):
    if not path.exists():
        errors.append(f'missing required file: {path.relative_to(ROOT)}')

if not errors:
    v10 = V10.read_text(encoding='utf-8')
    bridge = BRIDGE.read_text(encoding='utf-8')

    required_v10 = [
        'DPNMedicalDispatchCompatBridge',
        "bridge('medicalCommandEscalation',item)",
        "bridge('medicalMutualAid',item)",
        "exports('EscalateMedicalIncidentV10'",
        "exports('RequestMedicalMutualAidV10'",
        "exports('CreateMedicalCommandChannelV10'",
        "exports('GetV10DispatchBoard'",
    ]
    for needle in required_v10:
        if needle not in v10:
            errors.append(f'v10 missing compatibility marker: {needle}')

    forbidden_direct = [
        "TriggerEvent('dpn-dispatch-system:server:medicalCommandEscalation'",
        "TriggerEvent('dpn-dispatch:server:medicalCommandEscalation'",
        "TriggerEvent('dpn-dispatch-system:server:medicalMutualAid'",
        "TriggerEvent('dpn-dispatch:server:medicalMutualAid'",
    ]
    for needle in forbidden_direct:
        if needle in v10:
            errors.append(f'v10 bypasses compatibility router via: {needle}')

    if v10.count("TriggerEvent('dpn-dispatch-system:server:'..event,payload)") != 1:
        errors.append('v10 legacy fallback must retain exactly one historical dpn-dispatch-system target')
    if "TriggerEvent('dpn-dispatch:server:'..event,payload)" in v10:
        errors.append('v10 legacy fallback must not fan out to a second dispatch target')

    for needle in ['function Bridge.Route', 'GetResourceState(resource)', 'return true, resource']:
        if needle not in bridge:
            errors.append(f'compatibility bridge missing routing marker: {needle}')

if errors:
    print('Medical Dispatch v10 single-route check FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Medical Dispatch v10 single-route check PASS: v10 escalation and mutual-aid compatibility events use the shared active-target bridge with one bounded legacy fallback while all exports and local state surfaces remain present.')
