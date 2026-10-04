#!/usr/bin/env python3
from pathlib import Path
import sys

SERVER = Path('qbcore/admin/dpn-mib-system/server/main.lua')
CONFIG = Path('qbcore/admin/dpn-mib-system/shared/config.lua')


def fail(message: str) -> None:
    print(f'[mib-action-policy] ERROR: {message}')
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
    if not SERVER.is_file() or not CONFIG.is_file():
        fail('missing MIB server/config source')

    server = SERVER.read_text(encoding='utf-8')
    config = CONFIG.read_text(encoding='utf-8')

    server_required = {
        'separate MIB ACE helper': 'local function hasMIBAce(src)',
        'separate admin ACE policy': 'Config.AdminAcePermissions',
        'policy level map': "local POLICY_LEVELS = { mib = 1, director = 2, admin = 3 }",
        'server-derived source tier': 'local function sourcePolicyLevel(src)',
        'central policy authorization': 'local function authorizePolicy(src, requiredPolicy, action, target, reason)',
        'tool action authorization': 'local function authorizeToolAction(src, action, target, reason)',
        'config-driven tool policy': "(Config.MIBActionPolicy or {})[action] or 'mib'",
        'bounded denial audit': "MIBLog(src, 'ACTION_AUTHORIZATION_DENIED'",
        'tool gate before branches': 'if not authorizeToolAction(src, action, target, payload.reason) then return end',
        'basic neuralizer policy': "(Config.NeuralizerPolicy or {})[class] or 'director'",
        'advanced neuralizer policy': "(Config.AdvancedNeuralizerPolicy or {})[mode] or 'director'",
        'bucket bounds': 'Config.RoutingBucketBounds or { min = 0, max = 9999 }',
        'integer bucket validation': 'bucket ~= math.floor(bucket)',
    }
    missing = [name for name, needle in server_required.items() if needle not in server]
    if missing:
        fail('missing server controls: ' + ', '.join(missing))

    config_required = {
        'admin ACE split': "Config.AdminAcePermissions = { 'dpn.mib.admin' }",
        'tool policy table': 'Config.MIBActionPolicy = {',
        'kick admin tier': "kick='admin'",
        'bucket admin tier': "set_bucket='admin'",
        'scene wipe director tier': "wipe_scene='director'",
        'lockdown director tier': "lockdown='director'",
        'remote movement director tier': "goto_player='director'",
        'spectate director tier': "spectate='director'",
        'basic neuralizer tier map': 'Config.NeuralizerPolicy = {',
        'advanced neuralizer tier map': 'Config.AdvancedNeuralizerPolicy = {',
        'advanced area director tier': "area='director'",
        'routing bucket range': 'Config.RoutingBucketBounds = { min = 0, max = 9999 }',
    }
    missing = [name for name, needle in config_required.items() if needle not in config]
    if missing:
        fail('missing config controls: ' + ', '.join(missing))

    admin_block = block(server, 'local function isAdmin(src)', 'local function hasMIBAce(src)')
    if 'Config.AcePermissions' in admin_block:
        fail('general MIB ACE permissions must not grant admin authority')
    if 'Config.AdminAcePermissions' not in admin_block:
        fail('admin authority must use the dedicated admin ACE list')

    tool = block(server, "RegisterNetEvent('dpn-mib:server:toolAction'", "AddEventHandler('playerDropped'")
    gate_pos = tool.find('authorizeToolAction(src, action, target, payload.reason)')
    first_branch = tool.find("if action == 'freeze' then")
    if gate_pos < 0 or first_branch < 0 or gate_pos > first_branch:
        fail('tool action policy gate must execute before action branches')
    if 'if not requireAccess(src, action, payload.reason) then return end' in tool:
        fail('toolAction still falls back to general-access-only authorization')

    set_bucket = block(tool, "elseif action == 'set_bucket' then", "elseif action == 'kick' then")
    bounds_pos = set_bucket.find('Config.RoutingBucketBounds')
    mutation_pos = set_bucket.find('SetPlayerRoutingBucket(target, bucket)')
    if bounds_pos < 0 or mutation_pos < 0 or bounds_pos > mutation_pos:
        fail('routing bucket validation must occur before bucket mutation')

    advanced_start = server.find("RegisterNetEvent('dpn-mib:server:advancedNeuralizer'")
    if advanced_start < 0:
        fail('missing advanced neuralizer handler')
    advanced = server[advanced_start:]
    auth_pos = advanced.find("authorizePolicy(src, requiredPolicy, 'advanced_neuralizer:'..mode")
    effect_pos = advanced.find("TriggerClientEvent('dpn-mib:client:advancedNeuralize")
    if auth_pos < 0 or effect_pos < 0 or auth_pos > effect_pos:
        fail('advanced neuralizer policy must be checked before effects')

    print('[mib-action-policy] PASS: MIB, director, and admin authority are server-derived and enforced before privileged effects')


if __name__ == '__main__':
    main()
