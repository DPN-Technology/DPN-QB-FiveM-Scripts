#!/usr/bin/env python3
"""Regression guard for DPN FiveM hardening wave 1."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
errors: list[str] = []


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8", errors="ignore")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        errors.append(f"{label}: missing required hardening signal: {needle}")


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        errors.append(f"{label}: prohibited regression detected: {needle}")


real_server = read("qbcore/world/dpn-real-traffic/server/main.lua")
real_config = read("qbcore/world/dpn-real-traffic/shared/config.lua")
training = read(
    "qbcore/public-safety/dpn-unified-emergency-services-suite/"
    "[dpn-lawenforcement]/dpn-training-academy/server/main.lua"
)
medical = read(
    "qbcore/public-safety/dpn-unified-emergency-services-suite/"
    "[dpn-medical]/dpn-medical-core/server/persistence.lua"
)
auditor = read("tools/audit_resource_hardening.py")

for needle in (
    "local statusRequestRate = {}",
    "local function allowStatusRequest",
    "GetGameTimer()",
    "if not allowStatusRequest(src) then return end",
    "AddEventHandler('playerDropped'",
):
    require(real_server, needle, "dpn-real-traffic")
require(real_config, "Config.StatusRequestCooldownMs", "dpn-real-traffic config")

forbid(training, "INTERVAL %d DAY", "dpn-training-academy")
require(training, "local expiresAt =", "dpn-training-academy")
require(training, "NOW(), ?)", "dpn-training-academy")
require(training, "score, expiresAt", "dpn-training-academy")

forbid(medical, "INTERVAL %d DAY", "dpn-medical-core persistence")
require(medical, "created_at < ?", "dpn-medical-core persistence")
require(medical, "{ cutoff }", "dpn-medical-core persistence")

for needle in (
    "ZERO_ARG_NET_EVENT_RE",
    "def dynamic_sql_signals",
    "def uncooperative_loop_count",
    "input_bearing_handlers",
):
    require(auditor, needle, "hardening auditor")

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    raise SystemExit(1)

print("DPN hardening wave 1 regression guard: PASS")
