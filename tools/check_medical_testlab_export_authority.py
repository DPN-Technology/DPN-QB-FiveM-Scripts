#!/usr/bin/env python3
from pathlib import Path
import sys

TARGET = Path('qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-medical]/dpn-medical-core/server/testlab.lua')


def fail(message: str) -> None:
    print(f'[medical-testlab-export-authority] ERROR: {message}')
    sys.exit(1)


def block(text: str, start_marker: str, end_marker: str) -> str:
    start = text.find(start_marker)
    if start < 0:
        fail(f'missing block start: {start_marker}')
    end = text.find(end_marker, start + len(start_marker))
    if end < 0:
        fail(f'missing block end: {end_marker}')
    return text[start:end]


def main() -> None:
    if not TARGET.is_file():
        fail(f'missing {TARGET}')

    text = TARGET.read_text(encoding='utf-8')

    required = {
        'explicit mutation allowlist': 'local TRUSTED_TESTLAB_MUTATION_RESOURCES = {',
        'verified admin-tools integration': "['dpn-medical-admin-tools'] = true",
        'central authorization helper': 'local function authorizeMutationCaller(operation)',
        'server-derived caller identity': 'local caller = GetInvokingResource()',
        'default-deny unknown caller': "local deniedCaller = caller or 'unknown'",
        'denied mutation audit log': 'denied test-lab mutation export %s from %s',
        'private restore implementation': 'local function restoreTestSnapshot(target, actor, callerResource)',
        'restore audit evidence': 'invokingResource=callerResource',
    }
    missing = [name for name, needle in required.items() if needle not in text]
    if missing:
        fail('missing required trust-boundary controls: ' + ', '.join(missing))

    auth = block(text, 'local function authorizeMutationCaller(operation)', 'local function deepCopy(value)')
    if 'actor' in auth or 'target' in auth:
        fail('authorization helper must not trust actor/target input')
    if 'TRUSTED_TESTLAB_MUTATION_RESOURCES[caller] == true' not in auth:
        fail('authorization helper does not enforce explicit allowlist membership')

    restore = block(text, "exports('RestoreTestSnapshot'", "exports('ApplyTestScenario'")
    auth_pos = restore.find("authorizeMutationCaller('RestoreTestSnapshot')")
    mutate_pos = restore.find('restoreTestSnapshot(target, actor, callerResource)')
    if auth_pos < 0 or mutate_pos < 0 or auth_pos > mutate_pos:
        fail('RestoreTestSnapshot must authorize before restore mutation')

    apply = block(text, "exports('ApplyTestScenario'", "RegisterNetEvent('dpn-medical-core:server:requestTestCatalog'")
    auth_pos = apply.find("authorizeMutationCaller('ApplyTestScenario')")
    snapshot_pos = apply.find('snapshots[target]=deepCopy(current)')
    commit_pos = apply.find("DPNMedicalServer.Commit(target,cid,state,'admin_test_scenario'")
    event_pos = apply.find("TriggerClientEvent('dpn-medical-core:client:lifeState'")
    if auth_pos < 0:
        fail('ApplyTestScenario is missing mutation caller authorization')
    for name, pos in (('snapshot', snapshot_pos), ('commit', commit_pos), ('life-state event', event_pos)):
        if pos < 0 or auth_pos > pos:
            fail(f'ApplyTestScenario authorization must occur before {name} mutation')
    if "exports['dpn-medical-core']:RestoreTestSnapshot" in apply:
        fail('ApplyTestScenario must use the private restore function after authorization, not re-enter the public export')
    if 'restoreTestSnapshot(target,actor,callerResource)' not in apply:
        fail('ApplyTestScenario restore_snapshot path does not preserve authorized caller context')
    if 'invokingResource=callerResource' not in apply:
        fail('ApplyTestScenario does not persist server-derived caller evidence')

    for needle in (
        "exports('GetTestScenarioCatalog'",
        "exports('RunMedicalSelfTest'",
        "exports('GetTestRunHistory'",
    ):
        if needle not in text:
            fail(f'read-only Test Lab export was removed: {needle}')

    print('[medical-testlab-export-authority] PASS: mutation exports are default-deny by server-derived invoking resource and preserve trusted admin-tools compatibility')


if __name__ == '__main__':
    main()
