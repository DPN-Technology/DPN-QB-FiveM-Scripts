#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-core'
MANIFEST = CORE / 'fxmanifest.lua'
AUTHORITY = CORE / 'server/authority.lua'

errors = []

if not AUTHORITY.exists():
    errors.append('missing server/authority.lua')
else:
    text = AUTHORITY.read_text(encoding='utf-8')
    required = [
        'DPNMedicalAuthority',
        'Core.EnsureState',
        'Core.Commit',
        "exports('GetCanonicalMedicalState'",
        "exports('CommitCanonicalMedicalState'",
        "exports('SetCanonicalLifeState'",
        "exports('ResetCanonicalPatient'",
        "exports('ReviveCanonicalPatient'",
        "exports('GetMedicalAuthorityInfo'",
        "GetResourceMetadata(RESOURCE, 'version', 0)",
    ]
    for needle in required:
        if needle not in text:
            errors.append(f'authority missing required contract: {needle}')
    if 'MedicalStates = {}' in text or 'MedicalStates = MedicalStates or {}' in text:
        errors.append('authority layer must not create or own a second patient-state cache')

if not MANIFEST.exists():
    errors.append('missing Medical Core fxmanifest.lua')
else:
    manifest = MANIFEST.read_text(encoding='utf-8')
    main_pos = manifest.find("'server/main.lua'")
    authority_pos = manifest.find("'server/authority.lua'")
    if main_pos < 0 or authority_pos < 0:
        errors.append('manifest must load server/main.lua and server/authority.lua')
    elif authority_pos < main_pos:
        errors.append('server/authority.lua must load after server/main.lua')

# Historical version layers remain loaded for feature parity, but may not claim the
# new canonical Phase 3E authority exports. Retirement requires separate parity proof.
canonical_export_names = {
    'GetMedicalAuthorityInfo',
    'GetCanonicalMedicalState',
    'CommitCanonicalMedicalState',
    'SetCanonicalLifeState',
    'ResetCanonicalPatient',
    'ReviveCanonicalPatient',
}
for path in sorted((CORE / 'server').glob('v*.lua')):
    text = path.read_text(encoding='utf-8')
    for name in canonical_export_names:
        if re.search(r"exports\s*\(\s*['\"]" + re.escape(name) + r"['\"]", text):
            errors.append(f'{path.relative_to(ROOT)} duplicates canonical authority export {name}')

if errors:
    print('Medical Core authority check FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Medical Core authority check PASS: canonical Phase 3E authority is single-surface and additive.')
