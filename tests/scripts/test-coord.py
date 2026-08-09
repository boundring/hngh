"""Regression tests for src/plugins/hngh-coord — framing + routing.

Framing is protocol-specific and NOT interchangeable (mcp-server-setup
reference, 2026-08-08 ACP lesson): MCP = Content-Length, ACP = newline.
These tests lock in the wire behavior BEFORE any client wiring.
"""

import json
import subprocess
import sys
import threading
import time
from pathlib import Path

import pytest

COORD = Path(__file__).resolve().parents[2] / "src" / "plugins" / "hngh-coord" / "coord.py"


# ---- framing helpers under test -------------------------------------------

def acp_encode(obj):
    """ACP: newline-delimited JSON (one message per line)."""
    return json.dumps(obj) + "\n"


def mcp_encode(obj):
    """MCP: Content-Length header + body (LSP-style)."""
    body = json.dumps(obj).encode("utf-8")
    return f"Content-Length: {len(body)}\r\n\r\n".encode() + body


def read_mcp_frame(stream):
    """Read one Content-Length-framed message from a byte stream."""
    headers = b""
    while b"\r\n\r\n" not in headers:
        chunk = stream.read(1)
        if not chunk:
            raise EOFError
        headers += chunk
    head, _, rest = headers.partition(b"\r\n\r\n")
    length = None
    for line in head.split(b"\r\n"):
        if line.lower().startswith(b"content-length:"):
            length = int(line.split(b":", 1)[1].strip())
    if length is None:
        raise ValueError("no Content-Length")
    # rest may already hold part of the body
    body = rest
    while len(body) < length:
        body += stream.read(length - len(body))
    return json.loads(body.decode("utf-8"))


# ---- fixtures ---------------------------------------------------------------

