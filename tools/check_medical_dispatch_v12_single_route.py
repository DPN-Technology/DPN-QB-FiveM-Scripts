#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
V12 = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-dispatch/server/v12.lua'

errors = []
if not V12.exists():
    errors.append(f'missing v12 medical dispatch runtime: {V12.relative_to(ROOT)}')
else:
    text = V12.read_text(encoding='utf-8')
    if 'DPNMedicalDispatchCompatBridge.Route(event,payload)' not in text:
        errors.append('v12 does not prefer the canonical compatibility bridge')
    if text.count("TriggerEvent('dpn-dispatch-system:server:'..event,payload)") != 1:
        errors.append('v12 must retain exactly one bounded dpn-dispatch-system fallback')
    if "TriggerEvent('dpn-dispatch:server:'..event,payload)" in text:
        errors.append('v12 still broadcasts compatibility events to the second legacy dispatch target')
    if "return false,'legacy-fallback'" not in text:
        errors.append('v12 no longer reports bounded legacy fallback behavior')

if errors:
    print('Medical dispatch v12 single-route check FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Medical dispatch v12 single-route check PASS: canonical bridge preferred with one bounded historical fallback.')
