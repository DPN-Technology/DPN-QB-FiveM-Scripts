#!/usr/bin/env python3
from pathlib import Path
import sys

TARGET = Path("qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-lawenforcement]/dpn-le-core/server/main.lua")


def fail(message: str) -> None:
    print(f"[le-vehicle-placement-authority] ERROR: {message}")
    sys.exit(1)


def main() -> None:
    if not TARGET.is_file():
        fail(f"missing {TARGET}")

    text = TARGET.read_text(encoding="utf-8")
    start_marker = "RegisterNetEvent('dpn-le-core:server:putInVehicle'"
    end_marker = "RegisterNetEvent('dpn-le-core:server:removeFromVehicle'"
    start = text.find(start_marker)
    end = text.find(end_marker, start + 1)
    if start < 0 or end < 0:
        fail("unable to isolate putInVehicle server handler")
    block = text[start:end]

    required = {
        "target normalization": "target = tonumber(target)",
        "network ID normalization": "vehicleNetId = tonumber(vehicleNetId)",
        "officer action authority": "actionAllowed(src, true)",
        "officer-target proximity": "withinDistance(src, target, Config.Interactions.VehicleDistance)",
        "server-owned restraint state": "Restrained[target]",
        "server-side network resolution": "NetworkGetEntityFromNetworkId(vehicleNetId)",
        "entity existence validation": "DoesEntityExist(vehicle)",
        "vehicle type validation": "GetEntityType(vehicle) ~= 2",
        "officer ped lookup": "GetPlayerPed(src)",
        "target ped lookup": "GetPlayerPed(target)",
        "server vehicle coordinates": "GetEntityCoords(vehicle)",
        "server officer distance": "sourceDistance = #(GetEntityCoords(sourcePed) - vehicleCoords)",
        "server target distance": "targetDistance = #(GetEntityCoords(targetPed) - vehicleCoords)",
        "bounded vehicle distance": "maxVehicleDistance + 2.0",
        "observed-distance audit evidence": "vehicleDistance = math.max(sourceDistance, targetDistance)",
    }
    missing = [name for name, needle in required.items() if needle not in block]
    if missing:
        fail("missing required authority controls: " + ", ".join(missing))

    resolve_pos = block.find("NetworkGetEntityFromNetworkId(vehicleNetId)")
    existence_pos = block.find("DoesEntityExist(vehicle)")
    type_pos = block.find("GetEntityType(vehicle) ~= 2")
    source_distance_pos = block.find("sourceDistance = #(GetEntityCoords(sourcePed) - vehicleCoords)")
    target_distance_pos = block.find("targetDistance = #(GetEntityCoords(targetPed) - vehicleCoords)")
    bounded_pos = block.find("sourceDistance > maxVehicleDistance + 2.0")
    clear_escort_pos = block.find("Escorting[target] = nil")
    emit_pos = block.find("TriggerClientEvent('dpn-le-core:client:putInVehicle'")
    audit_pos = block.find("saveActionLog(src, 'PLACE_IN_VEHICLE'")

    ordered = [
        ("network resolution", resolve_pos),
        ("entity existence validation", existence_pos),
        ("vehicle type validation", type_pos),
        ("officer vehicle-distance observation", source_distance_pos),
        ("target vehicle-distance observation", target_distance_pos),
        ("distance enforcement", bounded_pos),
        ("escort-state mutation", clear_escort_pos),
        ("client placement event", emit_pos),
        ("success audit", audit_pos),
    ]
    previous_name, previous_pos = ordered[0]
    if previous_pos < 0:
        fail(f"missing {previous_name}")
    for name, pos in ordered[1:]:
        if pos < 0:
            fail(f"missing {name}")
        if pos <= previous_pos:
            fail(f"{name} must occur after {previous_name}")
        previous_name, previous_pos = name, pos

    if "GetEntityCoords(" not in block:
        fail("vehicle proximity must use server-observed entity coordinates")
    if "coords" in block.lower() and "GetEntityCoords" not in block:
        fail("client-provided coordinates must not become vehicle-placement authority")

    print(
        "[le-vehicle-placement-authority] PASS: client-selected vehicle network IDs are "
        "resolved and proximity-validated server-side before placement mutation"
    )


if __name__ == "__main__":
    main()
