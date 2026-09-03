from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DISPATCH = ROOT / 'qbcore/public-safety/dpn-unified-emergency-services-suite/core/dpn-dispatch'
BRIDGE = DISPATCH / 'server/mdt_correlation_bridge.lua'
MANIFEST = DISPATCH / 'fxmanifest.lua'

bridge = BRIDGE.read_text(encoding='utf-8')
manifest = MANIFEST.read_text(encoding='utf-8')

required = [
    "GetEmergencyCorrelation",
    "LinkEmergencyCorrelation",
    "'mdtCaseId'",
    "payload.call_id",
    "payload.legacyDispatchCallId",
    "payload.eventId",
    "payload.dispatchCallId",
    "payload.correlation",
    "function MDT.BuildCallPayload",
    "function MDT.BuildReportPayload",
    "function MDT.SyncCall",
]

missing = [token for token in required if token not in bridge]
assert not missing, f'Missing Phase 3D MDT integration tokens: {missing}'

assert "RegisterNetEvent" not in bridge, 'MDT correlation bridge must not expose a client-triggerable mutation event'
assert "server/mdt_correlation_bridge.lua" in manifest, 'Phase 3D bridge is not loaded by dpn-dispatch'
assert manifest.index("server/mdt_bridge.lua") < manifest.index("server/mdt_correlation_bridge.lua") < manifest.index("server/main.lua"), \
    'Phase 3D MDT bridge must load after the base MDT bridge and before dispatch runtime'

print('PASS: Phase 3D MDT correlation integration contract')
