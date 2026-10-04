#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path("qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-lawenforcement]/dpn-vehicle-computer")
SERVER = ROOT / "server/main.lua"
CONFIG = ROOT / "config.lua"
RESOURCE = ROOT / "resource.json"
README = ROOT / "README.md"

EVENTS = {
    "open": "dpn-vehicle-computer:server:open",
    "setStatus": "dpn-vehicle-computer:server:setStatus",
    "createCall": "dpn-vehicle-computer:server:createCall",
    "panic": "dpn-vehicle-computer:server:panic",
    "plateCheck": "dpn-vehicle-computer:server:plateCheck",
    "addHotlist": "dpn-vehicle-computer:server:addHotlist",
    "saveNote": "dpn-vehicle-computer:server:saveNote",
}


def fail(message: str) -> None:
    print(f"[vehicle-computer-security] ERROR: {message}")
    sys.exit(1)


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        fail(f"missing {label}: {needle}")


def main() -> None:
    for path in (SERVER, CONFIG, RESOURCE, README):
        if not path.is_file():
            fail(f"missing required file: {path}")

    server = SERVER.read_text(encoding="utf-8")
    config = CONFIG.read_text(encoding="utf-8")
    resource = RESOURCE.read_text(encoding="utf-8")
    readme = README.read_text(encoding="utf-8")

    server_controls = {
        "rate state": "local eventRate = {}",
        "rate helper": "local function rateAllowed(src, action)",
        "rate enforcement": "local function enforceRateLimit(src, action)",
        "rate audit cooldown": "RateLimitAuditCooldownSeconds",
        "disconnect cleanup": "AddEventHandler('playerDropped'",
        "server-owned call sanitizer": "local function sanitizeDispatchCall(input, officerName, src)",
        "server coordinate verification": "coords = verifiedCoords(src)",
        "priority lower bound": "if priority < 1 then priority = 1 end",
        "priority upper bound": "if priority > 5 then priority = 5 end",
        "server-owned departments": "departments = { 'law', 'dispatch' }",
        "server-owned metadata": "metadata = { source = 'vehicle-computer' }",
    }
    for label, needle in server_controls.items():
        require(server, needle, label)

    for action, event_name in EVENTS.items():
        event_pos = server.find(f"RegisterNetEvent('{event_name}'")
        if event_pos < 0:
            fail(f"missing server event: {event_name}")
        next_event = server.find("RegisterNetEvent(", event_pos + 1)
        block = server[event_pos: next_event if next_event >= 0 else len(server)]
        require(block, f"enforceRateLimit(src, '{action}')", f"{action} rate enforcement")

    config_controls = {
        "security table": "Config.Security = {",
        "window setting": "EventWindowSeconds = 10",
        "audit setting": "RateLimitAuditCooldownSeconds = 10",
        "open limit": "open = 6",
        "status limit": "setStatus = 12",
        "call limit": "createCall = 4",
        "panic limit": "panic = 2",
        "plate limit": "plateCheck = 12",
        "hotlist limit": "addHotlist = 5",
        "note limit": "saveNote = 6",
    }
    for label, needle in config_controls.items():
        require(config, needle, label)

    require(resource, '"version": "4.0.1"', "resource version")
    require(resource, '"status": "hardened"', "hardened maturity")
    require(readme, "Security model", "README security documentation")
    require(readme, "tools/check_vehicle_computer_security.py", "README regression-gate reference")

    forbidden = [
        "call.createdBy = data.name",
        "call.staffOnly = true",
        "call.departments = { 'law', 'dispatch' }",
    ]
    for needle in forbidden:
        if needle in server:
            fail(f"legacy client table mutation remains: {needle}")

    print(
        "[vehicle-computer-security] PASS: all exposed events are rate-limited, "
        "disconnect state is cleaned up, and dispatch payloads are rebuilt server-side"
    )


if __name__ == "__main__":
    main()
