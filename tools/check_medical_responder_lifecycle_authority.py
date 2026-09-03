#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-dispatch'
GUARD = RESOURCE / 'server/responder_authority.lua'
AUTHORITY = RESOURCE / 'server/authority.lua'
MANIFEST = RESOURCE / 'fxmanifest.lua'
errors = []

if not GUARD.exists():
    errors.append('missing responder lifecycle authority')
else:
    text = GUARD.read_text(encoding='utf-8')
    for needle in [
        'TRANSITIONS', 'available', 'accepted', 'enroute', 'onscene', 'transporting', 'clear', 'unavailable',
        'ValidateTransition', "exports('ValidateCanonicalResponderTransition'", "exports('GetCanonicalResponderTransitions'"
    ]:
        if needle not in text:
            errors.append(f'responder authority missing required contract: {needle}')
    for forbidden in ['MySQL.insert', 'MySQL.update', 'RegisterNetEvent(', 'responders = {}', 'activeCalls = {}']:
        if forbidden in text:
            errors.append(f'responder guard must not become a second runtime owner: {forbidden}')

if not AUTHORITY.exists():
    errors.append('missing dispatch authority')
else:
    text = AUTHORITY.read_text(encoding='utf-8')
    for needle in ['DPNMedicalResponderAuthority.ValidateTransition', 'ValidateCanonicalResponderLifecycle', 'responderAuthorityLayer']:
        if needle not in text:
            errors.append(f'dispatch authority missing responder lifecycle integration: {needle}')

if not MANIFEST.exists():
    errors.append('missing dispatch manifest')
else:
    text = MANIFEST.read_text(encoding='utf-8')
    main_pos = text.find("'server/main.lua'")
    guard_pos = text.find("'server/responder_authority.lua'")
    authority_pos = text.find("'server/authority.lua'")
    if min(main_pos, guard_pos, authority_pos) < 0:
        errors.append('manifest must load main, responder authority, and dispatch authority')
    elif not (main_pos < guard_pos < authority_pos):
        errors.append('responder authority must load after main and before dispatch authority')

if errors:
    print('Medical responder lifecycle authority check FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Medical responder lifecycle authority check PASS: transition policy is explicit, bounded, and non-owning.')
