#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
ADMISSIONS = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-hospital/server/admissions.lua'

errors = []

if not ADMISSIONS.exists():
    errors.append('missing hospital admissions.lua')
else:
    text = ADMISSIONS.read_text(encoding='utf-8')
    required = [
        "RegisterNetEvent('dpn-hospital:server:admitNearest'",
        "if not DPNHospital.IsAdmin(src) then",
        "local distance = GetPlayerDistance(src, targetId)",
        "if type(distance) ~= 'number' then",
        "DPNHospital.Notify(src, 'Unable to verify patient proximity.', 'error')",
        "local maxDistance = tonumber(Config.StaffAdmissionDistance) or 8.0",
        "if distance > maxDistance then",
        "DPNHospital.Notify(src, 'You are too far away from the patient.', 'error')",
    ]
    for needle in required:
        if needle not in text:
            errors.append(f'admissions.lua missing fail-closed admission authority marker: {needle}')

    fail_open = "if distance and distance > (Config.StaffAdmissionDistance or 8.0) then"
    if fail_open in text:
        errors.append('non-admin admission still uses fail-open distance conditional')

    event_pos = text.find("RegisterNetEvent('dpn-hospital:server:admitNearest'")
    admin_pos = text.find('if not DPNHospital.IsAdmin(src) then', event_pos)
    distance_pos = text.find('local distance = GetPlayerDistance(src, targetId)', admin_pos)
    fail_closed_pos = text.find("if type(distance) ~= 'number' then", distance_pos)
    admit_pos = text.find("local ok, result = AdmitPatient(targetId", event_pos)
    if min(event_pos, admin_pos, distance_pos, fail_closed_pos, admit_pos) < 0:
        errors.append('could not verify admission authorization ordering')
    elif not (event_pos < admin_pos < distance_pos < fail_closed_pos < admit_pos):
        errors.append('fail-closed proximity proof must execute before AdmitPatient')

if errors:
    print('Hospital admission distance authority check FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Hospital admission distance authority check PASS: non-admin admission requires positive server-side proximity proof before mutation.')
