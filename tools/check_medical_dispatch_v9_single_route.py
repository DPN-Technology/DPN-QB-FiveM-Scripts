#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V9 = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-dispatch/server/v9.lua'

text = V9.read_text(encoding='utf-8')
errors = []

if "DPNMedicalDispatchCompatBridge.Route(event,payload)" not in text:
    errors.append('v9 does not route through the canonical medical dispatch compatibility bridge')
if "bridge('medicalEscalation'" not in text:
    errors.append('v9 SLA escalation does not route through the compatibility bridge')
if "bridge('mutualAid'" not in text:
    errors.append('v9 mutual aid does not route through the compatibility bridge')
if "TriggerEvent('dpn-dispatch-system:server:medicalEscalation'" in text:
    errors.append('v9 still directly emits medicalEscalation to dpn-dispatch-system')
if "TriggerEvent('dpn-dispatch-system:server:mutualAid'" in text:
    errors.append('v9 still directly emits mutualAid to dpn-dispatch-system')
for export_name in ('OptimizeMedicalResponseV9', 'EscalateDispatchSLAV9', 'CreateMedicalMutualAidV9', 'GetV9DispatchBoard'):
    if f"exports('{export_name}'" not in text:
        errors.append(f'v9 export missing: {export_name}')

if errors:
    for error in errors:
        print(f'ERROR: {error}')
    raise SystemExit(1)

print('v9 medical dispatch compatibility routing guard passed')
