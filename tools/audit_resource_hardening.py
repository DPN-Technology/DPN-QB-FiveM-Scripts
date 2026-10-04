#!/usr/bin/env python3
"""Static hardening audit for DPN FiveM resources.

This tool scores observable defensive engineering signals. It is intentionally
conservative and is not a penetration test or a guarantee of runtime security.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
from dataclasses import dataclass, asdict

ROOT = pathlib.Path(__file__).resolve().parents[1]
FRAMEWORKS = ("qbcore", "standalone", "hybrid")

NET_EVENT_RE = re.compile(r"\b(?:RegisterNetEvent|RegisterServerEvent)\s*\(")
CALLBACK_RE = re.compile(r"\b(?:QBCore\.Functions\.CreateCallback|lib\.callback\.register)\s*\(")
SOURCE_RE = re.compile(r"\bsource\b")
AUTH_RE = re.compile(
    r"(?i)(IsPlayerAceAllowed|HasPermission|GetPermission|isAdmin|isAuthorized|"
    r"DPN\.Bridge\.Is[A-Za-z]+|DPN_EvidenceBridge\.Is[A-Za-z]+|"
    r"DPNMedical[A-Za-z]*Authority|Can[A-Z][A-Za-z]+|"
    r"PlayerData\.(?:job|gang)|\.job\.name|\.gang\.name|allowedJobs|allowedGroups|"
    r"permission|authorized|whitelist|role)"
)
VALIDATION_RE = re.compile(
    r"(?i)(\btype\s*\(|\btonumber\s*\(|\btostring\s*\(|"
    r"math\.(?:min|max|floor|ceil)|string\.(?:match|find|len)|"
    r"#[A-Za-z_][A-Za-z0-9_]*\s*[<>]=?|"
    r"GetPlayerPed\s*\(|GetEntityCoords\s*\(|#\s*\([^\n]*-[^\n]*\)|"
    r"distance|proximity|withinRange|isNear)"
)
RATE_RE = re.compile(
    r"(?i)(cooldown|rate.?limit|throttle|debounce|lastRequest|lastAction|"
    r"GetGameTimer\s*\(|os\.(?:time|clock)\s*\()"
)
PRIV_RE = re.compile(
    r"(?i)(AddMoney|RemoveMoney|SetMoney|AddItem|RemoveItem|SetJob|"
    r"DropPlayer|ExecuteCommand|SetMetaData|SetMetadata|"
    r"MySQL\.(?:insert|update|query|execute|transaction)|"
    r"exports\[['\"]ox_inventory['\"]\].*(?:AddItem|RemoveItem))"
)
LOG_RE = re.compile(
    r"(?i)(print\s*\(|QBCore\.ShowError|QBCore\.ShowSuccess|"
    r"logger|audit|logEvent|webhook|discord)"
)
BROADCAST_RE = re.compile(r"TriggerClientEvent\s*\([^\n,]+,\s*-1\b")
DYNAMIC_SQL_RE = re.compile(
    r"(?im)^.*(?:SELECT|INSERT|UPDATE|DELETE)[^\n]*(?::format\(|\.\.)[^\n]*$"
)
LOOP_RE = re.compile(r"(?is)while\s+true\s+do(?P<body>.{0,1200}?)end")
WAIT_ZERO_RE = re.compile(r"\b(?:Wait|Citizen\.Wait)\s*\(\s*0\s*\)")
WAIT_ANY_RE = re.compile(r"\b(?:Wait|Citizen\.Wait)\s*\(")


@dataclass
class Finding:
    severity: str
    code: str
    message: str
    deduction: int


@dataclass
class ResourceAudit:
    path: str
    name: str
    display_name: str
    framework: str
    category: str
    version: str
    status: str
    score: int
    risk: str
    server_files: int
    client_files: int
    net_events: int
    callbacks: int
    privileged_ops: int
    broadcasts: int
    findings: list[Finding]

    def json(self) -> dict:
        data = asdict(self)
        return data


def read_text(path: pathlib.Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


def lua_files(resource: pathlib.Path, part: str) -> list[pathlib.Path]:
    direct = resource / part
    files: list[pathlib.Path] = []
    if direct.is_dir():
        files.extend(direct.rglob("*.lua"))
    direct_file = resource / f"{part}.lua"
    if direct_file.is_file():
        files.append(direct_file)
    return sorted(set(files))


def risk_for(score: int, critical: bool) -> str:
    if critical or score < 55:
        return "CRITICAL"
    if score < 70:
        return "HIGH"
    if score < 85:
        return "MODERATE"
    return "LOW"


def audit_resource(resource: pathlib.Path) -> ResourceAudit:
    metadata_path = resource / "resource.json"
    metadata = json.loads(read_text(metadata_path) or "{}")
    server_files = lua_files(resource, "server")
    client_files = lua_files(resource, "client")
    server_text = "\n".join(read_text(p) for p in server_files)
    client_text = "\n".join(read_text(p) for p in client_files)

    findings: list[Finding] = []

    def add(severity: str, code: str, message: str, deduction: int) -> None:
        findings.append(Finding(severity, code, message, deduction))

    net_events = len(NET_EVENT_RE.findall(server_text))
    callbacks = len(CALLBACK_RE.findall(server_text))
    exposed_handlers = net_events + callbacks
    privileged_ops = len(PRIV_RE.findall(server_text))
    broadcasts = len(BROADCAST_RE.findall(server_text))

    has_source = bool(SOURCE_RE.search(server_text))
    has_auth = bool(AUTH_RE.search(server_text))
    has_validation = bool(VALIDATION_RE.search(server_text))
    has_rate = bool(RATE_RE.search(server_text))
    has_logs = bool(LOG_RE.search(server_text))
    dynamic_sql_lines = [
        line.strip()
        for line in server_text.splitlines()
        if DYNAMIC_SQL_RE.search(line)
    ]

    if metadata.get("status", "").lower() in {"imported", "legacy", "unknown"}:
        add(
            "info",
            "MATURITY_IMPORTED",
            "Resource metadata is still marked imported/legacy; runtime hardening has not been explicitly certified.",
            4,
        )

    if exposed_handlers and not has_source:
        add(
            "high",
            "EVENT_SOURCE",
            f"{exposed_handlers} server network/callback handler(s) found with no observable source-based authority signal.",
            18,
        )

    if exposed_handlers and privileged_ops and not has_auth:
        add(
            "critical",
            "PRIVILEGED_AUTH",
            f"Privileged server operations ({privileged_ops}) coexist with exposed handlers but no observable authorization/job/ACE check.",
            28,
        )
    elif exposed_handlers and not has_auth:
        add(
            "moderate",
            "EVENT_AUTH",
            "Exposed server handlers have no observable authorization/job/ACE signal; confirm events are intentionally public.",
            10,
        )

    if exposed_handlers and not has_validation:
        add(
            "high",
            "INPUT_VALIDATION",
            "Exposed server handlers have no observable type/bounds/proximity validation signal.",
            18,
        )

    if exposed_handlers >= 2 and not has_rate:
        add(
            "moderate",
            "RATE_LIMIT",
            "Multiple exposed server handlers have no observable cooldown/rate-limit signal.",
            10,
        )
    elif exposed_handlers == 1 and not has_rate:
        add(
            "info",
            "RATE_LIMIT_SINGLE",
            "Single exposed server handler has no observable cooldown/rate-limit signal.",
            4,
        )

    if privileged_ops and exposed_handlers and not has_logs:
        add(
            "moderate",
            "PRIVILEGED_AUDIT",
            "Privileged server operations have no observable audit/logging signal.",
            7,
        )

    if dynamic_sql_lines:
        # Dynamic SQL is not automatically injectable: some resources safely
        # interpolate validated identifiers or bounded numeric constants. Keep
        # this as a review signal instead of declaring a vulnerability.
        safe_identifier_layer = "local function ident" in server_text and "^[%w_]+$" in server_text
        deduction = 4 if safe_identifier_layer else 8
        add(
            "moderate",
            "DYNAMIC_SQL_REVIEW",
            f"{len(dynamic_sql_lines)} dynamic SQL construction signal(s) found; verify interpolated values are allowlisted, numeric, or otherwise not client-controlled.",
            deduction,
        )

    if broadcasts:
        add(
            "info",
            "GLOBAL_BROADCAST",
            f"{broadcasts} server broadcast(s) target all clients; verify fan-out is required and payload size is bounded.",
            min(6, 2 + broadcasts),
        )

    hot_loops = 0
    for text in (server_text, client_text):
        for match in LOOP_RE.finditer(text):
            body = match.group("body")
            if not WAIT_ANY_RE.search(body):
                hot_loops += 2
            elif WAIT_ZERO_RE.search(body):
                hot_loops += 1
    if hot_loops >= 2:
        add(
            "moderate",
            "HOT_LOOP",
            f"{hot_loops} potential hot-loop signal(s) found; review tick frequency and work performed per frame.",
            min(10, 4 + hot_loops),
        )

    # Client-only resources have no server trust boundary to harden. Treat the
    # absence of server code as neutral rather than penalizing it.
    if not server_files:
        if NET_EVENT_RE.search(client_text):
            add(
                "info",
                "CLIENT_EVENTS",
                "Client-only resource registers network events; confirm remote client events cannot mutate authoritative state.",
                3,
            )

    if not (resource / "README.md").is_file():
        add("moderate", "README", "README.md missing.", 8)
    elif (resource / "README.md").stat().st_size < 600:
        add("info", "README_DEPTH", "README is very short; setup/security assumptions may be under-documented.", 3)

    config_present = any(
        p.is_file()
        for p in (
            resource / "config.lua",
            resource / "shared" / "config.lua",
            resource / "config.json",
        )
    )
    if exposed_handlers and not config_present:
        add(
            "info",
            "CONFIG_SURFACE",
            "Networked resource has no obvious centralized configuration file.",
            3,
        )

    deduction = sum(f.deduction for f in findings)
    score = max(0, 100 - deduction)
    critical = any(f.severity == "critical" for f in findings)
    risk = risk_for(score, critical)

    return ResourceAudit(
        path=resource.relative_to(ROOT).as_posix(),
        name=str(metadata.get("name", resource.name)),
        display_name=str(metadata.get("display_name", metadata.get("name", resource.name))),
        framework=str(metadata.get("framework", resource.parts[0] if resource.parts else "")),
        category=str(metadata.get("category", "")),
        version=str(metadata.get("version", "")),
        status=str(metadata.get("status", "")),
        score=score,
        risk=risk,
        server_files=len(server_files),
        client_files=len(client_files),
        net_events=net_events,
        callbacks=callbacks,
        privileged_ops=privileged_ops,
        broadcasts=broadcasts,
        findings=findings,
    )


def resource_dirs() -> list[pathlib.Path]:
    out: list[pathlib.Path] = []
    for framework in FRAMEWORKS:
        root = ROOT / framework
        if not root.exists():
            continue
        for manifest in root.rglob("fxmanifest.lua"):
            if "templates" in manifest.parts:
                continue
            resource = manifest.parent
            if (resource / "resource.json").is_file():
                out.append(resource)
    return sorted(set(out))


def markdown(audits: list[ResourceAudit]) -> str:
    counts = {risk: sum(a.risk == risk for a in audits) for risk in ("CRITICAL", "HIGH", "MODERATE", "LOW")}
    lines = [
        "# DPN FiveM Resource Hardening Scorecard",
        "",
        "> Static defensive-engineering audit. Scores are triage signals, not a penetration test or a guarantee of security.",
        "",
        f"**Resources audited:** {len(audits)}  ",
        f"**Risk distribution:** CRITICAL {counts['CRITICAL']} · HIGH {counts['HIGH']} · MODERATE {counts['MODERATE']} · LOW {counts['LOW']}",
        "",
        "| Score | Risk | Resource | Surface | Key finding |",
        "|---:|---|---|---|---|",
    ]
    for a in sorted(audits, key=lambda x: (x.score, x.display_name.lower())):
        finding = a.findings[0].message if a.findings else "No heuristic hardening gaps detected."
        finding = finding.replace("|", "\\|").replace("\n", " ")
        surface = f"{a.net_events} events / {a.callbacks} callbacks / {a.privileged_ops} privileged ops"
        lines.append(
            f"| {a.score} | **{a.risk}** | [{a.display_name}](../{a.path}/) | {surface} | {finding} |"
        )

    lines += ["", "## Detailed findings", ""]
    for a in sorted(audits, key=lambda x: (x.score, x.display_name.lower())):
        lines += [
            f"### {a.display_name} — {a.score}/100 ({a.risk})",
            "",
            f"- Path: `{a.path}`",
            f"- Version: `{a.version or 'unknown'}`",
            f"- Server files: {a.server_files}; client files: {a.client_files}",
            f"- Network events: {a.net_events}; callbacks: {a.callbacks}; privileged-operation signals: {a.privileged_ops}",
        ]
        if a.findings:
            for finding in a.findings:
                lines.append(
                    f"- **{finding.severity.upper()} / {finding.code} (-{finding.deduction})** — {finding.message}"
                )
        else:
            lines.append("- No heuristic hardening gaps detected.")
        lines.append("")

    lines += [
        "## Scoring policy",
        "",
        "The auditor begins at 100 and deducts points for observable risk signals such as exposed server handlers without authority/validation signals, privileged operations without authorization/audit signals, possible dynamic SQL construction, unbounded global broadcasts, hot loops, or imported maturity state.",
        "",
        "Client-only resources are not penalized for lacking server-side controls. Static analysis can produce false positives or miss runtime issues; high-risk findings require code review and runtime testing before changing behavior.",
        "",
        "**DPN Technology — Develop • Pioneer • Navigate**",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--markdown", help="Write Markdown scorecard to this path")
    parser.add_argument("--json", help="Write JSON audit report to this path")
    parser.add_argument("--top", type=int, default=10, help="Print N lowest-scoring resources")
    parser.add_argument("--fail-critical", action="store_true", help="Exit non-zero if a CRITICAL resource is found")
    args = parser.parse_args()

    audits = [audit_resource(path) for path in resource_dirs()]
    audits.sort(key=lambda a: (a.score, a.display_name.lower()))

    if args.markdown:
        path = ROOT / args.markdown
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(markdown(audits), encoding="utf-8")

    if args.json:
        path = ROOT / args.json
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "resources": [a.json() for a in audits],
                },
                indent=2,
                sort_keys=True,
            ) + "\n",
            encoding="utf-8",
        )

    print(f"DPN Resource Hardening Audit: {len(audits)} resource(s)")
    print("score risk      resource")
    for a in audits[: max(0, args.top)]:
        print(f"{a.score:>3}  {a.risk:<9} {a.path}")
        for finding in a.findings[:3]:
            print(f"     - {finding.severity.upper():<8} {finding.code}: {finding.message}")

    critical = sum(a.risk == "CRITICAL" for a in audits)
    high = sum(a.risk == "HIGH" for a in audits)
    moderate = sum(a.risk == "MODERATE" for a in audits)
    low = sum(a.risk == "LOW" for a in audits)
    print(f"Distribution: CRITICAL={critical} HIGH={high} MODERATE={moderate} LOW={low}")

    if args.fail_critical and critical:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
