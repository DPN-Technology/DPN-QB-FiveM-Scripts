#!/usr/bin/env python3
from pathlib import Path
import sys

DATABASE = Path('qbcore/law-enforcement/dpn-starchase/server/database.lua')
RESOURCE = Path('qbcore/law-enforcement/dpn-starchase/resource.json')


def fail(message: str) -> None:
    print(f'[starchase-sql-identifier] ERROR: {message}')
    sys.exit(1)


def main() -> None:
    if not DATABASE.is_file() or not RESOURCE.is_file():
        fail('missing StarChase database or resource metadata')

    db = DATABASE.read_text(encoding='utf-8')
    metadata = RESOURCE.read_text(encoding='utf-8')

    required = {
        'identifier helper': 'local function ident(value, fallback)',
        'strict identifier pattern': "value:match('^[%w_]+$')",
        'MySQL identifier length bound': '#value > 64',
        'safe fallback': "local DEFAULT_TABLE_NAME = 'dpn_starchase_logs'",
        'resolved table identifier': 'local resolvedTableName, configuredTableNameValid = ident(',
        'bounded invalid identifier warning': "tostring(Config.Database.tableName):sub(1, 96)",
        'table resolver': 'return resolvedTableName',
        'parameterized insert values': 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    }
    missing = [name for name, needle in required.items() if needle not in db]
    if missing:
        fail('missing database hardening controls: ' + ', '.join(missing))

    if "format(Config.Database.tableName" in db or "format(Config.Database['tableName']" in db:
        fail('raw configured table name must not be interpolated directly into SQL')

    create_pos = db.find('CREATE TABLE IF NOT EXISTS `%s`')
    insert_pos = db.find('INSERT INTO `%s`')
    resolver_pos = db.find('local function tableName()')
    if min(create_pos, insert_pos, resolver_pos) < 0:
        fail('expected StarChase SQL construction surfaces are missing')
    if "format(tableName())" not in db:
        fail('dynamic SQL must use the validated tableName resolver')

    if '"status": "hardened"' not in metadata:
        fail('resource metadata must record hardened maturity after SQL validation is enforced')

    print('[starchase-sql-identifier] PASS: dynamic SQL table identifiers are server-validated and row data remains parameterized')


if __name__ == '__main__':
    main()
