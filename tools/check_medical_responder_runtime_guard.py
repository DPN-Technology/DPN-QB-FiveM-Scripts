#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-dispatch'
MAIN = RESOURCE / 'server/main.lua'
GUARD = RESOURCE / 'server/responder_authority.lua'
errors = []

if not MAIN.exists():
    errors.append('missing medical dispatch server/main.lua')
else:
    text = MAIN.read_text(encoding='utf-8')
    required = [
        'DPNMedicalResponderAuthority.ValidateTransition',
        "RegisterNetEvent('dpn-medical-dispatch:server:respond'",
        'currentStatus',
        'normalizedStatus',
        'transitionReason',
    ]
    for needle in required:
        if needle not in text:
            errors.append(f'main responder handler missing runtime lifecycle guard contract: {needle}')
    if 'if not transitionOk then' not in text:
        errors.append('responder handler must fail closed on invalid lifecycle transitions')
    if "if not allowed[status] then status='accepted' end" in text:
        errors.append('legacy permissive responder fallback still bypasses lifecycle authority')

if not GUARD.exists():
    errors.append('missing responder lifecycle authority')
else:
    guard = GUARD.read_text(encoding='utf-8')
    if 'ValidateTransition' not in guard:
        errors.append('responder lifecycle authority must expose ValidateTransition')

if errors:
    print('Medical responder runtime guard check FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Medical responder runtime guard check PASS: live responder state changes are validated by Phase 3F lifecycle authority.')
