#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
MED = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]'
DISPATCH = MED / 'dpn-medical-dispatch/server/main.lua'
EMS = MED / 'dpn-medical-ems/server/main.lua'
INVENTORY = ROOT / 'docs/phase-3f-ems-medical-dispatch-ownership-inventory-v1.md'

errors = []

for path in (DISPATCH, EMS, INVENTORY):
    if not path.exists():
        errors.append(f'missing required Phase 3F ownership file: {path.relative_to(ROOT)}')

if DISPATCH.exists():
    text = DISPATCH.read_text(encoding='utf-8')
    required = [
        'activeCalls',
        'responders',
        "exports('CreateMedicalCall'",
        "exports('GetActiveMedicalCalls'",
        "exports('GetResponderStatus'",
        "exports('UpdateMedicalCall'",
        "RegisterNetEvent('dpn-medical-dispatch:server:respond'",
    ]
    for needle in required:
        if needle not in text:
            errors.append(f'medical dispatch lost canonical ownership contract: {needle}')

if EMS.exists():
    text = EMS.read_text(encoding='utf-8')
    forbidden = [
        'local activeCalls',
        'activeCalls = {}',
        'local responders',
        'responders = {}',
        "exports('CreateMedicalCall'",
        "exports('GetActiveMedicalCalls'",
        "exports('GetResponderStatus'",
        "exports('UpdateMedicalCall'",
    ]
    for needle in forbidden:
        if needle in text:
            errors.append(f'EMS field-treatment layer must not claim dispatch authority: {needle}')

if errors:
    print('Phase 3F medical dispatch ownership check FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Phase 3F medical dispatch ownership check PASS: dispatch and EMS authority remain non-overlapping.')
