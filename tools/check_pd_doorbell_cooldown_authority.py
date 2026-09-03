#!/usr/bin/env python3
from pathlib import Path
import sys

TARGET = Path('qbcore/law-enforcement/dpn_police_qbdoorbell/server.lua')
text = TARGET.read_text(encoding='utf-8')

failures = []

if "RegisterNetEvent('QBCore:Server:OnPlayerUnload'" in text:
    failures.append('OnPlayerUnload cleanup must not be registered as a network event')

if "AddEventHandler('QBCore:Server:OnPlayerUnload', function()" not in text:
    failures.append('OnPlayerUnload cleanup must use a server-local AddEventHandler without caller arguments')

if 'local src = source' not in text:
    failures.append('cleanup must derive the player source from the server event context')

if 'playerCooldowns[src] = nil' not in text:
    failures.append('cleanup must remove only the disconnecting player cooldown')

if failures:
    print('PD doorbell cooldown authority check: FAIL')
    for failure in failures:
        print(f' - {failure}')
    sys.exit(1)

print('PD doorbell cooldown authority check: PASS')
