#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-dispatch'
MANIFEST = RESOURCE / 'fxmanifest.lua'
AUTHORITY = RESOURCE / 'server/authority.lua'
MAIN = RESOURCE / 'server/main.lua'

errors = []

if not AUTHORITY.exists():
    errors.append('missing medical-dispatch server/authority.lua')
else:
    text = AUTHORITY.read_text(encoding='utf-8')
    required = [
        'DPNMedicalDispatchAuthority',
        "dispatchExport('CreateMedicalCall'",
        "dispatchExport('UpdateMedicalCall'",
        "dispatchExport('GetActiveMedicalCalls'",
        "dispatchExport('GetResponderStatus'",
        "exports('GetMedicalDispatchAuthorityInfo'",
        "exports('CreateCanonicalMedicalCall'",
        "exports('UpdateCanonicalMedicalCall'",
        "exports('GetCanonicalMedicalCalls'",
        "exports('GetCanonicalResponderStatus'",
    ]
    for needle in required:
        if needle not in text:
            errors.append(f'authority missing required contract: {needle}')
    forbidden = ['activeCalls = {}', 'responders = {}', 'MySQL.insert', 'MySQL.update', 'RegisterNetEvent(']
    for needle in forbidden:
        if needle in text:
            errors.append(f'authority must delegate instead of owning runtime state: {needle}')

if not MAIN.exists():
    errors.append('missing medical-dispatch server/main.lua')
else:
    main = MAIN.read_text(encoding='utf-8')
    for export_name in ['CreateMedicalCall', 'UpdateMedicalCall', 'GetActiveMedicalCalls', 'GetResponderStatus']:
        if not re.search(r"exports\s*\(\s*['\"]" + re.escape(export_name) + r"['\"]", main):
            errors.append(f'main server owner missing delegated export {export_name}')

if not MANIFEST.exists():
    errors.append('missing medical-dispatch fxmanifest.lua')
else:
    manifest = MANIFEST.read_text(encoding='utf-8')
    main_pos = manifest.find("'server/main.lua'")
    authority_pos = manifest.find("'server/authority.lua'")
    if main_pos < 0 or authority_pos < 0:
        errors.append('manifest must load server/main.lua and server/authority.lua')
    elif authority_pos < main_pos:
        errors.append('server/authority.lua must load after server/main.lua')

canonical_exports = {
    'GetMedicalDispatchAuthorityInfo',
    'CreateCanonicalMedicalCall',
    'UpdateCanonicalMedicalCall',
    'GetCanonicalMedicalCalls',
    'GetCanonicalResponderStatus',
    'GetCanonicalMedicalDispatchHealth',
}
for path in sorted((RESOURCE / 'server').glob('v*.lua')):
    text = path.read_text(encoding='utf-8')
    for name in canonical_exports:
        if re.search(r"exports\s*\(\s*['\"]" + re.escape(name) + r"['\"]", text):
            errors.append(f'{path.relative_to(ROOT)} duplicates canonical Phase 3F export {name}')

if errors:
    print('Medical Dispatch authority check FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Medical Dispatch authority check PASS: Phase 3F authority is additive and delegates to the existing canonical owner.')
