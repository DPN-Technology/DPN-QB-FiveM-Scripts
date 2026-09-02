#!/usr/bin/env python3
from pathlib import Path
import sys

TARGET = Path('qbcore/admin/dpn-mib-system/server/main.lua')


def fail(message: str) -> None:
    print(f'[mib-loadout-auth] ERROR: {message}')
    sys.exit(1)


def main() -> None:
    if not TARGET.is_file():
        fail(f'missing {TARGET}')

    text = TARGET.read_text(encoding='utf-8')

    required = {
        'server-side director authorization helper': 'local function canUseDirectorLoadout(src)',
        'director authorization guard': "if rank == 'director' and not canUseDirectorLoadout(src) then",
        'denied escalation audit event': "MIBLog(src, 'LOADOUT_ESCALATION_DENIED'",
        'denied escalation early return': "return DPN.Notify(src, 'Director clearance is required for that MIB loadout.'",
        'server-side MIB job check': 'jobData.name == Config.MIBJobName',
        'server-side director grade check': "tostring(grade.name or ''):lower() == 'director'",
    }

    missing = [name for name, needle in required.items() if needle not in text]
    if missing:
        fail('missing required authorization controls: ' + ', '.join(missing))

    unsafe = "local rank = payload.rank or 'agent'; local loadout = Config.MIBLoadouts[rank]"
    if unsafe in text:
        fail('legacy client-trusted loadout selection is still present')

    guard_pos = text.find("if rank == 'director' and not canUseDirectorLoadout(src) then")
    loadout_pos = text.find('local loadout = Config.MIBLoadouts[rank]', guard_pos)
    if guard_pos < 0 or loadout_pos < 0 or guard_pos > loadout_pos:
        fail('director authorization must occur before privileged loadout selection')

    print('[mib-loadout-auth] PASS: privileged MIB loadout selection is server-authorized')


if __name__ == '__main__':
    main()
