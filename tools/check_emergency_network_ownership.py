#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SUITE = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite'

CORRELATION = SUITE / 'core/dpn-unified-emergency-network/server/correlation.lua'
DISPATCH_BRIDGE = SUITE / 'core/dpn-dispatch/server/correlation_bridge.lua'
MDT_BRIDGE = SUITE / 'core/dpn-dispatch/server/mdt_correlation_bridge.lua'
MEDICAL_CORE_AUTH = SUITE / '[dpn-medical]/dpn-medical-core/server/authority.lua'
MEDICAL_DISPATCH_AUTH = SUITE / '[dpn-medical]/dpn-medical-dispatch/server/authority.lua'
MEDICAL_DISPATCH_DEDUP = SUITE / '[dpn-medical]/dpn-medical-dispatch/server/dedup.lua'
RESPONDER_AUTH = SUITE / '[dpn-medical]/dpn-medical-dispatch/server/responder_authority.lua'
MATRIX = ROOT / 'docs/architecture/phase-3g-emergency-network-ownership-matrix.md'

errors = []

required_files = {
    CORRELATION: ["exports('CreateEmergencyCorrelation'", "exports('LinkEmergencyCorrelation'"],
    DISPATCH_BRIDGE: ['CreateEmergencyCorrelation', 'FindExistingCall'],
    MDT_BRIDGE: ['GetEmergencyCorrelation', 'LinkEmergencyCorrelation'],
    MEDICAL_CORE_AUTH: ['DPNMedicalAuthority', "exports('GetCanonicalMedicalState'"],
    MEDICAL_DISPATCH_AUTH: ['DPNMedicalDispatchAuthority', 'ValidateCanonicalResponderLifecycle'],
    MEDICAL_DISPATCH_DEDUP: ['DPNMedicalDispatchDedup', 'MAX_ENTRIES'],
    RESPONDER_AUTH: ['DPNMedicalResponderAuthority', 'ValidateTransition'],
    MATRIX: ['Canonical ownership', 'Non-negotiable invariants', 'Cleanup classification'],
}

for path, needles in required_files.items():
    if not path.exists():
        errors.append(f'missing canonical Phase 3G ownership surface: {path.relative_to(ROOT)}')
        continue
    text = path.read_text(encoding='utf-8')
    for needle in needles:
        if needle not in text:
            errors.append(f'{path.relative_to(ROOT)} missing ownership contract marker: {needle}')

# Historical numerical feature layers remain loaded for unique behavior, but they may
# not claim the explicit Phase 3E/3F canonical authority globals introduced by the
# architecture migration. This is an additive drift guard, not a retirement check.
for resource in [
    SUITE / '[dpn-medical]/dpn-medical-core/server',
    SUITE / '[dpn-medical]/dpn-medical-dispatch/server',
]:
    if not resource.exists():
        continue
    for path in sorted(resource.glob('v*.lua')):
        text = path.read_text(encoding='utf-8')
        for symbol in [
            'DPNMedicalAuthority =',
            'DPNMedicalDispatchAuthority =',
            'DPNMedicalDispatchDedup =',
            'DPNMedicalResponderAuthority =',
        ]:
            if symbol in text:
                errors.append(f'{path.relative_to(ROOT)} reclaims canonical ownership via {symbol.strip()}')

if errors:
    print('Emergency network ownership check FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Emergency network ownership check PASS: Phase 3B-3F canonical surfaces remain explicit and historical numerical layers do not reclaim them.')
