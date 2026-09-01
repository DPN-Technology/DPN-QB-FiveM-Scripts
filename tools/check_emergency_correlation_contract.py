#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
CORRELATION = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/core/dpn-unified-emergency-network/server/correlation.lua'
MANIFEST = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/core/dpn-unified-emergency-network/fxmanifest.lua'

errors = []

if not CORRELATION.exists():
    errors.append('missing canonical server/correlation.lua authority')
else:
    text = CORRELATION.read_text(encoding='utf-8')
    required = {
        'server-issued DPN-EVT IDs': 'DPN-EVT-',
        'CreateCorrelation authority': 'function DPN_UNES.Server.CreateCorrelation',
        'LinkCorrelation authority': 'function DPN_UNES.Server.LinkCorrelation',
        'ValidateCorrelation authority': 'function DPN_UNES.Server.ValidateCorrelation',
        'server export CreateEmergencyCorrelation': "exports('CreateEmergencyCorrelation'",
        'server export LinkEmergencyCorrelation': "exports('LinkEmergencyCorrelation'",
        'server export ValidateEmergencyCorrelation': "exports('ValidateEmergencyCorrelation'",
        'immutable link conflict protection': 'immutable-link-conflict',
        'invoking-resource authority': 'GetInvokingResource',
    }
    for label, needle in required.items():
        if needle not in text:
            errors.append(f'correlation contract missing {label}')

    if "RegisterNetEvent('dpn-unes:server:correlation" in text or 'RegisterNetEvent("dpn-unes:server:correlation' in text:
        errors.append('correlation authority must not expose a client-triggerable correlation network event')

if not MANIFEST.exists():
    errors.append('missing unified emergency network fxmanifest.lua')
else:
    manifest = MANIFEST.read_text(encoding='utf-8')
    marker = "'server/correlation.lua'"
    main = "'server/main.lua'"
    if marker not in manifest:
        errors.append('fxmanifest does not load server/correlation.lua')
    elif main in manifest and manifest.index(marker) > manifest.index(main):
        errors.append('server/correlation.lua must load before server/main.lua')

if errors:
    print('Emergency correlation contract validation FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Emergency correlation contract validation PASS')
