#!/usr/bin/env python3
"""MCP stdio server dispatch test, hermetic (plan step 1, omp-hngh integration).

Contract: the server spawned as a subprocess answers initialize, tools/list,
and tools/call over stdio. The kernel/readout CLIs are expensive or
daemon-backed, so the subprocess env points HNGH_MCP_KERNEL and repo-root
seams at stub scripts in a temp dir; the protocol layer itself is exercised
for real over stdio. Fail-closed: a non-zero CLI exit yields an isError
result, never a fake payload.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVER = ROOT / "mcp" / "hngh_mcp_server.py"


class McpServer(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.kernel_stub = self.root / "hngh-stub.sh"
        self.kernel_stub.write_text(
            "#!/usr/bin/env bash\n"
            'case "$1" in\n'
            "  present) echo 'run: demo ok' ;;\n"
            "  status) echo 'status: green' ;;\n"
            "  *) echo 'usage' >&2; exit 2 ;;\n"
            "esac\n")
        self.kernel_stub.chmod(0o755)
        self.queue_stub = self.root / "report-queue"
        self.queue_stub.write_text(
            "#!/usr/bin/env bash\nprintf '%s\\n' '{\"reports\":[]}'\n")
        self.queue_stub.chmod(0o755)
        self.dash_stub = self.root / "dashboard-readout"
        self.dash_stub.write_text(
            "#!/usr/bin/env bash\nprintf '%s\\n' '{\"spine\":1}'\n")
        self.dash_stub.chmod(0o755)
        self.fail_stub = self.root / "hngh-fail.sh"
        self.fail_stub.write_text(
            "#!/usr/bin/env bash\necho boom >&2\nexit 3\n")
        self.fail_stub.chmod(0o755)
        self.auto = self.root / "automation"
        self.auto.mkdir(parents=True, exist_ok=True)
        (self.auto / "research-lines.tsv").write_text(
            "alpha\treviewed\t2026-09-08T00:00:00Z\talpha line\n"
            "beta\topen\t2026-09-09T00:00:00Z\tbeta line\n")
        (self.auto / "research-dispositions.tsv").write_text(
            "line\taction\tverdict\treviewer\tevidence\tdate\n"
            "alpha\tadopted\tadopted -- keep\tmodel:x\t/path/e.md\t2026-09-08\n")

    def _server_env(self, kernel=None):
        repo = self.root / "repo"
        (repo / "scripts").mkdir(parents=True, exist_ok=True)
        for name in ("report-queue", "dashboard-readout"):
            stub = repo / "scripts" / name
            stub.write_text((self.queue_stub if name == "report-queue"
                             else self.dash_stub).read_text())
            stub.chmod(0o755)
        env = dict(os.environ)
        env.update({
            "HNGH_MCP_REPO_ROOT": str(repo),
            "HNGH_MCP_KERNEL_CMD": "scripts/hngh-wrapped",
            "HNGH_MCP_KERNEL": kernel or str(self.kernel_stub),
            "HNGH_MCP_AUTOMATION_ROOT": str(self.auto),
        })
        return env

    def _rpc(self, proc, obj):
        proc.stdin.write(json.dumps(obj) + "\n")
        proc.stdin.flush()
        return json.loads(proc.stdout.readline())

    def _spawn(self, **kw):
        return subprocess.Popen(
            [sys.executable, str(SERVER)],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, text=True,
            env=self._server_env(**kw))

    def test_initialize_tools_and_call(self):
        proc = self._spawn()
        try:
            init = self._rpc(proc, {"jsonrpc": "2.0", "id": 1, "method": "initialize",
                                    "params": {}})
            self.assertEqual(init["result"]["serverInfo"]["name"], "hngh")
            self.assertTrue(init["result"]["protocolVersion"])
            names = {t["name"] for t in
                     self._rpc(proc, {"jsonrpc": "2.0", "id": 2, "method": "tools/list"})["result"]["tools"]}
            self.assertEqual(names, {"hngh_present", "hngh_status",
                                     "queue_report", "dashboard_readout", "research_lines"})
            call = self._rpc(proc, {"jsonrpc": "2.0", "id": 3, "method": "tools/call",
                                    "params": {"name": "hngh_present", "arguments": {}}})
            self.assertIn("run: demo ok", call["result"]["content"][0]["text"])
            queue = self._rpc(proc, {"jsonrpc": "2.0", "id": 4, "method": "tools/call",
                                     "params": {"name": "queue_report"}})
            self.assertIn("reports", queue["result"]["content"][0]["text"])
        finally:
            proc.stdin.close(); proc.stdout.close()
            proc.wait(timeout=10)

    def test_unknown_tool_errors(self):
        proc = self._spawn()
        try:
            resp = self._rpc(proc, {"jsonrpc": "2.0", "id": 9, "method": "tools/call",
                                    "params": {"name": "nope"}})
            self.assertEqual(resp["error"]["code"], -32601)
        finally:
            proc.stdin.close(); proc.stdout.close()
            proc.wait(timeout=10)

    def test_failing_command_is_error_result(self):
        proc = self._spawn(kernel=str(self.fail_stub))
        try:
            resp = self._rpc(proc, {"jsonrpc": "2.0", "id": 5, "method": "tools/call",
                                    "params": {"name": "hngh_status"}})
            self.assertTrue(resp["result"]["isError"])
            self.assertIn("boom", resp["result"]["content"][0]["text"])
        finally:
            proc.stdin.close(); proc.stdout.close()
            proc.wait(timeout=10)

    def test_research_lines_parses_fixtures(self):
        proc = self._spawn()
        try:
            resp = self._rpc(proc, {"jsonrpc": "2.0", "id": 20, "method": "tools/call",
                                    "params": {"name": "research_lines"}})
            self.assertFalse(resp["result"].get("isError"))
            data = json.loads(resp["result"]["content"][0]["text"])
            self.assertEqual(data["counts"], {"lines": 2, "dispositions": 1})
            self.assertFalse(data["truncated"])
            self.assertEqual(data["lines"][1],
                             {"line": "beta", "status": "open",
                              "date": "2026-09-09T00:00:00Z", "title": "beta line"})
            self.assertEqual(data["dispositions"][0]["action"], "adopted")
            self.assertEqual(data["dispositions"][0]["verdict"], "adopted -- keep")
        finally:
            proc.stdin.close(); proc.stdout.close()
            proc.wait(timeout=10)

    def test_research_lines_reflects_live_appends(self):
        proc = self._spawn()
        try:
            with (self.auto / "research-lines.tsv").open("a") as fh:
                fh.write("gamma\tscouted\t2026-09-10T00:00:00Z\tgamma line\n")
            resp = self._rpc(proc, {"jsonrpc": "2.0", "id": 21, "method": "tools/call",
                                    "params": {"name": "research_lines"}})
            data = json.loads(resp["result"]["content"][0]["text"])
            self.assertEqual(data["counts"]["lines"], 3)
            self.assertEqual(data["lines"][2]["line"], "gamma")
        finally:
            proc.stdin.close(); proc.stdout.close()
            proc.wait(timeout=10)

    def test_research_lines_truncates_over_cap(self):
        cap = 200
        (self.auto / "research-lines.tsv").write_text("".join(
            "r%03d\topen\t2026-09-10T00:00:00Z\trow %d\n" % (i, i)
            for i in range(cap + 50)))
        proc = self._spawn()
        try:
            resp = self._rpc(proc, {"jsonrpc": "2.0", "id": 22, "method": "tools/call",
                                    "params": {"name": "research_lines"}})
            data = json.loads(resp["result"]["content"][0]["text"])
            self.assertTrue(data["truncated"])
            self.assertEqual(data["counts"]["lines"], cap)
            self.assertEqual(data["lines"][-1]["line"], "r199")
        finally:
            proc.stdin.close(); proc.stdout.close()
            proc.wait(timeout=10)


if __name__ == "__main__":
    unittest.main()
