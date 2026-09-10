#!/usr/bin/env python3
"""hngh read-only MCP stdio server (plan step 1, omp-hngh integration).

Thin automation-edge adapter: exposes existing hngh CLI read-only commands
as MCP tools over stdio. The kernel never knows MCP exists; every tool is
one subprocess call to an existing CLI (hngh present/status via
scripts/hngh, scripts/report-queue --json, scripts/dashboard-readout
--json). No daemon: spawned per connection by the MCP client.

Env seams (hermetic tests / operators):
  HNGH_MCP_REPO_ROOT   repo root override (default: parent of this dir)
  HNGH_MCP_TIMEOUT     per-tool subprocess timeout seconds (default 60)
  HNGH_MCP_KERNEL_CMD  command wrapping the kernel CLI (default scripts/hngh)
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

PROTOCOL_VERSION = "2025-06-18"
REPO_ROOT = Path(os.environ.get("HNGH_MCP_REPO_ROOT", Path(__file__).resolve().parent.parent.parent))
TIMEOUT = float(os.environ.get("HNGH_MCP_TIMEOUT", "60"))


def run_cli(cmd, timeout=TIMEOUT):
    """Run one CLI read-only command; return its stdout or raise RuntimeError."""
    proc = subprocess.run(
        cmd, capture_output=True, text=True, timeout=timeout, cwd=str(REPO_ROOT)
    )
    if proc.returncode != 0:
        raise RuntimeError(
            "%s exited %d: %s" % (cmd[0], proc.returncode, proc.stderr.strip() or proc.stdout.strip())
        )
    return proc.stdout


def kernel_cli(*args):
    base = [str(REPO_ROOT / os.environ.get("HNGH_MCP_KERNEL_CMD", "scripts/hngh"))]
    if os.environ.get("HNGH_MCP_KERNEL"):
        base = os.environ["HNGH_MCP_KERNEL"].split()
    return base + list(args)


def tool_hngh_present(args):
    cmd = kernel_cli("present")
    if args.get("run"):
        cmd.append(str(args["run"]))
    return {"output": run_cli(cmd)}


def tool_hngh_status(args):
    return {"output": run_cli(kernel_cli("status"))}


def tool_queue_report(args):
    return {"output": run_cli([str(REPO_ROOT / "scripts" / "report-queue"), "--json"])}


def tool_dashboard_readout(args):
    return {"output": run_cli([str(REPO_ROOT / "scripts" / "dashboard-readout"), "--json"])}


READONLY_SCHEMA = {
    "type": "object",
    "properties": {},
    "additionalProperties": False,
}

HANDLERS = {
    "hngh_present": tool_hngh_present,
    "hngh_status": tool_hngh_status,
    "queue_report": tool_queue_report,
    "dashboard_readout": tool_dashboard_readout,
}


def tools_list():
    return [
        {
            "name": "hngh_present",
            "description": "Render one hngh run (read-only): hngh present [RUN].",
            "inputSchema": {
                "type": "object",
                "properties": {"run": {"type": "string", "description": "Optional run id"}},
                "required": [],
            },
        },
        {
            "name": "hngh_status",
            "description": "hngh kernel status command (read-only).",
            "inputSchema": READONLY_SCHEMA,
        },
        {
            "name": "queue_report",
            "description": "Report-queue ledger as JSON (scripts/report-queue --json).",
            "inputSchema": READONLY_SCHEMA,
        },
        {
            "name": "dashboard_readout",
            "description": "Automation dashboard spine as JSON (scripts/dashboard-readout --json).",
            "inputSchema": READONLY_SCHEMA,
        },
    ]


def handle_request(request):
    method = request.get("method", "")
    params = request.get("params", {}) or {}
    req_id = request.get("id")

    if method == "initialize":
        return {"jsonrpc": "2.0", "id": req_id, "result": {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "hngh", "version": "1.0.0"},
        }}
    if method == "tools/list":
        return {"jsonrpc": "2.0", "id": req_id, "result": {"tools": tools_list()}}
    if method == "tools/call":
        name = params.get("name", "")
        handler = HANDLERS.get(name)
        if not handler:
            return {"jsonrpc": "2.0", "id": req_id, "error": {
                "code": -32601, "message": "Unknown tool: %s" % name}}
        try:
            result = handler(params.get("arguments", {}) or {})
        except Exception as exc:  # fail closed: error result, never partial
            return {"jsonrpc": "2.0", "id": req_id, "result": {
                "content": [{"type": "text", "text": "error: %s" % exc}], "isError": True}}
        return {"jsonrpc": "2.0", "id": req_id, "result": {
            "content": [{"type": "text", "text": json.dumps(result, ensure_ascii=False)}]}}
    if method == "notifications/initialized":
        return None
    return {"jsonrpc": "2.0", "id": req_id, "error": {
        "code": -32601, "message": "Unknown method: %s" % method}}


def main():
    sys.stderr.write("hngh MCP stdio server started\n")
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except json.JSONDecodeError:
            continue
        response = handle_request(request)
        if response:
            sys.stdout.write(json.dumps(response) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
