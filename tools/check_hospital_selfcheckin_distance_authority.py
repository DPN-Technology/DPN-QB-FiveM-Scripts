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
        "RegisterNetEvent('dpn-hospital:server:selfCheckIn'",
        "local distance = GetDistanceFromCoords(src, hospital.checkIn)",
        "if type(distance) ~= 'number' then",
        "DPNHospital.Notify(src, 'Unable to verify hospital check-in proximity.', 'error')",
        "local maxDistance = tonumber(Config.CheckInInteractionDistance) or 6.0",
        "if distance > maxDistance then",
        "DPNHospital.Notify(src, 'You must be at the hospital check-in desk.', 'error')",
    ]
    for needle in required:
        if needle not in text:
            errors.append(f'admissions.lua missing fail-closed self-check-in authority marker: {needle}')

    fail_open = "if distance and distance > (Config.CheckInInteractionDistance or 6.0) then"
    if fail_open in text:
        errors.append('self-check-in still uses fail-open distance conditional')

    event_pos = text.find("RegisterNetEvent('dpn-hospital:server:selfCheckIn'")
    distance_pos = text.find('local distance = GetDistanceFromCoords(src, hospital.checkIn)', event_pos)
    fail_closed_pos = text.find("if type(distance) ~= 'number' then", distance_pos)
    charge_pos = text.find("Player.Functions.RemoveMoney('bank', charge, 'hospital-checkin')", event_pos)
    admit_pos = text.find("local ok, result = AdmitPatient(src, hospitalId", event_pos)
    if min(event_pos, distance_pos, fail_closed_pos, charge_pos, admit_pos) < 0:
        errors.append('could not verify self-check-in proximity/charge/admission ordering')
    elif not (event_pos < distance_pos < fail_closed_pos < charge_pos < admit_pos):
        errors.append('fail-closed self-check-in proximity proof must execute before charging or AdmitPatient')

if errors:
    print('Hospital self-check-in distance authority check FAILED:')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('Hospital self-check-in distance authority check PASS: self-check-in requires positive server-side proximity proof before charging or admission mutation.')