@pytest.fixture
def coord_proc(tmp_path, monkeypatch):
    """Start the coordinator with a temp store — BINARY stdio (MCP framing
    is bytes; text wrappers corrupt Content-Length frames)."""
    monkeypatch.setenv("HNGH_COORD_HOME", str(tmp_path))
    p = subprocess.Popen(
        [sys.executable, str(COORD), "--agent", "test-agent"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    # wait for readiness banner on stderr (server prints it after init)
    ready = False
    deadline = time.time() + 5
    while time.time() < deadline and p.poll() is None:
        line = p.stderr.readline()
        if b"coord ready" in line:
            ready = True
            break
        if not line:
            break
    if not ready:
        p.kill()
        raise RuntimeError("coordinator did not become ready")
    yield p
    p.kill()
    p.wait()


def mcp_initialize_and_ping(proc):
    """MCP handshake: initialize then initialized notification."""
    req = {"jsonrpc": "2.0", "id": 1, "method": "initialize",
           "params": {"protocolVersion": "2024-11-05",
                      "capabilities": {},
                      "clientInfo": {"name": "test", "version": "0"}}}
    proc.stdin.write(mcp_encode(req))
    proc.stdin.flush()
    resp = read_mcp_frame(proc.stdout)
    # initialized notification (no id)
    proc.stdin.write(mcp_encode({"jsonrpc": "2.0",
                                 "method": "notifications/initialized",
                                 "params": {}}))
    proc.stdin.flush()
    return resp


def mcp_call(proc, rid, method, params):
    req = {"jsonrpc": "2.0", "id": rid, "method": method, "params": params}
    proc.stdin.write(mcp_encode(req))
    proc.stdin.flush()
    return read_mcp_frame(proc.stdout)


# ---- framing tests -----------------------------------------------------------

def test_acp_newline_roundtrip():
    obj = {"from": "A", "to": "B", "kind": "note", "body": "hello"}
    wire = acp_encode(obj)
    # exactly one line, no content-length headers
    assert wire.count("\n") == 1
    assert "Content-Length" not in wire
    parsed = json.loads(wire)
    assert parsed == obj


def test_mcp_content_length_compose_parse():
    obj = {"jsonrpc": "2.0", "method": "tools/list"}
    wire = mcp_encode(obj)
    assert wire.startswith(b"Content-Length: ")
    import io
    parsed = read_mcp_frame(io.BytesIO(wire))
    assert parsed == obj


def test_mcp_not_interchangeable_with_acp():
    # An ACP client sending newline JSON to an MCP reader would hang/fail.
    # The two encodings must NOT be identical.
    obj = {"jsonrpc": "2.0", "method": "tools/list"}
    assert mcp_encode(obj) != acp_encode(obj).encode()


# ---- server behavior (MCP face) ---------------------------------------------

def test_mcp_initialize(coord_proc):
    resp = mcp_initialize_and_ping(coord_proc)
    assert resp["jsonrpc"] == "2.0"
    assert resp["id"] == 1
    caps = resp.get("result", {})
    assert "capabilities" in caps
    assert "tools" in caps["capabilities"] or "tools" in caps


def test_register_and_status(coord_proc):
    mcp_initialize_and_ping(coord_proc)
    r1 = mcp_call(coord_proc, 2, "tools/call", {
        "name": "register",
        "arguments": {"agent_id": "A", "role": "design"}})
    r2 = mcp_call(coord_proc, 3, "tools/call", {
        "name": "status", "arguments": {}})
    status = text_content(r2)
    assert "A" in status


def test_post_read_routing(coord_proc):
    mcp_initialize_and_ping(coord_proc)
    mcp_call(coord_proc, 2, "tools/call", {
        "name": "post_message",
        "arguments": {"to": "B", "kind": "question", "body": "status?"}})
    # A reads its own inbox -> empty (message went to B)
    r = mcp_call(coord_proc, 3, "tools/call", {
        "name": "read_inbox", "arguments": {"agent_id": "A"}})
    assert "status?" not in text_content(r)
    # B reads its inbox -> sees the message
    r = mcp_call(coord_proc, 4, "tools/call", {
        "name": "read_inbox", "arguments": {"agent_id": "B"}})
    assert "status?" in text_content(r)


def test_multiseat_broadcast(coord_proc):
    mcp_initialize_and_ping(coord_proc)
    mcp_call(coord_proc, 2, "tools/call", {
        "name": "post_message",
        "arguments": {"to": "*", "kind": "note", "body": "all-hands"}})
    rA = text_content(mcp_call(coord_proc, 3, "tools/call", {
        "name": "read_inbox", "arguments": {"agent_id": "A"}}))
    rB = text_content(mcp_call(coord_proc, 4, "tools/call", {
        "name": "read_inbox", "arguments": {"agent_id": "B"}}))
    assert "all-hands" in rA
    assert "all-hands" in rB


def test_acp_newline_post_into_store(coord_proc):
    """ACP face: a newline-JSON client can post a message."""
    # ACP isn't MCP-framed; the same stdio server accepts a bare
    # newline-delimited JSON object with method 'coord/post'.
    acp_msg = {"jsonrpc": "2.0", "id": 99, "method": "coord/post",
               "params": {"to": "B", "kind": "note", "body": "from-acp"}}
    coord_proc.stdin.write(acp_encode(acp_msg).encode())
    coord_proc.stdin.flush()
    line = coord_proc.stdout.readline()
    resp = json.loads(line)
    assert resp.get("id") == 99
    # and it's visible via MCP read
    mcp_initialize_and_ping(coord_proc)
    r = text_content(mcp_call(coord_proc, 5, "tools/call", {
        "name": "read_inbox", "arguments": {"agent_id": "B"}}))
    assert "from-acp" in r


def text_content(resp):
    """Extract text from an MCP tools/call result (text content list)."""
    result = resp.get("result", {})
    content = result.get("content") or []
    parts = [c.get("text", "") for c in content if c.get("type") == "text"]
    return "\n".join(parts)