#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-dispatch'
BRIDGE = BASE / 'server/compat_bridge.lua'
MANIFEST = BASE / 'fxmanifest.lua'
V11 = BASE / 'server/v11.lua'
V12 = BASE / 'server/v12.lua'

errors = []

for path in (BRIDGE, MANIFEST, V11, V12):
    if not path.exists():
        errors.append(f'missing required Phase 3G compatibility file: {path.relative_to(ROOT)}')

if BRIDGE.exists():
    text = BRIDGE.read_text(encoding='utf-8')
    for needle in [
        'DPNMedicalDispatchCompatBridge',
        'GetResourceState(resource)',
        'local function fallbackResource(resources)',
        'local fallback = fallbackResource(resources)',
        'TriggerEvent(eventName(fallback, event), payload)',
        'stats.lastFallbackResource = fallback',
        "exports('RouteMedicalDispatchCompatEvent'",
        "exports('GetMedicalDispatchCompatBridgeStats'",
        "return false, 'legacy-fallback'",
    ]:
        if needle not in text:
            errors.append(f'compat bridge missing marker: {needle}')

    if text.count('TriggerEvent(eventName(') != 2:
        errors.append('compat bridge must contain exactly one active-route emit and one fallback emit')
    if "for _, resource in ipairs(resources) do\n        TriggerEvent(eventName(resource, event), payload)" in text:
        errors.append('compat bridge still fans one fallback event out to every configured resource')

if MANIFEST.exists():
    text = MANIFEST.read_text(encoding='utf-8')
    bridge_pos = text.find("'server/compat_bridge.lua'")
    v11_pos = text.find("'server/v11.lua'")
    v12_pos = text.find("'server/v12.lua'")
    if min(bridge_pos, v11_pos, v12_pos) < 0 or not (bridge_pos < v11_pos < v12_pos):
        errors.append('compat bridge must load before v11/v12 historical layers')

for path in (V11, V12):
    if not path.exists():
        continue
    text = path.read_text(encoding='utf-8')
    if 'DPNMedicalDispatchCompatBridge.Route(event,payload)' not in text:
        errors.append(f'{path.name} does not route through canonical compatibility bridge')
    if "local function bridge(event,payload)TriggerEvent('dpn-dispatch-system:server:'" in text:
        errors.append(f'{path.name} still contains unconditional dual-target bridge')

if errors:
    print('Medical dispatch compatibility single-route check FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Medical dispatch compatibility single-route check PASS: active and legacy fallback routing each select exactly one configured dispatch owner.')
