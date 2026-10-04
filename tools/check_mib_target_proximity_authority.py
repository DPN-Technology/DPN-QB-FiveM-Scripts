#!/usr/bin/env python3
from pathlib import Path
import sys

SERVER = Path('qbcore/admin/dpn-mib-system/server/main.lua')
CONFIG = Path('qbcore/admin/dpn-mib-system/shared/config.lua')


def fail(message: str) -> None:
    print(f'[mib-target-proximity] ERROR: {message}')
    sys.exit(1)


def branch_slice(text: str, marker: str, next_marker: str) -> str:
    start = text.find(marker)
    if start < 0:
        fail(f'missing action branch: {marker}')
    end = text.find(next_marker, start + len(marker))
    if end < 0:
        fail(f'missing following action branch: {next_marker}')
    return text[start:end]


def main() -> None:
    if not SERVER.is_file():
        fail(f'missing {SERVER}')
    if not CONFIG.is_file():
        fail(f'missing {CONFIG}')

    server = SERVER.read_text(encoding='utf-8')
    config = CONFIG.read_text(encoding='utf-8')

    required_helper = {
        'target validation helper': 'local function validTargetInRange(src, target, maxDistance, rejectSelf)',
        'server caller ped lookup': 'local sourcePed = GetPlayerPed(src)',
        'server target ped lookup': 'local targetPed = GetPlayerPed(target)',
        'server caller coordinates': 'local sourceCoords = GetEntityCoords(sourcePed)',
        'server target coordinates': 'local targetCoords = GetEntityCoords(targetPed)',
        'distance rejection': "return false, 'Target is outside the authorized interaction range.'",
    }
    missing = [name for name, needle in required_helper.items() if needle not in server]
    if missing:
        fail('missing server-observed proximity primitives: ' + ', '.join(missing))

    freeze = branch_slice(server, "if action == 'freeze' then", "elseif action == 'scan' then")
    scan = branch_slice(server, "elseif action == 'scan' then", "elseif action == 'emergency_ping' then")
    revive = branch_slice(server, "elseif action == 'revive' then", "elseif action == 'armor' then")

    expected = {
        'freeze': (freeze, 'validTargetInRange(src, target, Config.Tools.freeze.range, false)'),
        'scan': (scan, 'validTargetInRange(src, target, Config.Tools.scan.range, false)'),
        'revive': (revive, 'validTargetInRange(src, target, Config.Tools.revive.range, false)'),
    }
    for action, (block, needle) in expected.items():
        if needle not in block:
            fail(f'{action} is missing server-side configured range validation')

    if "cooled(src, 'revive', Config.Tools.revive.cooldown)" not in revive:
        fail('revive is missing server-side cooldown enforcement')
    if "TriggerClientEvent('hospital:client:Revive', target)" not in revive:
        fail('revive effect is missing after target validation')

    range_guard = "revive = { label='Medical Override', range=10.0, cooldown=30 }"
    if range_guard not in config:
        fail('revive tool must define an explicit server-owned range and cooldown')

    remote_sections = {
        'goto_player': ("elseif action == 'goto_player' then", "elseif action == 'bring' then"),
        'bring': ("elseif action == 'bring' then", "elseif action == 'spectate' then"),
        'spectate': ("elseif action == 'spectate' then", "\n    end\nend)"),
    }
    for action, (start, end) in remote_sections.items():
        block = branch_slice(server, start, end)
        if 'validTargetInRange(' in block:
            fail(f'{action} must preserve intentional remote administrative semantics')

    print('[mib-target-proximity] PASS: local MIB target effects require server-observed proximity and remote admin actions remain remote')


if __name__ == '__main__':
    main()
