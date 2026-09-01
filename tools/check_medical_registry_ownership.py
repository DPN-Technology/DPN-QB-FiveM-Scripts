#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MEDICAL_ROOT = ROOT / "qbcore" / "public-safety" / "dpn-unified-emergency-services-suite" / "[dpn-medical]"

NUMERICAL_LAYER = re.compile(r"^v\d+\.lua$")
REGISTER_CALL = re.compile(r"RegisterModule\s*\(")
HEARTBEAT_TOKENS = ("moduleHeartbeat", "ModuleHeartbeat")
ADV_REGISTER_TABLE = re.compile(
    r"RegisterModule\s*\(\s*[^,]+\s*,\s*[^,]+\s*,\s*\{",
    re.DOTALL,
)
HARDCODED_ADV_VERSION = re.compile(
    r"local\s+ADV_VERSION\s*=\s*['\"][^'\"]+['\"]"
)


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def main() -> int:
    if not MEDICAL_ROOT.is_dir():
        print(f"ERROR: medical root not found: {MEDICAL_ROOT}")
        return 2

    errors: list[str] = []
    checked_layers = 0
    checked_advanced = 0

    for path in sorted(MEDICAL_ROOT.rglob("server/*.lua")):
        text = path.read_text(encoding="utf-8")

        if NUMERICAL_LAYER.match(path.name):
            checked_layers += 1
            if REGISTER_CALL.search(text):
                errors.append(
                    f"{rel(path)}: historical numerical layer must not call RegisterModule"
                )
            for token in HEARTBEAT_TOKENS:
                if token in text:
                    errors.append(
                        f"{rel(path)}: historical numerical layer must not own heartbeat token {token}"
                    )

        if path.name == "advanced.lua" and REGISTER_CALL.search(text):
            checked_advanced += 1
            if not ADV_REGISTER_TABLE.search(text):
                errors.append(
                    f"{rel(path)}: RegisterModule capabilities must be passed as a table"
                )
            if HARDCODED_ADV_VERSION.search(text):
                errors.append(
                    f"{rel(path)}: ADV_VERSION must come from manifest metadata, not a hard-coded string"
                )
            if "GetResourceMetadata" not in text:
                errors.append(
                    f"{rel(path)}: lifecycle owner must derive runtime version with GetResourceMetadata"
                )
            if "GetCurrentResourceName" not in text:
                errors.append(
                    f"{rel(path)}: lifecycle owner must derive resource identity with GetCurrentResourceName"
                )

    if errors:
        print("DPN Medical Registry Ownership Guard: FAILED")
        for error in errors:
            print(f" - {error}")
        print(f"Checked {checked_layers} numerical server layers and {checked_advanced} advanced registration owners.")
        return 1

    print("DPN Medical Registry Ownership Guard: PASSED")
    print(f"Checked {checked_layers} numerical server layers and {checked_advanced} advanced registration owners.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
