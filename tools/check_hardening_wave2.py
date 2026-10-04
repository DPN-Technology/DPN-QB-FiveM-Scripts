#!/usr/bin/env python3
"""Regression guard for DPN FiveM hardening wave 2."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
errors: list[str] = []


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8", errors="ignore")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        errors.append(f"{label}: missing hardening control: {needle}")


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        errors.append(f"{label}: prohibited regression detected: {needle}")


crime_server = read(
    "qbcore/public-safety/dpn-unified-emergency-services-suite/"
    "[dpn-lawenforcement]/dpn-crime-intelligence/server/main.lua"
)
crime_config = read(
    "qbcore/public-safety/dpn-unified-emergency-services-suite/"
    "[dpn-lawenforcement]/dpn-crime-intelligence/shared/config.lua"
)
crime_readme = read(
    "qbcore/public-safety/dpn-unified-emergency-services-suite/"
    "[dpn-lawenforcement]/dpn-crime-intelligence/README.md"
)

mdt_server = read(
    "qbcore/public-safety/dpn-unified-emergency-services-suite/core/dpn-mdt/server/main.lua"
)
mdt_config = read(
    "qbcore/public-safety/dpn-unified-emergency-services-suite/core/dpn-mdt/config.lua"
)
mdt_readme = read(
    "qbcore/public-safety/dpn-unified-emergency-services-suite/core/dpn-mdt/README.md"
)

# Crime Intelligence rate-limit contract.
for needle in (
    "local requestRate = {}",
    "local function allowRequest",
    "GetGameTimer()",
    "rateLimit(src, 'open'",
    "rateLimit(src, 'search'",
    "rateLimit(src, 'mutation'",
    "rateLimit(src, 'alert'",
    "AddEventHandler('playerDropped'",
):
    require(crime_server, needle, "Crime Intelligence")

for needle in (
    "Config.RateLimits",
    "OpenMs",
    "SearchMs",
    "MutationMs",
    "AlertMs",
):
    require(crime_config, needle, "Crime Intelligence config")

require(crime_server, "id = tonumber(id)", "Crime Intelligence")
require(crime_server, "if not id or id < 1 then return end", "Crime Intelligence")
forbid(crime_readme, "Scaffold resource.", "Crime Intelligence README")
require(crime_readme, "## Abuse resistance", "Crime Intelligence README")

# MDT central callback throttle + event validation contract.
for needle in (
    "local requestRate = {}",
    "local function allowRequest",
    "local function callbackCooldown",
    "'callback:' .. name",
    "MDT request throttled",
    "'event:SetUnitStatus'",
    "Config.UnitStatuses and Config.UnitStatuses[status]",
    "status = tostring(status or '')",
    "callId = tostring(callId or '')",
    "AddEventHandler('playerDropped'",
):
    require(mdt_server, needle, "DPN MDT")

for needle in (
    "Config.RateLimits",
    "DefaultCallbackMs",
    "HeavyCallbackMs",
    "UnitStatusMs",
    "HeavyCallbacks",
    "Config.UnitStatuses",
    "available = true",
    "enroute = true",
    "out_of_service = true",
):
    require(mdt_config, needle, "DPN MDT config")

require(mdt_readme, "### Request throttling and status validation", "DPN MDT README")
require(mdt_readme, "### Dynamic SQL boundary", "DPN MDT README")

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    raise SystemExit(1)

print("DPN hardening wave 2 regression guard: PASS")
