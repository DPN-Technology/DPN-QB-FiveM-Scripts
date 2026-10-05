#!/usr/bin/env python3
"""Regression checks for DPN FiveM server trust boundaries.

These checks lock in the runtime-hardening rules that are easy to regress when
resources are refactored: server-only QBCore lifecycle hooks, authoritative
vehicle/position state, bounded event rates, and internal-only integration hooks.
"""
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str, failures: list[str]) -> None:
    if needle not in text:
        failures.append(f"{label}: missing {needle!r}")


def forbid(text: str, needle: str, label: str, failures: list[str]) -> None:
    if needle in text:
        failures.append(f"{label}: forbidden {needle!r}")


def main() -> int:
    failures: list[str] = []

    spikes = read("qbcore/law-enforcement/dpn_mobilespikes/server/main.lua")
    require(
        spikes,
        "AddEventHandler('QBCore:Server:OnPlayerUnload', function()",
        "Mobile Spikes lifecycle",
        failures,
    )
    forbid(
        spikes,
        "RegisterNetEvent('QBCore:Server:OnPlayerUnload'",
        "Mobile Spikes lifecycle",
        failures,
    )
    require(spikes, "GetAuthorizedDeploymentVehicle", "Mobile Spikes deployment", failures)
    require(
        spikes,
        "local normalizedCoords = CalculateServerDeploymentPosition(vehicle)",
        "Mobile Spikes deployment",
        failures,
    )
    require(
        spikes,
        "local normalizedHeading = GetEntityHeading(vehicle)",
        "Mobile Spikes deployment",
        failures,
    )
    require(
        spikes,
        "if not HasAuthorization(source) then",
        "Mobile Spikes callback",
        failures,
    )

    unes_main = read(
        "qbcore/public-safety/dpn-unified-emergency-services-suite/"
        "core/dpn-unified-emergency-network/server/main.lua"
    )
    require(
        unes_main,
        "AddEventHandler('QBCore:Server:OnJobUpdate', function()",
        "UNES job lifecycle",
        failures,
    )
    require(
        unes_main,
        "AddEventHandler('QBCore:Server:SetDuty', function()",
        "UNES duty lifecycle",
        failures,
    )
    forbid(
        unes_main,
        "RegisterNetEvent('QBCore:Server:OnJobUpdate'",
        "UNES job lifecycle",
        failures,
    )
    forbid(
        unes_main,
        "RegisterNetEvent('QBCore:Server:SetDuty'",
        "UNES duty lifecycle",
        failures,
    )

    unes_dispatch = read(
        "qbcore/public-safety/dpn-unified-emergency-services-suite/"
        "core/dpn-unified-emergency-network/server/dispatch.lua"
    )
    require(
        unes_dispatch,
        "AddEventHandler('dpn-unes:server:broadcastIncident', function(incident)",
        "UNES incident broadcast",
        failures,
    )
    forbid(
        unes_dispatch,
        "RegisterNetEvent('dpn-unes:server:broadcastIncident'",
        "UNES incident broadcast",
        failures,
    )

    incidents = read(
        "qbcore/public-safety/dpn-unified-emergency-services-suite/"
        "core/dpn-unified-emergency-network/server/incidents.lua"
    )
    require(
        incidents,
        "local networkSource = tonumber(source) or 0",
        "UNES incident source authority",
        failures,
    )
    forbid(
        incidents,
        "local src = type(srcOverride) == 'number' and srcOverride or source",
        "UNES incident source authority",
        failures,
    )
    require(
        incidents,
        "AddEventHandler('dpn-unes:server:linkRecord', function(",
        "UNES record linking",
        failures,
    )
    forbid(
        incidents,
        "RegisterNetEvent('dpn-unes:server:linkRecord'",
        "UNES record linking",
        failures,
    )
    require(
        incidents,
        "if not INCIDENT_STATUS[status] then return end",
        "UNES incident status validation",
        failures,
    )
    require(
        incidents,
        "while #incident.linkedRecords > 100 do",
        "UNES linked-record bound",
        failures,
    )
    require(
        incidents,
        "and #encoded <= 8000",
        "UNES metadata bound",
        failures,
    )

    pa = read("hybrid/communications/dpn_pasystem/server/main.lua")
    require(pa, "local LastHeartbeat = {}", "PA heartbeat protection", failures)
    require(pa, "local heartbeatInterval = math.max", "PA heartbeat protection", failures)
    require(pa, "local serverCoords = ped and ped ~= 0 and GetEntityCoords(ped)", "PA telemetry authority", failures)
    require(pa, "NetworkGetNetworkIdFromEntity(veh)", "PA vehicle authority", failures)

    dispatch = read(
        "qbcore/public-safety/dpn-unified-emergency-services-suite/"
        "core/dpn-dispatch/server/main.lua"
    )
    require(dispatch, "local RequestRate = {}", "Dispatch rate limiting", failures)
    require(dispatch, "function RateAllowed(src, action, intervalMs)", "Dispatch rate limiting", failures)
    require(
        dispatch,
        "Units[src].coords = GetCoords(src) or Units[src].coords",
        "Dispatch position authority",
        failures,
    )
    require(
        dispatch,
        "RateAllowed(src, 'createCall'",
        "Dispatch call rate limiting",
        failures,
    )

    if failures:
        print("DPN runtime authority regression check: FAIL")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("DPN runtime authority regression check: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
