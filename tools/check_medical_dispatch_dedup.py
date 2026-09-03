#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-dispatch'
DEDUP = RESOURCE / 'server/dedup.lua'
AUTHORITY = RESOURCE / 'server/authority.lua'
MANIFEST = RESOURCE / 'fxmanifest.lua'
errors = []

if not DEDUP.exists():
    errors.append('missing server/dedup.lua')
else:
    text = DEDUP.read_text(encoding='utf-8')
    for needle in ['MAX_ENTRIES', 'DEFAULT_WINDOW', 'correlationId', 'eventId', 'dispatchCallId', 'incidentId', 'medicalCallId', "exports('GetMedicalDispatchDedupStats'"]:
        if needle not in text:
            errors.append(f'dedup layer missing required bounded/idempotent contract: {needle}')
    if 'MAX_ENTRIES = ' not in text or 'entries[key] = nil' not in text:
        errors.append('dedup layer must have deterministic bounded cleanup')
    for forbidden in ['MySQL.insert', 'MySQL.update', 'RegisterNetEvent(']:
        if forbidden in text:
            errors.append(f'dedup layer must not own persistence/event authority: {forbidden}')

if not AUTHORITY.exists():
    errors.append('missing server/authority.lua')
else:
    text = AUTHORITY.read_text(encoding='utf-8')
    if 'DPNMedicalDispatchDedup.Create' not in text:
        errors.append('canonical authority must route creation through bounded dedup adapter')
    if "dispatchExport('CreateMedicalCall'" not in text:
        errors.append('canonical authority must preserve legacy CreateMedicalCall delegation fallback')

if not MANIFEST.exists():
    errors.append('missing fxmanifest.lua')
else:
    manifest = MANIFEST.read_text(encoding='utf-8')
    main_pos = manifest.find("'server/main.lua'")
    dedup_pos = manifest.find("'server/dedup.lua'")
    authority_pos = manifest.find("'server/authority.lua'")
    if min(main_pos, dedup_pos, authority_pos) < 0:
        errors.append('manifest must load main, dedup, and authority layers')
    elif not (main_pos < dedup_pos < authority_pos):
        errors.append('manifest load order must be main -> dedup -> authority')

if errors:
    print('Medical Dispatch dedup check FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Medical Dispatch dedup check PASS: canonical create path has bounded correlation-key idempotency.')
