#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path("qbcore/public-safety/dpn-unified-emergency-services-suite/core/dpn-mdt")
SERVER = ROOT / "server/main.lua"
RESOURCE = ROOT / "resource.json"
README = ROOT / "README.md"


def fail(message: str) -> None:
    print(f"[mdt-sql-boundary] ERROR: {message}")
    sys.exit(1)


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        fail(f"missing {label}: {needle}")


def main() -> None:
    for path in (SERVER, RESOURCE, README):
        if not path.is_file():
            fail(f"missing required file: {path}")

    server = SERVER.read_text(encoding="utf-8")
    resource = RESOURCE.read_text(encoding="utf-8")
    readme = README.read_text(encoding="utf-8")

    controls = {
        "safe configured identifier helper": "local function safeConfiguredIdentifier(key)",
        "identifier length bound": "#value > 64",
        "strict identifier allowlist": "value:match('^[%w_]+$')",
        "known-safe defaults": "local DB_DEFAULTS = {",
        "bounded invalid identifier log": "value:sub(1, 96)",
        "server-owned filter allowlist": "local COUNT_FILTERS = {",
        "active filter": "active = \"AND status = 'active'\"",
        "filter key lookup": "local clause = COUNT_FILTERS[filterKey]",
        "unsafe filter rejection": "Unsafe SQL count filter key",
        "parameterized count equality": "WHERE %s = ?",
        "parameterized count like": "WHERE %s LIKE ?",
    }
    for label, needle in controls.items():
        require(server, needle, label)

    if "whereExtra" in server:
        fail("raw whereExtra SQL suffix composition remains in server/main.lua")

    if 'countWhere(\'dpn_mdt_warrants\', \'citizenid\', row.citizenid, "AND status = \'active\'")' in server:
        fail("raw active-warrant SQL suffix remains")

    require(resource, '"version": "1.1.1-charges"', "resource version")
    require(resource, '"status": "hardened"', "hardened maturity")
    require(readme, "Current hardened release: **1.1.1-charges**.", "README hardened release")
    require(readme, "server-owned allowlist", "README SQL boundary documentation")

    print(
        "[mdt-sql-boundary] PASS: configured SQL identifiers are bounded/allowlisted, "
        "invalid config falls back safely, and dynamic suffixes use a server-owned allowlist"
    )


if __name__ == "__main__":
    main()
